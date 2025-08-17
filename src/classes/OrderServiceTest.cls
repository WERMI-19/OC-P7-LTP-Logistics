@IsTest
private class OrderServiceTest {
    @IsTest
    static void launch_delivery_creates_shipment() {
        Pricebook2 pb = LtpTestDataFactory.ensureStdPricebook();
        Account acc = LtpTestDataFactory.makeAccount('Client X', 'PARTICULIER');
        Order o = LtpTestDataFactory.makeOrder(acc, pb);

        Carrier__c c1 = LtpTestDataFactory.makeCarrier('Celeritas', 'C01');
        Product2 p1 = LtpTestDataFactory.makeShippingProduct(c1, 'Express');
        LtpTestDataFactory.makePbe(pb, p1, 25, 2, 'FR');

        Test.startTest();
        Id shipmentId = OrderService.launchDelivery(o.Id, c1.Id, 'FR', 'TRK-001');
        Test.stopTest();

        Shipment__c s = [SELECT Id, Order__c, Carrier__c, Status__c, ShippingCost__c, EstimatedLeadTimeHours__c, ZoneCode__c, TrackingNumber__c
                         FROM Shipment__c WHERE Id = :shipmentId];
        System.assertEquals(o.Id, s.Order__c, 'lié à la commande');
        System.assertEquals(c1.Id, s.Carrier__c, 'transporteur choisi');
        System.assertEquals('Planned', s.Status__c, 'statut initial');
        System.assertEquals('FR', s.ZoneCode__c, 'zone');
        System.assertEquals('TRK-001', s.TrackingNumber__c, 'tracking');
        System.assert(s.ShippingCost__c > 0, 'prix posé');
        System.assert(s.EstimatedLeadTimeHours__c != null, 'délai posé');
    }
}
