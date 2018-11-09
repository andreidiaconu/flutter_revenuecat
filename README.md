# RevenueCat Flutter plugin

This is not an official RevenueCat repo. We use this plugin at [PostMuse](https://try.postmuseapp.com/github) and decided to open source it. We welcome contributions of any kind.

## How to use
1. Go over to [RevenueCat](https://www.revenuecat.com) and create an account. [Understand](https://docs.revenuecat.com/docs/entitlements) what Entitlements are and create the ones you need.

2. Initialize the plugin
```
await Purchases.setup("YOUR_API_KEY_HERE", null);
```
If you have user accounts, the second parameter should be the user id. Leaving that `null` makes RevenueCat generate ids for you. [Read more in the docs](https://docs.revenuecat.com/docs/user-ids)

3. Know if the user is paying
This bit is async. You need to listen for changes to the Purchaser Info and find a way to update the app UI to reflect locked/unlocked features.
```
Purchases.addPurchaseListener(purchaseListener);
Purchases.addPurchaserInfoUpdateListener(purchaserListener);
Purchases.addRestoreTransactionListener(purchaserListener);
```
We recommend you do this at the highest level in your app and find a way to propagate this info. We use an [InheritedWidget](https://docs.flutter.io/flutter/widgets/InheritedWidget-class.html) to keep this state and listen for changes in another "blocker" widget that updates when the InheritedWidget changes state. The "blocker" widget blocks access to whatever is below it and shows a "PRO" badge on top. This is approach is simplistic but effective, and works for us. 

Bottom line is you need to listen for state changes from RevenueCat. Listener structure is [found here](https://github.com/andreidiaconu/flutter_revenuecat/blob/c572129f330a193b873fc93ab8d1f0f177ba95af/lib/purchases.dart#L6).

4. Get the Entitlements
```
var entitlements = await Purchases.getEntitlements();
```
Response is a Map with Entitlements, which then contain Offerings, which contain Products. Products contain price, period, introductory price, etc. It's best to [look at the models directly](https://github.com/andreidiaconu/flutter_revenuecat/blob/c572129f330a193b873fc93ab8d1f0f177ba95af/lib/purchases.dart#L163) to understand more.

5. Display Products, start payment flow
```
await Purchases.makePurchase(product.identifier);
```

6. RevenueCat will take care of the rest and update your listeners from number 3
