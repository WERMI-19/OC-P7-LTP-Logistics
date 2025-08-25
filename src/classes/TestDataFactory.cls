@IsTest
//Centralise la logique de création des enregistrements sur la base du modèle de données (MDD).

public class TestDataFactory {

    /**
     * @description Crée un Compte (Account) avec un type de client spécifique.
     * @param customerType 'Particulier' ou 'Professionnel'.
     * @return Le Compte inséré.
     */
    public static Account makeAccount(String customerType){
        Account a = new Account(
            Name = 'Acme ' + customerType + ' ' + String.valueOf(Crypto.getRandomInteger()),
            CustomerType__c    = String.isBlank(customerType) ? 'Particulier' : customerType,
            ShippingCountry    = 'FR', // pour les tests basés sur la zone
            ShippingPostalCode = '75001',
            ShippingState      = 'Île-de-France'
        );
        insert a;
        return a;
    }

    /**
     * @description Surcharge pour créer un compte 'Particulier' par défaut.
     * @return Le Compte 'Consumer' inséré.
     */
    public static Account makeAccount(){
        return makeAccount('Particulier');
    }

    /**
     * @description Crée un Transporteur (Carrier__c) avec des compatibilités spécifiques.
     * @param b2b Supporte les clients 'Professionnel'.
     * @param b2c Supporte les clients 'Particulier'.
     * @return Le Transporteur inséré.
     */
    public static Carrier__c makeCarrier(Boolean b2b, Boolean b2c){
        Carrier__c c = new Carrier__c(
            Name='Carrier ' + String.valueOf(Crypto.getRandomInteger()),
            Active__c=true,
            SupportsBusiness__c = (b2b==null?true:b2b),
            SupportsConsumers__c= (b2c==null?true:b2c)
        );
        insert c;
        return c;
    }

    /**
     * @description Surcharge pour créer un transporteur compatible B2B et B2C par défaut.
     * @return Le Transporteur inséré.
     */
    public static Carrier__c makeCarrier(){
        return makeCarrier(true,true);
    }

    /**
     * @description Crée un Produit (Product2) de type service de transport.
     * @param carrierId L'ID du transporteur associé.
     * @param level Le niveau de service (ex: 'Standard', 'Express').
     * @return Le Produit inséré.
     */
    public static Product2 makeProduct(Id carrierId, String level){
        Product2 p = new Product2(
            Name='Transport ' + (String.isBlank(level)?'Standard':level),
            IsActive=true,
            Carrier__c=carrierId,
            ServiceLevel__c = String.isBlank(level)?'Standard':level
        );
        insert p;
        return p;
    }

    /**
     * @description Surcharge pour créer un produit de niveau 'Standard' par défaut.
     * @param carrierId L'ID du transporteur associé.
     * @return Le Produit inséré.
     */
    public static Product2 makeProduct(Id carrierId){
        return makeProduct(carrierId, 'Standard');
    }

    /**
     * @description Crée une entrée de catalogue de prix (PricebookEntry).
     * @param pbId L'ID du Pricebook2.
     * @param productId L'ID du Product2.
     * @param price Le prix unitaire.
     * @param zone Le code de la zone (ex: 'FR').
     * @param leadDays Le délai de livraison en jours.
     * @return Le PricebookEntry inséré.
     */
    public static PricebookEntry makePbe(Id pbId, Id productId, Decimal price, String zone, Integer leadDays){
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pbId, 
            Product2Id = productId, 
            UnitPrice = price,
            IsActive = true, 
            UseStandardPrice = false,
            ZoneCode__c = zone, 
            LeadTimeDays__c = leadDays
        );
        insert pbe;
        return pbe;
    }

    /**
     * @description Surcharge pour créer une PBE en zone 'FR' avec un délai de 2 jours par défaut.
     * @param pbId L'ID du Pricebook2.
     * @param productId L'ID du Product2.
     * @param price Le prix unitaire.
     * @return Le PricebookEntry inséré.
     */
    public static PricebookEntry makePbe(Id pbId, Id productId, Decimal price){
        return makePbe(pbId, productId, price, 'FR', 2);
    }

    /**
     * @description Crée une Commande (Order) minimale pour les tests.
     * @param accountId L'ID du Compte associé.
     * @param pricebookId L'ID du Pricebook2 associé.
     * @return La Commande insérée.
     */
    public static Order makeOrder(Id accountId, Id pricebookId){
        Order o = new Order(
            AccountId=accountId, 
            Status='Draft',
            EffectiveDate=Date.today(), 
            Pricebook2Id=pricebookId,
            ShippingCountry='FR'
        );
        insert o;
        return o;
    }

    /**
     * @description Crée un Article de commande (OrderItem).
     * @param orderId L'ID de la Commande.
     * @param pbeId L'ID du PricebookEntry.
     * @param q La quantité.
     * @return L'OrderItem inséré.
     */
    public static OrderItem makeOi(Id orderId, Id pbeId, Integer q){
        OrderItem oi = new OrderItem(
            OrderId=orderId, 
            PricebookEntryId=pbeId, 
            Quantity=q, 
            UnitPrice=10 // Prix arbitraire, car le coût de livraison est sur la PBE.
        );
        insert oi;
        return oi;
    }
}