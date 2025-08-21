@IsTest
private class AccountSelectorTest {

    // Test n°1 : Scénario de succès (le "happy path")
    // Vérifie que la méthode retourne le bon compte pour un ID valide.
    @IsTest
    static void getAccountById_returnsAccount_whenIdIsValid() {
        // 1. Préparation : Créer un compte de test
        Account acc = new Account(Name='Test Corp');
        insert acc;

        // 2. Action : Appeler la méthode à tester
        Test.startTest();
        Account result = AccountSelector.getAccountById(acc.Id);
        Test.stopTest();

        // 3. Vérification : S'assurer que le compte retourné est le bon
        System.assertNotEquals(null, result, 'Le compte retourné ne doit pas être nul.');
        System.assertEquals(acc.Id, result.Id, 'L\'ID du compte retourné doit correspondre.');
    }

    // Test n°2 : Scénario d'échec
    // Vérifie que la méthode lève une exception si aucun compte n'est trouvé (ID nul).
    @IsTest
    static void getAccountById_throwsException_whenIdIsInvalid() {
        try {
            // 2. Action : Appeler la méthode avec un ID nul, ce qui doit provoquer une erreur
            AccountSelector.getAccountById(null);
            
            // Si on arrive ici, le test échoue car aucune erreur n'a été levée
            System.assert(false, 'Une exception QueryException était attendue.');

        } catch (System.QueryException e) {
            // 3. Vérification : L'exception attendue a bien été attrapée, le test réussit.
            System.assert(e.getMessage().contains('List has no rows for assignment'), 
                'Le message d\'erreur est incorrect.');
        }
    }
}