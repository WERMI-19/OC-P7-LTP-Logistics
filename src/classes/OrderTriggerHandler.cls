// Classe: OrderTriggerHandler - applique les règles métier sur Order
// Règle principale: min d'items pour activer une commande (3 pour Consumer, 5 pour Business)
// Architecture: Handler dédié pour un trigger léger/testable (Single Responsibility)
// Robustesse: regroupe les requêtes, pas de SOQL dans les boucles (bulkification)
// Explicabilité: message d'erreur contextualisé (type de client + quantité requise)
// Extensibilité: point d'entrée pour ajouter de futures règles Order (validation/normalisation)
// Sécurité: with sharing pour respecter le modèle de partage
// Testabilité: méthode statique pure — facile à couvrir depuis un test
public with sharing class OrderTriggerHandler {

    // Valide la contrainte "minimum d'items" à l'activation
    public static void validateMinimumItems(List<Order> orders){
        // Prépare les ensembles/Maps pour requêtes groupées
        Set<Id> toCheck = new Set<Id>(); // ids d'ordres à valider
        Set<Id> accountIds = new Set<Id>(); // ids de comptes liés

        // Filtre uniquement les ordres ciblés (status 'Activated')
        for(Order o : orders){
            if(o.Status == 'Activated'){ // cible uniquement l'activation
                toCheck.add(o.Id); // stocke l'Id pour agrégation
                if(o.AccountId != null) accountIds.add(o.AccountId); // garde l'account
            }
        }

        // Rien à faire si aucun ordre activé
        if(toCheck.isEmpty()) return; // sortie anticipée

        // Compte les OrderItem par Order (agrégation SOQL efficace)
        Map<Id, Integer> counts = new Map<Id, Integer>(); // map OrderId -> count
        for(AggregateResult ar : [
            SELECT OrderId oid, COUNT(Id) c FROM OrderItem
            WHERE OrderId IN :toCheck GROUP BY OrderId
        ]){
            counts.put((Id)ar.get('oid'), (Integer)ar.get('c')); // enregistre le total
        }

        // Charge le type de client pour déterminer le seuil 3/5
        Map<Id, Account> accs = new Map<Id, Account>([
            SELECT Id, CustomerType__c FROM Account WHERE Id IN :accountIds
        ]); // carte des comptes

        // Applique la règle et remonte une erreur bloquante si non conforme
        for(Order o : orders){
            if(o.Status == 'Activated'){ // uniquement à l'activation
                Account a = accs.get(o.AccountId); // récupère le compte
                Integer minItems = (a != null && a.CustomerType__c == 'Business') ? 5 : 3; // calcule le seuil
                Integer actual   = counts.get(o.Id); // nombre réel d'items

                if(actual == null || actual < minItems){ // vérifie la contrainte
                    String kind = (a!=null && a.CustomerType__c=='Business') ? 'compte pro' : 'client particulier'; // type
                    o.addError('Un ' + kind + ' doit contenir au moins ' + minItems + ' produits pour être activé.'); // message clair
                }
            }
        }
    }
}
