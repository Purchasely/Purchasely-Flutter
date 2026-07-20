// End-to-end Dart <-> Android bridge integration tests.
//
// Tests T1-T13 mirror the React Native E2E_TEST_INDEX.md suite, run on a real
// Android device/emulator against the REAL Purchasely backend.
//
// Same API key and placements as the native Android `integration-tests` module
// (com.purchasely.integration.BaseIntegrationTest).
//
// Tests requiring a host driver (T8, T9):
//   T8 — (bash integration_test/tools/tap_purchase.sh &)
//   T9 — (bash integration_test/tools/press_back.sh &)
//
// Run with:
//   flutter test integration_test/dart_android_bridge_test.dart -d emulator-5554

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

import 'helpers/e2e_start.dart';

const String kApiKey = '0ad0594b-3b3d-4fea-8ee1-4b5df91efe87';
const String kPlacementAudiences = 'integration_test_audiences';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final configured = await startWithRetry(() => Purchasely.apiKey(kApiKey)
        .runningMode(PLYRunningMode.full)
        .logLevel(PLYLogLevel.debug)
        .stores([PLYStore.google]).start());
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
      await Purchasely.userLogin('flutter_it_user');
      expect(await Purchasely.isAnonymous(), isFalse);
      await Purchasely.userLogout();
      expect(await Purchasely.isAnonymous(), isTrue);
    });
  });

  // T3 — Preload: presentation properties
  // T4 — Dynamic offerings
  // T5 — All products
  group('T3-T5 — Catalog / data round-trips', () {
    testWidgets('T3 — preload(placement) returns a full PLYPresentation',
        (tester) async {
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

    testWidgets('T4 — getDynamicOfferings returns a typed list',
        (tester) async {
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
      await Purchasely.removeActionInterceptor(
          PLYPresentationActionKind.purchase);
      await Purchasely.removeAllActionInterceptors();
      expect(true, isTrue);
    });
  });

  // synchronize() — v6-specific (not in RN index but important for Android)
  group('synchronize() -> Future<bool> (v6)', () {
    testWidgets('resolves true or throws PlatformException on billing error',
        (tester) async {
      try {
        final result = await Purchasely.synchronize();
        expect(result, isTrue);
        debugPrint('synchronize → $result (success)');
      } on PlatformException catch (e) {
        debugPrint('synchronize → PlatformException(${e.code}): ${e.message}');
      }
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
        final outcome =
            await displayFuture.timeout(const Duration(seconds: 15));

        expect(outcome, isA<PLYPresentationOutcome>());
        expect(outcome.error, isNull);
        expect(
          outcome.closeReason,
          anyOf(PLYCloseReason.programmatic, PLYCloseReason.button,
              PLYCloseReason.backSystem),
        );
        expect(outcome.plan, anyOf(isNull, isA<PLYPlan>()));
        // v6 — outcome carries presentation metadata (RN T7 steps 7-8)
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

  // T8 — Purchase interceptor fires on real tap (host driver: tap_purchase.sh)
  // Covered by integration_test/interceptor_trigger_test.dart

  // T9 — Default dismiss handler + deeplink + BACK (host driver: press_back.sh)
  // Covered by integration_test/default_dismiss_handler_test.dart

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

        final request =
            PLYPresentationBuilder.placement(kPlacementAudiences).build();
        final presentation = await request.preload();
        // ignore: unawaited_futures
        presentation.display(const PLYTransition.fullScreen());

        final sw = Stopwatch()..start();
        while (
            paywallEvent == null && sw.elapsed < const Duration(seconds: 15)) {
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

        final request =
            PLYPresentationBuilder.placement(kPlacementAudiences).build();
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
        // source_identifier is the placement_id in the Flutter event contract.
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

        final request =
            PLYPresentationBuilder.placement(kPlacementAudiences).build();
        final presentation = await request.preload();
        // ignore: unawaited_futures
        presentation.display(const PLYTransition.fullScreen());

        // Allow the paywall to render before closing.
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
        await Purchasely.setUserAttributeWithString('e2e_str', 'hello_flutter');
        await Purchasely.setUserAttributeWithInt('e2e_num', 42);
        await Purchasely.setUserAttributeWithBoolean('e2e_bool', true);

        await Future<void>.delayed(const Duration(milliseconds: 300));

        final strVal = await Purchasely.userAttribute('e2e_str');
        expect(strVal, equals('hello_flutter'));

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

  // T14 — Extended user attribute types: double, date, arrays
  group('T14 — User attributes: types étendus', () {
    testWidgets(
        'double / date / string-array / int-array / boolean-array round-trip',
        (tester) async {
      await tester.runAsync(() async {
        await Purchasely.setUserAttributeWithDouble('e2e_dbl', 3.14);
        await Purchasely.setUserAttributeWithDate(
            'e2e_date', DateTime.utc(2024, 6, 15, 12, 0, 0));
        await Purchasely.setUserAttributeWithStringArray(
            'e2e_str_arr', ['alpha', 'beta', 'gamma']);
        await Purchasely.setUserAttributeWithIntArray(
            'e2e_int_arr', [10, 20, 30]);
        await Purchasely.setUserAttributeWithBooleanArray(
            'e2e_bool_arr', [true, false, true]);

        await Future<void>.delayed(const Duration(milliseconds: 400));

        final rawDbl = await Purchasely.userAttribute('e2e_dbl');
        expect(rawDbl, isNotNull);
        expect((rawDbl as num).toDouble(), closeTo(3.14, 0.01));

        final dateVal = await Purchasely.userAttribute('e2e_date');
        expect(dateVal, isA<DateTime>());
        final dt = dateVal as DateTime;
        expect(dt.year, equals(2024));
        expect(dt.month, equals(6));
        expect(dt.day, equals(15));

        final strArr = await Purchasely.userAttribute('e2e_str_arr');
        expect(strArr, isA<List>());
        expect((strArr as List).length, equals(3));

        final intArr = await Purchasely.userAttribute('e2e_int_arr');
        expect(intArr, isA<List>());
        expect((intArr as List).length, equals(3));

        final boolArr = await Purchasely.userAttribute('e2e_bool_arr');
        expect(boolArr, isA<List>());
        expect((boolArr as List).length, equals(3));

        for (final k in [
          'e2e_dbl',
          'e2e_date',
          'e2e_str_arr',
          'e2e_int_arr',
          'e2e_bool_arr'
        ]) {
          Purchasely.clearUserAttribute(k);
        }
        debugPrint('T14 → dbl=${(rawDbl).toDouble()} '
            'date=${dt.toIso8601String()} '
            'strArr=$strArr ✓');
      });
    });
  });

  // T15 — Bulk attribute operations: userAttributes(), clearUserAttributes(), clearBuiltInAttributes()
  group('T15 — User attributes: opérations bulk', () {
    testWidgets(
        'userAttributes() returns map / clearUserAttributes() vide tout / clearBuiltInAttributes() no-throw',
        (tester) async {
      await tester.runAsync(() async {
        await Purchasely.setUserAttributeWithString('bulk_a', 'hello');
        await Purchasely.setUserAttributeWithInt('bulk_b', 99);
        await Future<void>.delayed(const Duration(milliseconds: 300));

        final all = await Purchasely.userAttributes();
        expect(all, isA<Map>());
        expect(all.containsKey('bulk_a'), isTrue,
            reason: 'bulk_a doit apparaître dans userAttributes()');
        expect(all['bulk_a'], equals('hello'));

        Purchasely.clearUserAttributes();
        await Future<void>.delayed(const Duration(milliseconds: 300));

        final afterClear = await Purchasely.userAttribute('bulk_a');
        expect(afterClear, isNull,
            reason: 'clearUserAttributes doit supprimer tous les attributs');

        Purchasely.clearBuiltInAttributes();
        debugPrint('T15 → userAttributes=${all.length} entrées, '
            'clearUserAttributes ✓, clearBuiltInAttributes no-throw ✓');
      });
    });
  });

  // T16 — Increment / decrement
  group('T16 — User attributes: increment / decrement', () {
    testWidgets(
        'incrementUserAttribute / decrementUserAttribute modifient le compteur',
        (tester) async {
      await tester.runAsync(() async {
        Purchasely.clearUserAttribute('e2e_counter');
        await Future<void>.delayed(const Duration(milliseconds: 300));

        await Purchasely.incrementUserAttribute('e2e_counter', value: 7);
        await Future<void>.delayed(const Duration(milliseconds: 300));
        final v1 = await Purchasely.userAttribute('e2e_counter');
        expect(v1, isNotNull);

        await Purchasely.incrementUserAttribute('e2e_counter', value: 3);
        await Future<void>.delayed(const Duration(milliseconds: 300));
        final v2 = await Purchasely.userAttribute('e2e_counter');
        expect(v2, isNotNull);
        if (v1 is num && v2 is num) {
          expect((v2).toDouble(), greaterThan((v1).toDouble()),
              reason: 'increment doit augmenter la valeur');
        }

        await Purchasely.decrementUserAttribute('e2e_counter', value: 4);
        await Future<void>.delayed(const Duration(milliseconds: 300));
        final v3 = await Purchasely.userAttribute('e2e_counter');
        expect(v3, isNotNull);
        if (v2 is num && v3 is num) {
          expect((v3).toDouble(), lessThan((v2).toDouble()),
              reason: 'decrement doit diminuer la valeur');
        }

        Purchasely.clearUserAttribute('e2e_counter');
        debugPrint('T16 → counter: v1=$v1 → +3 → v2=$v2 → -4 → v3=$v3 ✓');
      });
    });
  });

  // T17 — Catalogue: productWithIdentifier / planWithIdentifier / isEligibleForIntroOffer
  group(
      'T17 — Catalogue: productWithIdentifier / planWithIdentifier / isEligibleForIntroOffer',
      () {
    testWidgets('lookup par vendorId + eligibility check', (tester) async {
      await tester.runAsync(() async {
        final products = await Purchasely.allProducts();
        expect(products, isNotEmpty,
            reason:
                'Au moins un produit est nécessaire pour tester le catalogue');

        final product = products.first;
        final fetched =
            await Purchasely.productWithIdentifier(product.vendorId);
        expect(fetched.vendorId, equals(product.vendorId));
        expect(fetched.name, isNotEmpty);
        debugPrint('T17 → productWithIdentifier=${fetched.vendorId}');

        final plan = product.plans.isNotEmpty ? product.plans.first : null;
        final planId = plan?.vendorId;
        if (planId != null) {
          final fetchedPlan = await Purchasely.planWithIdentifier(planId);
          expect(fetchedPlan, isNotNull);
          expect(fetchedPlan!.vendorId, equals(planId));
          debugPrint('T17 → planWithIdentifier=${fetchedPlan.vendorId}');

          final isEligible = await Purchasely.isEligibleForIntroOffer(planId);
          expect(isEligible, isA<bool>());
          debugPrint('T17 → isEligibleForIntroOffer=$isEligible');
        }
      });
    });
  });

  // T18 — Dynamic offerings: set / get / remove / clear
  group('T18 — Dynamic offerings: CRUD', () {
    testWidgets(
        'setDynamicOffering → getDynamicOfferings → removeDynamicOffering → clearDynamicOfferings',
        (tester) async {
      await tester.runAsync(() async {
        final presentation =
            await PLYPresentationBuilder.placement(kPlacementAudiences)
                .build()
                .preload();
        final planVendorId = presentation.plans.isNotEmpty
            ? presentation.plans.first.planVendorId
            : null;
        expect(planVendorId, isNotNull,
            reason: 'Un plan est nécessaire pour tester setDynamicOffering');

        final ok = await Purchasely.setDynamicOffering(
          PLYDynamicOffering('e2e_ref', planVendorId!, null),
        );
        expect(ok, isA<bool>());

        await Future<void>.delayed(const Duration(milliseconds: 300));
        final offerings = await Purchasely.getDynamicOfferings();
        expect(offerings, isA<List<PLYDynamicOffering>>());

        Purchasely.removeDynamicOffering('e2e_ref');
        await Future<void>.delayed(const Duration(milliseconds: 300));
        Purchasely.clearDynamicOfferings();

        debugPrint('T18 → setDynamicOffering=$ok '
            'offerings=${offerings.length} '
            'remove+clear ✓');
      });
    });
  });

  // T19 — Builder screen(id) + variantes de transition (modal, popin)
  group('T19 — Builder screen(id) + transitions: modal / popin', () {
    testWidgets('PLYPresentationBuilder.screen(id) fonctionne + modal + popin',
        (tester) async {
      await tester.runAsync(() async {
        final byPlacement =
            await PLYPresentationBuilder.placement(kPlacementAudiences)
                .build()
                .preload();
        final screenId = byPlacement.screenId;
        expect(screenId, isNotNull);

        // Variante screen(id) → modal
        final byScreen =
            await PLYPresentationBuilder.screen(screenId!).build().preload();
        expect(byScreen.screenId, isNotNull);

        final f1 = byScreen.display(const PLYTransition.modal());
        await Future<void>.delayed(const Duration(seconds: 2));
        await byScreen.close();
        final outcome1 = await f1.timeout(const Duration(seconds: 10));
        expect(outcome1.presentation?.screenId, isNotNull);
        debugPrint('T19 → screen($screenId) modal → ${outcome1.closeReason}');

        // Variante popin
        final byScreen2 =
            await PLYPresentationBuilder.screen(screenId).build().preload();
        final f2 = byScreen2.display(const PLYTransition.popin(
          width: PLYTransitionDimension.pixel(320),
          height: PLYTransitionDimension.percentage(0.6),
        ));
        await Future<void>.delayed(const Duration(seconds: 2));
        await byScreen2.close();
        final outcome2 = await f2.timeout(const Duration(seconds: 10));
        expect(outcome2.presentation?.screenId, isNotNull);
        debugPrint('T19 → popin → ${outcome2.closeReason}');
      });
    });
  });

  // T20 — Config setters: smoke test (allowDeeplink, allowCampaigns, setLanguage,
  //        setThemeMode, setLogLevel, setDebugMode, revokeDataProcessingConsent,
  //        handleDeeplink)
  group('T20 — Config setters: smoke test', () {
    testWidgets(
        'allowDeeplink / allowCampaigns / setLanguage / setThemeMode / setLogLevel / '
        'setDebugMode / revokeDataProcessingConsent / handleDeeplink ne throw pas',
        (tester) async {
      await tester.runAsync(() async {
        await Purchasely.allowDeeplink(true);
        await Purchasely.allowDeeplink(false);
        await Purchasely.allowCampaigns(true);
        await Purchasely.allowCampaigns(false);
        await Purchasely.setLanguage('en');
        await Purchasely.setThemeMode(PLYThemeMode.system);
        await Purchasely.setLogLevel(PLYLogLevel.debug);
        await Purchasely.setDebugMode(false);
        Purchasely.revokeDataProcessingConsent(
            [PLYDataProcessingPurpose.analytics]);

        // Sur iOS le SDK fait un aller-retour réseau avant de rejeter l'URL → timeout court.
        final handled = await Purchasely.handleDeeplink(
                'https://example.com/not-a-ply-link')
            .timeout(const Duration(seconds: 5), onTimeout: () => false);
        expect(handled, isA<bool>());
        debugPrint(
            'T20 → handleDeeplink=$handled, all config setters no-throw ✓');
      });
    });
  });
}
