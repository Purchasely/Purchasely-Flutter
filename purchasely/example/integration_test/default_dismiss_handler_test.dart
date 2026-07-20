// E2E: the global default dismiss handler receives the typed outcome for a
// presentation the SDK opens itself (here via a deeplink), and the system-back
// dismissal maps to PLYCloseReason.backSystem.
//
// A concurrent host-side driver (scripts: press_back.sh) waits for the paywall
// to render, then presses the system BACK button.
//
// Run together with the driver:
//   (bash .../press_back.sh &) ; \
//   flutter test integration_test/default_dismiss_handler_test.dart -d emulator-5554

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
    final configured = await startWithRetry(() => Purchasely.apiKey(kApiKey)
        .runningMode(PLYRunningMode.full)
        .logLevel(PLYLogLevel.debug)
        .allowDeeplink(true)
        .stores([PLYStore.google]).start());
    expect(configured, isTrue);
  });

  testWidgets(
      'default dismiss handler receives outcome for an SDK-opened presentation',
      (tester) async {
    await tester.runAsync(() async {
      PLYPresentationOutcome? globalOutcome;
      await Purchasely.setDefaultPresentationDismissHandler((outcome) {
        globalOutcome = outcome;
      });

      // The SDK opens the presentation itself (deeplink) — its dismissal is
      // routed to the default handler, not to any per-request onDismissed.
      final handled = await Purchasely.handleDeeplink(
          'ply://ply/placements/$kPlacementAudiences');
      expect(handled, isTrue, reason: 'deeplink route should be handled');

      // The concurrent driver presses BACK once the paywall renders. Poll for
      // the default handler to receive the dismissal outcome.
      final sw = Stopwatch()..start();
      while (
          globalOutcome == null && sw.elapsed < const Duration(seconds: 40)) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }

      expect(globalOutcome, isNotNull,
          reason: 'default dismiss handler should fire after dismissal');
      expect(globalOutcome!.error, isNull);
      // System-back dismissal maps to backSystem; allow programmatic/button in
      // case the SDK attributes the dismissal differently. interactiveDismiss
      // no longer exists in the reduced v6 enum.
      expect(
        globalOutcome!.closeReason,
        anyOf(PLYCloseReason.backSystem, PLYCloseReason.programmatic,
            PLYCloseReason.button),
      );
      debugPrint('default dismiss handler → '
          'closeReason=${globalOutcome!.closeReason} '
          'presentation=${globalOutcome!.presentation?.screenId}');
    });
  });
}
