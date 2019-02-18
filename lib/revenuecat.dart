import 'dart:async';

import 'package:flutter/services.dart';

/// Listener for purchase events or errors (eg. if the user makes a purchase or cancels a purchase flow)
typedef void PurchaseListener(String productIdentifier, PurchaserInfo purchaserInfo, PurchasesError error);

/// Listener for puchasER changes (eg. if the user changes from non-paying to paying)
typedef void PurchaserListener(PurchaserInfo purchaserInfo, PurchasesError error);

class RevenueCat{
  static final Set<PurchaseListener> _purchaseListener = Set();
  static final Set<PurchaserListener> _purchaserInfoUpdateListener = Set();
  static final Set<PurchaserListener> _restoreTransactionsListener = Set();

  static final _channel = new MethodChannel('channel:com.flutterplugin.revenuecat/purchases')
    ..setMethodCallHandler((MethodCall call) async {
      try {
        Map<dynamic, dynamic> arguments = call.arguments;
        PurchaserInfo purchaserInfo = arguments != null && arguments['purchaserInfo'] != null
            ? PurchaserInfo.fromJson(arguments['purchaserInfo'])
            : null;
        PurchasesError paymentError = arguments != null && arguments['error'] != null
            ? PurchasesError.fromJson(arguments['error'])
            : null;
        switch (call.method) {
          case 'purchaseCompleted':
            _purchaseListener.forEach((listener) =>
                listener(
                  arguments['productIdentifier'],
                  purchaserInfo,
                  paymentError,
                ));
            break;
          case 'purchaserInfoUpdated':
            _purchaserInfoUpdateListener.forEach((listener) =>
                listener(
                  purchaserInfo,
                  paymentError,
                ));
            break;
          case 'restoredTransactions':
            _restoreTransactionsListener.forEach((listener) =>
                listener(
                  purchaserInfo,
                  paymentError,
                ));
            break;
        }
      } catch (e, s) {
        print("Could not interpret purchases event $e : $s");
      }
    });

  /// Setup your Purchases instance
  static Future<void> setup(String apiKey, String appUserId) async {
    await _channel.invokeMethod('setupPurchases', {'apiKey' : apiKey, 'appUserId' : appUserId});
  }

  /// Set this to true if you are passing in an appUserID but it is anonymous, this is true by default if you didn't pass an appUserID
  /// If a user tries to purchase a product that is active on the current app store account, we will treat it as a restore and alias
  /// the new ID with the previous id.
  static Future<void> setAllowSharingStoreAccount(bool allowSharingStoreAccount) async {
    await _channel.invokeMethod('setAllowSharingStoreAccount', {'allowSharingStoreAccount' : allowSharingStoreAccount});
  }

  /// Start listening for purchase events and changes
  static void addPurchaseListener(PurchaseListener listener) async {
    _purchaseListener.add(listener);
  }

  /// Stop listening for purchase events
  static void removePurchaseListener(PurchaseListener listener) async {
    _purchaseListener.remove(listener);
  }

  /// Start listening for purchasER changes. You should update the UI with the latest instance of your purchaser (eg. paying / non-paying)
  static void addPurchaserInfoUpdateListener(PurchaserListener listener) async {
    _purchaserInfoUpdateListener.add(listener);
  }

  /// Stop listenning for purchasER changes
  static void removePurchaserInfoUpdateListener(PurchaserListener listener) async {
    _purchaserInfoUpdateListener.remove(listener);
  }

  /// Same as addPurchaseListener, but this is specific for restore operations
  static void addRestoreTransactionListener(PurchaserListener listener) async {
    _restoreTransactionsListener.add(listener);
  }

  /// Stop listening for restore operations
  static void removeRestoreTransactionListener(PurchaserListener listener) async {
    _restoreTransactionsListener.remove(listener);
  }

  /// Get the entitlements from RevenueCat servers. An entitlement represents features or content that a user is "entitled" to. Entitlements can be unlocked by having an active subscription or making a one-time purchase.
  static Future<Map<String, Entitlement>> getEntitlements() async {
    Map<dynamic, dynamic> result = await _channel.invokeMethod('getEntitlements');
    return result.map((key, jsonValue) => MapEntry<String, Entitlement>(key, Entitlement.fromJson(jsonValue)));
  }

  /// Get all products. Products are a 1-to-1 mapping with your Apple or Google in-app purchase products.
  static Future<List<Product>> getProducts(List<String> productIdentifiers, {type = "subs"}) async {
    List<dynamic> result = await _channel.invokeMethod('getProductInfo', {'productIdentifiers' : productIdentifiers, 'type' : type});
    return result.map((item)=>Product.fromJson(item)).toList();
  }

  /// Start the purchase flow for a certain product. After the purchase is made, listeners should kick in.
  static Future<void> makePurchase(String productIdentifier, {List<String> oldSKUs = const [], String type= "subs"}) async {
    await _channel.invokeMethod('makePurchase', {'productIdentifier' : productIdentifier, 'oldSKUs' : oldSKUs, 'type' : type});
  }

  /// Start the restore procedures. This does not show any UI in most cases, but the listener should kick in if there is something to restore.
  static Future<void> restoreTransactions() async {
    await _channel.invokeMethod('restoreTransactions');
  }

  /// Get the unique id used by Purchases or the id assigned during setup. This is what we identify our purchaser by.
  static Future<String> getAppUserID() async {
    return await _channel.invokeMethod('getAppUserID') as String;
  }

  /// Add attribution data, which is used to know how much each acquisition source contributes to revenue
  static Future<void> addAttributionData(Map<String, Object> data, int network) async {
    await _channel.invokeMethod('addAttributionData', {'data' : data, 'network' : network});
  }
}

/// Produced when there was an error either in RevenueCat, Android or iOS
class PurchasesError{
  /// Where did the error occur. Also used to know if the error was a cancellation
  final String domain;
  final int code;
  final String message;

  /// This is in fact not an error, but the user cancelled the purchase
  bool get userCancelled =>  _userCancelledDomainCodes[code] == domain;

  static const Map<int, String> _userCancelledDomainCodes = {
    1: 'Play Billing',
    2: 'SKErrorDomain'
  };

  PurchasesError.fromJson(Map<dynamic, dynamic> map):
        domain = map['domain'],
        code = map['code'],
        message = map['message'];

  @override
  String toString() {
    return 'PurchasesError{domain: $domain, code: $code, message: $message}';
  }
}

/// Purchaser information, used mainly to know if a user is paying or not
class PurchaserInfo{
  /// If the user is entitled to something, it will be in this list. For most apps with subscriptions, this will be empty for non-paying users and contain one entitlement for paying ones
  final List<String> activeEntitlements;
  /// When will the entitlement no longer be active
  final String latestExpirationDate;
  /// Expiration dates for each entitlement
  final Map<String, String> allExpirationDates;
  /// Expiration dates for the active entitlements
  final Map<String, String> expirationsForActiveEntitlements;
  /// Active subscriptions. Take into account that an active subscription should in turn make the user "entitled", hence using activeEntitlements is preferred
  final List<String> activeSubscriptions;
  /// All things (subs or not) owned by the user. Keep in mind that this should also make the user "entitled", hence using activeEntitlements is preferred
  final List<String> allPurchasedProductIdentifiers;

  /// Constructor used for converting json from the native side
  PurchaserInfo.fromJson(Map<dynamic, dynamic> map):
        activeEntitlements = (map["activeEntitlements"] as List<dynamic>).map((item)=>item as String).toList(),
        latestExpirationDate = map["latestExpirationDate"],
        allExpirationDates = (map["allExpirationDates"] as Map<dynamic, dynamic>).map((key, value) => MapEntry(key as String, value as String)),
        expirationsForActiveEntitlements = (map["expirationsForActiveEntitlements"] as Map<dynamic, dynamic>).map((key, value) => MapEntry(key as String, value as String)),
        activeSubscriptions = (map["activeSubscriptions"] as List<dynamic>).map((item)=>item as String).toList(),
        allPurchasedProductIdentifiers = (map["allPurchasedProductIdentifiers"] as List<dynamic>).map((item)=>item as String).toList();

  /// Constructor used for producing a placeholder, not paying purchaser
  PurchaserInfo.nonPaying():
        activeEntitlements = [],
        latestExpirationDate = "",
        allExpirationDates = {},
        expirationsForActiveEntitlements = {},
        activeSubscriptions = [],
        allPurchasedProductIdentifiers = [];

  @override
  String toString() {
    return 'PurchaserInfo{activeEntitlements: $activeEntitlements, latestExpirationDate: $latestExpirationDate, allExpirationDates: $allExpirationDates, expirationsForActiveEntitlements: $expirationsForActiveEntitlements, activeSubscriptions: $activeSubscriptions, allPurchasedProductIdentifiers: $allPurchasedProductIdentifiers}';
  }
}

/// An entitlement represents features or content that a user is "entitled" to. Entitlements can be unlocked by having an active subscription or making a one-time purchase.
class Entitlement{
  /// In order to be "entitled" to this entitlement, the user can purchase one of the offerings. This is an abstraction above "products" and can be configured in RevenueCat
  final Map<String, Product> offerings;

  Entitlement.fromJson(Map<dynamic, dynamic> map):
        offerings = map.map((key, offeringMap)=>MapEntry(key, Product.fromJson(offeringMap)));

  @override
  String toString() {
    return 'Entitlement{offerings: $offerings}';
  }
}

/// Products are a 1-to-1 mapping with your Apple or Google in-app purchase products.
class Product{
  final String identifier,
      introPricePeriod,
      priceString,
      introPriceString,
      description,
      title,
      introPrice,
      introPriceCycles,
      currencyCode;
  final double  price;

  /// Used to create a Product from json from native
  Product.fromJson(Map<dynamic, dynamic> map):
        identifier = map['identifier'],
        introPricePeriod = map['intro_price_period'],
        priceString = map['price_string'],
        introPrice = map['intro_price'],
        price = map['price'],
        introPriceString = map['intro_price_string'],
        description = map['description'],
        introPriceCycles = map['intro_price_cycles'],
        title = map['title'],
        currencyCode = map['currency_code'];

  @override
  String toString() {
    return 'Product{identifier: $identifier, intro_price_period: $introPricePeriod, price_string: $priceString, intro_price: $introPrice, intro_price_string: $introPriceString, description: $description, intro_price_cycles: $introPriceCycles, title: $title, currency_code: $currencyCode, price: $price}';
  }
}