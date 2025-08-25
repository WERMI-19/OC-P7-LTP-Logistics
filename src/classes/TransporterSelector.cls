// Calcule les options de transport compatibles pour une commande.
public with sharing class TransporterSelector {

    // DTO simple pour exposer les options de transport.
    public class TransportOption {
        @AuraEnabled public Id carrierId;
        @AuraEnabled public Id pbeId;
        @AuraEnabled public String carrierName;
        @AuraEnabled public String serviceLevel;
        @AuraEnabled public Decimal price;
        @AuraEnabled public Integer leadTimeDays;
        @AuraEnabled public String zone;
    }

    // Dérive la zone (FR, BE, CH, LU) à partir du pays de livraison de la commande.
    public static String deriveZoneCode(Order o){
        String c = (o != null && o.ShippingCountry != null) ? o.ShippingCountry.trim().toUpperCase() : null;
        if(c == null) return null;
        if(c == 'FR' || c == 'FRANCE') return 'FR';
        if(c == 'BE' || c == 'BELGIQUE' || c == 'BELGIUM') return 'BE';
        if(c == 'CH' || c == 'SUISSE' || c == 'SWITZERLAND') return 'CH';
        if(c == 'LU' || c == 'LUXEMBOURG') return 'LU';
        return null;
    }

    // Retourne les options de transport compatibles pour une commande donnée.
    public static List<TransportOption> forOrder(Id orderId){
        if(orderId == null) return new List<TransportOption>();

        Order o = [SELECT Id, AccountId, Pricebook2Id, ShippingCountry FROM Order WHERE Id = :orderId LIMIT 1];

        // Préconditions: une zone valide, un catalogue de prix et un compte sont requis.
        String zone = deriveZoneCode(o);
        if(String.isBlank(zone) || o.Pricebook2Id == null || o.AccountId == null){
            return new List<TransportOption>();
        }

        // Le type de client détermine les transporteurs compatibles.
        Account a = [SELECT CustomerType__c FROM Account WHERE Id = :o.AccountId LIMIT 1];
        Boolean isBusiness = (a.CustomerType__c == 'Professionnel');

        // Sélectionne les entrées de catalogue actives pour la zone concernée.
        List<PricebookEntry> entries = [
            SELECT UnitPrice, LeadTimeDays__c, Product2.ServiceLevel__c, Product2.Carrier__c
            FROM PricebookEntry
            WHERE Pricebook2Id = :o.Pricebook2Id AND ZoneCode__c = :zone AND IsActive = true
        ];

        Set<Id> carrierIds = new Set<Id>();
        for(PricebookEntry pbe : entries){
            if(pbe.Product2 != null && pbe.Product2.Carrier__c != null){
                carrierIds.add(pbe.Product2.Carrier__c);
            }
        }

        if(carrierIds.isEmpty()) return new List<TransportOption>();

        // Charge les transporteurs actifs et filtre par compatibilité B2B/B2C.
        Map<Id, Carrier__c> carriersById = new Map<Id, Carrier__c>([
            SELECT Name, SupportsBusiness__c, SupportsConsumers__c
            FROM Carrier__c WHERE Id IN :carrierIds AND Active__c = true
        ]);

        // Construit la liste finale des options compatibles.
        List<TransportOption> out = new List<TransportOption>();
        for(PricebookEntry pbe : entries){
            Carrier__c carrier = carriersById.get(pbe.Product2.Carrier__c);
            
            if(carrier == null) continue; // Exclut si le transporteur est inactif.
            if((isBusiness && !carrier.SupportsBusiness__c) || (!isBusiness && !carrier.SupportsConsumers__c) ){
                continue; // Exclut si incompatible avec le type de client.
            }

            TransportOption opt = new TransportOption();
            opt.carrierId    = carrier.Id;
            opt.pbeId        = pbe.Id;
            opt.carrierName  = carrier.Name;
            opt.serviceLevel = pbe.Product2.ServiceLevel__c;
            opt.price        = pbe.UnitPrice;
            opt.leadTimeDays = (pbe.LeadTimeDays__c == null) ? 0 : Integer.valueOf(pbe.LeadTimeDays__c);
            opt.zone         = zone;
            out.add(opt);
        }
        return out;
    }
}