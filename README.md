# Deprecated - Please use [official lib](https://pub.dev/packages/purchases_flutter)

This is not an official RevenueCat library. When this was created, RevenueCat did not have official support for Flutter yet. 
The good news is that they do support Flutter now. Please use the [official lib](https://pub.dev/packages/purchases_flutter) instead.

I have no plans of maintaining this project.

## Install

Plugin is published on [Pub](https://pub.dartlang.org/packages/revenuecat). Add this to your `pubspec.yaml`:
```
dependencies:
  revenuecat: ^1.0.4
```

Then run
```
flutter packages get
```

Import it in your dart files
```
import 'package:revenuecat/revenuecat.dart';
```

## How to use
1. Go over to [RevenueCat](https://www.revenuecat.com) and create an account. [Understand](https://docs.revenuecat.com/docs/entitlements) what Entitlements are and create the ones you need.

2. Initialize the plugin
```
await RevenueCat.setup("YOUR_API_KEY_HERE", null);
```
If you have user accounts, the second parameter should be the user id. Leaving that `null` makes RevenueCat generate ids for you. [Read more in the docs](https://docs.revenuecat.com/docs/user-ids)

3. Know if the user is paying

This bit is async. You need to listen for changes to the Purchaser Info and find a way to update the app UI to reflect locked/unlocked features.
```
RevenueCat.addPurchaseListener(purchaseListener);
RevenueCat.addPurchaserInfoUpdateListener(purchaserListener);
RevenueCat.addRestoreTransactionListener(purchaserListener);
```
We recommend you do this at the highest level in your app and find a way to propagate this info. We use an [InheritedWidget](https://docs.flutter.io/flutter/widgets/InheritedWidget-class.html) to keep this state and listen for changes in another "blocker" widget that updates when the InheritedWidget changes state. The "blocker" widget blocks access to whatever is below it and shows a "PRO" badge on top. This is approach is simplistic but effective, and works for us. 

Bottom line is you need to listen for state changes from RevenueCat. Listener structure is [found here](https://github.com/andreidiaconu/flutter_revenuecat/blob/master/lib/revenuecat.dart#L6).

4. Get the Entitlements
```
var entitlements = await RevenueCat.getEntitlements();
```
Response is a Map with Entitlements, which then contain Offerings, which contain Products. Products contain price, period, introductory price, etc. It's best to [look at the models directly](https://github.com/andreidiaconu/flutter_revenuecat/blob/master/lib/revenuecat.dart#L157) to understand more.

5. Display Products, start payment flow
```
await RevenueCat.makePurchase(product.identifier);
```

6. RevenueCat will take care of the rest and update your listeners from number 3

# License
Published under MIT License. [Read it here](https://github.com/andreidiaconu/flutter_revenuecat/blob/master/LICENSE)
