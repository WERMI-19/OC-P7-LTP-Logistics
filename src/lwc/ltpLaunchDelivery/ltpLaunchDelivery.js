import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import hasLaunchDelivery from '@salesforce/customPermission/Can_Launch_Delivery';
import computeTransportOptions from '@salesforce/apex/OrderService.computeTransportOptions';
import launchDelivery from '@salesforce/apex/OrderService.launchDelivery';

/**
 * LTP - Lancer la livraison (Order Record Page)
 * - Respecte SLDS, cahier des charges Projet7
 * - Affiche options compatible + "plus rapide" & "moins chère"
 * - Permet de créer Shipment__c via Apex
 */
export default class LtpLaunchDelivery extends LightningElement {
    @api recordId; // Id de la commande (Order)
    @track loading = false;
    @track optionsDTO;
    @track selectedCarrier = null;
    @track trackingNumber = '';
    @track zoneCode = 'FR'; // Par défaut : France (cahier des charges)

    // Permissions (masque l'UI si non attribuée)
    get hasPermission() { return hasLaunchDelivery === true; }

    // États utiles pour le rendu
    get hasData() { return this.optionsDTO && this.optionsDTO.compatible && this.optionsDTO.compatible.length > 0; }
    get noData() { return this.optionsDTO && (!this.optionsDTO.compatible || this.optionsDTO.compatible.length === 0); }
    get fastest() { return this.optionsDTO?.fastest || null; }
    get cheapest() { return this.optionsDTO?.cheapest || null; }
    get fastestLabel() {
        if (!this.fastest) return '—';
        return `${this.fastest.carrierName} • ${this.fastest.serviceLevel} • ${this.fastest.price}`;
    }
    get cheapestLabel() {
        if (!this.cheapest) return '—';
        return `${this.cheapest.carrierName} • ${this.cheapest.serviceLevel} • ${this.cheapest.price}`;
    }
    get disableLaunch() {
        // Autorise le lancement si un transporteur est sélectionné
        return !this.selectedCarrier;
    }

    // Combobox zone de livraison (FR/BE/CH/LU)
    get zoneOptions() {
        return [
            { label: 'France (FR)', value: 'FR' },
            { label: 'Belgique (BE)', value: 'BE' },
            { label: 'Suisse (CH)', value: 'CH' },
            { label: 'Luxembourg (LU)', value: 'LU' }
        ];
    }

    // Options pour le radio-group (transporteurs compatibles)
    get radioOptions() {
        if (!this.hasData) return [];
        return this.optionsDTO.compatible.map(c => {
            const label = `${c.carrierName} • ${c.serviceLevel} • ${c.price} • ${c.leadTimeDays} j`;
            return { label, value: c.carrierId };
        });
    }

    // Handlers UI
    handleZoneChange(event) { this.zoneCode = event.detail.value; }
    handleCarrierChange(event) { this.selectedCarrier = event.detail.value; }
    handleTrackingChange(event) { this.trackingNumber = event.detail.value; }

    async loadOptions() {
        this.loading = true;
        try {
            const res = await computeTransportOptions({ orderId: this.recordId, zoneCodeOpt: this.zoneCode });
            this.optionsDTO = res;
            // Pré-sélection : moins chère si dispo
            if (res && res.cheapest && res.cheapest.carrierId) {
                this.selectedCarrier = res.cheapest.carrierId;
            } else {
                this.selectedCarrier = null;
            }
            this.toast('Options mises à jour', 'Les options de transport ont été calculées.', 'success');
        } catch (e) {
            this.toast('Erreur', this.normaliseError(e), 'error');
        } finally {
            this.loading = false;
        }
    }

    async handleLaunch() {
        this.loading = true;
        try {
            const shipmentId = await launchDelivery({
                orderId: this.recordId,
                carrierId: this.selectedCarrier,
                zoneCodeOpt: this.zoneCode,
                trackingNumberOpt: this.trackingNumber
            });
            this.toast('Livraison lancée', `Shipment créé : ${shipmentId}`, 'success');
            // Reset léger
            this.trackingNumber = '';
        } catch (e) {
            this.toast('Erreur', this.normaliseError(e), 'error');
        } finally {
            this.loading = false;
        }
    }

    // Utilitaires
    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
    normaliseError(e) {
        if (!e) return 'Erreur inconnue';
        if (Array.isArray(e.body)) return (e.body[0] && e.body[0].message) || e.message;
        return (e.body && e.body.message) || e.message || e;
    }
}
