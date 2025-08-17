public with sharing class OrderItemSelector {
    /**
     * Compte les OrderItem par Order, bulk-safe.
     */
    public static Map<Id, Integer> countByOrder(Set<Id> orderIds) {
        Map<Id, Integer> out = new Map<Id, Integer>();
        if (orderIds == null || orderIds.isEmpty()) return out;
        for (AggregateResult ar : [
            SELECT OrderId oid, COUNT(Id) cnt
            FROM OrderItem
            WHERE OrderId IN :orderIds
            GROUP BY OrderId
        ]) {
            out.put((Id) ar.get('oid'), (Integer) ar.get('cnt'));
        }
        return out;
    }
}
