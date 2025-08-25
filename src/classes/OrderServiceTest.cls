@IsTest
// Classe de test complète pour OrderService
private class OrderServiceTest {

    // Utilise @TestSetup pour créer un jeu de données commun à tous les tests
    // Cela rend les tests plus rapides et plus propres
    @TestSetup
    static void makeData(){
        // Crée un jeu de données de base : Compte, Transporteur, Produit, Commande et une offre (PBE)
        Account acc = TestDataFactory.makeAccount('Particulier');
        Carrier__c carrier = TestDataFactory.makeCarrier(true, true);
        Product2 product = TestDataFactory.makeProduct(carrier.Id, 'Standard');
        
        Id stdPbId = Test.getStandardPricebookId();
        PricebookEntry pbe = TestDataFactory.makePbe(stdPbId, product.Id, 20, 'FR', 3);
        
        Order ord = TestDataFactory.makeOrder(acc.Id, stdPbId);
        TestDataFactory.makeOi(ord.Id, pbe.Id, 1);
    }

    // --- Tests pour la méthode computeOptions ---

    @IsTest
    static void computeOptions_returnsFastestAndCheapest() {
        // Préparation de données additionnelles pour ce test
        Order ord = [SELECT Id FROM Order LIMIT 1];
        Product2 pFast = TestDataFactory.makeProduct([SELECT Id FROM Carrier__c LIMIT 1].Id, 'Express');
        TestDataFactory.makePbe(Test.getStandardPricebookId(), pFast.Id, 50, 'FR', 1);

        // Action
        Test.startTest();
        OrderService.OptionsDTO dto = OrderService.computeOptions(ord.Id, 'test-key');
        Test.stopTest();

        // Vérification
        System.assertNotEquals(null, dto, 'Le DTO ne doit pas être null.');
        System.assertEquals(2, dto.compatible.size(), 'Doit trouver 2 options compatibles.');
        System.assertEquals('Express', dto.fastest.serviceLevel, 'L\'option la plus rapide est incorrecte.');
        System.assertEquals(20, dto.cheapest.price, 'L\'option la moins chère est incorrecte.');
    }

    @IsTest
    static void computeOptions_throwsException_whenOrderIdIsNull() {
        try {
            OrderService.computeOptions(null, 'test-key');
            System.assert(false, 'Une exception était attendue pour un orderId null.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Order Id requis'), 'Message d\'erreur incorrect.');
        }
    }

    // --- Tests pour la méthode launchDelivery ---

    @IsTest
    static void launchDelivery_createsShipmentCorrectly() {
        // Récupère les données créées dans @TestSetup
        Order ord = [SELECT Id FROM Order LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Product2.ServiceLevel__c = 'Standard' LIMIT 1];
        OrderService.TEST_BYPASS_PERMISSION = true;

        // Action
        Test.startTest();
        Shipment__c sh = OrderService.launchDelivery(ord.Id, pbe.Id, 'TRACK123');
        Test.stopTest();

        // Vérification
        System.assertNotEquals(null, sh.Id, 'La livraison aurait dû être créée.');
        sh = [SELECT Status__c, ShippingCost__c FROM Shipment__c WHERE Id = :sh.Id];
        System.assertEquals('Created', sh.Status__c, 'Le statut initial est incorrect.');
        System.assertEquals(20, sh.ShippingCost__c, 'Le coût de livraison est incorrect.');
    }

    @IsTest
    static void launchDelivery_throwsException_whenIdsAreNull() {
        try {
            OrderService.launchDelivery(null, [SELECT Id FROM PricebookEntry LIMIT 1].Id, null);
            System.assert(false, 'Exception attendue pour un orderId nul.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Order Id et PricebookEntry Id requis'), 'Message incorrect.');
        }
    }

    @IsTest
    static void launchDelivery_throwsException_whenPermissionIsMissing() {
        Order ord = [SELECT Id FROM Order LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];
        OrderService.TEST_BYPASS_PERMISSION = false;

        try {
            OrderService.launchDelivery(ord.Id, pbe.Id, null);
            System.assert(false, 'Une exception était attendue pour une permission manquante.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Accès refusé'), 'Message d\'erreur incorrect.');
        } finally {
            OrderService.TEST_BYPASS_PERMISSION = true;
        }
    }

    @IsTest
    static void launchDelivery_throwsException_whenPbeIsNotFound() {
        // On récupère une PBE valide, puis on la désactive
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];
        pbe.IsActive = false;
        update pbe;
        
        Order ord = [SELECT Id FROM Order LIMIT 1];
        OrderService.TEST_BYPASS_PERMISSION = true;

        try {
            OrderService.launchDelivery(ord.Id, pbe.Id, null);
            System.assert(false, 'Une QueryException était attendue car la PBE est inactive.');
        } catch (System.QueryException e) {
            // C'est l'erreur attendue car la requête ne trouvera aucune ligne
            System.assert(e.getMessage().contains('List has no rows for assignment to SObject'), 'Erreur incorrecte.');
        }
    }
}