trigger OrderTrigger on Order (before insert, before update) {

    List<Order> ordersToValidate = new List<Order>();

    for(Order newOrder : Trigger.new){
        Order oldOrder = Trigger.isUpdate ? Trigger.oldMap.get(newOrder.Id) : null;

        // Condition : La commande est nouvelle et "Activated" OU le statut vient de changer pour "Activated"
        if(newOrder.Status == 'Activated' && (Trigger.isInsert || oldOrder.Status != 'Activated')){
            ordersToValidate.add(newOrder);
        }
    }

    // N'appelle le handler que si c'est nécessaire
    if(!ordersToValidate.isEmpty()){
        OrderTriggerHandler.validateMinimumItems(ordersToValidate);
    }
}