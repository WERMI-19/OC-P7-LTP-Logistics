@IsTest
private class OrderRulesServiceTest {
    @IsTest
    static void validate_minimum_items_rules() {
        Pricebook2 pb = LtpTestDataFactory.ensureStdPricebook();
        Account pro = LtpTestDataFactory.makeAccount('ACME PRO', 'PRO');
        Account part = LtpTestDataFactory.makeAccount('Jane PART', 'PARTICULIER');

        Order o1 = LtpTestDataFactory.makeOrder(pro, pb);
        Order o2 = LtpTestDataFactory.makeOrder(part, pb);

        // Tentative d'activation sans items -> doit échouer
        o1.Status = 'Activated';
        o2.Status = 'Activated';
        Test.startTest();
        try {
            update new List<Order>{ o1, o2 };
            System.assert(false, 'Une erreur utilisateur était attendue pour o1 et o2');
        } catch (DmlException e) {
            System.assert(true, 'Erreur bien levée');
        }
        Test.stopTest();

        // Ajout des items requis : PRO=5, PARTICULIER=3
        Product2 dummy = new Product2(Name='Dummy', IsActive=true);
        insert dummy;
        PricebookEntry pbe = new PricebookEntry(Pricebook2Id = pb.Id, Product2Id = dummy.Id, UnitPrice=10, IsActive=true);
        insert pbe;

        // PRO : 5 items
        for (Integer i=0; i<5; i++) LtpTestDataFactory.addItem(o1, pbe, 1);
        // PARTICULIER : 3 items
        for (Integer j=0; j<3; j++) LtpTestDataFactory.addItem(o2, pbe, 1);

        // Re-activation -> OK
        o1 = [SELECT Id, Status FROM Order WHERE Id = :o1.Id];
        o2 = [SELECT Id, Status FROM Order WHERE Id = :o2.Id];
        o1.Status = 'Activated';
        o2.Status = 'Activated';
        Test.startTest();
        update new List<Order>{ o1, o2 };
        Test.stopTest();
    }
}
