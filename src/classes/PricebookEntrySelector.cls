public with sharing class PricebookEntrySelector {
    /**
     * Retourne les offres de transport sous forme de PricebookEntry
     * Champs custom attendus :
     *  - PricebookEntry.ZoneCode__c (Texte) : code de zone
     *  - PricebookEntry.LeadTimeDays__c (Nombre) : délai en jours
     *  - Product2.ServiceLevel__c (Picklist) : niveau service (Economy, Standard, Express...)
     *  - Product2.Carrier__c (Lookup -> Carrier__c) : transporteur
     */
    public static List<PricebookEntry> listActiveByZone(String zoneCodeOpt) {
        String z = (zoneCodeOpt == null) ? null : zoneCodeOpt.trim();
        String soql =
            'SELECT Id, UnitPrice, IsActive, ZoneCode__c, LeadTimeDays__c, ' +
            '       Pricebook2Id, Pricebook2.IsActive, ' +
            '       Product2Id, Product2.Name, Product2.ServiceLevel__c, Product2.Carrier__c, ' +
            '       Product2.Carrier__r.Name ' +
            'FROM PricebookEntry ' +
            'WHERE IsActive = true AND Pricebook2.IsActive = true';
        if (z != null && z != '') {
            soql += ' AND ZoneCode__c = :z';
            return Database.query(soql);
        }
        return Database.query(soql);
    }
}
