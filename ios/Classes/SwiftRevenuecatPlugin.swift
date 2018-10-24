import Flutter
import UIKit

import StoreKit
import Purchases

public class SwiftRevenuecatPlugin: NSObject, FlutterPlugin, RCPurchasesDelegate {
    
    private static let PURCHASE_COMPLETED_EVENT = "purchaseCompleted";
    private static let PURCHASER_INFO_UPDATED = "purchaserInfoUpdated";
    private static let TRANSACTIONS_RESTORED = "restoredTransactions";
    
    let channel: FlutterMethodChannel;
    let registrar: FlutterPluginRegistrar;
    var purchases: RCPurchases?
    private var cachedProducts: Dictionary<String, SKProduct> = Dictionary();
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "channel:com.flutterplugin.revenuecat/purchases", binaryMessenger: registrar.messenger())
        let instance = SwiftRevenuecatPlugin(channel, registrar)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? Dictionary<String, Any>
        switch call.method {
        case "setupPurchases":
            setupPurchases(
                arguments!["apiKey"] as! String,
                arguments!["appUserId"] as? String,
                result: result)
            break
        case "setIsUsingAnonymousID":
            setIsUsingAnonymousID(
                arguments!["isUsingAnonymousID"] as! Bool,
                result: result)
            break
        case "getEntitlements":
            getEntitlements(result: result)
            break
        case "getProductInfo":
            getProductInfo(
                arguments!["productIdentifiers"] as! Array<String>,
                result: result)
            break
        case "makePurchase":
            makePurchase(
                arguments!["productIdentifier"] as! String,
                result: result)
            break
        case "restoreTransactions":
            restoreTransactions(result: result)
            break
        case "addAttributionData":
            addAttributionData(
                arguments!["data"] as! Dictionary<String, Any>,
                arguments!["network"] as! Int,
                result: result)
            break
        case "getAppUserID":
            getAppUserID(result: result)
            break
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    init(_ channel : FlutterMethodChannel, _ registrar : FlutterPluginRegistrar) {
        self.channel = channel
        self.registrar = registrar
    }
    
    public func setupPurchases(_ apiKey : String, _ appUserId : String?, result:@escaping FlutterResult){
        self.purchases?.delegate = nil
        self.cachedProducts = Dictionary()
        self.purchases = RCPurchases.init(apiKey: apiKey, appUserID: appUserId)
        self.purchases!.delegate = self
        result(nil)
    }
    
    public func setIsUsingAnonymousID(_ isUsingAnonymousID : Bool, result:@escaping FlutterResult) {
        checkPurchases()
        purchases?.isUsingAnonymousID = isUsingAnonymousID
        result(nil)
    }
    
    public func getEntitlements(result:@escaping FlutterResult){
        checkPurchases()
        self.purchases!.entitlements({ (entitlementMap : [String : RCEntitlement]?) in
            var resultMap = Dictionary<String, Any>()
            entitlementMap?.forEach({ (entitlementSet) in
                let (entitlementId, entitlement) = entitlementSet
                var offeringsMap = Dictionary<String, Any>()
                let offerings = entitlement.offerings
                offerings?.forEach({ (offeringSet) in
                    let (offeringId, offering) = offeringSet
                    let offeringDetailsMap = offering.activeProduct == nil ? nil : self.mapForOfferingDetails(offering.activeProduct!)
                    offeringsMap[offeringId] = offeringDetailsMap
                    if (offering.activeProduct != nil){
                        self.cachedProducts[offering.activeProduct!.productIdentifier] = offering.activeProduct
                    }
                })
                resultMap[entitlementId] = offeringsMap
            })
            result(resultMap)
        })
    }
    
    public func getProductInfo(_ productIds : Array<String>, result:@escaping FlutterResult) {
        checkPurchases()
        self.purchases!.products(withIdentifiers: productIds) { (products: [SKProduct]) in
            var resultArray = Array<Any>()
            products.forEach({ (product:SKProduct) in
                resultArray.append(self.mapForOfferingDetails(product))
                self.cachedProducts[product.productIdentifier] = product
            })
            result(resultArray)
        }
    }
    
    public func makePurchase(_ productId : String, result:@escaping FlutterResult) {
        checkPurchases()
        let product = self.cachedProducts[productId]
        if (product == nil) {
            result(FlutterError.init(code: "Purchase not found", message: "Purchases cannot find product. Did you call getEntitlements or getProductInfo first?", details: nil))
        } else {
            self.purchases!.makePurchase(product!)
            result(nil)
        }
    }
    
    public func restoreTransactions(result:@escaping FlutterResult) {
        checkPurchases()
        self.purchases!.restoreTransactionsForAppStoreAccount()
        result(nil)
    }
    
    public func addAttributionData(_ data : Dictionary<String, Any>, _ network : Int, result:@escaping FlutterResult) {
        checkPurchases()
        self.purchases!.addAttributionData(data, from: RCAttributionNetwork.init(rawValue: network)!)
        result(nil)
    }
    
    public func getAppUserID(result:@escaping FlutterResult){
        checkPurchases()
        result(self.purchases!.appUserID)
    }
    
    private func checkPurchases(){
        assert(self.purchases != nil, "You must call setupPurchases first")
    }
    
    private func mapForOfferingDetails(_ detail: SKProduct) -> Dictionary<String, Any> {
        var map = Dictionary<String, Any>();
        
        map["identifier"] = detail.productIdentifier;
        map["description"] = detail.localizedDescription;
        map["title"] = detail.localizedTitle;
        map["price"] = detail.price;
        map["currency_code"] = detail.priceLocale.currencyCode;
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = detail.priceLocale
        map["price_string"] = formatter.string(from: detail.price)!;
        
        if #available(iOS 11.2, *) {
            if (detail.introductoryPrice != nil){
                map["intro_price"] = detail.introductoryPrice!.price.stringValue
                map["intro_price_string"] = formatter.string(from: detail.introductoryPrice!.price);
                map["intro_price_period"] = NSNumber.init(value: detail.introductoryPrice!.subscriptionPeriod.numberOfUnits).stringValue;
                map["intro_price_cycles"] = NSNumber.init(value: detail.introductoryPrice!.numberOfPeriods).stringValue;
            }
        }
        return map;
    }
    
    /// Callbacks from the library
    public func purchases(_ purchases: RCPurchases, completedTransaction transaction: SKPaymentTransaction, withUpdatedInfo purchaserInfo: RCPurchaserInfo) {
        
    }
    
    public func purchases(_ purchases: RCPurchases, failedTransaction transaction: SKPaymentTransaction, withReason failureReason: Error) {
        
    }
    
    public func purchases(_ purchases: RCPurchases, receivedUpdatedPurchaserInfo purchaserInfo: RCPurchaserInfo) {
        
    }
    
    public func purchases(_ purchases: RCPurchases, restoredTransactionsWith purchaserInfo: RCPurchaserInfo) {
        
    }
    
    public func purchases(_ purchases: RCPurchases, failedToRestoreTransactionsWithError error: Error) {
        
    }
    
    public func purchases(_ purchases: RCPurchases, failedToUpdatePurchaserInfoWithError error: Error) {
        
    }
}
