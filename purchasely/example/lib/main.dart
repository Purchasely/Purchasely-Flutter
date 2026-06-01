import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:developer';

import 'package:purchasely_flutter/purchasely_flutter.dart';

import 'presentation_screen.dart';
import 'presentation_demo_screen.dart';

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

      /*Purchasely.listenToEvents((event) {
        print('Flutter Event : ${event.name}');
        print('Event properties : ${event.properties.event_name}');
        inspect(event);
      });*/

      bool configured = await PurchaselyBuilder.apiKey(
        'fcb39be4-2ba4-4db7-bde3-2a5a1e20745d',
      )
          .runningMode(RunningMode.full)
          .logLevel(LogLevel.debug)
          .stores([PLYStore.google]).start();

      if (!configured) {
        print('Purchasely SDK not configured');
        return;
      }

      Purchasely.readyToOpenDeeplink(true);
      Purchasely.setLogLevel(PLYLogLevel.debug);

      Purchasely.setUserAttributeListener(MyUserAttributeListener());

      Purchasely.userLogin("MY_USER_ID");

      Purchasely.setAttribute(
          PLYAttribute.firebase_app_instance_id, "firebaseAppInstanceId");
      Purchasely.setAttribute(
          PLYAttribute.airship_channel_id, "airshipChannelId");
      Purchasely.setAttribute(PLYAttribute.airship_user_id, "airshipUserId");
      Purchasely.setAttribute(
          PLYAttribute.batch_installation_id, "batchInstallationId");
      Purchasely.setAttribute(PLYAttribute.adjust_id, "adjustUserId");
      Purchasely.setAttribute(PLYAttribute.appsflyer_id, "appsflyerId");
      Purchasely.setAttribute(
          PLYAttribute.mixpanel_distinct_id, "mixpanelDistinctId");
      Purchasely.setAttribute(PLYAttribute.clever_tap_id, "cleverTapId");
      Purchasely.setAttribute(
          PLYAttribute.sendinblueUserEmail, "sendinblueUserEmail");
      Purchasely.setAttribute(
          PLYAttribute.iterableUserEmail, "iterableUserEmail");
      Purchasely.setAttribute(PLYAttribute.iterableUserId, "iterableUserId");
      Purchasely.setAttribute(
          PLYAttribute.atInternetIdClient, "atInternetIdClient");
      Purchasely.setAttribute(PLYAttribute.mParticleUserId, "mParticleUserId");
      Purchasely.setAttribute(
          PLYAttribute.customerioUserId, "customerioUserId");
      Purchasely.setAttribute(
          PLYAttribute.customerioUserEmail, "customerioUserEmail");
      Purchasely.setAttribute(PLYAttribute.branchUserDeveloperIdentity,
          "branchUserDeveloperIdentity");
      Purchasely.setAttribute(PLYAttribute.amplitudeUserId, "amplitudeUserId");
      Purchasely.setAttribute(
          PLYAttribute.amplitudeDeviceId, "amplitudeDeviceId");
      Purchasely.setAttribute(
          PLYAttribute.moengageUniqueId, "moengageUniqueId");
      Purchasely.setAttribute(
          PLYAttribute.oneSignalExternalId, "oneSignalExternalId");
      Purchasely.setAttribute(
          PLYAttribute.batchCustomUserId, "batchCustomUserId");

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

      Purchasely.revokeDataProcessingConsent(
          [PLYDataProcessingPurpose.campaigns]);

      //Attributes
      Purchasely.setUserAttributeWithString("stringKey", "StringValue",
          processingLegalBasis: PLYDataProcessingLegalBasis.essential);
      Purchasely.setUserAttributeWithInt("intKey", 3,
          processingLegalBasis: PLYDataProcessingLegalBasis.essential);
      Purchasely.setUserAttributeWithDouble("doubleKey", 1.2,
          processingLegalBasis: PLYDataProcessingLegalBasis.essential);
      Purchasely.setUserAttributeWithBoolean("booleanKey", true,
          processingLegalBasis: PLYDataProcessingLegalBasis.essential);
      Purchasely.setUserAttributeWithDate("dateKey", DateTime.now(),
          processingLegalBasis: PLYDataProcessingLegalBasis.essential);

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

      manageDynamicOfferings();

      if (kDebugMode) {
        Purchasely.setDebugMode(true);
      }

      // Register a typed `navigate` action interceptor as an example.
      await PurchaselyBridge.ensureInstalled().registerInterceptor(
        PresentationActionKind.navigate,
        (info, payload) {
          if (payload is NavigatePayload) {
            print('User wants to navigate to ${payload.url}');
          }
          return InterceptResult.notHandled;
        },
      );
    } catch (e) {
      print(e);
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;
  }

  Future<void> manageDynamicOfferings() async {
    // Set a dynamic offering
    final PLYDynamicOffering p1yOfferData = PLYDynamicOffering(
      'p1yOffer',
      'PURCHASELY_PLUS_YEARLY',
      'Winback',
    );
    final bool p1yOfferSuccess =
        await Purchasely.setDynamicOffering(p1yOfferData);
    print('Dynamic offering p1yOffer set success: $p1yOfferSuccess');

    final PLYDynamicOffering p1mData = PLYDynamicOffering(
      'p1m',
      'PURCHASELY_PLUS_MONTHLY',
      'NON_EXISTING_OFFER', // This might result in 'false' or an error depending on native handling
    );
    final bool p1mSuccess = await Purchasely.setDynamicOffering(p1mData);
    print('Dynamic offering p1mError set success: $p1mSuccess');

    final PLYDynamicOffering p1yData = PLYDynamicOffering(
      'p1y',
      'PURCHASELY_PLUS_YEARLY',
      null, // offerVendorId is nullable
    );
    final bool p1ySuccess = await Purchasely.setDynamicOffering(p1yData);
    print('Dynamic offering p1y set success: $p1ySuccess');

    // Get dynamic offerings
    final List<PLYDynamicOffering> offerings =
        await Purchasely.getDynamicOfferings();
    print('Dynamic offerings: ${offerings.map((o) => o.toString()).toList()}');

    // Remove a dynamic offering
    Purchasely.removeDynamicOffering('p1yOffer');
    print('Removed dynamic offering: p1yOffer');

    // Clear all dynamic offerings
    Purchasely.clearDynamicOfferings();
    print('Cleared all dynamic offerings');

    final List<PLYDynamicOffering> offeringsEmpty =
        await Purchasely.getDynamicOfferings();
    print(
        'Dynamic offerings after clear: ${offeringsEmpty.map((o) => o.toString()).toList()}');
  }

  Future<void> displayPresentation() async {
    try {
      final outcome = await PresentationBuilder.placement('STRIPE')
          .build()
          .display(const Transition.fullScreen());

      switch (outcome.purchaseResult) {
        case PurchaseResult.cancelled:
          print("User cancelled purchase");
          break;
        case PurchaseResult.purchased:
          print("User purchased ${outcome.plan}");
          break;
        case PurchaseResult.restored:
          print("User restored ${outcome.plan}");
          break;
        case null:
          print("Presentation dismissed without a purchase");
          break;
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> displayPresentationInline(BuildContext context) async {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => PresentationScreen.placement(
          'onboarding',
          onDismissed: (outcome) {
            print('Presentation was closed');
            print('Presentation result: ${outcome.purchaseResult}');
            navigatorKey.currentState?.pop();
          },
        ),
      ),
    );
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
            // Presentation API demo — start, display, interceptor, enriched outcome.
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.only(left: 20.0, right: 30.0),
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final navigator = navigatorKey.currentState;
                navigator?.push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PresentationDemoScreen(),
                  ),
                );
              },
              child: const Text('Open presentation demo'),
            ),
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
                displayPresentationInline(context);
              },
              child: const Text('Display presentation (Inline View)'),
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
