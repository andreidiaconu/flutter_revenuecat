import 'dart:async';
import 'dart:ui';

import 'package:flutter/services.dart';

typedef void PurchaseListener(String productIdentifier, PurchaserInfo purchaserInfo, PurchasesError error);
typedef void PurchaserListener(PurchaserInfo purchaserInfo, PurchasesError error);

class RevenueCat{
  static final Set<PurchaseListener> purchaseListener = Set();
  static final Set<PurchaserListener> purchaserInfoUpdateListener = Set();
  static final Set<PurchaserListener> restoreTransactionsListener = Set();

  static final channel = new MethodChannel('channel:com.flutterplugin.revenuecat/purchases')
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
            purchaseListener.forEach((listener) =>
                listener(
                  arguments['productIdentifier'],
                  purchaserInfo,
                  paymentError,
                ));
            break;
          case 'purchaserInfoUpdated':
            purchaserInfoUpdateListener.forEach((listener) =>
                listener(
                  purchaserInfo,
                  paymentError,
                ));
            break;
          case 'restoredTransactions':
            restoreTransactionsListener.forEach((listener) =>
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

  static Future<void> setup(String apiKey, String appUserId) async {
    await channel.invokeMethod('setupPurchases', {'apiKey' : apiKey, 'appUserId' : appUserId});
  }

  static Future<void> setIsUsingAnonymousID(bool isUsingAnonymousID) async {
    await channel.invokeMethod('setIsUsingAnonymousID', {'isUsingAnonymousID' : isUsingAnonymousID});
  }

  static void addPurchaseListener(PurchaseListener listener) async {
    purchaseListener.add(listener);
  }

  static void removePurchaseListener(PurchaseListener listener) async {
    purchaseListener.remove(listener);
  }

  static void addPurchaserInfoUpdateListener(PurchaserListener listener) async {
    purchaserInfoUpdateListener.add(listener);
  }

  static void removePurchaserInfoUpdateListener(PurchaserListener listener) async {
    purchaserInfoUpdateListener.remove(listener);
  }

  static void addRestoreTransactionListener(PurchaserListener listener) async {
    restoreTransactionsListener.add(listener);
  }

  static void removeRestoreTransactionListener(PurchaserListener listener) async {
    restoreTransactionsListener.remove(listener);
  }

  static Future<Map<String, Entitlement>> getEntitlements() async {
    Map<dynamic, dynamic> result = await channel.invokeMethod('getEntitlements');
    return result.map((key, jsonValue) => MapEntry<String, Entitlement>(key, Entitlement.fromJson(jsonValue)));
  }

  static Future<List<Product>> getProducts(List<String> productIdentifiers, {type = "subs"}) async {
    List<dynamic> result = await channel.invokeMethod('getProductInfo', {'productIdentifiers' : productIdentifiers, 'type' : type});
    return result.map((item)=>Product.fromJson(item)).toList();
  }

  static Future<void> makePurchase(String productIdentifier, {List<String> oldSKUs = const [], String type= "subs"}) async {
    await channel.invokeMethod('makePurchase', {'productIdentifier' : productIdentifier, 'oldSKUs' : oldSKUs, 'type' : type});
  }

  static Future<void> restoreTransactions() async {
    await channel.invokeMethod('restoreTransactions');
  }

  static Future<String> getAppUserID() async {
    return await channel.invokeMethod('getAppUserID') as String;
  }

  static Future<void> addAttributionData(Map<String, Object> data, int network) async {
    await channel.invokeMethod('addAttributionData', {'data' : data, 'network' : network});
  }
}

class PurchasesError{
  final String domain;
  final int code;
  final String message;
  bool get userCancelled =>  userCancelledDomainCodes[code] == domain;
  static const Map<int, String> userCancelledDomainCodes = {
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

class PurchaserInfo{
  final List<String> activeEntitlements;
  final String latestExpirationDate; //2018-10-15T15:51:01.000Z
  final Map<String, String> allExpirationDates;
  final Map<String, String> expirationsForActiveEntitlements;
  final List<String> activeSubscriptions;
  final List<String> allPurchasedProductIdentifiers;

  PurchaserInfo.fromJson(Map<dynamic, dynamic> map):
        activeEntitlements = (map["activeEntitlements"] as List<dynamic>).map((item)=>item as String).toList(),
        latestExpirationDate = map["latestExpirationDate"],
        allExpirationDates = (map["allExpirationDates"] as Map<dynamic, dynamic>).map((key, value) => MapEntry(key as String, value as String)),
        expirationsForActiveEntitlements = (map["expirationsForActiveEntitlements"] as Map<dynamic, dynamic>).map((key, value) => MapEntry(key as String, value as String)),
        activeSubscriptions = (map["activeSubscriptions"] as List<dynamic>).map((item)=>item as String).toList(),
        allPurchasedProductIdentifiers = (map["allPurchasedProductIdentifiers"] as List<dynamic>).map((item)=>item as String).toList();

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

class Entitlement{
  final Map<String, Product> offerings;
  Entitlement.fromJson(Map<dynamic, dynamic> map):
        offerings = map.map((key, offeringMap)=>MapEntry(key, Product.fromJson(offeringMap)));

  @override
  String toString() {
    return 'Entitlement{offerings: $offerings}';
  }
}

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