import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import SHIPPING_COUNTRY_FIELD from '@salesforce/schema/Order.ShippingCountry';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import hasLaunchPermission from '@salesforce/customPermission/Can_Launch_Delivery';
import computeOptions from '@salesforce/apex/OrderService.computeOptions';
import launchDelivery from '@salesforce/apex/OrderService.launchDelivery';

export default class LtpLaunchDelivery extends LightningElement {
    @api recordId;
    loading = false;
    dto;
    selectedCarrier = null;
    selectedZone;

    // Listes pour stocker les options triées
    fastestOptionsList = [];
    cheapestOptionsList = [];

    @wire(getRecord, { recordId: '$recordId', fields: [SHIPPING_COUNTRY_FIELD] })
    wiredOrder({ error, data }) {
        if (data) {
            const countryName = getFieldValue(data, SHIPPING_COUNTRY_FIELD);
            // On ne pré-remplit la zone que si l'utilisateur ne l'a pas déjà modifiée
            if (!this.selectedZone) {
                this.selectedZone = this.deriveZoneCode(countryName);
            }
        } else if (error) {
            console.error('Erreur de chargement de la commande via @wire', error);
        }
    }

    // --- Getters ---
    get hasPermission() { return hasLaunchPermission === true; }
    get hasData() { return this.dto && this.dto.compatible && this.dto.compatible.length > 0; }
    get fastestLabel() { if (!this.dto?.fastest) return '—'; const f = this.dto.fastest; return `${f.carrierName} (${f.price}€, ${f.leadTimeDays} jours)`; }
    get cheapestLabel() { if (!this.dto?.cheapest) return '—'; const c = this.dto.cheapest; return `${c.carrierName} (${c.price}€, ${c.leadTimeDays} jours)`; }
    
    get fastestOptions() {
        return this.fastestOptionsList.map(opt => ({
            label: `${opt.carrierName} (${opt.price}€, ${opt.leadTimeDays} jours)`,
            value: opt.carrierId
        }));
    }

    get cheapestOptions() {
        return this.cheapestOptionsList.map(opt => ({
            label: `${opt.carrierName} (${opt.price}€, ${opt.leadTimeDays} jours)`,
            value: opt.carrierId
        }));
    }

    get disableLaunch() { return !this.selectedCarrier || this.loading; }
    get zoneOptions() { return [{ label: 'France', value: 'FR' }, { label: 'Belgique', value: 'BE' }, { label: 'Suisse', value: 'CH' }, { label: 'Luxembourg', value: 'LU' }]; }

    // --- Gestionnaires d'Événements ---
    handleZoneChange(event) {
        this.selectedZone = event.detail.value;
        // Recharge automatiquement les options pour la nouvelle zone.
        this.loadOptions();
    }

    handleCarrierChange(event) {
        this.selectedCarrier = event.detail.value;
    }
    
    async handleLaunch() {
        if (!this.selectedCarrier) {
            this.showToast('Action requise', 'Veuillez sélectionner un transporteur.', 'warning');
            return;
        }
        this.loading = true;
        try {
            // On envoie la zone sélectionnée à la méthode Apex
            await launchDelivery({
                orderId: this.recordId,
                carrierId: this.selectedCarrier,
                selectedZone: this.selectedZone
            });
            this.showToast('Succès', 'La livraison a été créée avec succès !', 'success');
        } catch (error) {
            this.showToast('Erreur de lancement', error.body?.message || error.message, 'error');
        } finally {
            this.loading = false;
        }
    }

    // --- Logique Métier ---
    async loadOptions() {
        this.loading = true;
        this.dto = null;
        this.selectedCarrier = null;
        this.fastestOptionsList = [];
        this.cheapestOptionsList = [];

        try {
            const result = await computeOptions({ orderId: this.recordId, selectedZone: this.selectedZone, refreshKey: new Date().getTime() });
            this.dto = result;

            if (this.hasData) {
                this.processAndCategorizeOptions();
                if (this.dto.cheapest) {
                    this.selectedCarrier = this.dto.cheapest.carrierId;
                }
                this.showToast('Succès', `${this.dto.compatible.length} options chargées pour la zone ${this.selectedZone}.`, 'success');
            } else {
                 this.showToast('Information', `Aucune option trouvée pour la zone '${this.selectedZone}'.`, 'info');
            }
        } catch (error) {
            this.showToast('Erreur de chargement', error.body?.message || error.message, 'error');
        } finally {
            this.loading = false;
        }
    }
    
    processAndCategorizeOptions() {
        const compatibleOptions = this.dto.compatible;
        if (!compatibleOptions || compatibleOptions.length === 0) return;

        const minLeadTime = Math.min(...compatibleOptions.map(opt => opt.leadTimeDays));
        const premiumSpeedOptions = compatibleOptions.filter(opt => opt.leadTimeDays <= minLeadTime + 1);
        const priceThreshold = premiumSpeedOptions.length > 0 ? Math.min(...premiumSpeedOptions.map(opt => opt.price)) : Infinity;

        let cheapest = [];
        let fastest = [];
        
        compatibleOptions.forEach(opt => {
            if (opt.price < priceThreshold) {
                cheapest.push(opt);
            } else {
                fastest.push(opt);
            }
        });

        if (cheapest.length === 0 && fastest.length > 0) {
            fastest.sort((a, b) => a.price - b.price);
            const cheapestOfTheFast = fastest.shift(); 
            cheapest.push(cheapestOfTheFast);
        }

        cheapest.sort((a, b) => a.price - b.price);
        fastest.sort((a, b) => {
            if (a.leadTimeDays !== b.leadTimeDays) {
                return a.leadTimeDays - b.leadTimeDays;
            }
            return a.price - b.price;
        });

        this.cheapestOptionsList = cheapest;
        this.fastestOptionsList = fastest;
    }

    // --- Utilitaires ---
    showToast(title, message, variant) { this.dispatchEvent(new ShowToastEvent({ title, message, variant })); }
    
    deriveZoneCode(countryName) {
        if (!countryName) return 'FR';
        const c = countryName.trim().toUpperCase();
        if (c === 'FR' || c.includes('FRANCE')) return 'FR';
        if (c === 'BE' || c.includes('BELGIQUE') || c.includes('BELGIUM')) return 'BE';
        if (c === 'CH' || c.includes('SUISSE') || c.includes('SWITZERLAND')) return 'CH';
        if (c === 'LU' || c.includes('LUXEMBOURG')) return 'LU';
        return 'FR';
    }
}