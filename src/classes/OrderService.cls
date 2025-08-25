// Services métier pour le LWC "Lancer une livraison"
public with sharing class OrderService {

    @TestVisible public static Boolean TEST_BYPASS_PERMISSION = false;

    // DTO retourné au LWC
    public class OptionsDTO {
        @AuraEnabled public List<TransporterSelector.TransportOption> compatible;
        @AuraEnabled public TransporterSelector.TransportOption fastest;
        @AuraEnabled public TransporterSelector.TransportOption cheapest;
        @AuraEnabled public String shippingCountry;
        @AuraEnabled public Integer totalQuantity;  
    }

    // Vérifie la permission "Can_Launch_Delivery"
    private static void ensurePermission(){
        if(TEST_BYPASS_PERMISSION) return;
        if(!FeatureManagement.checkPermission('Can_Launch_Delivery')){
            throw new AuraHandledException('Accès refusé: la permission requise est manquante.');
        }
    }

    // Calcule les options de transport pour une commande donnée
    @AuraEnabled(cacheable=true)
    public static OptionsDTO computeOptions(Id orderId, String refreshKey){
        if(orderId == null) throw new AuraHandledException('Order Id requis');

        Order o = [SELECT Id, ShippingCountry FROM Order WHERE Id = :orderId LIMIT 1];
        List<TransporterSelector.TransportOption> allOpts = TransporterSelector.forOrder(orderId);
        
        TransporterSelector.TransportOption fastest, cheapest;
        for(TransporterSelector.TransportOption opt : allOpts){
            if(cheapest == null || (opt.price != null && opt.price < cheapest.price)) cheapest = opt;
            if(fastest  == null || (opt.leadTimeDays != null && opt.leadTimeDays < fastest.leadTimeDays)) fastest  = opt;
        }

        OptionsDTO dto = new OptionsDTO();
        dto.compatible = allOpts;
        dto.fastest    = fastest;
        dto.cheapest   = cheapest;
        dto.shippingCountry = o.ShippingCountry; 
        return dto;
    }

    /**
     * @description Crée un enregistrement Shipment__c basé sur le service exact (PricebookEntry) choisi par l'utilisateur.
     * @param orderId L'ID de la commande.
     * @param pbeId L'ID de la PricebookEntry sélectionnée dans l'interface.
     * @param trackingNumber Le numéro de suivi optionnel.
     * @return Le Shipment__c créé.
     */
    @AuraEnabled
    public static Shipment__c launchDelivery(Id orderId, Id pbeId, String trackingNumber){
        if(orderId == null || pbeId == null) throw new AuraHandledException('Order Id et PricebookEntry Id requis');
        ensurePermission();

        Order o = [SELECT Id, Pricebook2Id, ShippingCountry, ShippingPostalCode, ShippingState
                   FROM Order WHERE Id = :orderId LIMIT 1];

        String zone = TransporterSelector.deriveZoneCode(o);
        if(String.isBlank(zone)) throw new AuraHandledException('Pays de livraison manquant ou non supporté');
        
        // Sélectionne directement l'entrée de catalogue choisie par l'utilisateur, ce qui élimine toute ambiguïté.
        PricebookEntry chosen = [
            SELECT Id, UnitPrice, LeadTimeDays__c, Product2.Carrier__c
            FROM PricebookEntry
            WHERE Id = :pbeId AND IsActive = true
            LIMIT 1
        ];

        Integer leadDays = (chosen.LeadTimeDays__c == null) ? 0 : Integer.valueOf(chosen.LeadTimeDays__c);

        Shipment__c sh = new Shipment__c(
            Order__c                   = o.Id,
            Carrier__c                 = chosen.Product2.Carrier__c, // L'ID du transporteur vient du service choisi
            Status__c                  = 'Created',
            ShipDate__c                = Date.today(),
            ZoneCode__c                = zone,
            DestinationCountry__c      = o.ShippingCountry,
            DestinationRegion__c       = o.ShippingState,
            DestinationPostalCode__c   = o.ShippingPostalCode,
            ShippingCost__c            = chosen.UnitPrice,
            EstimatedLeadTimeHours__c  = leadDays * 24,
            EstimatedDeliveryDate__c   = Date.today().addDays(leadDays),
            TrackingNumber__c          = String.isBlank(trackingNumber) ? generateTracking(orderId) : trackingNumber.trim()
        ); 

        insert sh;
        return sh;
    }

    // Génère un numéro de suivi unique
    private static String generateTracking(Id orderId){
        return 'SHIP-' + String.valueOf(orderId).right(5) + '-' + Datetime.now().getTime();
    }
}