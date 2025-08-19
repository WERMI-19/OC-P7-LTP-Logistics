@IsTest
// Tests du trigger Order -> règle "minimum d'items" (3 Consumer / 5 Business)
// Méthode: on utilise le handler directement via insert/update en situation réelle
// Cas: (1) Consumer avec 2 items -> erreur ; (2) Business avec 5 items -> OK
// Données: PB standard + PBE simple pour permettre la création d'OrderItem
// Message: valide que l'erreur contient la contrainte (non vide)
public class OrderTriggerHandlerTest {

    @IsTest
    static void consumer_with2Items_cannotActivate(){
        Id stdPb = Test.getStandardPricebookId(); // PB
        Account a = TestDataFactory.makeAccount('Consumer'); // particulier

        Carrier__c c = TestDataFactory.makeCarrier(true,true); // transporteur
        Product2 p = TestDataFactory.makeProduct(c.Id, 'Standard'); // produit
        PricebookEntry e = TestDataFactory.makePbe(stdPb, p.Id, 10, 'FR', 3); // PBE

        Order o = TestDataFactory.makeOrder(a.Id, stdPb); // commande
        TestDataFactory.makeOi(o.Id, e.Id, 1); // item 1
        TestDataFactory.makeOi(o.Id, e.Id, 1); // item 2

        o.Status = 'Activated'; // tente l'activation
        try{
            update o; // doit lever une erreur
            System.assert(false, 'Une erreur était attendue'); // ne doit pas passer
        } catch (DmlException ex){
            System.assert(ex.getMessage().contains('au moins'), 'Le message doit mentionner le minimum'); // message
        }
    }

    @IsTest
    static void business_with5Items_canActivate(){
        Id stdPb = Test.getStandardPricebookId(); // PB
        Account a = TestDataFactory.makeAccount('Business'); // pro

        Carrier__c c = TestDataFactory.makeCarrier(true,false); // B2B only
        Product2 p = TestDataFactory.makeProduct(c.Id, 'Standard'); // produit
        PricebookEntry e = TestDataFactory.makePbe(stdPb, p.Id, 10, 'FR', 2); // PBE

        Order o = TestDataFactory.makeOrder(a.Id, stdPb); // commande
        // Ajoute 5 items
        for(Integer i=0; i<5; i++){
            TestDataFactory.makeOi(o.Id, e.Id, 1); // ajoute items
        }

        o.Status = 'Activated'; // activation autorisée
        Test.startTest();
        update o; // ne doit pas lever
        Test.stopTest();

        System.assertEquals('Activated', [SELECT Status FROM Order WHERE Id = :o.Id].Status, 'Activation doit réussir'); // OK
    }
}
