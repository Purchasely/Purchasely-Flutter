import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:purchasely_flutter/purchasely_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

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
      Purchasely.readyToOpenDeeplink(true);

      bool configured = await Purchasely.start(
          apiKey: 'fcb39be4-2ba4-4db7-bde3-2a5a1e20745d', storeKit1: true);

      // Default values
      /*bool configured = await Purchasely.start(
        apiKey: 'fcb39be4-2ba4-4db7-bde3-2a5a1e20745d',
        androidStores: ['Google'],
        storeKit1: false,
        logLevel: PLYLogLevel.error,
        runningMode: PLYRunningMode.full,
        userId: null,
      );*/

      if (!configured) {
        print('Purchasely SDK not configured');
        return;
      }

      //Purchasely.setLogLevel(LogLevel.debug);

      Purchasely.setAttribute(
          PLYAttribute.amplitudeUserId, "amplitude_user_id");
      Purchasely.setAttribute(PLYAttribute.adjust_id, "adjust_user_id");
      Purchasely.setAttribute(
          PLYAttribute.moengageUniqueId, "momengage_unique_id");

      Purchasely.setLanguage("en");

      String anonymousId = await Purchasely.anonymousUserId;
      print('Anonymous Id : $anonymousId');

      bool isAnonymous = await Purchasely.isAnonymous();
      print('is Anonymous ? : $isAnonymous');

      bool isEligible =
          await Purchasely.isEligibleForIntroOffer('PURCHASELY_PLUS_YEARLY');
      print('is eligible ? : $isEligible');

      try {
        List<PLYSubscription> subscriptions =
            await Purchasely.userSubscriptions();
        print(' ==> Subscriptions');
        if (subscriptions.isNotEmpty) {
          print(subscriptions.first.plan);
          print(subscriptions.first.subscriptionSource);
          print(subscriptions.first.nextRenewalDate);
          print(subscriptions.first.cancelledDate);
        }
      } catch (e) {
        print(e);
      }

      List<PLYProduct> products = await Purchasely.allProducts();
      inspect(products);

      PLYProduct product =
          await Purchasely.productWithIdentifier("PURCHASELY_PLUS");
      print('Product found');
      inspect(product);

      Purchasely.listenToEvents((event) {
        print('Event : ${event.name}');
        inspect(event);
      });

      Purchasely.setDefaultPresentationResultCallback(
          (PresentPresentationResult value) {
        print('Presentation Result : ' + value.result.toString());

        if (value.plan != null) {
          //User bought a plan
        }
      });

      //Attributes
      Purchasely.setUserAttributeWithString("stringKey", "StringValue");
      Purchasely.setUserAttributeWithInt("intKey", 3);
      Purchasely.setUserAttributeWithDouble("doubleKey", 1.2);
      Purchasely.setUserAttributeWithBoolean("booleanKey", true);
      Purchasely.setUserAttributeWithDate("dateKey", DateTime.now());

      Map<dynamic, dynamic> attributes = await Purchasely.userAttributes();
      attributes.forEach((key, value) {
        print("Attribute $key is $value");
      });

      dynamic dateAttribute = await Purchasely.userAttribute("dateKey");
      print(dateAttribute.year);

      Purchasely.clearUserAttribute("dateKey");

      Purchasely.clearUserAttributes();
      print(await Purchasely.userAttributes());

      Purchasely.setPaywallActionInterceptorCallback(
          (PaywallActionInterceptorResult result) {
        print('Received action from paywall');
        inspect(result);

        if (result.action == PLYPaywallAction.navigate) {
          print('User wants to navigate');
          Purchasely.onProcessAction(true);
        } else if (result.action == PLYPaywallAction.close) {
          print('User wants to close paywall');
          Purchasely.onProcessAction(true);
        } else if (result.action == PLYPaywallAction.login) {
          print('User wants to login');
          //Present your own screen for user to log in
          Purchasely.closePresentation();
          Purchasely.userLogin('MY_USER_ID');
          //Call this method to update Purchasely Paywall
          Purchasely.onProcessAction(true);
        } else if (result.action == PLYPaywallAction.open_presentation) {
          print('User wants to open a new paywall');
          Purchasely.onProcessAction(true);
        } else if (result.action == PLYPaywallAction.purchase) {
          print('User wants to purchase');
          //If you want to intercept it, hide paywall and display your screen
          Purchasely.hidePresentation();
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
      var result = await Purchasely.presentPresentationForPlacement(
          "ONBOARDING",
          isFullscreen: false);

      switch (result.result) {
        case PLYPurchaseResult.cancelled:
          {
            print("User cancelled purchased");
          }
          break;
        case PLYPurchaseResult.purchased:
          {
            print("User purchased ${result.plan?.name}");
          }
          break;
        case PLYPurchaseResult.restored:
          {
            print("User restored ${result.plan?.name}");
          }
          break;
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> fetchPresentation() async {
    try {
      var presentation = await Purchasely.fetchPresentation("ONBOARDING");

      if (presentation == null) {
        print("No presentation found");
        return;
      }

      print("Presentation: ${presentation}");

      if (presentation.type == PLYPresentationType.deactivated) {
        // No paywall to display
        return;
      }

      if (presentation.type == PLYPresentationType.client) {
        print("Presentation metadata: ${presentation.metadata}");
        return;
      }

      //Display Purchasely paywall

      var presentResult = await Purchasely.presentPresentation(presentation,
          isFullscreen: true);

      switch (presentResult.result) {
        case PLYPurchaseResult.cancelled:
          {
            print("User cancelled purchased");
          }
          break;
        case PLYPurchaseResult.purchased:
          {
            print("User purchased ${presentResult.plan?.name}");
          }
          break;
        case PLYPurchaseResult.restored:
          {
            print("User restored ${presentResult.plan?.name}");
          }
          break;
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
    Purchasely.showPresentation();
    Purchasely.onProcessAction(true);
  }

  Future<void> purchase() async {
    try {
      Map<dynamic, dynamic> plan = await Purchasely.purchaseWithPlanVendorId(
          vendorId: 'PURCHASELY_PLUS_MONTHLY');
      print('Plan is $plan');
    } catch (e) {
      print(e);
    }
  }

  Future<void> purchaseWithPromotionalOffer() async {
    try {
      Map<dynamic, dynamic> plan = await Purchasely.purchaseWithPlanVendorId(
          vendorId: 'PURCHASELY_PLUS_YEARLY',
          offerId: 'com.purchasely.plus.yearly.promo');
      print('Plan is $plan');
    } catch (e) {
      print(e);
    }
  }

  Future<void> signPromotionalOffer() async {
    try {
      Map<dynamic, dynamic> signature = await Purchasely.signPromotionalOffer(
          'com.purchasely.plus.yearly',
          'com.purchasely.plus.yearly.winback.test');
      print('Signature $signature');
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

    Future<void> synchronize() async {
    bool restored;
    print('start synchronization');
    try {
      restored = await Purchasely.synchronize();
    } catch (e) {
      print('Exception $e');
      restored = false;
    }

    print('synchronized ? $restored');
  }

  Future<void> hidePresentation() async {
    Purchasely.hidePresentation();
  }

  Future<void> showPresentation() async {
    Purchasely.showPresentation();
  }

  Future<void> closePresentation() async {
    Purchasely.closePresentation();
  }

  Future<void> testFunction() async {
    displayPresentation();
    sleep(const Duration(seconds: 3));
    displayPresentation();
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
            const Text('Purchasely sample'),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.only(left: 20.0, right: 30.0),
              ),
              onPressed: () {
                displayPresentation();
              },
              child: const Text('Display presentation'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.only(left: 20.0, right: 30.0),
              ),
              onPressed: () {
                fetchPresentation();
              },
              child: const Text('Fetch presentation'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.only(left: 20.0, right: 30.0),
              ),
              onPressed: () {
                showPresentation();
              },
              child: const Text('Show presentation'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.only(left: 20.0, right: 30.0),
              ),
              onPressed: () {
                closePresentation();
              },
              child: const Text('Close presentation'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.only(left: 20.0, right: 30.0),
              ),
              onPressed: () {
                continuePurchase();
              },
              child: const Text('Continue purchase'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.only(left: 20.0, right: 30.0),
              ),
              onPressed: () {
                purchase();
              },
              child: const Text('Purchase'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.only(left: 20.0, right: 30.0),
              ),
              onPressed: () {
                purchaseWithPromotionalOffer();
              },
              child: const Text('Purchase with promotional offer'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.only(left: 20.0, right: 30.0),
              ),
              onPressed: () {
                signPromotionalOffer();
              },
              child: const Text('Sign promotional offer'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.only(left: 20.0, right: 30.0),
              ),
              onPressed: () {
                displaySubscriptions();
              },
              child: const Text('Display subscriptions'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.only(left: 20.0, right: 30.0),
              ),
              onPressed: () {
                restoreAllProducts();
              },
              child: const Text('Restore purchases'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.only(left: 20.0, right: 30.0),
              ),
              onPressed: () {
                synchronize();
              },
              child: const Text('Synchronize'),
            ),
          ],
        )),
      ),
    );
  }
}
