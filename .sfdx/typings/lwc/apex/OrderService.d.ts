declare module "@salesforce/apex/OrderService.computeOptions" {
  export default function computeOptions(param: {orderId: any, refreshKey: any}): Promise<any>;
}
declare module "@salesforce/apex/OrderService.launchDelivery" {
  export default function launchDelivery(param: {orderId: any, carrierId: any, trackingNumber: any}): Promise<any>;
}
