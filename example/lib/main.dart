import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:developer';

import 'package:purchasely_flutter/purchasely_flutter.dart';

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
    initPurchaselySdk();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPurchaselySdk() async {
    try {
      bool configured = await Purchasely.startWithApiKey(
          'afa96c76-1d8e-4e3c-a48f-204a3cd93a15',
          ['Google'],
          null,
          LogLevel.debug,
          RunningMode.full);

      if (!configured) {
        print('Purchasely SDK not configured');
        return;
      }

      //Purchasely.setLogLevel(LogLevel.debug);

      String anonymousId = await Purchasely.anonymousUserId;
      print('Anonymous Id : $anonymousId');

      PurchaselyProduct product =
          await Purchasely.productWithIdentifier("PURCHASELY_PLUS");
      print('Product found');
      inspect(product);

      Purchasely.listenToEvents((event) {
        print('Event : $event');
      });

      var subscriptions = await Purchasely.userSubscriptions();
      subscriptions.forEach((element) {
        inspect(element);
      });

      Purchasely.setDefaultPresentationResultCallback(
          (PresentPresentationResult value) {
        print('Default with $value');
      });

      Purchasely.setPaywallActionInterceptorCallback(
          (PaywallActionInterceptorResult result) {
        print('Received action from paywall');
        inspect(result);

        if (result.action == PLYPaywallAction.navigate) {
          Purchasely.onProcessAction(true);
        } else if (result.action == PLYPaywallAction.close) {
          print('User wants to close paywall');
          Purchasely.onProcessAction(true);
        } else if (result.action == PLYPaywallAction.login) {
          print('User wants to login');
          //Present your own screen for user to log in
          Purchasely.closePaywall();
          Purchasely.userLogin('MY_USER_ID');
          //Call this method to update Purchasely Paywall
          Purchasely.onProcessAction(true);
        } else if (result.action == PLYPaywallAction.open_presentation) {
          print('User wants to open a new paywall');
          Purchasely.onProcessAction(true);
        } else if (result.action == PLYPaywallAction.purchase) {
          print('User wants to purchase');
          //If you want to intercept it, close paywall and display your screen
          Purchasely.closePaywall();
        } else if (result.action == PLYPaywallAction.restore) {
          print('User wants to restore his purchases');
          Purchasely.onProcessAction(true);
        } else {
          print('Action unknown ' + result.action.toString());
          Purchasely.onProcessAction(true);
        }
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
      var result =
          await Purchasely.presentProductWithIdentifier("PURCHASELY_PLUS");
      print('Result : $result');
      if (result.result == PurchaseResult.cancelled) {
        print("User cancelled purchased");
      } else {
        print('User purchased: $result.plan.name');
      }
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

  Future<void> continuePurchase() async {
    Purchasely.onProcessAction(true);
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
                continuePurchase();
              },
              child: Text('Continue purchase'),
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
