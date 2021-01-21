import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:purchasely/purchasely.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    try {
      Purchasely.startWithApiKey(
          'afa96c76-1d8e-4e3c-a48f-204a3cd93a15', ['Google']);
      Purchasely.setLogLevel(LogLevel.debug);
      String anonymousId = await Purchasely.anonymousUserId;
      print('Anonymous Id : $anonymousId');
      Map<dynamic, dynamic> product =
          await Purchasely.productWithIdentifier("PURCHASELY_PLUS");
      print('Product is $product');
      Purchasely.listenToEvents();
      var subscriptions = await Purchasely.userSubscriptions();
      subscriptions.forEach((element) {
        print('Subscription : $element');
      });
    } catch (e) {
      print(e);
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;
  }

  Future<void> displayPresentation() async {
    try {
      var data = await Purchasely.presentProductWithIdentifier(
          'PURCHASELY_PLUS', null);
      print('Result : $data');
    } catch (e) {
      print(e);
    }
  }

  Future<void> displaySubscriptions() async {
    try {
      Purchasely.presentSubscriptions();
    } catch (e) {
      print(e);
    }
  }

  Future<void> purchase() async {
    try {
      Map<dynamic, dynamic> plan =
          await Purchasely.purchaseWithPlanVendorId('PURCHASELY_PLUS_MONTHLY');
      print('Plan is $plan');
    } catch (e) {
      print(e);
    }
  }

  Future<void> restoreAllProducts() async {
    bool restored;
    print('start restoration');
    try {
      restored = await Purchasely.restoreAllProducts();
    } catch (e) {
      print('Exception $e');
      restored = false;
    }

    print('restored ? $restored');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('Purchasely sample'),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.only(left: 20.0, right: 30.0),
              ),
              onPressed: () {
                displayPresentation();
              },
              child: Text('Display presentation'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.only(left: 20.0, right: 30.0),
              ),
              onPressed: () {
                purchase();
              },
              child: Text('Purchase'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.only(left: 20.0, right: 30.0),
              ),
              onPressed: () {
                displaySubscriptions();
              },
              child: Text('Display subscriptions'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.only(left: 20.0, right: 30.0),
              ),
              onPressed: () {
                restoreAllProducts();
              },
              child: Text('Restore purchases'),
            ),
          ],
        )),
      ),
    );
  }
}
