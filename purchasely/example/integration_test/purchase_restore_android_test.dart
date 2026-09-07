// E2E (S7 — StoreKit-equivalent purchase + restore, Android): honest-degradation
// suite for `emulator-5554`, which has NO Google Play Store / Play Billing
// service. Unlike the iOS S7 suite (purchase_restore_ios_test.dart), which
// completes a REAL local StoreKit2 transaction via Configuration.storekit,
// there is no equivalent "local billing" test double on Android — Play
// Billing has no offline/sandbox config file analogous to a `.storekit`
// file, and this CI/dev fleet has no device signed into a Play Store test
// track.
//
// ==> S7-Android (an actual completed purchase) is STRUCTURALLY BLOCKED on
//     this fleet without a real Play-enabled device/emulator image. This
//     suite does NOT fake that gap: it does not assert `purchased`, and it
//     does not skip silently. It proves the two things that ARE true and
//     observable here:
//
//   1. The purchase action interceptor still fires correctly on a real tap
//      (the bridge + native paywall UI pipeline works right up to the point
//      where Play Billing itself is unavailable) — this is NOT a hang.
//   2. `restoreAllProducts(timeout: 15s)` degrades CLEANLY — either
//      resolving `false` or throwing a `TimeoutException` — never hanging
//      past the bound. Both are asserted; a real infinite hang would fail
//      this test via its own outer `-d emulator-5554` process timeout, not
//      silently pass.
//
// Run together with the driver:
//   (bash .../tap_purchase.sh emulator-5554 &) ; \
//   flutter test integration_test/purchase_restore_android_test.dart \
//     -d emulator-5554

import 'dart:async';

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
    debugPrint('SETUP → calling Purchasely.start()…');
    final configured = await startWithRetry(() => Purchasely.apiKey(kApiKey)
        .runningMode(PLYRunningMode.full)
        .logLevel(PLYLogLevel.debug)
        .stores([PLYStore.google])
        .start()
        .timeout(const Duration(seconds: 120),
            onTimeout: () =>
                throw StateError('Purchasely.start() timed out after 120s')));
    debugPrint('SETUP → configured=$configured');
    expect(configured, isTrue);
  });

  testWidgets(
      'S7 — purchase interceptor fires, then fails/degrades cleanly (no Play Store); restore fast-fails',
      (tester) async {
    await tester.runAsync(() async {
      PLYInterceptorInfo? capturedInfo;
      PLYActionPayload? capturedPayload;
      var presented = false;

      // notHandled: let the SDK attempt its own default purchase flow against
      // real Play Billing — which is unavailable on this emulator. We are NOT
      // asserting success; we're asserting the tap→interceptor pipeline works
      // and that whatever happens next does not hang.
      await Purchasely.interceptAction(
        PLYPresentationActionKind.purchase,
        (info, payload) async {
          capturedInfo = info;
          capturedPayload = payload;
          return PLYInterceptResult.notHandled;
        },
      );

      final request = PLYPresentationBuilder.placement(kPlacementAudiences)
          .onPresented((p, e) => presented = true)
          .build();
      final presentation = await request.preload();
      final displayFuture =
          presentation.display(const PLYTransition.fullScreen());

      final presentSw = Stopwatch()..start();
      while (!presented && presentSw.elapsed < const Duration(seconds: 20)) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      expect(presented, isTrue, reason: 'paywall should present');

      // The concurrent driver (tap_purchase.sh) taps `action:purchase`.
      final fireSw = Stopwatch()..start();
      while (capturedPayload == null &&
          fireSw.elapsed < const Duration(seconds: 40)) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      expect(capturedPayload, isA<PLYPurchasePayload>(),
          reason: 'purchase interceptor should fire on the native tap even '
              'though the purchase itself cannot complete here');
      final purchase = capturedPayload as PLYPurchasePayload;
      debugPrint('S7 Android → interceptor fired (notHandled → proceeding) '
          'plan.vendorId=${purchase.plan.vendorId} '
          'contentId=${capturedInfo?.contentId}');

      // Without Play Billing, the SDK's default purchase attempt fails; the
      // presentation may never resolve its display future on this fleet. Bound
      // the wait — a clean bounded failure (error OR timeout), never an
      // unbounded hang.
      final purchaseSw = Stopwatch()..start();
      var purchaseHandledCleanly = false;
      try {
        final outcome =
            await displayFuture.timeout(const Duration(seconds: 30));
        purchaseHandledCleanly = true;
        expect(outcome.purchaseResult, isNot(PLYPurchaseResult.purchased),
            reason: 'S7-Android is structurally blocked: no completed '
                'purchase must ever be reported on this fleet');
        debugPrint('S7 Android → display resolved without a completed '
            'purchase after ${purchaseSw.elapsedMilliseconds}ms: '
            'purchaseResult=${outcome.purchaseResult} error=${outcome.error}');
      } on TimeoutException {
        purchaseHandledCleanly = true;
        debugPrint('S7 Android → display future bounded-timeout after '
            '${purchaseSw.elapsedMilliseconds}ms (expected: no Play Billing '
            'to complete/cancel the purchase) — cleaning up locally');
        await presentation.close();
      } on PlatformException catch (e) {
        purchaseHandledCleanly = true;
        debugPrint('S7 Android → PlatformException(${e.code}): ${e.message} '
            'after ${purchaseSw.elapsedMilliseconds}ms (expected: no Play '
            'Billing on this emulator)');
      }
      expect(purchaseHandledCleanly, isTrue,
          reason: 'the purchase attempt must resolve, error, or time out '
              'cleanly — never hang unboundedly');

      await Purchasely.removeAllActionInterceptors();

      // restoreAllProducts: fast, honest degradation. Never hangs past 15s.
      final restoreSw = Stopwatch()..start();
      var restoreHandledCleanly = false;
      try {
        final restored = await Purchasely.restoreAllProducts(
            timeout: const Duration(seconds: 15));
        restoreHandledCleanly = true;
        expect(restored, isFalse,
            reason: 'no Play Store on this emulator: nothing to restore');
        debugPrint('S7 Android → restoreAllProducts=$restored after '
            '${restoreSw.elapsedMilliseconds}ms');
      } on TimeoutException {
        restoreHandledCleanly = true;
        debugPrint('S7 Android → restoreAllProducts TimeoutException after '
            '${restoreSw.elapsedMilliseconds}ms (clean bounded failure, as '
            'documented on restoreAllProducts)');
      }
      expect(restoreHandledCleanly, isTrue,
          reason: 'restoreAllProducts must return false or throw '
              'TimeoutException — never hang past the 15s bound');
      expect(restoreSw.elapsed, lessThan(const Duration(seconds: 20)),
          reason: 'restoreAllProducts must fast-fail, not stall near/above '
              'its own timeout budget');
    });
  });
}
