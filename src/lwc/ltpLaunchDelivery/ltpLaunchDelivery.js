import { LightningElement, api, track } from 'lwc'; // API LWC de base
import { ShowToastEvent } from 'lightning/platformShowToastEvent'; // toasts standard
import hasLaunchPermission from '@salesforce/customPermission/Can_Launch_Delivery'; // Custom Permission
import computeOptions from '@salesforce/apex/OrderService.computeOptions';   // ✅ calcule DTO options
import launchDelivery from '@salesforce/apex/OrderService.launchDelivery';   // ✅ crée Shipment__c

export default class LtpLaunchDelivery extends LightningElement {
    @api recordId;                 // Id de la commande courante (Record Page)
    @track loading = false;        // État du spinner (UX)
    @track dto;                    // DTO retourné par Apex (compatible/fastest/cheapest)
    @track options = [];           // Options formatées {label,value} pour radio-group
    @track selectedCarrier = null; // Transporteur sélectionné (Id)
    @track zoneCode;               // <-- La valeur par défaut  dynamique

    // Autorisation: booléen injecté par la Custom Permission (plateforme)
    get hasPermission() { return hasLaunchPermission === true; } // garde l'UI si true

    // Indique s'il y a des options à afficher (radio-group visible)
    get hasData() { return Array.isArray(this.options) && this.options.length > 0; } // simple check

    // Libellé résumé de l'option la plus rapide (DTO.fastest)
    get fastestLabel() {
        if (!this.dto?.fastest) return '—'; // rien si pas de données
        const f = this.dto.fastest; // référence rapide
        return `${f.carrierName} • ${f.serviceLevel} • ${f.price}`; // format compact
    }

    // Libellé résumé de l'option la moins chère (DTO.cheapest)
    get cheapestLabel() {
        if (!this.dto?.cheapest) return '—'; // rien si pas de données
        const c = this.dto.cheapest; // référence rapide
        return `${c.carrierName} • ${c.serviceLevel} • ${c.price}`; // format compact
    }

    // État du bouton "Lancer la livraison" : désactivé si pas de sélection ou chargement
    get disableLaunch() {
        return !this.selectedCarrier || this.loading; // évite clicks multiples
    }

    // Liste de zones affichée (indicatif UI) – Apex dérive réellement la zone via ShippingCountry
    get zoneOptions() {
        return [
            { label: 'France', value: 'FR' },   // FR
            { label: 'Belgique', value: 'BE' }, // BE
            { label: 'Suisse', value: 'CH' },   // CH
            { label: 'Luxembourg', value: 'LU' }
        ]; // UX uniquement
    }

    // <-- BLOC AJOUTÉ : Fonction pour dériver le code de zone à partir du nom du pays
    deriveZoneCode(country) {
        if (!country) return 'FR'; // Valeur par défaut si le pays est vide
        const c = country.trim().toUpperCase();
        if (c === 'FR' || c === 'FRANCE') return 'FR';
        if (c === 'BE' || c === 'BELGIQUE' || c === 'BELGIUM') return 'BE';
        if (c === 'CH' || c === 'SUISSE' || c === 'SWITZERLAND') return 'CH';
        if (c === 'LU' || c === 'LUXEMBOURG') return 'LU';
        return 'FR'; // Valeur par défaut si pays non trouvé
    }

    // Gestion du changement de zone (affichage seulement)
    handleZoneChange(e) { this.zoneCode = e.detail.value; } // UI helper

    // Choix d'un transporteur dans la liste
    handleCarrierChange(e) { this.selectedCarrier = e.detail.value; } // stocke l'Id

    // Saisie d'un tracking (optionnel)
    handleTrackingChange(e) { this.trackingNumber = e.detail.value; } // garde la valeur

    // Charge les options via Apex (impératif) et les mappe pour le radio-group
    async loadOptions() {
        this.loading = true; // spinner ON
        try {
            this.dto = await computeOptions({ orderId: this.recordId, refreshKey: new Date().getTime() }); // appel Apex
            
            // <-- BLOC AJOUTÉ : Définit la valeur par défaut du menu déroulant
            if (this.dto && this.dto.shippingCountry) {
                this.zoneCode = this.deriveZoneCode(this.dto.shippingCountry);
            }

            const list = this.dto?.compatible || []; // sécurise la lecture
            // Mappe vers {label,value} attendu par lightning-radio-group
            this.options = list.map(o => ({
                label: `${o.carrierName} (${o.serviceLevel}) - ${o.price}`, // libellé lisible
                value: o.carrierId // valeur = Id transporteur
            })); // conversion simple
            this.selectedCarrier = null; // reset une éventuelle ancienne sélection
            if(this.options.length === 0){
                this.showToast('Information', 'Aucune option trouvée pour cette commande.', 'info'); // feedback
            }
        } catch (error) {
            this.showToast('Erreur', error?.body?.message || error.message, 'error'); // surface l'erreur
        } finally {
            this.loading = false; // spinner OFF
        }
    }

    // Lance la livraison (création Shipment__c) via Apex
    async handleLaunch() {
        this.loading = true; // spinner ON
        try {
            await launchDelivery({
                orderId: this.recordId, // Id de l'ordre
                carrierId: this.selectedCarrier, // choix utilisateur
                trackingNumber: this.trackingNumber || null // optionnel
            }); // exécute le DML côté serveur
            this.showToast('Succès', 'Livraison lancée avec succès', 'success'); // feedback positif
        } catch (error) {
            this.showToast('Erreur', error?.body?.message || error.message, 'error'); // surface l'erreur
        } finally {
            this.loading = false; // spinner OFF
        }
    }

    // Confort: wrapper pour ShowToastEvent
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant })); // déclenche le toast
    }
}