package com.flutterplugin.revenuecat;

import android.support.annotation.Nullable;

import com.android.billingclient.api.SkuDetails;
import com.revenuecat.purchases.Entitlement;
import com.revenuecat.purchases.Offering;
import com.revenuecat.purchases.PurchaserInfo;
import com.revenuecat.purchases.Purchases;
import com.revenuecat.purchases.util.Iso8601Utils;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry;
import io.flutter.plugin.common.PluginRegistry.Registrar;
import io.flutter.view.FlutterNativeView;

/** RevenuecatPlugin */
public class RevenuecatPlugin implements MethodCallHandler, Purchases.PurchasesListener{
  /** Plugin registration. */
  public static void registerWith(Registrar registrar) {
    final MethodChannel channel = new MethodChannel(registrar.messenger(), "channel:com.flutterplugin.revenuecat/purchases");
    RevenuecatPlugin plugin = new RevenuecatPlugin(registrar, channel);
    channel.setMethodCallHandler(plugin);
  }

  @Override
  public void onMethodCall(MethodCall call, Result result) {
    try {
      if (call.method.equals("setupPurchases")) {
        //{'apiKey' : apiKey, 'appUserId' : appUserId}
        setupPurchases((String) call.argument("apiKey"), (String) call.argument("appUserId"), result);
      } else if (call.method.equals("setIsUsingAnonymousID")) {
        setIsUsingAnonymousID((Boolean) call.argument("isUsingAnonymousID"), result);
      } else if (call.method.equals("getEntitlements")) {
        getEntitlements(result);
      } else if (call.method.equals("getProductInfo")) {
        getProductInfo((ArrayList<String>) call.argument("productIdentifiers"), (String) call.argument("type"), result);
      } else if (call.method.equals("makePurchase")) {
        makePurchase((String) call.argument("productIdentifier"), (ArrayList<String>) call.argument("oldSKUs"), (String) call.argument("type"), result);
      } else if (call.method.equals("restoreTransactions")) {
        restoreTransactions(result);
      } else if (call.method.equals("getAppUserID")) {
        getAppUserID(result);
      } else if (call.method.equals("addAttributionData")) {
        addAttributionData((Map<String, Object>) call.argument("data"), (Integer) call.argument("network"), result);
      } else {
        result.notImplemented();
      }
    } catch (Exception ex){
      result.error("METHOD_CALL", ex.getLocalizedMessage(), ex);
    }
  }

  private void sendEvent(String eventName,
                         @Nullable Map<String, Object> params) {
    channel.invokeMethod(eventName, params);
  }

  private static final String PURCHASE_COMPLETED_EVENT = "purchaseCompleted";
  private static final String PURCHASER_INFO_UPDATED = "purchaserInfoUpdated";
  private static final String TRANSACTIONS_RESTORED = "restoredTransactions";

  private final Registrar registrar;
  private final MethodChannel channel;
  private Purchases purchases;

  public RevenuecatPlugin(Registrar registrar, MethodChannel channel) {
    this.registrar = registrar;
    this.channel = channel;
    this.registrar.addViewDestroyListener(new PluginRegistry.ViewDestroyListener() {
      @Override
      public boolean onViewDestroy(FlutterNativeView flutterNativeView) {
        onDestroy();
        return false;
      }
    });
  }

  private void checkPurchases() {
    if (purchases == null) {
      throw new RuntimeException("You must call setupPurchases first");
    }
  }

  public void onDestroy() {
    if (purchases != null) {
      purchases.close();
      purchases = null;
    }
  }

  public void setupPurchases(String apiKey, String appUserID, final Result result) {
    if (purchases != null) {
      purchases.close();
    }
    purchases = new Purchases.Builder(registrar.context(), apiKey, this).appUserID(appUserID).build();
    result.success(null);
  }

  public void setIsUsingAnonymousID(boolean isUsingAnonymousID, Result result) {
    checkPurchases();
    purchases.setIsUsingAnonymousID(isUsingAnonymousID);
    result.success(null);
  }

  public void addAttributionData(Map<String, Object> data, Integer network, Result result) {
    checkPurchases();
    try {
      JSONObject object = convertMapToJson(data);
      purchases.addAttributionData(object, network);
      result.success(null);
    } catch (JSONException e) {
      result.error("JSON-PARSE","Error parsing attribution date to JSON" + e.getLocalizedMessage(), null);
    }
  }

  private Map<String, Object> mapForSkuDetails(final SkuDetails detail) {
    Map<String, Object> map = new HashMap<>();

    map.put("identifier", detail.getSku());
    map.put("description", detail.getDescription());
    map.put("title", detail.getTitle());
    map.put("price", ((double) detail.getPriceAmountMicros()) / 1000000);
    map.put("price_string", detail.getPrice());

    map.put("intro_price", detail.getIntroductoryPriceAmountMicros());
    map.put("intro_price_string", detail.getIntroductoryPrice());
    map.put("intro_price_period", detail.getIntroductoryPricePeriod());
    map.put("intro_price_cycles", detail.getIntroductoryPriceCycles());

    map.put("currency_code", detail.getPriceCurrencyCode());

    return map;
  }

  public void getEntitlements(final Result result) {
    checkPurchases();

    purchases.getEntitlements(new Purchases.GetEntitlementsHandler() {
      @Override
      public void onReceiveEntitlements(Map<String, Entitlement> entitlementMap) {
        try {
          Map<String, Object> response = new HashMap<>();

          for (String entId : entitlementMap.keySet()) {
            Entitlement ent = entitlementMap.get(entId);

            Map<String, Object> offeringsMap = new HashMap<>();
            Map<String, Offering> offerings = ent.getOfferings();

            for (String offeringId : offerings.keySet()) {
              Offering offering = offerings.get(offeringId);
              SkuDetails skuDetails = offering.getSkuDetails();
              if (skuDetails != null) {
                Map<String, Object> skuMap = mapForSkuDetails(skuDetails);
                offeringsMap.put(offeringId, skuMap);
              } else {
                offeringsMap.put(offeringId, null);
              }
            }
            response.put(entId, offeringsMap);
          }

          result.success(response);
        } catch (Exception e){
          result.error("PARSING_ERRORS", e.getLocalizedMessage(), e);
        }
      }

      @Override
      public void onReceiveEntitlementsError(int domain, int code, String message) {
        result.error("ERROR_FETCHING_ENTITLEMENTS", message, null);
      }
    });
  }

  public void getProductInfo(List<String> productIDs, String type, final Result result) {
    checkPurchases();

    Purchases.GetSkusResponseHandler handler = new Purchases.GetSkusResponseHandler() {
      @Override
      public void onReceiveSkus(List<SkuDetails> skus) {
        ArrayList<Map> writableArray = new ArrayList<>();
        for (SkuDetails detail : skus) {
          writableArray.add(mapForSkuDetails(detail));
        }

        result.success(writableArray);
      }
    };

    if (type.toLowerCase().equals("subs")) {
      purchases.getSubscriptionSkus(productIDs, handler);
    } else {
      purchases.getNonSubscriptionSkus(productIDs, handler);
    }
  }

  public void makePurchase(String productIdentifier, ArrayList<String> oldSkus, String type, Result result) {
    checkPurchases();
    purchases.makePurchase(registrar.activity(), productIdentifier, type, oldSkus);
    result.success(null);
  }

  public void getAppUserID(final Result result) {
    result.success(purchases.getAppUserID());
  }

  public void restoreTransactions(Result result) {
    checkPurchases();
    purchases.restorePurchasesForPlayStoreAccount();
    result.success(null);
  }

  @Override
  public void onCompletedPurchase(String sku, PurchaserInfo purchaserInfo) {
    Map<String, Object> map = new HashMap<>();
    map.put("productIdentifier", sku);
    map.put("purchaserInfo", createPurchaserInfoMap(purchaserInfo));
    sendEvent(PURCHASE_COMPLETED_EVENT, map);
  }

  @Override
  public void onFailedPurchase(int domain, int code, String message) {
    Map<String, Object> map = new HashMap<>();

    map.put("error", errorMap(domain, code, message));

    sendEvent(PURCHASE_COMPLETED_EVENT, map);
  }

  @Override
  public void onReceiveUpdatedPurchaserInfo(PurchaserInfo purchaserInfo) {
    Map<String, Object> map = new HashMap<>();

    map.put("purchaserInfo", createPurchaserInfoMap(purchaserInfo));

    sendEvent(PURCHASER_INFO_UPDATED, map);
  }

  @Override
  public void onRestoreTransactions(PurchaserInfo purchaserInfo) {
    Map<String, Object> map = new HashMap<>();
    map.put("purchaserInfo", createPurchaserInfoMap(purchaserInfo));

    sendEvent(TRANSACTIONS_RESTORED, map);
  }

  @Override
  public void onRestoreTransactionsFailed(int domain, int code, String reason) {
    sendEvent(TRANSACTIONS_RESTORED, errorMap(domain, code, reason));
  }

  private static JSONObject convertMapToJson(Map<String, Object> source) throws JSONException {
    // This method does not support possible byte[], int[], long[], double[]
    JSONObject object = new JSONObject();
    Iterator<String> iterator = source.keySet().iterator();
    while (iterator.hasNext()) {
      String key = iterator.next();
      Object value = source.get(key);
      if (value instanceof Map) {
        object.put(key, convertMapToJson((Map<String, Object>) value));
      } else if (value instanceof List) {
        object.put(key, convertArrayToJson((List) value));
      } else {
        object.put(key, value);
      }
    }
    return object;
  }

  private static JSONArray convertArrayToJson(List source) throws JSONException {
    // This method does not support possible byte[], int[], long[], double[]
    JSONArray array = new JSONArray();
    for (int i = 0; i < source.size(); i++) {
      Object value = source.get(i);
      if (value instanceof Map) {
        array.put(convertMapToJson((Map<String, Object>) value));
      } else if (value instanceof List) {
        array.put(convertArrayToJson((List) value));
      } else {
        array.put(value);
      }
    }
    return array;
  }

  private Map<String, Object> createPurchaserInfoMap(PurchaserInfo purchaserInfo) {
    Map<String, Object> map = new HashMap<>();

    map.put("activeEntitlements", new ArrayList<>(purchaserInfo.getActiveEntitlements()));
    map.put("activeSubscriptions", new ArrayList<>(purchaserInfo.getActiveSubscriptions()));
    map.put("allPurchasedProductIdentifiers", new ArrayList<>(purchaserInfo.getAllPurchasedSkus()));

    Date latest = purchaserInfo.getLatestExpirationDate();
    if (latest != null) {
      map.put("latestExpirationDate", Iso8601Utils.format(latest));
    } else {
      map.put("latestExpirationDate", null);
    }

    Map<String, String> allExpirationDates = new HashMap<>();
    Map<String, Date> dates = purchaserInfo.getAllExpirationDatesByProduct();
    for (Map.Entry<String, Date> entry : dates.entrySet()) {
      allExpirationDates.put(entry.getKey(), Iso8601Utils.format(entry.getValue()));
    }
    map.put("allExpirationDates", allExpirationDates);

    Map<String, String> allEntitlementExpirationDates = new HashMap<>();

    for (String entitlementId : purchaserInfo.getActiveEntitlements()) {
      Date date = purchaserInfo.getExpirationDateForEntitlement(entitlementId);
      if (date != null) {
        allEntitlementExpirationDates.put(entitlementId, Iso8601Utils.format(date));
      } else {
        allEntitlementExpirationDates.put(entitlementId, null);
      }
    }
    map.put("expirationsForActiveEntitlements", allEntitlementExpirationDates);

    return map;
  }

  private Map<String, Object> errorMap(int domain, int code, String message) {
    Map<String, Object> errorMap = new HashMap<>();
    String domainString;

    switch (domain) {
      case Purchases.ErrorDomains.REVENUECAT_BACKEND:
        domainString = "RevenueCat Backend";
        break;
      case Purchases.ErrorDomains.PLAY_BILLING:
        domainString = "Play Billing";
        break;
      default:
        domainString = "Unknown";
    }

    errorMap.put("message", message);
    errorMap.put("code", code);
    errorMap.put("domain", domainString);

    return errorMap;
  }
}
