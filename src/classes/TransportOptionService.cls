public with sharing class TransportOptionService {

    // ---------- DTOs ----------
    public class TransportOptionDTO {
        @AuraEnabled public Id carrierId;
        @AuraEnabled public String carrierName;
        @AuraEnabled public Decimal price;
        @AuraEnabled public Integer leadTimeDays;
        @AuraEnabled public String zoneCode;
        @AuraEnabled public String serviceLevel;
    }

    public class OptionsResponse {
        @AuraEnabled public List<TransportOptionDTO> compatible;
        @AuraEnabled public TransportOptionDTO cheapest;
        @AuraEnabled public TransportOptionDTO fastest;
        public OptionsResponse(){ compatible = new List<TransportOptionDTO>(); }
    }

    // ---------- Logic ----------
    @AuraEnabled(cacheable=true)
    public static OptionsResponse computeOptions(String zoneCodeOpt) {
        if (String.isBlank(zoneCodeOpt)) {
            throw new AuraHandledException('ZoneCode requis');
        }

        OptionsResponse res = new OptionsResponse();

        // Pas de filtre sur Pricebook2 : on prend tous les PBE actifs de la zone
        List<PricebookEntry> entries = [
            SELECT Id, UnitPrice,
                   ZoneCode__c, LeadTimeDays__c,
                   Product2.Id, Product2.Name,
                   Product2.ServiceLevel__c,
                   Product2.Carrier__c, Product2.Carrier__r.Name
            FROM PricebookEntry
            WHERE IsActive = true
              AND ZoneCode__c = :zoneCodeOpt
        ];

        for (PricebookEntry pbe : entries) {
            if (pbe.Product2 == null) continue;

            TransportOptionDTO dto = new TransportOptionDTO();

            // Fallback si Product2.Carrier__c est vide
            dto.carrierId    = (pbe.Product2.Carrier__c != null) ? pbe.Product2.Carrier__c : pbe.Product2.Id;
            dto.carrierName  = (pbe.Product2.Carrier__r != null) ? pbe.Product2.Carrier__r.Name : pbe.Product2.Name;

            dto.serviceLevel = (pbe.Product2.ServiceLevel__c == null)
                               ? null
                               : String.valueOf(pbe.Product2.ServiceLevel__c);

            dto.price        = pbe.UnitPrice;

            // ✅ conversion sûre Decimal -> Integer
            Decimal ld = (Decimal)pbe.get('LeadTimeDays__c');
            dto.leadTimeDays = (ld == null) ? null : ld.intValue();

            dto.zoneCode     = (String)pbe.get('ZoneCode__c');

            res.compatible.add(dto);
        }

        // Déterminer moins cher / plus rapide (robuste aux nulls)
        if (!res.compatible.isEmpty()) {
            // Cheapest
            TransportOptionDTO cheapest = null;
            for (TransportOptionDTO d : res.compatible) {
                if (d.price == null) continue;
                if (cheapest == null || d.price < cheapest.price) cheapest = d;
            }
            // Si toutes les prices sont null (hautement improbable), prend la première
            res.cheapest = (cheapest != null) ? cheapest : res.compatible[0];

            // Fastest
            TransportOptionDTO fastest = null;
            for (TransportOptionDTO d : res.compatible) {
                if (d.leadTimeDays == null) continue;
                if (fastest == null || d.leadTimeDays < fastest.leadTimeDays) fastest = d;
            }
            res.fastest = (fastest != null) ? fastest : res.cheapest;
        }

        return res;
    }
}
