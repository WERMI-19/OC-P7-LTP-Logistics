@IsTest
// Tests unitaires de TransporterSelector – couvrent compatibilité zone, B2B/B2C et cas limites.
public class TransporterSelectorTest {

    // Test principal : filtre correctement par type de client (B2B/B2C)
    @IsTest
    static void forOrder_filtersByCustomerType() {
        Id stdPb = Test.getStandardPricebookId();
        Account aConsumer = TestDataFactory.makeAccount('Consumer');
        Account aBiz = TestDataFactory.makeAccount('Business');

        // Création de transporteurs spécifiques
        Carrier__c cAll = TestDataFactory.makeCarrier(true, true);  // Compatible B2B & B2C
        Carrier__c cB2B = TestDataFactory.makeCarrier(true, false); // B2B uniquement
        Carrier__c cB2C = TestDataFactory.makeCarrier(false, true); // B2C uniquement

        // Création des produits et des entrées de catalogue de prix
        Product2 pAll = TestDataFactory.makeProduct(cAll.Id, 'Standard');
        Product2 pB2B = TestDataFactory.makeProduct(cB2B.Id, 'Express');
        Product2 pB2C = TestDataFactory.makeProduct(cB2C.Id, 'Eco');
        TestDataFactory.makePbe(stdPb, pAll.Id, 10, 'FR', 2);
        TestDataFactory.makePbe(stdPb, pB2B.Id, 20, 'FR', 1);
        TestDataFactory.makePbe(stdPb, pB2C.Id, 5,  'FR', 4);

        // Création des commandes
        Order oConsumer = TestDataFactory.makeOrder(aConsumer.Id, stdPb);
        Order oBiz = TestDataFactory.makeOrder(aBiz.Id, stdPb);

        Test.startTest();
        List<TransporterSelector.TransportOption> optsConsumer = TransporterSelector.forOrder(oConsumer.Id);
        List<TransporterSelector.TransportOption> optsBiz = TransporterSelector.forOrder(oBiz.Id);
        Test.stopTest();

        // Vérification pour le client particulier (Consumer)
        System.assertEquals(2, optsConsumer.size(), 'Le Consumer doit voir 2 options (All + B2C)');
        System.assert(!JSON.serialize(optsConsumer).contains(cB2B.Id), 'Le Consumer ne doit pas voir l\'option B2B only.');

        // Vérification pour le client professionnel (Business)
        System.assertEquals(2, optsBiz.size(), 'Le Business doit voir 2 options (All + B2B)');
        System.assert(!JSON.serialize(optsBiz).contains(cB2C.Id), 'Le Business ne doit pas voir l\'option B2C only.');
    }

    // NOUVEAU TEST : Couvre les cas de la méthode deriveZoneCode
    @IsTest
    static void deriveZoneCode_handlesSupportedAndUnsupportedCountries() {
        // Préparation d'une commande
        Account a = TestDataFactory.makeAccount('Consumer');
        Order o = TestDataFactory.makeOrder(a.Id, Test.getStandardPricebookId());

        // Cas 1: Pays supporté
        o.ShippingCountry = 'FR';
        System.assertEquals('FR', TransporterSelector.deriveZoneCode(o), 'Doit retourner FR pour la France.');

        // Cas 2: Autre pays supporté
        o.ShippingCountry = 'BE';
        System.assertEquals('BE', TransporterSelector.deriveZoneCode(o), 'Doit retourner BE pour la Belgique.');

        // Cas 3: Pays non supporté
        o.ShippingCountry = 'USA';
        System.assertEquals(null, TransporterSelector.deriveZoneCode(o), 'Ne doit rien retourner pour un pays non supporté.');

        // Cas 4: Pays vide
        o.ShippingCountry = '';
        System.assertEquals(null, TransporterSelector.deriveZoneCode(o), 'Ne doit rien retourner si le pays est vide.');
    }

    // NOUVEAU TEST : Gère le cas d'une commande sans compte
    @IsTest
    static void forOrder_returnsEmpty_whenOrderHasNoAccount() {
        Order o = TestDataFactory.makeOrder(null, Test.getStandardPricebookId());

        Test.startTest();
        List<TransporterSelector.TransportOption> options = TransporterSelector.forOrder(o.Id);
        Test.stopTest();

        System.assert(options.isEmpty(), 'Ne doit retourner aucune option pour une commande sans compte.');
    }
}