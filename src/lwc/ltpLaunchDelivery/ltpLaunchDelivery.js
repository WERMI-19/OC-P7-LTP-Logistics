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
    selectedPbeId = null; // On stocke l'ID du service (PricebookEntry), pas du transporteur
    selectedZone;

    optionsLoaded = false;
    selectedValueFast = null;
    selectedValueCheap = null;
    fastestOptionsList = [];
    cheapestOptionsList = [];

    @wire(getRecord, { recordId: '$recordId', fields: [SHIPPING_COUNTRY_FIELD] })
    wiredOrder({ error, data }) {
        if (data) {
            const countryName = getFieldValue(data, SHIPPING_COUNTRY_FIELD);
            this.selectedZone = this.deriveZoneCode(countryName);
        } else if (error) {
            console.error('Erreur de chargement de la commande via @wire', error);
        }
    }

    // Getters

    get hasPermission() { return hasLaunchPermission === true; }
    get hasData() { return this.dto && this.dto.compatible && this.dto.compatible.length > 0; }
    get fastestLabel() { if (!this.dto?.fastest) return '—'; const f = this.dto.fastest; return `${f.carrierName} (${f.price}€, ${f.leadTimeDays} jours)`; }
    get cheapestLabel() { if (!this.dto?.cheapest) return '—'; const c = this.dto.cheapest; return `${c.carrierName} (${c.price}€, ${c.leadTimeDays} jours)`; }
    
    // La valeur envoyée est maintenant pbeId pour être précise
    get fastestOptions() {
        return this.fastestOptionsList.map(opt => ({
            label: `${opt.carrierName} (${opt.price}€, ${opt.leadTimeDays} jours)`,
            value: opt.pbeId
        }));
    }

    // La valeur envoyée est maintenant pbeId pour être précise
    get cheapestOptions() {
        return this.cheapestOptionsList.map(opt => ({
            label: `${opt.carrierName} (${opt.price}€, ${opt.leadTimeDays} jours)`,
            value: opt.pbeId
        }));
    }

    get disableLoadOptions() { return !this.selectedZone || this.loading; }
    get disableLaunch() { return !this.optionsLoaded || !this.selectedPbeId || this.loading; }
    get zoneOptions() { return [{ label: 'France', value: 'FR' }, { label: 'Belgique', value: 'BE' }, { label: 'Suisse', value: 'CH' }, { label: 'Luxembourg', value: 'LU' }]; }

    // Logique Métier (Appels Apex et Traitement)

    async loadOptions() {
        if (!this.selectedZone) {
            this.showToast('Action requise', 'Veuillez sélectionner une zone de livraison.', 'warning');
            return;
        }
        
        this.loading = true;
        this.dto = null;
        this.resetSelection();

        try {
            this.dto = await computeOptions({ orderId: this.recordId, refreshKey: new Date().getTime() });

            if (this.hasData) {
                this.processAndCategorizeOptions();
                this.showToast('Succès', `${this.dto.compatible.length} options chargées.`, 'success');
                this.optionsLoaded = true;
            } else {
                 this.showToast('Information', `Aucune option trouvée pour la zone '${this.selectedZone}'.`, 'info');
                 this.optionsLoaded = true;
            }
        } catch (error) {
            this.showToast('Erreur de chargement', error.body?.message || error.message, 'error');
        } finally {
            this.loading = false;
        }
    }
    
    processAndCategorizeOptions() {
        // Votre logique de catégorisation est conservée
        const compatibleOptions = [...this.dto.compatible];
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

        const totalUniqueOptions = new Set(compatibleOptions.map(o => o.carrierId)).size;
        if (totalUniqueOptions > 2) {
            if (cheapest.length === 0 && fastest.length > 0) {
                let cheapestOfFastest = fastest.reduce((prev, curr) => prev.price < curr.price ? prev : curr);
                cheapest.push(cheapestOfFastest);
                fastest = fastest.filter(opt => opt.pbeId !== cheapestOfFastest.pbeId);
            }
            else if (fastest.length === 0 && cheapest.length > 0) {
                let fastestOfCheapest = cheapest.reduce((prev, curr) => {
                    if (curr.leadTimeDays < prev.leadTimeDays) return curr;
                    if (curr.leadTimeDays === prev.leadTimeDays && curr.price < prev.price) return curr;
                    return prev;
                });
                fastest.push(fastestOfCheapest);
                cheapest = cheapest.filter(opt => opt.pbeId !== fastestOfCheapest.pbeId);
            }
        }

        cheapest.sort((a, b) => a.price - b.price);
        fastest.sort((a, b) => (a.leadTimeDays - b.leadTimeDays) || (a.price - b.price));

        this.cheapestOptionsList = cheapest;
        this.fastestOptionsList = fastest;
    }

    // =================================================================================================
    // Gestionnaires d'Événements et Utilitaires
    // =================================================================================================
    
    handleZoneChange(event) {
        this.selectedZone = event.detail.value;
        this.dto = null;
        this.resetSelection();
    }
    
    resetSelection() {
        this.selectedPbeId = null;
        this.selectedValueFast = null;
        this.selectedValueCheap = null;
        this.fastestOptionsList = [];
        this.cheapestOptionsList = [];
        this.optionsLoaded = false;
    }

    handleCarrierChange(event) {
        const newPbeId = event.detail.value;
        const sourceName = event.target.name;
        this.selectedPbeId = newPbeId;

        if (sourceName === 'carrierSelectionFast') {
            this.selectedValueFast = newPbeId;
            this.selectedValueCheap = null;
        } else if (sourceName === 'carrierSelectionCheap') {
            this.selectedValueCheap = newPbeId;
            this.selectedValueFast = null;
        }
    }
    
    async handleLaunch() {
        if (!this.selectedPbeId) {
            this.showToast('Action requise', 'Veuillez sélectionner une option de livraison.', 'warning');
            return;
        }
        this.loading = true;
        try {
            await launchDelivery({ 
                orderId: this.recordId, 
                pbeId: this.selectedPbeId, 
                trackingNumber: null 
            });
            this.showToast('Succès', 'La livraison a été créée avec succès !', 'success');
        } catch (error) {
            this.showToast('Erreur de lancement', error.body?.message || error.message, 'error');
        } finally {
            this.loading = false;
        }
    }

    showToast(title, message, variant) { this.dispatchEvent(new ShowToastEvent({ title, message, variant })); }
    
    deriveZoneCode(countryName) {
        if (!countryName) return null;
        const c = countryName.trim().toUpperCase();
        if (c === 'FR' || c.includes('FRANCE')) return 'FR';
        if (c === 'BE' || c.includes('BELGIQUE') || c.includes('BELGIUM')) return 'BE';
        if (c === 'CH' || c.includes('SUISSE') || c.includes('SWITZERLAND')) return 'CH';
        if (c === 'LU' || c.includes('LUXEMBOURG')) return 'LU';
        return null;
    }
}