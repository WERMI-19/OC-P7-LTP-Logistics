public with sharing class CarrierSelector {
    /**
     * Sélecteur pour l'objet Carrier__c (Transporteur)
     * Règles : retourner uniquement les transporteurs actifs.
     */
    public static List<Carrier__c> listActive() {
        return [SELECT Id, Name, Code__c, Active__c, SupportsBusiness__c, SupportsConsumers__c
                FROM Carrier__c
                WHERE Active__c = true];
    }

    public static Map<Id, Carrier__c> mapByIds(Set<Id> ids) {
        if (ids == null || ids.isEmpty()) return new Map<Id, Carrier__c>();
        return new Map<Id, Carrier__c>([SELECT Id, Name, Code__c, Active__c, SupportsBusiness__c, SupportsConsumers__c
                                        FROM Carrier__c
                                        WHERE Id IN :ids AND Active__c = true]);
    }
}
