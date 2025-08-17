@IsTest
private class TransportOptionServiceTest {
    @IsTest
    static void compute_options_cheapest_and_fastest() {
        Pricebook2 pb = LtpTestDataFactory.ensureStdPricebook();
        Carrier__c c1 = LtpTestDataFactory.makeCarrier('Celeritas', 'C01');
        Carrier__c c2 = LtpTestDataFactory.makeCarrier('Economica', 'C02');
        Product2 p1 = LtpTestDataFactory.makeShippingProduct(c1, 'Express');
        Product2 p2 = LtpTestDataFactory.makeShippingProduct(c2, 'Economy');
        LtpTestDataFactory.makePbe(pb, p1, 30, 1, 'FR');
        LtpTestDataFactory.makePbe(pb, p2, 10, 3, 'FR');

        Test.startTest();
        TransportOptionService.OptionsResponse res = TransportOptionService.computeOptions('FR');
        Test.stopTest();

        System.assertNotEquals(null, res, 'Response non nulle');
        System.assert(res.compatible.size() >= 2, 'Au moins 2 options');
        System.assertEquals('Celeritas', res.fastest.carrierName, 'Fastest = Express');
        System.assertEquals('Economica', res.cheapest.carrierName, 'Cheapest = Economy');
    }
}
