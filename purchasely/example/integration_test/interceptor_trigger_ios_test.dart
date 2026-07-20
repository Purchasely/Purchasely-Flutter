// E2E: action interceptor is actually TRIGGERED by a real tap on the native
// paywall, and the typed payload is delivered to Dart.
//
// Mirror of interceptor_trigger_test.dart for iOS. Uses PLYStore.apple and
// a concurrent host-side driver (tools/tap_purchase_ios.sh) that uses idb to
// tap the purchase button by its accessibility identifier
// (ply_action_purchase_<planVendorId>).
//
// Run together with the driver:
//   (bash .../tap_purchase_ios.sh <sim-udid> &) ; \
//   flutter test integration_test/interceptor_trigger_ios_test.dart -d <sim-udid>

import 'package:flutter/material.dart';
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
        .storekitVersion(PLYStorekitVersion.storeKit2)
        .start()
        .timeout(const Duration(seconds: 120),
            onTimeout: () =>
                throw StateError('Purchasely.start() timed out after 120s')));
    debugPrint('SETUP → configured=$configured');
    expect(configured, isTrue);
  });

  testWidgets(
      'purchase action interceptor fires with a typed PLYPurchasePayload on tap',
      (tester) async {
    await tester.runAsync(() async {
      PLYInterceptorInfo? capturedInfo;
      PLYActionPayload? capturedPayload;
      var presented = false;

      // SUCCESS for purchase: skip the SDK default but continue the chain.
      // SUCCESS for close_all keeps the paywall open so the driver has time to
      // detect and assert (mirrors native iOS ACT-01 / Android ACT-01).
      await Purchasely.interceptAction(
        PLYPresentationActionKind.purchase,
        (info, payload) async {
          capturedInfo = info;
          capturedPayload = payload;
          return PLYInterceptResult.success;
        },
      );
      await Purchasely.interceptAction(
        PLYPresentationActionKind.closeAll,
        (info, payload) async => PLYInterceptResult.success,
      );

      final request = PLYPresentationBuilder.placement(kPlacementAudiences)
          .onPresented((p, e) => presented = true)
          .build();
      // ignore: unawaited_futures
      request.display(const PLYTransition.fullScreen());

      // Wait for the paywall to present.
      final presentSw = Stopwatch()..start();
      while (!presented && presentSw.elapsed < const Duration(seconds: 20)) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      expect(presented, isTrue, reason: 'paywall should present');

      // The concurrent driver taps the purchase button. Poll for interceptor.
      final fireSw = Stopwatch()..start();
      while (capturedPayload == null &&
          fireSw.elapsed < const Duration(seconds: 40)) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }

      expect(capturedPayload, isA<PLYPurchasePayload>(),
          reason: 'purchase interceptor should fire on the native tap');
      expect(capturedPayload!.kind, PLYPresentationActionKind.purchase);
      final purchase = capturedPayload as PLYPurchasePayload;
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
