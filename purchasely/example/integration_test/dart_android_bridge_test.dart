// End-to-end Dart <-> Android bridge integration tests.
//
// These run on a real Android device/emulator against the REAL Purchasely
// backend (real network calls), using the same test API key and placements as
// the native Android `integration-tests` module
// (`com.purchasely.integration.BaseIntegrationTest`).
//
// Goal: prove every public Dart API forwards its inputs across the
// MethodChannel/EventChannel to the native Android SDK and returns the correct,
// typed outputs — with special focus on the v6 changes:
//   * synchronize() -> Future<bool>
//   * PLYPresentationOutcome (typed plan, reduced PLYCloseReason)
//   * PLYTransition dimension model (width/height as PLYTransitionDimension)
//   * removeActionInterceptor / removeAllActionInterceptors
//
// Run with:
//   flutter test integration_test/dart_android_bridge_test.dart -d emulator-5554

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

// Mirrors com.purchasely.integration.BaseIntegrationTest.
const String kApiKey = '0ad0594b-3b3d-4fea-8ee1-4b5df91efe87';
const String kPlacementAudiences = 'integration_test_audiences';
const String kPlacementFlow = 'integration_test_flow';
const String kPlacementInteractions = 'integration_tests_interactions';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Start the SDK once for the whole suite (real config fetch over network).
    final configured = await PLYPurchaselyBuilder.apiKey(kApiKey)
        .runningMode(PLYRunningMode.full)
        .logLevel(PLYLogLevel.debug)
        .stores([PLYStore.google]).start();
    expect(configured, isTrue,
        reason: 'SDK should configure against the real backend');
  });

  group('Identity APIs', () {
    testWidgets('anonymousUserId returns a non-empty id', (tester) async {
      final id = await Purchasely.anonymousUserId;
      expect(id, isNotEmpty);
    });

    testWidgets('isAnonymous true → login → false → logout → true',
        (tester) async {
      expect(await Purchasely.isAnonymous(), isTrue);

      await Purchasely.userLogin('flutter_it_user');
      expect(await Purchasely.isAnonymous(), isFalse);

      await Purchasely.userLogout();
      expect(await Purchasely.isAnonymous(), isTrue);
    });
  });

  group('Catalog / data round-trips', () {
    testWidgets('preload(placement) returns a typed PLYPresentation',
        (tester) async {
      final presentation =
          await PLYPresentationBuilder.placement(kPlacementAudiences)
              .build()
              .preload();

      // A real backend round-trip: the screen id must come back.
      expect(presentation.screenId, isNotNull);
      expect(presentation.screenId, isNotEmpty);
      expect(presentation.type, isA<PLYPresentationType>());
      // Plans embedded in the presentation are typed PLYPresentationPlan.
      expect(presentation.plans, isA<List<PLYPresentationPlan>>());
      debugPrint('preload → screenId=${presentation.screenId} '
          'type=${presentation.type} plans=${presentation.plans.length}');
    });

    testWidgets('getDynamicOfferings returns a typed list', (tester) async {
      final offerings = await Purchasely.getDynamicOfferings();
      expect(offerings, isA<List<PLYDynamicOffering>>());
    });

    testWidgets('allProducts returns a typed list', (tester) async {
      final products = await Purchasely.allProducts();
      expect(products, isA<List<PLYProduct>>());
      debugPrint('allProducts → ${products.length} product(s)');
    });
  });

  group('synchronize() -> Future<bool> (v6)', () {
    testWidgets('resolves true on success OR throws PlatformException on error',
        (tester) async {
      // v6 contract: synchronize() resolves `true` on native success and
      // rethrows the native error as a PlatformException (was fire-and-forget).
      // On a CI emulator without Play billing the store reports
      // BillingUnavailable — which exercises (and proves) the error path.
      try {
        final result = await Purchasely.synchronize();
        expect(result, isTrue);
        debugPrint('synchronize → resolved $result (success path)');
      } on PlatformException catch (e) {
        // Correct v6 behavior: native onError -> PlatformException in Dart.
        debugPrint(
            'synchronize → threw PlatformException(${e.code}) (error path): ${e.message}');
      }
    });
  });

  group('Action interceptor lifecycle (renamed v6 cleanup APIs)', () {
    testWidgets('register → removeActionInterceptor → removeAll round-trips',
        (tester) async {
      // Each call forwards to the native plugin over the MethodChannel.
      await Purchasely.interceptAction(
        PLYPresentationActionKind.purchase,
        (info, payload) async => PLYInterceptResult.notHandled,
      );
      await Purchasely.interceptAction(
        PLYPresentationActionKind.navigate,
        (info, payload) async => PLYInterceptResult.notHandled,
      );

      // Renamed in v6: must reach the native side without error.
      await Purchasely.removeActionInterceptor(PLYPresentationActionKind.purchase);
      await Purchasely.removeAllActionInterceptors();
      // Reaching here means all four bridge round-trips succeeded.
      expect(true, isTrue);
    });
  });

  group('Display + local dismiss (presentation.close)', () {
    testWidgets(
        'display(drawer 60%) → onPresented → close() resolves the outcome',
        (tester) async {
      // Real native display needs real async (timers + platform/event channels).
      await tester.runAsync(() async {
        var presented = false;
        PLYPresentationError? presentError;

        final request = PLYPresentationBuilder.placement(kPlacementAudiences)
            .onPresented((presentation, error) {
          presented = true;
          presentError = error;
        }).build();
        final presentation = await request.preload();

        // Display with the v6 dimension model (drawer height = 60%): exercises
        // parseTransition → PLYTransition(height=PERCENTAGE, value=0.6) natively.
        // The future resolves at dismiss.
        final displayFuture = presentation.display(const PLYTransition(
          type: PLYTransitionType.drawer,
          height: PLYTransitionDimension.percentage(0.6),
          dismissible: true,
        ));

        // Wait for the native screen to present — proves the drawer transition
        // (with its dimension) was accepted and rendered by the native SDK.
        final presentSw = Stopwatch()..start();
        while (!presented && presentSw.elapsed < const Duration(seconds: 15)) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
        expect(presented, isTrue,
            reason:
                'native drawer should present with the v6 dimension transition');
        expect(presentError, isNull);

        // Local dismiss from Dart: presentation.close() → native closeAllScreens.
        // With the onDismissed wiring fixed, the display future MUST resolve.
        await presentation.close();
        final outcome =
            await displayFuture.timeout(const Duration(seconds: 15));

        expect(outcome, isA<PLYPresentationOutcome>());
        expect(outcome.error, isNull);
        // Reduced v6 enum — interactiveDismiss no longer exists. A programmatic
        // close reports programmatic (button if the SDK attributes the chain to
        // the close control).
        expect(
          outcome.closeReason,
          anyOf(PLYCloseReason.programmatic, PLYCloseReason.button,
              PLYCloseReason.backSystem),
        );
        expect(outcome.plan, anyOf(isNull, isA<PLYPlan>()));
        debugPrint('local dismiss → purchaseResult=${outcome.purchaseResult} '
            'closeReason=${outcome.closeReason} plan=${outcome.plan?.vendorId}');
      });
    });
  });
}
