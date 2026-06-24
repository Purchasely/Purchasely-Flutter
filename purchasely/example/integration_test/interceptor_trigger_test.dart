// E2E: action interceptor is actually TRIGGERED by a real tap on the native
// paywall, and the typed payload is delivered to Dart.
//
// This test displays the `integration_test_audiences` placement (which exposes a
// purchase button with content-desc `action:purchase,plan:monthly; action:close_all`,
// mirroring the native Android PaywallActionInterceptorTests) and then polls for
// the interceptor to fire. A concurrent host-side driver
// (scripts: tap_purchase.sh) taps the purchase button via uiautomator.
//
// Run together with the driver:
//   (bash .../tap_purchase.sh &) ; \
//   flutter test integration_test/interceptor_trigger_test.dart -d emulator-5554

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

const String kApiKey = '0ad0594b-3b3d-4fea-8ee1-4b5df91efe87';
const String kPlacementAudiences = 'integration_test_audiences';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final configured = await PurchaselyBuilder.apiKey(kApiKey)
        .runningMode(RunningMode.full)
        .logLevel(LogLevel.debug)
        .stores([PLYStore.google]).start();
    expect(configured, isTrue);
  });

  testWidgets(
      'purchase action interceptor fires with a typed PurchasePayload on tap',
      (tester) async {
    await tester.runAsync(() async {
      InterceptorInfo? capturedInfo;
      ActionPayload? capturedPayload;
      var presented = false;

      // SUCCESS for purchase: skip the SDK default but continue the chain. The
      // chain then fires close_all, which we also intercept with SUCCESS so the
      // paywall stays open (mirrors native Android ACT-01).
      await Purchasely.interceptAction(
        PresentationActionKind.purchase,
        (info, payload) async {
          capturedInfo = info;
          capturedPayload = payload;
          return InterceptResult.success;
        },
      );
      await Purchasely.interceptAction(
        PresentationActionKind.closeAll,
        (info, payload) async => InterceptResult.success,
      );

      final request = PresentationBuilder.placement(kPlacementAudiences)
          .onPresented((p, e) => presented = true)
          .build();
      // ignore: unawaited_futures
      request.display(const Transition.fullScreen());

      // Wait for the paywall to present.
      final presentSw = Stopwatch()..start();
      while (!presented && presentSw.elapsed < const Duration(seconds: 20)) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      expect(presented, isTrue, reason: 'paywall should present');

      // The concurrent driver taps `action:purchase`. Poll for the interceptor.
      final fireSw = Stopwatch()..start();
      while (capturedPayload == null &&
          fireSw.elapsed < const Duration(seconds: 40)) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }

      expect(capturedPayload, isA<PurchasePayload>(),
          reason: 'purchase interceptor should fire on the native tap');
      expect(capturedPayload!.kind, PresentationActionKind.purchase);
      final purchase = capturedPayload as PurchasePayload;
      expect(purchase.plan, isA<PLYPlan>());
      expect(purchase.plan.vendorId, isNotNull);
      expect(capturedInfo, isNotNull);
      debugPrint('interceptor fired → kind=${capturedPayload!.kind} '
          'plan.vendorId=${purchase.plan.vendorId} '
          'plan.productId=${purchase.plan.productId} '
          'contentId=${capturedInfo!.contentId}');

      await Purchasely.removeAllActionInterceptors();
    });
  });
}
