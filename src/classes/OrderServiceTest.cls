@IsTest
// Classe de test : OrderServiceTest — couvre computeOptions + launchDelivery
// Objectif : valider DTO (fastest/cheapest) + création Shipment__c complète
// Pré-requis MDD : Product2.Carrier__c, Product2.ServiceLevel__c, PBE.ZoneCode__c, PBE.LeadTimeDays__c
// Astuce : on utilise le Pricebook standard pour simplifier (mêmes PBE que l'Order)
// Sécurité : bypass Custom Permission via OrderService.TEST_BYPASS_PERMISSION = true
// Qualité : Test.startTest/stopTest pour isoler les limites et le cache
public class OrderServiceTest {

    // --- Helpers locaux pour réduire le bruit des tests ---
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
        // Compte Consumer -> autorise B2C
        Account a = new Account(
            Name='Acme Consumer',
            CustomerType__c='Consumer',
            ShippingCountry='FR', ShippingPostalCode='75001', ShippingState='Île-de-France'
        );
        insert a; // insert compte

        // 2 transporteurs compatibles (B2B+B2C)
        Carrier__c cFast = makeCarrier(true,true);  // pour Express
        Carrier__c cCheap= makeCarrier(true,true);  // pour Eco

        // Produits : Express (rapide+cher) vs Eco (lent+pas cher)
        Product2 pFast  = makeProduct(cFast.Id, 'Express'); // lead 1j
        Product2 pCheap = makeProduct(cCheap.Id, 'Eco');    // lead 4j

        // PBE zone FR cohérents avec l’Order
        makePbe(stdPb, pFast.Id, 30, 'FR', 1); // Express : 30€ / 1j
        makePbe(stdPb, pCheap.Id,10, 'FR', 4); // Eco     : 10€ / 4j

        // Order lié au PB standard
        Order o = makeOrder(a.Id, stdPb); // ShippingCountry=FR => zone=FR

        Test.startTest(); // isole les limites + efface caches
        // Anti-cache : refreshKey quelconque
        OrderService.OptionsDTO dto = OrderService.computeOptions(o.Id, 'test-refresh-key');
        Test.stopTest();

        // Assertions : DTO non null et ≥ 2 options
        System.assertNotEquals(null, dto, 'Le DTO ne doit pas être null');
        System.assert(dto.compatible.size() >= 2, 'Au moins 2 options attendues');

        // Fastest = Express (1j) ; Cheapest = Eco (10€)
        System.assertEquals('Express', dto.fastest.serviceLevel, 'La plus rapide doit être Express');
        System.assertEquals(10, dto.cheapest.price, 'La moins chère doit avoir un prix de 10');
    }

    // --- Test 2 : launchDelivery crée une Shipment__c complète et correcte ---
    @IsTest
    static void launchDelivery_createsShipment_andComputesCostEta() {
        Id stdPb = Test.getStandardPricebookId(); // PB standard requis

        // Compte Business -> compatible B2B
        Account a = new Account(
            Name='Acme Business',
            CustomerType__c='Business',
            ShippingCountry='FR', ShippingPostalCode='75002', ShippingState='Île-de-France'
        );
        insert a; // insert compte

        // Transporteur B2B-only (juste pour varier)
        Carrier__c c = makeCarrier(true,false); // B2B only

        // Produit standard pour ce transporteur
        Product2 pStd = makeProduct(c.Id, 'Standard'); // niveau Standard

        // PBE zone FR : 25€ / 2 jours
        makePbe(stdPb, pStd.Id, 25, 'FR', 2);

        // Order lié au PB standard
        Order o = makeOrder(a.Id, stdPb);

        // Bypass la Custom Permission pendant le test
        OrderService.TEST_BYPASS_PERMISSION = true;

        Test.startTest(); // isole les limites
        // Pas de tracking fourni -> doit être généré
        Shipment__c sh = OrderService.launchDelivery(o.Id, c.Id, null);
        Test.stopTest();

        // Relecture pour vérifier les champs MDD remplis
        sh = [SELECT Id, Order__c, Carrier__c, Status__c, ZoneCode__c,
                     DestinationCountry__c, DestinationRegion__c, DestinationPostalCode__c,
                     ShippingCost__c, EstimatedLeadTimeHours__c, EstimatedDeliveryDate__c, TrackingNumber__c
              FROM Shipment__c WHERE Id=:sh.Id];

        // Liens et statut
        System.assertEquals(o.Id, sh.Order__c, 'Lien commande attendu');
        System.assertEquals(c.Id, sh.Carrier__c, 'Lien transporteur attendu');
        System.assertEquals('Created', sh.Status__c, 'Statut initial "Created" attendu');

        // Zone/Adresse
        System.assertEquals('FR', sh.ZoneCode__c, 'Zone FR attendue');
        System.assertEquals('FR', sh.DestinationCountry__c, 'Pays destination = FR');
        System.assertNotEquals(null, sh.DestinationPostalCode__c, 'Code postal doit être renseigné');

        // Coût & délai (2 jours -> 48h)
        System.assertEquals(25, sh.ShippingCost__c, 'Coût issu de la PBE');
        System.assertEquals(48, sh.EstimatedLeadTimeHours__c, '2 jours = 48 heures');
        System.assertEquals(Date.today().addDays(2), sh.EstimatedDeliveryDate__c, 'ETA = +2 jours');

        // Tracking auto non vide
        System.assertNotEquals(null, sh.TrackingNumber__c, 'Tracking doit être généré');
    }
}
