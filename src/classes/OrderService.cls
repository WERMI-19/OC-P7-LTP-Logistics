// Classe: OrderService – services métier pour le LWC "Lancer une livraison"
// Rôle: calculer les options (DTO) et créer un Shipment__c complet (coût, délai, ETA, tracking)
// Sécurité: protégé par Custom Permission "Can_Launch_Delivery" (vérifiée côté serveur)
// MDD: s'appuie sur Product2.Carrier__c / ServiceLevel__c et PricebookEntry.ZoneCode__c / LeadTimeDays__c
// Anti-cache: computeOptions prend "refreshKey" pour casser le cache storable sans changer la logique
// Testabilité: TEST_BYPASS_PERMISSION permet d'exécuter les tests sans Custom Permission
// Robustesse: messages clairs via AuraHandledException pour le LWC
// Partage: "with sharing" pour respecter FLS / rules en runtime
public with sharing class OrderService {

    // Flag de test: autorise à ignorer la Custom Permission pendant les tests unitaires
    @TestVisible public static Boolean TEST_BYPASS_PERMISSION = false; // switch test

    // DTO retourné au LWC: liste compatible + la plus rapide + la moins chère
    public class OptionsDTO {
        @AuraEnabled public List<TransporterSelector.TransportOption> compatible; // toutes les options
        @AuraEnabled public TransporterSelector.TransportOption fastest;          // délai min
        @AuraEnabled public TransporterSelector.TransportOption cheapest;         // prix min
        @AuraEnabled public String shippingCountry; // <-- LIGNE AJOUTÉE
    }

    // Vérifie la permission "Can_Launch_Delivery" (ou bypass si test)
    private static void ensurePermission(){
        if(TEST_BYPASS_PERMISSION) return; // autorise en test
        if(!FeatureManagement.checkPermission('Can_Launch_Delivery')){
            throw new AuraHandledException('Accès refusé: permission requise.'); // message lisible
        }
    }

    // Calcule les options transport pour une commande (param "refreshKey" casse le cache)
    @AuraEnabled(cacheable=true)
    public static OptionsDTO computeOptions(Id orderId, String refreshKey){
        if(orderId == null) throw new AuraHandledException('Order Id requis'); // garde-fou

        // <-- BLOC AJOUTÉ : Récupérer la commande pour son pays de livraison
        Order o = [SELECT Id, ShippingCountry FROM Order WHERE Id = :orderId LIMIT 1];

        List<TransporterSelector.TransportOption> allOpts = TransporterSelector.forOrder(orderId); // collecte
        TransporterSelector.TransportOption fastest, cheapest; // init
        for(TransporterSelector.TransportOption opt : allOpts){
            if(cheapest == null || (opt.price != null && opt.price < cheapest.price)) cheapest = opt; // moins chère
            if(fastest  == null || (opt.leadTimeDays != null && opt.leadTimeDays < fastest.leadTimeDays)) fastest  = opt; // plus rapide
        }
        OptionsDTO dto = new OptionsDTO(); // construction du DTO
        dto.compatible = allOpts; // liste
        dto.fastest    = fastest; // plus rapide
        dto.cheapest   = cheapest; // moins chère
        dto.shippingCountry = o.ShippingCountry; // <-- LIGNE AJOUTÉE

        return dto; // retour LWC
    }

    // Lance la livraison: crée Shipment__c avec coût/délai/ETA/tracking à partir du carrier choisi
    @AuraEnabled
    public static Shipment__c launchDelivery(Id orderId, Id carrierId, String trackingNumber){
        if(orderId == null || carrierId == null) throw new AuraHandledException('Order Id et Carrier Id requis'); // input
        ensurePermission(); // protège l’action critique

        // Charge l'ordre (Pricebook + adresse) et dérive la zone (FR/BE/CH/LU)
        Order o = [SELECT Id, Pricebook2Id, ShippingCountry, ShippingPostalCode, ShippingState
                   FROM Order WHERE Id = :orderId LIMIT 1]; // requête ciblée
        String zone = TransporterSelector.deriveZoneCode(o); // calcule la zone
        if(String.isBlank(zone))   throw new AuraHandledException('Pays de livraison manquant ou non supporté'); // contrôle zone
        if(o.Pricebook2Id == null) throw new AuraHandledException('La commande n\'a pas de catalogue de prix');   // contrôle PB

        // Sélectionne la meilleure PBE pour ce transporteur dans la zone de l'ordre (tri prix ASC)
        PricebookEntry chosen = [
            SELECT Id, UnitPrice, LeadTimeDays__c, Product2.ServiceLevel__c
            FROM PricebookEntry
            WHERE Pricebook2Id = :o.Pricebook2Id
              AND ZoneCode__c   = :zone
              AND IsActive      = true
              AND Product2.Carrier__c = :carrierId
            ORDER BY UnitPrice ASC NULLS LAST
            LIMIT 1
        ]; // PBE choisie

        Integer leadDays = (chosen.LeadTimeDays__c == null) ? 0 : Integer.valueOf(chosen.LeadTimeDays__c); // délai jours

        // Construit la Shipment__c complète selon le MDD
        Shipment__c sh = new Shipment__c(
            Order__c                   = o.Id,                              // relation Order
            Carrier__c                 = carrierId,                         // relation Carrier
            Status__c                  = 'Created',                         // statut initial
            ShipDate__c                = Date.today(),                      // date d'expédition
            ZoneCode__c                = zone,                               // zone de livraison
            DestinationCountry__c      = o.ShippingCountry,                 // pays destination
            DestinationRegion__c       = o.ShippingState,                   // région destination
            DestinationPostalCode__c   = o.ShippingPostalCode,              // code postal destination
            ShippingCost__c            = chosen.UnitPrice,                  // coût transport
            EstimatedLeadTimeHours__c  = leadDays * 24,                     // délai en heures
            EstimatedDeliveryDate__c   = Date.today().addDays(leadDays),    // ETA
            TrackingNumber__c          = String.isBlank(trackingNumber) ? generateTracking(orderId) : trackingNumber.trim() // tracking
        ); // enregistrement prêt

        insert sh; // DML unique pour créer la livraison
        return sh; // renvoie l'enregistrement créé
    }

    // Génère un numéro de tracking lisible et unique (Id partiel + timestamp)
    private static String generateTracking(Id orderId){
        return 'SHIP-' + String.valueOf(orderId).right(5) + '-' + Datetime.now().getTime(); // format simple
    }
}