// Classe: TransporterSelector - calcule les options de transport compatibles pour une commande
// Règle: on respecte le MDD (Product2.Carrier__c, Product2.ServiceLevel__c, PBE.ZoneCode__c, PBE.LeadTimeDays__c)

public with sharing class TransporterSelector {

    // DTO simple exposé au LWC — valeurs calculées sur PBE/Produit/Transporteur
    public class TransportOption {
        @AuraEnabled public Id carrierId;       // Id du Transporteur sélectionné
        @AuraEnabled public String carrierName; // Nom du transporteur
        @AuraEnabled public String serviceLevel;// Niveau de service (Product2.ServiceLevel__c)
        @AuraEnabled public Decimal price;      // Prix (PricebookEntry.UnitPrice)
        @AuraEnabled public Integer leadTimeDays; // Délai (PricebookEntry.LeadTimeDays__c)
        @AuraEnabled public String zone;        // Zone dérivée (FR/BE/CH/LU)
    }

    // Dérive la zone à partir du pays de livraison — à adapter si plus de pays/logic
    public static String deriveZoneCode(Order o){
        // Sécurité: null-check
        String c = (o != null && o.ShippingCountry != null) ? o.ShippingCountry.trim().toUpperCase() : null; // normalise
        if(c == null) return null; // rien à faire si pays manquant
        if(c == 'FR' || c == 'FRANCE') return 'FR'; // map simple pays->zone
        if(c == 'BE' || c == 'BELGIQUE' || c == 'BELGIUM') return 'BE'; // BE
        if(c == 'CH' || c == 'SUISSE' || c == 'SWITZERLAND') return 'CH'; // CH
        if(c == 'LU' || c == 'LUXEMBOURG') return 'LU'; // LU
        return null; // zone non supportée -> pas d'options
    }

    // Retourne les options compatibles pour une commande donnée (filtrage par zone + type de compte)
    public static List<TransportOption> forOrder(Id orderId){
        // Robustesse: entrée invalide -> liste vide
        if(orderId == null) return new List<TransportOption>(); // aucun travail sans Id

        // On récupère les infos minimales nécessaires à la sélection
        Order o = [SELECT Id, AccountId, Pricebook2Id, ShippingCountry, ShippingPostalCode, ShippingState
                   FROM Order WHERE Id = :orderId LIMIT 1]; // requête ciblée

        // Préconditions: zone dérivée + PB assigné + compte lié
        String zone = deriveZoneCode(o); // calcule la zone à partir du pays
        if(String.isBlank(zone) || o.Pricebook2Id == null || o.AccountId == null){
            return new List<TransportOption>(); // retourne vide si prérequis manquants
        }

        // On doit connaître le type de client (Business vs Consumer) pour filtrer les transporteurs
        Account a = [SELECT Id, Name, CustomerType__c FROM Account WHERE Id = :o.AccountId LIMIT 1]; // lis le type
        Boolean isBusiness = (a.CustomerType__c == 'Business'); // calcule le flag pro

        // Sélectionne les entrées de catalogue actives pour la zone concernée (clé: PricebookEntry)
        List<PricebookEntry> entries = [
            SELECT Id, UnitPrice, LeadTimeDays__c, Product2Id,
                   Product2.ServiceLevel__c, Product2.Carrier__c, Product2.IsActive
            FROM PricebookEntry
            WHERE Pricebook2Id = :o.Pricebook2Id
              AND ZoneCode__c   = :zone
              AND IsActive      = true
        ]; // récupère les offres de transport disponibles

        // Collecte les transporteurs associés aux produits (Product2.Carrier__c)
        Set<Id> carrierIds = new Set<Id>(); // contiendra les Id de transporteurs
        for(PricebookEntry pbe : entries){
            if(pbe.Product2 != null && pbe.Product2.IsActive && pbe.Product2.Carrier__c != null){
                carrierIds.add(pbe.Product2.Carrier__c); // agrège les transporteurs éligibles
            }
        }

        // Si aucun transporteur trouvé, on s'arrête proprement
        if(carrierIds.isEmpty()) return new List<TransportOption>(); // pas d'options

        // Charge les transporteurs et filtre par compatibilité B2B/B2C + actif
        Map<Id, Carrier__c> carriersById = new Map<Id, Carrier__c>([
            SELECT Id, Name, Active__c, SupportsBusiness__c, SupportsConsumers__c
            FROM Carrier__c WHERE Id IN :carrierIds AND Active__c = true
        ]); // dictionnaire des transporteurs actifs

        // Construit les options compatibles (zone + B2B/B2C + produit actif)
        List<TransportOption> out = new List<TransportOption>(); // résultat à retourner
        for(PricebookEntry pbe : entries){
            Carrier__c carrier = carriersById.get(pbe.Product2.Carrier__c); // map PBE -> transporteur
            if(carrier == null) continue; // exclut si transporteur inactif/non chargé
            if( (isBusiness && !carrier.SupportsBusiness__c) || (!isBusiness && !carrier.SupportsConsumers__c) ){
                continue; // incompatible avec le type de client
            }
            TransportOption opt = new TransportOption(); // instancie le DTO
            opt.carrierId    = carrier.Id; // identifiant du transporteur
            opt.carrierName  = carrier.Name; // libellé du transporteur
            opt.serviceLevel = pbe.Product2.ServiceLevel__c; // niveau de service
            opt.price        = pbe.UnitPrice; // prix de l'offre
            opt.leadTimeDays = (pbe.LeadTimeDays__c == null) ? 0 : Integer.valueOf(pbe.LeadTimeDays__c); // délai
            opt.zone         = zone; // renseigne la zone utilisée
            out.add(opt); // ajoute l'option à la liste
        }
        return out; // renvoie toutes les options compatibles
    }
}