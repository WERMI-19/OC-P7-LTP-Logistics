public with sharing class OrderRulesService {
    // Selon cahier des charges : Particuliers = 3, Professionnels = 5
    public static final Integer MIN_ITEMS_PRO = 5;
    public static final Integer MIN_ITEMS_PART = 3;

    /**
     * Valide la règle métier "nombre minimal de produits" au moment
     * où la commande passe à Status = 'Activated'.
     * La règle dépend du type de client via Account.CustomerType__c.
     */
    public static void validateMinimumItems(List<Order> orders) {
        if (orders == null || orders.isEmpty()) return;

        Set<Id> orderIds = new Set<Id>();
        Set<Id> accountIds = new Set<Id>();
        for (Order o : orders) {
            orderIds.add(o.Id);
            if (o.AccountId != null) accountIds.add(o.AccountId);
        }

        // Compter les OrderItem par commande
        Map<Id, Integer> counts = OrderItemSelector.countByOrder(orderIds);

        // Charger les types de clients
        Map<Id, Account> accMap = new Map<Id, Account>();
        if (!accountIds.isEmpty()) {
            accMap = new Map<Id, Account>([
                SELECT Id, Name, CustomerType__c
                FROM Account
                WHERE Id IN :accountIds
            ]);
        }

        for (Order o : orders) {
            if (o.Status == null) continue;
            if (o.Status.equalsIgnoreCase('Activated')) {
                Account a = (o.AccountId != null) ? accMap.get(o.AccountId) : null;
                String custType = (a != null) ? String.valueOf(a.CustomerType__c) : null;
                Integer minItems = (custType == 'PRO') ? MIN_ITEMS_PRO : MIN_ITEMS_PART;
                Integer have = counts.get(o.Id);
                have = (have == null) ? 0 : have;
                if (have < minItems) {
                    o.addError('Un ordre doit contenir au moins ' + minItems + ' produit(s) pour être activé '
                               + '(Type client = ' + (custType == null ? 'N/A' : custType) + ', trouvés = ' + have + ').');
                }
            }
        }
    }
}
