import { LightningElement, api, track } from 'lwc'; // API LWC de base
import { ShowToastEvent } from 'lightning/platformShowToastEvent'; // toasts standard
import hasLaunchPermission from '@salesforce/customPermission/Can_Launch_Delivery'; // Custom Permission
import computeOptions from '@salesforce/apex/OrderService.computeOptions';   // calcule DTO options
import launchDelivery from '@salesforce/apex/OrderService.launchDelivery';   // Crée Shipment__c

export default class LtpLaunchDelivery extends LightningElement {
    // -- 1. Déclaration des propriétés du composant --
    @api recordId;                 // Reçoit l'ID de la page de commande
    @track loading = false;        // Gère l'affichage du spinner
    @track dto;                    // Stocke le résultat complet de l'appel Apex
    @track options = [];           // Liste des transporteurs pour le radio group
    @track selectedCarrier = null; // ID du transporteur choisi par l'utilisateur
    @track trackingNumber = '';    // Numéro de suivi optionnel
    @track zoneCode;               // Code de zone pour le menu déroulant (ex: 'FR')

    // -- 2. Getters : Propriétés calculées pour l'affichage --
    get hasPermission() { return hasLaunchPermission === true; }
    get hasData() { return Array.isArray(this.options) && this.options.length > 0; }

    // Formate l'affichage pour l'option la plus rapide
    get fastestLabel() {
        if (!this.dto?.fastest) return '—';
        const f = this.dto.fastest;
        return `${f.carrierName} • ${f.serviceLevel} • ${f.price}`;
    }

    // Formate l'affichage pour l'option la moins chère
    get cheapestLabel() {
        if (!this.dto?.cheapest) return '—';
        const c = this.dto.cheapest;
        return `${c.carrierName} • ${c.serviceLevel} • ${c.price}`;
    }

    // Gère l'état (activé/désactivé) du bouton "Lancer la livraison"
    get disableLaunch() {
        return !this.selectedCarrier || this.loading;
    }

    // Définit les options statiques pour le menu déroulant des zones
    get zoneOptions() {
        return [
            { label: 'France', value: 'FR' },
            { label: 'Belgique', value: 'BE' },
            { label: 'Suisse', value: 'CH' },
            { label: 'Luxembourg', value: 'LU' }
        ];
    }
    
    // -- 3. Fonctions de gestion des événements de l'interface --

    // "Traduit" le nom complet du pays en code de zone (FR, BE...)
    deriveZoneCode(country) {
        if (!country) return 'FR';
        const c = country.trim().toUpperCase();
        if (c === 'FR' || c === 'FRANCE') return 'FR';
        if (c === 'BE' || c === 'BELGIQUE' || c === 'BELGIUM') return 'BE';
        if (c === 'CH' || c === 'SUISSE' || c === 'SWITZERLAND') return 'CH';
        if (c === 'LU' || c === 'LUXEMBOURG') return 'LU';
        return 'FR';
    }

    // Met à jour la variable quand l'utilisateur change la zone
    handleZoneChange(e) { this.zoneCode = e.detail.value; }

    // Stocke l'ID du transporteur sélectionné
    handleCarrierChange(e) { this.selectedCarrier = e.detail.value; }

    // Met à jour la variable du numéro de suivi
    handleTrackingChange(e) { this.trackingNumber = e.detail.value; }

    // -- 4. Logique principale : Appels au serveur (Apex) --

    // Appelle Apex pour charger les options de livraison
    async loadOptions() {
        this.loading = true;
        try {
            // Appel à la méthode Apex computeOptions
            this.dto = await computeOptions({ orderId: this.recordId, refreshKey: new Date().getTime() });
            
            // Préremplit le menu déroulant avec le pays de la commande
            if (this.dto && this.dto.shippingCountry) {
                this.zoneCode = this.deriveZoneCode(this.dto.shippingCountry);
            }

            // Transforme les données reçues pour la liste de radio-boutons
            const list = this.dto?.compatible || [];
            this.options = list.map(o => ({
                label: `${o.carrierName} (${o.serviceLevel}) - ${o.price}`,
                value: o.carrierId
            }));
            this.selectedCarrier = null;

            if(this.options.length === 0){
                this.showToast('Information', 'Aucune option trouvée pour cette commande.', 'info');
            }
        } catch (error) {
            this.showToast('Erreur', error?.body?.message || error.message, 'error');
        } finally {
            this.loading = false;
        }
    }

    // Appelle Apex pour créer l'enregistrement de Livraison (Shipment__c)
    async handleLaunch() {
        this.loading = true;
        try {
            // Appel à la méthode Apex launchDelivery
            await launchDelivery({
                orderId: this.recordId,
                carrierId: this.selectedCarrier,
                trackingNumber: this.trackingNumber || null
            });
            this.showToast('Succès', 'Livraison lancée avec succès', 'success');
        } catch (error) {
            this.showToast('Erreur', error?.body?.message || error.message, 'error');
        } finally {
            this.loading = false;
        }
    }

    // Fonction utilitaire pour afficher les notifications toast
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}