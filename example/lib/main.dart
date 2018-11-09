import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:revenuecat/revenuecat.dart';

void main() => runApp(new MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      await RevenueCat.setup("YOUR_API_KEY_HERE", null);
      var entitlements = await RevenueCat.getEntitlements();
      print("Entitlements are $entitlements");
      var products = await RevenueCat.getProducts(["com.postmuseapp.designer.sub.monthly"]);
      print("Products are $products");
      platformVersion = await RevenueCat.getAppUserID();
    } catch (e, s) {
      platformVersion = 'Failed with $e $s';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      home: new Scaffold(
        appBar: new AppBar(
          title: const Text('RevenueCat example app'),
        ),
        body: new Center(
          child: new Text('RevenueCat user id: $_platformVersion\n'),
        ),
      ),
    );
  }
}
