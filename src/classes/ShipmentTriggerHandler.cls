public with sharing class ShipmentTriggerHandler {
    public static void beforeInsert(List<Shipment__c> listNew) {
        for (Shipment__c s : listNew) {
            // Si date d'expédition manquante mais statut InTransit/Planned, définir aujourd'hui
            if (s.ShipDate__c == null && (s.Status__c == 'InTransit' || s.Status__c == 'Planned')) {
                s.ShipDate__c = Date.today();
            }
            // Si EstimatedLeadTimeHours__c défini mais pas EstimatedDeliveryDate__c, calculer
            if (s.EstimatedLeadTimeHours__c != null && s.EstimatedDeliveryDate__c == null) {
                Integer days = Integer.valueOf(Math.floor((Decimal)s.EstimatedLeadTimeHours__c / 24));
                s.EstimatedDeliveryDate__c = (s.ShipDate__c != null ? s.ShipDate__c : Date.today()).addDays(days);
            }
        }
    }
    public static void beforeUpdate(List<Shipment__c> newList, Map<Id, Shipment__c> oldMap) {
        for (Shipment__c s : newList) {
            Shipment__c oldS = oldMap.get(s.Id);
            // Passage à livré si la date réelle est renseignée
            if (s.ActualDeliveryDate__c != null && s.Status__c != 'Delivered') {
                s.Status__c = 'Delivered';
            }
            // Définir ShipDate s'il passe en transit
            if (oldS.Status__c != 'InTransit' && s.Status__c == 'InTransit' && s.ShipDate__c == null) {
                s.ShipDate__c = Date.today();
            }
            // Recalculer l'ETA si délai changé
            if (s.EstimatedLeadTimeHours__c != oldS.EstimatedLeadTimeHours__c) {
                Integer days = (s.EstimatedLeadTimeHours__c == null) ? null :
                    Integer.valueOf(Math.floor((Decimal)s.EstimatedLeadTimeHours__c / 24));
                if (days != null) {
                    Date base = (s.ShipDate__c != null) ? s.ShipDate__c :
                                (oldS.ShipDate__c != null ? oldS.ShipDate__c : Date.today());
                    s.EstimatedDeliveryDate__c = base.addDays(days);
                }
            }
        }
    }
}
