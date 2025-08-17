LTP SFDX Package – Objets logistique + Permission

Contenu (source format):
- force-app/main/default/objects/
  - Carrier__c (Transporteur)
  - DeliveryZone__c (Zone de livraison)
  - CarrierRate__c (Tarification transport)
  - Shipment__c (Livraison)
  - Account/fields/CustomerType__c (Type de client)
- force-app/main/default/customPermissions/Can_Launch_Delivery
- force-app/main/default/permissionsets/Launch_Delivery
- manifest/package.xml

Commandes utiles :
1) sfdx force:org:list
2) sfdx force:source:deploy -p force-app -u <aliasOrUsername> --json
3) Assigner le permission set :
   sfdx force:user:permset:assign -n Launch_Delivery -u <aliasOrUsername>

Après déploiement :
- Créez des Transporteurs, Zones, Tarifs (CarrierRate__c).
- Ajoutez le LWC sur la page Order si besoin.
- Vérifiez la Custom Permission dans le Permission Set (Can_Launch_Delivery).
