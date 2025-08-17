@isTest
public class LtpTestDataFactory {
    public static Pricebook2 ensureStdPricebook() {
        Pricebook2 pb = [SELECT Id, Name, IsActive FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
        if (!pb.IsActive) { pb.IsActive = true; update pb; }
        return pb;
    }
    public static Carrier__c makeCarrier(String name, String code) {
        Carrier__c c = new Carrier__c(Name = name, Code__c = code, Active__c = true,
                                       SupportsBusiness__c = true, SupportsConsumers__c = true);
        insert c; return c;
    }
    public static Product2 makeShippingProduct(Carrier__c carrier, String serviceLevel) {
        Product2 p = new Product2(Name = carrier.Name + ' ' + serviceLevel,
                                  IsActive = true,
                                  ServiceLevel__c = serviceLevel,
                                  Carrier__c = carrier.Id);
        insert p; return p;
    }
    public static PricebookEntry makePbe(Pricebook2 pb, Product2 p, Decimal unitPrice, Integer leadTimeDays, String zoneCode) {
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pb.Id,
            Product2Id   = p.Id,
            UnitPrice    = unitPrice,
            IsActive     = true
        );
        pbe.put('LeadTimeDays__c', leadTimeDays);
        pbe.put('ZoneCode__c', zoneCode);
        insert pbe; return pbe;
    }
    public static Account makeAccount(String name, String custType) {
        Account a = new Account(Name = name);
        a.put('CustomerType__c', custType);
        insert a; return a;
    }
    public static Order makeOrder(Account a, Pricebook2 pb) {
        Order o = new Order(AccountId = a.Id, Status = 'Draft', EffectiveDate = Date.today(), Pricebook2Id = pb.Id);
        insert o; return o;
    }
    public static OrderItem addItem(Order o, PricebookEntry pbe, Integer qty) {
        OrderItem oi = new OrderItem(OrderId = o.Id, PricebookEntryId = pbe.Id, Quantity = qty, UnitPrice = pbe.UnitPrice);
        insert oi; return oi;
    }
}
