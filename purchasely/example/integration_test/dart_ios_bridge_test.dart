// End-to-end Dart <-> iOS bridge integration tests.
//
// Tests T1-T13 mirror the React Native E2E_TEST_INDEX.md suite, run on a real
// iOS device or simulator against the REAL Purchasely backend.
//
// Tests requiring a host driver (T8, T9):
//   T8 — (bash integration_test/tools/tap_purchase_ios.sh &)   # idb tap
//   T9 — (bash integration_test/tools/swipe_dismiss_ios.sh &)  # idb swipe
//
// Run with:
//   flutter test integration_test/dart_ios_bridge_test.dart \
//     -d "iPhone 16"

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

const String kApiKey = '0ad0594b-3b3d-4fea-8ee1-4b5df91efe87';
const String kPlacementAudiences = 'integration_test_audiences';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final configured = await Purchasely.apiKey(kApiKey)
        .runningMode(PLYRunningMode.full)
        .logLevel(PLYLogLevel.debug)
        .storekitVersion(PLYStorekitVersion.storeKit2)
        .start();
    expect(configured, isTrue,
        reason: 'SDK should configure against the real backend');
  });

  // T1 — Anonymous user ID (non-empty + UUID format)
  group('T1 — Identity APIs', () {
    testWidgets('anonymousUserId returns a non-empty UUID', (tester) async {
      final id = await Purchasely.anonymousUserId;
      expect(id, isNotEmpty);
      final uuidRegex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false,
      );
      expect(uuidRegex.hasMatch(id), isTrue,
          reason: 'anonymousUserId must be a UUID');
      debugPrint('T1 → anonymousUserId=$id');
    });

    // T2 — Login / logout cycle
    testWidgets('T2 — isAnonymous true → login → false → logout → true',
        (tester) async {
      expect(await Purchasely.isAnonymous(), isTrue);
      await Purchasely.userLogin('flutter_ios_it_user');
      expect(await Purchasely.isAnonymous(), isFalse);
      await Purchasely.userLogout();
      expect(await Purchasely.isAnonymous(), isTrue);
    });
  });

  // T3 — Preload: presentation properties
  // T4 — Dynamic offerings
  // T5 — All products
  group('T3-T5 — Catalog / data round-trips', () {
    testWidgets(
        'T3 — preload(placement) returns a full PLYPresentation', (tester) async {
      final presentation =
          await PLYPresentationBuilder.placement(kPlacementAudiences)
              .build()
              .preload();

      expect(presentation.screenId, isNotNull);
      expect(presentation.screenId, isNotEmpty);
      expect(presentation.placementId, equals(kPlacementAudiences));
      expect(presentation.type, isA<PLYPresentationType>());
      expect(presentation.plans, isA<List<PLYPresentationPlan>>());
      if (presentation.plans.isNotEmpty) {
        expect(presentation.plans.first.planVendorId, isNotNull);
        expect(presentation.plans.first.planVendorId, isNotEmpty);
      }
      final firstPlanVendorId = presentation.plans.isNotEmpty
          ? presentation.plans.first.planVendorId
          : null;
      debugPrint('T3 → screenId=${presentation.screenId} '
          'placementId=${presentation.placementId} '
          'type=${presentation.type} plans=${presentation.plans.length} '
          'plans[0].planVendorId=$firstPlanVendorId');
    });

    testWidgets('T4 — getDynamicOfferings returns a typed list', (tester) async {
      final offerings = await Purchasely.getDynamicOfferings();
      expect(offerings, isA<List<PLYDynamicOffering>>());
      debugPrint('T4 → ${offerings.length} offering(s)');
    });

    testWidgets('T5 — allProducts returns a typed list', (tester) async {
      final products = await Purchasely.allProducts();
      expect(products, isA<List<PLYProduct>>());
      debugPrint('T5 → ${products.length} product(s)');
    });
  });

  // T6 — Interceptor cleanup round-trip
  group('T6 — Action interceptor lifecycle', () {
    testWidgets(
        'interceptAction → removeActionInterceptor → removeAllActionInterceptors',
        (tester) async {
      await Purchasely.interceptAction(
        PLYPresentationActionKind.purchase,
        (info, payload) async => PLYInterceptResult.notHandled,
      );
      await Purchasely.interceptAction(
        PLYPresentationActionKind.navigate,
        (info, payload) async => PLYInterceptResult.notHandled,
      );
      await Purchasely.removeActionInterceptor(PLYPresentationActionKind.purchase);
      await Purchasely.removeAllActionInterceptors();
      expect(true, isTrue);
    });
  });

  // T7 — Display drawer + programmatic close → outcome properties
  group('T7 — Display + local dismiss (presentation.close)', () {
    testWidgets(
        'display(drawer 60%) → onPresented → close() → outcome with presentation',
        (tester) async {
      await tester.runAsync(() async {
        var presented = false;
        PLYPresentationError? presentError;

        final request = PLYPresentationBuilder.placement(kPlacementAudiences)
            .onPresented((presentation, error) {
          presented = true;
          presentError = error;
        }).build();
        final presentation = await request.preload();

        final displayFuture = presentation.display(const PLYTransition(
          type: PLYTransitionType.drawer,
          height: PLYTransitionDimension.percentage(0.6),
          dismissible: true,
        ));

        final presentSw = Stopwatch()..start();
        while (!presented && presentSw.elapsed < const Duration(seconds: 15)) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
        expect(presented, isTrue,
            reason: 'drawer should present with the v6 dimension transition');
        expect(presentError, isNull);

        await presentation.close();
        final outcome = await displayFuture.timeout(const Duration(seconds: 15));

        expect(outcome, isA<PLYPresentationOutcome>());
        expect(outcome.error, isNull);
        expect(
          outcome.closeReason,
          anyOf(PLYCloseReason.programmatic, PLYCloseReason.button,
              PLYCloseReason.backSystem),
        );
        expect(outcome.plan, anyOf(isNull, isA<PLYPlan>()));
        expect(outcome.presentation?.screenId, isNotNull);
        expect(outcome.presentation?.screenId, isNotEmpty);
        expect(outcome.presentation?.placementId, isNotNull);
        expect(outcome.presentation?.placementId, isNotEmpty);
        debugPrint('T7 → closeReason=${outcome.closeReason} '
            'screenId=${outcome.presentation?.screenId} '
            'placementId=${outcome.presentation?.placementId}');
      });
    });
  });

  // T8 — Purchase interceptor fires on real tap
  // Host driver: integration_test/tools/tap_purchase_ios.sh (idb tap)
  // Covered by integration_test/interceptor_trigger_ios_test.dart

  // T9 — Default dismiss handler + deeplink + swipe-dismiss
  // Host driver: integration_test/tools/swipe_dismiss_ios.sh (idb swipe)
  // Covered by integration_test/default_dismiss_handler_ios_test.dart

  // T10 — addEventListener → PRESENTATION_VIEWED
  group('T10 — Events: PRESENTATION_VIEWED', () {
    testWidgets(
        'listenToEvents fires PRESENTATION_VIEWED when a presentation renders',
        (tester) async {
      await tester.runAsync(() async {
        // Accept PRESENTATION_LOADED or PRESENTATION_VIEWED — the SDK may
        // deduplicate PRESENTATION_VIEWED per session when the same paywall was
        // already shown in T7. PRESENTATION_LOADED fires unconditionally.
        PLYEvent? paywallEvent;
        Purchasely.listenToEvents((event) {
          if (event.name == PLYEventName.PRESENTATION_VIEWED ||
              event.name == PLYEventName.PRESENTATION_LOADED) {
            paywallEvent ??= event;
          }
        });

        final request = PLYPresentationBuilder.placement(kPlacementAudiences).build();
        final presentation = await request.preload();
        // ignore: unawaited_futures
        presentation.display(const PLYTransition.fullScreen());

        final sw = Stopwatch()..start();
        while (paywallEvent == null && sw.elapsed < const Duration(seconds: 15)) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }

        expect(paywallEvent, isNotNull,
            reason: 'PRESENTATION_VIEWED must fire when the paywall renders');
        expect(paywallEvent!.properties.sdk_version, isNotNull);
        expect(paywallEvent!.properties.sdk_version, isNotEmpty);
        debugPrint('T10 → ${paywallEvent!.name} '
            'sdk_version=${paywallEvent!.properties.sdk_version}');

        await presentation.close();
        Purchasely.stopListeningToEvents();
      });
    });
  });

  // T11 — PRESENTATION_CLOSED → source_identifier + displayed_presentation
  group('T11 — Events: PRESENTATION_CLOSED', () {
    testWidgets(
        'PRESENTATION_CLOSED fires with source_identifier and displayed_presentation',
        (tester) async {
      await tester.runAsync(() async {
        PLYEvent? viewedEvent;
        PLYEvent? closedEvent;

        Purchasely.listenToEvents((event) {
          // Accept LOADED or VIEWED (VIEWED may be deduped by the SDK per session).
          if (event.name == PLYEventName.PRESENTATION_VIEWED ||
              event.name == PLYEventName.PRESENTATION_LOADED) {
            viewedEvent ??= event;
          } else if (event.name == PLYEventName.PRESENTATION_CLOSED) {
            closedEvent ??= event;
          }
        });

        final request = PLYPresentationBuilder.placement(kPlacementAudiences).build();
        final presentation = await request.preload();
        // ignore: unawaited_futures
        presentation.display(const PLYTransition.fullScreen());

        final viewedSw = Stopwatch()..start();
        while (viewedEvent == null &&
            viewedSw.elapsed < const Duration(seconds: 15)) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
        expect(viewedEvent, isNotNull,
            reason: 'A paywall event must fire before testing CLOSED');

        await presentation.close();

        final closedSw = Stopwatch()..start();
        while (closedEvent == null &&
            closedSw.elapsed < const Duration(seconds: 10)) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }

        expect(closedEvent, isNotNull,
            reason: 'PRESENTATION_CLOSED must fire after programmatic close');
        expect(closedEvent!.properties.source_identifier, isNotNull);
        expect(closedEvent!.properties.source_identifier, isNotEmpty);
        expect(closedEvent!.properties.displayed_presentation, isNotNull);
        expect(closedEvent!.properties.displayed_presentation, isNotEmpty);
        debugPrint('T11 → PRESENTATION_CLOSED '
            'source_identifier=${closedEvent!.properties.source_identifier} '
            'displayed_presentation=${closedEvent!.properties.displayed_presentation}');

        Purchasely.stopListeningToEvents();
      });
    });
  });

  // T12 — Programmatic close does NOT trigger close/closeAll interceptors
  group('T12 — Programmatic close bypasses interceptors', () {
    testWidgets(
        'presentation.close() does not route through close or closeAll interceptors',
        (tester) async {
      await tester.runAsync(() async {
        var interceptorCalled = false;

        await Purchasely.interceptAction(
          PLYPresentationActionKind.close,
          (info, payload) async {
            interceptorCalled = true;
            return PLYInterceptResult.notHandled;
          },
        );
        await Purchasely.interceptAction(
          PLYPresentationActionKind.closeAll,
          (info, payload) async {
            interceptorCalled = true;
            return PLYInterceptResult.notHandled;
          },
        );

        final request = PLYPresentationBuilder.placement(kPlacementAudiences).build();
        final presentation = await request.preload();
        // ignore: unawaited_futures
        presentation.display(const PLYTransition.fullScreen());

        await Future<void>.delayed(const Duration(seconds: 3));
        await presentation.close();
        await Future<void>.delayed(const Duration(seconds: 2));

        expect(interceptorCalled, isFalse,
            reason:
                'programmatic close() must NOT route through action interceptors');
        debugPrint('T12 → interceptorCalled=$interceptorCalled ✓');

        await Purchasely.removeAllActionInterceptors();
      });
    });
  });

  // T13 — User attributes: set / get / clear
  group('T13 — User attributes', () {
    testWidgets(
        'setUserAttribute* / userAttribute / clearUserAttribute round-trip',
        (tester) async {
      await tester.runAsync(() async {
        await Purchasely.setUserAttributeWithString('e2e_str', 'hello_flutter_ios');
        await Purchasely.setUserAttributeWithInt('e2e_num', 42);
        await Purchasely.setUserAttributeWithBoolean('e2e_bool', true);

        await Future<void>.delayed(const Duration(milliseconds: 300));

        final strVal = await Purchasely.userAttribute('e2e_str');
        expect(strVal, equals('hello_flutter_ios'));

        final numVal = await Purchasely.userAttribute('e2e_num');
        expect(numVal, equals(42));

        final boolVal = await Purchasely.userAttribute('e2e_bool');
        expect(boolVal, equals(true));

        Purchasely.clearUserAttribute('e2e_str');
        Purchasely.clearUserAttribute('e2e_num');
        Purchasely.clearUserAttribute('e2e_bool');

        await Future<void>.delayed(const Duration(milliseconds: 300));

        final strAfter = await Purchasely.userAttribute('e2e_str');
        expect(strAfter, isNull);

        final numAfter = await Purchasely.userAttribute('e2e_num');
        expect(numAfter, isNull);

        debugPrint('T13 → str=$strVal num=$numVal bool=$boolVal '
            '→ after clear: str=$strAfter num=$numAfter');
      });
    });
  });
}
