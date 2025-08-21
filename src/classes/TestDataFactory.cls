@IsTest
// Classe utilitaire de données de test – centralise la création des enregistrements
// Avantage: factorise la logique et garantit la cohérence avec le MDD
public class TestDataFactory {

    // Création d'un compte (Consumer/Business)
    public static Account makeAccount(String customerType){
        Account a = new Account(
            Name = 'Acme ' + customerType,
            CustomerType__c    = String.isBlank(customerType) ? 'Consumer' : customerType,
            ShippingCountry    = 'FR', // facilite deriveZoneCode
            ShippingPostalCode = '75001',
            ShippingState      = 'Île-de-France'
        );
        insert a; return a; // insert direct
    }

    // Surcharge: Consumer par défaut
    public static Account makeAccount(){ return makeAccount('Consumer'); } // helper simple

    // Création d'un transporteur avec flags B2B/B2C
    public static Carrier__c makeCarrier(Boolean b2b, Boolean b2c){
        Carrier__c c = new Carrier__c(
            Name='Carrier ' + String.valueOf(Crypto.getRandomInteger()),
            Active__c=true,
            SupportsBusiness__c = (b2b==null?true:b2b),
            SupportsConsumers__c= (b2c==null?true:b2c)
        );
        insert c; return c; // insert direct
    }

    // Surcharge: transporteur compatible par défaut
    public static Carrier__c makeCarrier(){ return makeCarrier(true,true); } // à la fois B2B et B2C

    // Produit de transport rattaché à un transporteur
    public static Product2 makeProduct(Id carrierId, String level){
        Product2 p = new Product2(
            Name='Transport ' + (String.isBlank(level)?'Standard':level),
            IsActive=true,
            Carrier__c=carrierId,
            ServiceLevel__c = String.isBlank(level)?'Standard':level
        );
        insert p; return p; // insert direct
    }

    // Surcharge: niveau "Standard"
    public static Product2 makeProduct(Id carrierId){ return makeProduct(carrierId, 'Standard'); } // helper

    // Création d'une PBE complète pour une zone donnée
    public static PricebookEntry makePbe(Id pbId, Id productId, Decimal price, String zone, Integer leadDays){
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pbId, Product2Id = productId, UnitPrice = price,
            IsActive = true, UseStandardPrice = false,
            ZoneCode__c = zone, LeadTimeDays__c = leadDays
        );
        insert pbe; return pbe; // insert direct
    }

    // Surcharge: zone FR avec délai 2 jours
    public static PricebookEntry makePbe(Id pbId, Id productId, Decimal price){
        return makePbe(pbId, productId, price, 'FR', 2); // défaut utile pour tests
    }

    // Création d'une commande minimale
    public static Order makeOrder(Id accountId, Id pricebookId){
        Order o = new Order(AccountId=accountId, Status='Draft',
                            EffectiveDate=Date.today(), Pricebook2Id=pricebookId,ShippingCountry='FR');
        insert o; return o; // insert direct
    }

    // Ajoute un item à une commande
    public static OrderItem makeOi(Id orderId, Id pbeId, Integer q){
        OrderItem oi = new OrderItem(OrderId=orderId, PricebookEntryId=pbeId, Quantity=q, UnitPrice=10);
        insert oi; return oi; // insert direct
    }
}