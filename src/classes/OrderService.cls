public with sharing class OrderService {

    @AuraEnabled(cacheable=false)
    public static TransportOptionService.OptionsResponse computeTransportOptions(Id orderId, String zoneCodeOpt){
        if(orderId == null) throw new AuraHandledException('orderId requis');
        // La logique des options ne dépend que de la zone dans TransportOptionService
        return TransportOptionService.computeOptions(zoneCodeOpt);
    }

    @AuraEnabled
    public static Id launchDelivery(Id orderId, Id carrierId, String zoneCodeOpt, String trackingNumberOpt){
        if(orderId == null) throw new AuraHandledException('orderId requis');

        TransportOptionService.OptionsResponse res = TransportOptionService.computeOptions(zoneCodeOpt);

        // Choix de l’option
        TransportOptionService.TransportOptionDTO chosen = null;
        if (carrierId != null && res != null && res.compatible != null) {
            for (TransportOptionService.TransportOptionDTO d : res.compatible) {
                if (d.carrierId == carrierId) {
                    chosen = d;
                    break;
                }
            }
        }
        if (chosen == null && res != null) chosen = res.cheapest;

        // Création de la shipment
        Shipment__c s = new Shipment__c();
        s.Order__c = orderId;

        if (chosen != null) {
            s.Carrier__c = chosen.carrierId;
            if (chosen.price != null) s.ShippingCost__c = chosen.price;
            if (chosen.leadTimeDays != null) {
                Integer days = chosen.leadTimeDays;                 // ✅ plus de cast Decimal -> Integer
                s.EstimatedLeadTimeHours__c = days * 24;
                s.EstimatedDeliveryDate__c  = Date.today().addDays(days);
            }
            s.ZoneCode__c = chosen.zoneCode;
        } else {
            // fallback : on garde la zone choisie par l’utilisateur
            s.ZoneCode__c = zoneCodeOpt;
        }

        s.Status__c = 'Planned';
        s.ShipDate__c = Date.today();

        if (trackingNumberOpt != null && trackingNumberOpt.trim() != '') {
            s.TrackingNumber__c = trackingNumberOpt.trim();
        }

        insert s;
        return s.Id;
    }

    
}
