trigger ShipmentTrigger on Shipment__c (before insert, before update) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) ShipmentTriggerHandler.beforeInsert(Trigger.new);
        if (Trigger.isUpdate) ShipmentTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
    }
}
