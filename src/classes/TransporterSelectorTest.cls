@IsTest
// Tests unitaires de TransporterSelector – couvrent compatibilité zone et B2B/B2C
// Objectif: garantir que seules les offres valides remontent pour une commande donnée
// Données: on utilise la factory pour rester DRY et respectueux du MDD
// Cas: Consumer exclut carriers B2C=false ; Business exclut carriers B2B=false
// Zone: FR par défaut pour simplifier (ShippingCountry='FR')
// Perf: tests rapides sans DML inutile
public class TransporterSelectorTest {

    @IsTest
    static void forOrder_filtersByZoneAndCustomerType(){
        Id stdPb = Test.getStandardPricebookId(); // récupère le PB standard
        Account aConsumer = TestDataFactory.makeAccount('Consumer'); // compte particulier
        Account aBiz      = TestDataFactory.makeAccount('Business'); // compte pro

        // Carrier A (compatible pour tous), Carrier B (B2B only), Carrier C (B2C only)
        Carrier__c cAll = TestDataFactory.makeCarrier(true,true); // B2B+B2C
        Carrier__c cB2B = TestDataFactory.makeCarrier(true,false); // pro only
        Carrier__c cB2C = TestDataFactory.makeCarrier(false,true); // particulier only

        // Produits et PBEs en zone FR
        Product2 pAll = TestDataFactory.makeProduct(cAll.Id, 'Standard'); // produit standard
        Product2 pB2B = TestDataFactory.makeProduct(cB2B.Id, 'Express');  // express
        Product2 pB2C = TestDataFactory.makeProduct(cB2C.Id, 'Eco');      // eco

        PricebookEntry eAll = TestDataFactory.makePbe(stdPb, pAll.Id, 10, 'FR', 2); // offre FR
        PricebookEntry eB2B = TestDataFactory.makePbe(stdPb, pB2B.Id, 20, 'FR', 1); // plus rapide
        PricebookEntry eB2C = TestDataFactory.makePbe(stdPb, pB2C.Id, 5,  'FR', 4); // moins chère

        // Deux commandes (Consumer & Business)
        Order oConsumer = TestDataFactory.makeOrder(aConsumer.Id, stdPb); // commande particulier
        Order oBiz      = TestDataFactory.makeOrder(aBiz.Id, stdPb);      // commande pro

        Test.startTest();
        List<TransporterSelector.TransportOption> optsConsumer =
            TransporterSelector.forOrder(oConsumer.Id); // récupère options
        List<TransporterSelector.TransportOption> optsBiz =
            TransporterSelector.forOrder(oBiz.Id); // récupère options
        Test.stopTest();

        System.assertNotEquals(0, optsConsumer.size(), 'Consumer devrait avoir des options'); // sanity check
        System.assertNotEquals(0, optsBiz.size(), 'Business devrait avoir des options'); // sanity check

        // Consumer NE DOIT PAS voir l’offre strictement B2B
        Boolean hasB2BOnlyForConsumer = false; // init
        for(TransporterSelector.TransportOption opt : optsConsumer){
            if(opt.carrierId == cB2B.Id) hasB2BOnlyForConsumer = true; // repère b2b only
        }
        System.assertEquals(false, hasB2BOnlyForConsumer, 'Consumer ne doit pas voir B2B only'); // vérifie exclusion

        // Business NE DOIT PAS voir l’offre strictement B2C
        Boolean hasB2COnlyForBiz = false; // init
        for(TransporterSelector.TransportOption opt : optsBiz){
            if(opt.carrierId == cB2C.Id) hasB2COnlyForBiz = true; // repère b2c only
        }
        System.assertEquals(false, hasB2COnlyForBiz, 'Business ne doit pas voir B2C only'); // vérifie exclusion
    }
}