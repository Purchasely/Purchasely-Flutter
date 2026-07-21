// E2E: a host-initiated display() that is fire-and-forget (NOT awaited, and with
// NO per-presentation onDismissed callback) routes its dismissal to the global
// default dismiss handler — the new fallback in `_handleOnDismissed`.
//
// iOS mirror of default_dismiss_via_display_test.dart. Uses PLYStore.apple.
// A concurrent host-side driver (tools/close_paywall_ios.sh) uses idb to tap
// the paywall's close button (accessibility ID: ply_action_close) once it
// renders — equivalent to pressing system BACK on Android.
//
// Run together with the driver:
//   (bash .../close_paywall_ios.sh <sim-udid> &) ; \
//   flutter test integration_test/default_dismiss_via_display_ios_test.dart -d <sim-udid>

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
        .allowDeeplink(true)
        .storekitVersion(PLYStorekitVersion.storeKit2)
        .start()
        .timeout(const Duration(seconds: 120),
            onTimeout: () =>
                throw StateError('Purchasely.start() timed out after 120s')));
    debugPrint('SETUP → configured=$configured');
    expect(configured, isTrue);
  });

  testWidgets(
      'fire-and-forget display() routes dismissal to the default dismiss handler',
      (tester) async {
    await tester.runAsync(() async {
      PLYPresentationOutcome? globalOutcome;
      var presented = false;
      await Purchasely.setDefaultPresentationDismissHandler((outcome) {
        globalOutcome = outcome;
      });

      // The host opens the presentation itself via display(). Crucially:
      //   * no onDismissed is set on the builder/presentation, and
      //   * the display() future is intentionally not awaited (fire-and-forget),
      // so the dismissal isn't handled locally and must reach the default handler.
      final presentation =
          await PLYPresentationBuilder.placement(kPlacementAudiences)
              .onPresented((presentation, error) {
                if (presentation != null) presented = true;
              })
              .build()
              .preload();
      // Fire-and-forget: intentionally not awaited.
      // ignore: unawaited_futures
      presentation.display();

      final presentedSw = Stopwatch()..start();
      while (!presented && presentedSw.elapsed < const Duration(seconds: 30)) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      expect(presented, isTrue,
          reason: 'fire-and-forget paywall should render before dismissal');
      debugPrint('DISMISS-DISPLAY-READY');

      // The concurrent driver swipes once the readiness marker is logged.
      // Poll for the default handler to receive the dismissal outcome.
      final sw = Stopwatch()..start();
      while (
          globalOutcome == null && sw.elapsed < const Duration(seconds: 40)) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }

      expect(globalOutcome, isNotNull,
          reason: 'default dismiss handler should catch the unhandled '
              'fire-and-forget display() dismissal');
      expect(globalOutcome!.error, isNull);
      // Tapping the SDK close button maps to PLYCloseReason.button on iOS.
      // programmatic/backSystem also accepted (different attribution paths).
      expect(
        globalOutcome!.closeReason,
        anyOf(PLYCloseReason.button, PLYCloseReason.programmatic,
            PLYCloseReason.backSystem),
      );
      debugPrint('default dismiss handler (via display) → '
          'closeReason=${globalOutcome!.closeReason} '
          'presentation=${globalOutcome!.presentation?.screenId}');
    });
  });
}
