// Règle principale: min d'items pour activer une commande (3 pour Particulier, 5 pour Professionnel)
public with sharing class OrderTriggerHandler {

    // Valide la contrainte "minimum d'items" à l'activation
    public static void validateMinimumItems(List<Order> orders){
        Set<Id> toCheck = new Set<Id>();
        Set<Id> accountIds = new Set<Id>();

        // Filtre uniquement les ordres qui viennent d'être activés
        for(Order o : orders){
            if(o.Status == 'Activated'){
                toCheck.add(o.Id);
                if(o.AccountId != null) accountIds.add(o.AccountId);
            }
        }

        if(toCheck.isEmpty()) return; // Sortie anticipée si aucun ordre concerné

        // Compte les OrderItem par Order via une agrégation SOQL
        Map<Id, Integer> counts = new Map<Id, Integer>();
        for(AggregateResult ar : [
            SELECT OrderId oid, COUNT(Id) c FROM OrderItem
            WHERE OrderId IN :toCheck GROUP BY OrderId
        ]){
            counts.put((Id)ar.get('oid'), (Integer)ar.get('c'));
        }

        // Charge le type de client pour déterminer le seuil (3 ou 5)
        Map<Id, Account> accs = new Map<Id, Account>([
            SELECT Id, CustomerType__c FROM Account WHERE Id IN :accountIds
        ]);

        // Applique la règle et remonte une erreur bloquante si non conforme
        for(Order o : orders){
            if(o.Status == 'Activated'){
                Account a = accs.get(o.AccountId);
                Integer minItems = (a != null && a.CustomerType__c == 'Professionnel') ? 5 : 3;
                Integer actual   = counts.get(o.Id);

                if(actual == null || actual < minItems){
                    String kind = (a != null && a.CustomerType__c == 'Professionnel') ? 'compte pro' : 'client particulier';
                    o.addError('Un ' + kind + ' doit contenir au moins ' + minItems + ' produits pour être activé.');
                }
            }
        }
    }
}