import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:purchasely_flutter/purchasely_flutter.dart';
import 'package:purchasely_flutter/native_view_widget.dart';

import 'presentation_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    initPurchaselySdk();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPurchaselySdk() async {
    try {
      Purchasely.readyToOpenDeeplink(true);

      Purchasely.listenToEvents((event) {
        print('Flutter Event : ${event.name}');
        print('Event properties : ${event.properties.event_name}');
        print('Event property displayed_options: ${event.properties.displayed_options}');
        print('Event property selected_option_id: ${event.properties.selected_option_id}');
        print('Event property selected_options: ${event.properties.selected_options}');
        inspect(event);
      });

      bool configured = await Purchasely.start(
          apiKey: 'fcb39be4-2ba4-4db7-bde3-2a5a1e20745d',
          androidStores: ['Google'],
          storeKit1: true,
          logLevel: PLYLogLevel.debug);

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

      Purchasely.readyToOpenDeeplink(true);
      Purchasely.setLogLevel(PLYLogLevel.debug);

      Purchasely.setUserAttributeListener(MyUserAttributeListener());

      Purchasely.userLogin("MY_USER_ID");

      Purchasely.setAttribute(PLYAttribute.firebase_app_instance_id, "firebaseAppInstanceId");
      Purchasely.setAttribute(PLYAttribute.airship_channel_id, "airshipChannelId");
      Purchasely.setAttribute(PLYAttribute.airship_user_id, "airshipUserId");
      Purchasely.setAttribute(PLYAttribute.batch_installation_id, "batchInstallationId");
      Purchasely.setAttribute(PLYAttribute.adjust_id, "adjustUserId");
      Purchasely.setAttribute(PLYAttribute.appsflyer_id, "appsflyerId");
      Purchasely.setAttribute(PLYAttribute.mixpanel_distinct_id, "mixpanelDistinctId");
      Purchasely.setAttribute(PLYAttribute.clever_tap_id, "cleverTapId");
      Purchasely.setAttribute(PLYAttribute.sendinblueUserEmail, "sendinblueUserEmail");
      Purchasely.setAttribute(PLYAttribute.iterableUserEmail, "iterableUserEmail");
      Purchasely.setAttribute(PLYAttribute.iterableUserId, "iterableUserId");
      Purchasely.setAttribute(PLYAttribute.atInternetIdClient, "atInternetIdClient");
      Purchasely.setAttribute(PLYAttribute.mParticleUserId, "mParticleUserId");
      Purchasely.setAttribute(PLYAttribute.customerioUserId, "customerioUserId");
      Purchasely.setAttribute(PLYAttribute.customerioUserEmail, "customerioUserEmail");
      Purchasely.setAttribute(PLYAttribute.branchUserDeveloperIdentity, "branchUserDeveloperIdentity");
      Purchasely.setAttribute(PLYAttribute.amplitudeUserId, "amplitudeUserId");
      Purchasely.setAttribute(PLYAttribute.amplitudeDeviceId, "amplitudeDeviceId");
      Purchasely.setAttribute(PLYAttribute.moengageUniqueId, "moengageUniqueId");
      Purchasely.setAttribute(PLYAttribute.oneSignalExternalId, "oneSignalExternalId");
      Purchasely.setAttribute(PLYAttribute.batchCustomUserId, "batchCustomUserId");

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
        print(' ==> Active Subscriptions');
        if (subscriptions.isNotEmpty) {
          print(subscriptions.first.plan);
          print(subscriptions.first.subscriptionSource);
          print(subscriptions.first.nextRenewalDate);
          print(subscriptions.first.cancelledDate);
        }
      } catch (e) {
        print(e);
      }

      try {
        List<PLYSubscription> expiredSubscriptions =
            await Purchasely.userSubscriptionsHistory();
        print(' ==> Expired Subscriptions');
        if (expiredSubscriptions.isNotEmpty) {
          print(expiredSubscriptions.first.plan);
          print(expiredSubscriptions.first.subscriptionSource);
          print(expiredSubscriptions.first.nextRenewalDate);
          print(expiredSubscriptions.first.cancelledDate);
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

      Purchasely.setUserAttributeWithStringArray(
          "stringArrayKey", ["StringValue", "test"]);
      Purchasely.setUserAttributeWithIntArray("intArrayKey", [3, 8, 42]);
      Purchasely.setUserAttributeWithDoubleArray(
          "doubleArrayKey", [1.2, 19.9, 2323.213]);
      Purchasely.setUserAttributeWithBooleanArray(
          "booleanArrayKey", [true, true, false, false]);

      Purchasely.incrementUserAttribute("sessions");
      Purchasely.incrementUserAttribute("sessions");
      Purchasely.incrementUserAttribute("sessions");
      Purchasely.decrementUserAttribute("sessions");

      Purchasely.incrementUserAttribute("app_views", value: 8);

      Map<dynamic, dynamic> attributes = await Purchasely.userAttributes();
      attributes.forEach((key, value) {
        print("Attribute $key is $value");
      });

      dynamic dateAttribute = await Purchasely.userAttribute("dateKey");
      print(dateAttribute.year);

      Purchasely.clearUserAttribute("dateKey");

      Purchasely.clearUserAttributes();
      print(await Purchasely.userAttributes());

      Purchasely.clearBuiltInAttributes();

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
      var result = await Purchasely.presentPresentationForPlacement("abtest",
          isFullscreen: true);

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

  Future<void> displayPresentationNativeView(BuildContext context) async {
    // You can fetch the presentation before displaying it when ready
    var presentation = await Purchasely.fetchPresentation("Settings");

    if (presentation != null) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
            builder: (context) => PresentationScreen(
                    properties: {
                      'presentation': presentation,
                      //'contentId': null, // Optional
                    },
                    callback: (PresentPresentationResult result) {
                      print('Presentation was closed');
                      print(
                          'Presentation result:${result.result} - plan:${result.plan?.vendorId}');
                      navigatorKey.currentState?.pop();
                    })),
      );
    } else {
      print("No presentation found");

      // You can also display a presentation without fetching it before
      // Purchasely will fetch it automatically, display a loader and display it
      navigatorKey.currentState?.push(
        MaterialPageRoute(
            builder: (context) => PresentationScreen(
                    properties: const {
                      'placementId': 'onboarding',
                      //'presentationId': 'TF1', // You can also set a presentationId directly but this is not recommended
                      //'contentId': null, // Optional
                    },
                    callback: (PresentPresentationResult result) {
                      print('Presentation was closed');
                      print(
                          'Presentation result:${result.result} - plan:${result.plan?.vendorId}');
                      navigatorKey.currentState?.pop();
                    })),
      );
    }
  }

  Future<void> fetchPresentation() async {
    try {
      var presentation = await Purchasely.fetchPresentation(null, presentationId: 'headspace_survey');

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
    Purchasely.synchronize();
    print('synchronization with Purchasely');
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
      navigatorKey: navigatorKey,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Purchasely Flutter Sample'),
        ),
        body: Center(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
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
                displayPresentationNativeView(context);
              },
              child: const Text('Display presentation (Native View)'),
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

class MyUserAttributeListener implements UserAttributeListener {
  @override
  void onUserAttributeSet(String key, PLYUserAttributeType type, dynamic value,
      PLYUserAttributeSource source) {
    print("Attribute set: $key, Type: $type, Value: $value, Source: $source");
  }

  @override
  void onUserAttributeRemoved(String key, PLYUserAttributeSource source) {
    print("Attribute removed: $key, Source: $source");
  }
}
