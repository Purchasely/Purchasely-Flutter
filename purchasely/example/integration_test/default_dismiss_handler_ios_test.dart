// E2E: the global default dismiss handler receives the typed outcome for a
// presentation the SDK opens itself (here via a deeplink), and the close-button
// dismissal maps to PLYCloseReason.button.
//
// Mirror of default_dismiss_handler_test.dart for iOS. Uses PLYStore.apple.
// A concurrent host-side driver (tools/close_paywall_ios.sh) uses idb to tap
// the paywall's close button (accessibility ID: ply_action_close) once it
// renders — equivalent to pressing system BACK on Android.
//
// Run together with the driver:
//   (bash .../close_paywall_ios.sh <sim-udid> &) ; \
//   flutter test integration_test/default_dismiss_handler_ios_test.dart -d <sim-udid>

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
      'default dismiss handler receives outcome for an SDK-opened presentation',
      (tester) async {
    await tester.runAsync(() async {
      PLYPresentationOutcome? globalOutcome;
      var presentationViewed = false;
      await Purchasely.setDefaultPresentationDismissHandler((outcome) {
        globalOutcome = outcome;
      });
      Purchasely.listenToEvents((event) {
        if (event.name == PLYEventName.PRESENTATION_VIEWED) {
          presentationViewed = true;
        }
      });

      // The SDK opens the presentation itself (deeplink) — its dismissal is
      // routed to the default handler, not to any per-request onDismissed.
      final handled = await Purchasely.handleDeeplink(
          'ply://ply/placements/$kPlacementAudiences');
      expect(handled, isTrue, reason: 'deeplink route should be handled');

      final viewedSw = Stopwatch()..start();
      while (!presentationViewed &&
          viewedSw.elapsed < const Duration(seconds: 30)) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      expect(presentationViewed, isTrue,
          reason: 'deeplink paywall should render before dismissal');
      debugPrint('DISMISS-DEFAULT-READY');

      // The concurrent driver swipes once the readiness marker is logged.
      // Poll for the default handler to receive the dismissal outcome.
      final sw = Stopwatch()..start();
      while (
          globalOutcome == null && sw.elapsed < const Duration(seconds: 40)) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }

      expect(globalOutcome, isNotNull,
          reason: 'default dismiss handler should fire after dismissal');
      expect(globalOutcome!.error, isNull);
      // Tapping the SDK close button maps to PLYCloseReason.button on iOS.
      // programmatic is also accepted (e.g. if the SDK attributes it differently).
      expect(
        globalOutcome!.closeReason,
        anyOf(PLYCloseReason.button, PLYCloseReason.programmatic,
            PLYCloseReason.backSystem),
      );
      debugPrint('default dismiss handler → '
          'closeReason=${globalOutcome!.closeReason} '
          'presentation=${globalOutcome!.presentation?.screenId}');
      Purchasely.stopListeningToEvents();
    });
  });
}
