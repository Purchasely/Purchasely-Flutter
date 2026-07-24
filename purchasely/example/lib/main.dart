// ignore_for_file: avoid_print, library_private_types_in_public_api

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:developer';

import 'package:purchasely_flutter/purchasely_flutter.dart';

import 'presentation_screen.dart';
import 'presentation_demo_screen.dart';
import 'custom_screens.dart';

void main() {
  runApp(const MyApp());
}

/// Dedicated entrypoint used by the secondary Flutter engine created for a
/// CLIENT step inside a native Purchasely flow.
@pragma('vm:entry-point')
void purchaselyCustomScreen(List<String> args) {
  PurchaselyCustomScreens.run(args, (context, presentation) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CustomScreenStep(presentation: presentation),
    );
  });
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
      /*Purchasely.listenToEvents((event) {
        print('Flutter Event : ${event.name}');
        print('Event properties : ${event.properties.event_name}');
        inspect(event);
      });*/

      bool configured =
          await Purchasely.apiKey('fcb39be4-2ba4-4db7-bde3-2a5a1e20745d')
              .runningMode(PLYRunningMode.full)
              .logLevel(PLYLogLevel.debug)
              .allowDeeplink(true)
              .stores([PLYStore.google]).start();

      if (!configured) {
        print('Purchasely SDK not configured');
        return;
      }

      await Purchasely.setCustomScreenProvider(
        entrypoint: 'purchaselyCustomScreen',
      );

      Purchasely.allowDeeplink(true);
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
      await Purchasely.interceptAction(
        PLYPresentationActionKind.navigate,
        (info, payload) {
          if (payload is PLYNavigatePayload) {
            print('User wants to navigate to ${payload.url}');
          }
          return PLYInterceptResult.notHandled;
        },
      );

      // Register a typed `purchase` action interceptor: inspect the selected
      // plan via the typed `PLYPurchasePayload`, then return `notHandled` so the
      // SDK keeps owning the purchase flow.
      await Purchasely.interceptAction(
        PLYPresentationActionKind.purchase,
        (info, payload) {
          if (payload is PLYPurchasePayload) {
            print(
                'User wants to purchase plan ${payload.plan} with ${payload.offer} — letting the SDK '
                'proceed');
          }
          return PLYInterceptResult.notHandled;
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
      final presentation =
          await PLYPresentationBuilder.placement('premium').build().preload();

      final outcome = await presentation.display();

      //.display(const PLYTransition.drawer(height: PLYTransitionDimension.percentage(0.5)));

      switch (outcome.purchaseResult) {
        case PLYPurchaseResult.cancelled:
          print("User cancelled purchase");
          break;
        case PLYPurchaseResult.purchased:
          print("User purchased ${outcome.plan}");
          break;
        case PLYPurchaseResult.restored:
          print("User restored ${outcome.plan}");
          break;
        case null:
          print("PLYPresentation dismissed without a purchase");
          break;
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> displayCustomScreenFlow() async {
    try {
      // Placement `byos` displays flow `flow_byos`. Its second step is the
      // client-authored screen `byos`, with `continue`, `close`, and
      // `close_all` connections configured in the Purchasely Console.
      final outcome =
          await PLYPresentationBuilder.placement('byos').build().display();
      print('BYOS flow dismissed: ${outcome.closeReason}');
    } catch (e) {
      print('Unable to display BYOS flow: $e');
    }
  }

  Future<void> displayPresentationInline(BuildContext context) async {
    // Closing an inline paywall fires BOTH onCloseRequested (the ✕ asks the
    // host to close) and, right after the view is removed, onDismissed. Pop the
    // route only ONCE — otherwise the second pop would also dismiss the screen
    // underneath (black screen).
    var popped = false;
    void closeInline() {
      if (popped) return;
      popped = true;
      navigatorKey.currentState?.pop();
    }

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => PresentationScreen.placement(
          'promo_offers',
          onCloseRequested: () {
            // Inline view: the ✕ button only requests a close, so we pop the
            // screen ourselves.
            print('PLYPresentation close requested — popping inline screen');
            closeInline();
          },
          onDismissed: (outcome) {
            print('PLYPresentation was closed');
            print('PLYPresentation result: ${outcome.purchaseResult}');
            closeInline();
          },
        ),
      ),
    );
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
    // Since the 6.0 native SDKs expose success/error callbacks on
    // synchronize(), the Dart Future now resolves once the sync completes and
    // throws on failure — so it can be awaited and wrapped in try/catch.
    try {
      await Purchasely.synchronize();
      print('synchronization with Purchasely succeeded');
    } catch (e) {
      print('synchronization with Purchasely failed: $e');
    }
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
            // PLYPresentation API demo — start, display, interceptor, enriched outcome.
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
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              onPressed: displayCustomScreenFlow,
              child: const Text('Display BYOS flow (byos)'),
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
