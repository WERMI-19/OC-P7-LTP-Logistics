declare module "@salesforce/apex/OrderService.computeTransportOptions" {
  export default function computeTransportOptions(param: {orderId: any, zoneCodeOpt: any}): Promise<any>;
}
declare module "@salesforce/apex/OrderService.launchDelivery" {
  export default function launchDelivery(param: {orderId: any, carrierId: any, zoneCodeOpt: any, trackingNumberOpt: any}): Promise<any>;
}
