@IsTest
// Classe de test : OrderServiceTest — couvre computeOptions + launchDelivery + cas d'erreur
public class OrderServiceTest {

    // --- Helpers locaux pour créer les données de test ---
    private static Carrier__c makeCarrier(Boolean b2b, Boolean b2c) {
        // Crée un transporteur actif avec compat B2B/B2C paramétrable
        Carrier__c c = new Carrier__c(
            Name='Carrier ' + String.valueOf(Crypto.getRandomInteger()),
            Active__c=true,
            SupportsBusiness__c = (b2b==null?true:b2b),
            SupportsConsumers__c= (b2c==null?true:b2c)
        );
        insert c; return c; // insert et retourne
    }

    private static Product2 makeProduct(Id carrierId, String level) {
        // Produit "service de transport" relié à un Carrier + niveau de service
        Product2 p = new Product2(
            Name='Transport ' + level,
            IsActive=true,
            Carrier__c=carrierId,
            ServiceLevel__c=level
        );
        insert p; return p; // insert et retourne
    }

    private static PricebookEntry makePbe(Id pbId, Id productId, Decimal price, String zone, Integer leadDays) {
        // PBE conforme MDD : prix + zone + délai (jours)
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id=pbId, Product2Id=productId,
            UnitPrice=price, IsActive=true, UseStandardPrice=false,
            ZoneCode__c=zone, LeadTimeDays__c=leadDays
        );
        insert pbe; return pbe; // insert et retourne
    }

    private static Order makeOrder(Id accountId, Id pbId) {
        // Order minimal avec PB + adresse FR (zone FR)
        Order o = new Order(
            AccountId=accountId,
            Status='Draft',
            EffectiveDate=Date.today(),
            Pricebook2Id=pbId,
            ShippingCountry='FR',
            ShippingPostalCode='75001',
            ShippingState='Île-de-France'
        );
        insert o; return o; // insert et retourne
    }

    // --- Test 1 : computeOptions renvoie fastest/cheapest corrects ---
    @IsTest
    static void computeOptions_returnsFastestAndCheapest() {
        Id stdPb = Test.getStandardPricebookId(); // PB standard requis
        Account a = new Account(Name='Acme Consumer', CustomerType__c='Consumer');
        insert a;

        Carrier__c cFast = makeCarrier(true,true);
        Carrier__c cCheap= makeCarrier(true,true);

        Product2 pFast  = makeProduct(cFast.Id, 'Express');
        Product2 pCheap = makeProduct(cCheap.Id, 'Eco');

        makePbe(stdPb, pFast.Id, 30, 'FR', 1);
        makePbe(stdPb, pCheap.Id,10, 'FR', 4);

        Order o = makeOrder(a.Id, stdPb);

        Test.startTest();
        OrderService.OptionsDTO dto = OrderService.computeOptions(o.Id, 'test-refresh-key');
        Test.stopTest();

        System.assertNotEquals(null, dto, 'Le DTO ne doit pas être null');
        System.assert(dto.compatible.size() >= 2, 'Au moins 2 options attendues');
        System.assertEquals('Express', dto.fastest.serviceLevel, 'La plus rapide doit être Express');
        System.assertEquals(10, dto.cheapest.price, 'La moins chère doit avoir un prix de 10');
    }

    // --- Test 2 : launchDelivery crée une Shipment__c complète et correcte ---
    @IsTest
    static void launchDelivery_createsShipment_andComputesCostEta() {
        Id stdPb = Test.getStandardPricebookId();
        Account a = new Account(Name='Acme Business', CustomerType__c='Business');
        insert a;

        Carrier__c c = makeCarrier(true,false);
        Product2 pStd = makeProduct(c.Id, 'Standard');
        makePbe(stdPb, pStd.Id, 25, 'FR', 2);

        Order o = makeOrder(a.Id, stdPb);
        OrderService.TEST_BYPASS_PERMISSION = true;

        Test.startTest();
        Shipment__c sh = OrderService.launchDelivery(o.Id, c.Id, null);
        Test.stopTest();

        sh = [SELECT Id, Order__c, Carrier__c, Status__c, ShippingCost__c, EstimatedLeadTimeHours__c, EstimatedDeliveryDate__c, TrackingNumber__c FROM Shipment__c WHERE Id=:sh.Id];

        System.assertEquals(o.Id, sh.Order__c, 'Lien commande attendu');
        System.assertEquals(c.Id, sh.Carrier__c, 'Lien transporteur attendu');
        System.assertEquals('Created', sh.Status__c, 'Statut initial "Created" attendu');
        System.assertEquals(25, sh.ShippingCost__c, 'Coût issu de la PBE');
        System.assertEquals(48, sh.EstimatedLeadTimeHours__c, '2 jours = 48 heures');
        System.assertEquals(Date.today().addDays(2), sh.EstimatedDeliveryDate__c, 'ETA = +2 jours');
        System.assertNotEquals(null, sh.TrackingNumber__c, 'Tracking doit être généré');
    }

    // --- NOUVEAU TEST : Vérifie que computeOptions lève une exception si l'ID est nul ---
    @IsTest
    static void computeOptions_throwsException_whenOrderIdIsNull() {
        try {
            OrderService.computeOptions(null, 'test-key');
            System.assert(false, 'Une exception était attendue pour un ID de commande nul.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Order Id requis'), 'Le message d\'erreur est incorrect.');
        }
    }

    // --- NOUVEAU TEST : Vérifie que launchDelivery lève une exception si les IDs sont nuls ---
    @IsTest
    static void launchDelivery_throwsException_whenIdsAreNull() {
        Account a = TestDataFactory.makeAccount('Consumer');
        Order o = TestDataFactory.makeOrder(a.Id, Test.getStandardPricebookId());
        Carrier__c c = TestDataFactory.makeCarrier(true, true);
        
        try {
            OrderService.launchDelivery(null, c.Id, null);
            System.assert(false, 'Exception attendue pour un orderId nul.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Order Id et Carrier Id requis'), 'Message d\'erreur incorrect pour orderId nul.');
        }

        try {
            OrderService.launchDelivery(o.Id, null, null);
            System.assert(false, 'Exception attendue pour un carrierId nul.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Order Id et Carrier Id requis'), 'Message d\'erreur incorrect pour carrierId nul.');
        }
    }

    // --- NOUVEAU TEST : Vérifie le blocage si la permission custom est manquante ---
    @IsTest
    static void launchDelivery_throwsException_whenPermissionIsMissing() {
        Account a = TestDataFactory.makeAccount('Business');
        Order o = TestDataFactory.makeOrder(a.Id, Test.getStandardPricebookId());
        Carrier__c c = TestDataFactory.makeCarrier(true, false);
        Product2 p = TestDataFactory.makeProduct(c.Id, 'Standard');
        TestDataFactory.makePbe(Test.getStandardPricebookId(), p.Id, 25, 'FR', 2);

        OrderService.TEST_BYPASS_PERMISSION = false;

        try {
            OrderService.launchDelivery(o.Id, c.Id, null);
            System.assert(false, 'Une exception était attendue car la permission est manquante.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Accès refusé'), 'Le message d\'erreur pour la permission manquante est incorrect.');
        } finally {
            OrderService.TEST_BYPASS_PERMISSION = true;
        }
    }
}