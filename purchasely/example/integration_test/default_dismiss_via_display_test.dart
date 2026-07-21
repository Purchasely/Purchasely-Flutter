// E2E: a host-initiated display() that is fire-and-forget (NOT awaited, and with
// NO per-presentation onDismissed callback) routes its dismissal to the global
// default dismiss handler — the new fallback in `_handleOnDismissed`.
//
// This is the Dart-opened counterpart of default_dismiss_handler_test.dart
// (which opens the screen via the SDK itself, through a deeplink). Here the app
// owns the display() call, so the dismissal flows through the per-request
// onDismissed event; because the host set no local handler, it must fall back to
// setDefaultPresentationDismissHandler instead of being dropped.
//
// A concurrent host-side driver (scripts: press_back.sh) waits for the paywall
// to render, then presses the system BACK button.
//
// Run together with the driver:
//   (bash .../press_back.sh &) ; \
//   flutter test integration_test/default_dismiss_via_display_test.dart -d emulator-5554

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
        .allowDeeplink(true)
        .stores([PLYStore.google]).start();
    expect(configured, isTrue);
  });

  testWidgets(
      'fire-and-forget display() routes dismissal to the default dismiss handler',
      (tester) async {
    await tester.runAsync(() async {
      PLYPresentationOutcome? globalOutcome;
      await Purchasely.setDefaultPresentationDismissHandler((outcome) {
        globalOutcome = outcome;
      });

      // The host opens the presentation itself via display(). Crucially:
      //   * no onDismissed is set on the builder/presentation, and
      //   * the display() future is intentionally not awaited (fire-and-forget),
      // so the dismissal isn't handled locally and must reach the default handler.
      final presentation =
          await PLYPresentationBuilder.placement(kPlacementAudiences)
              .build()
              .preload();
      // Fire-and-forget: intentionally not awaited.
      // ignore: unawaited_futures
      presentation.display();

      // The concurrent driver presses BACK once the paywall renders. Poll for
      // the default handler to receive the dismissal outcome.
      final sw = Stopwatch()..start();
      while (
          globalOutcome == null && sw.elapsed < const Duration(seconds: 40)) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }

      expect(globalOutcome, isNotNull,
          reason: 'default dismiss handler should catch the unhandled '
              'fire-and-forget display() dismissal');
      expect(globalOutcome!.error, isNull);
      // System-back dismissal maps to backSystem; allow programmatic/button in
      // case the SDK attributes the dismissal differently.
      expect(
        globalOutcome!.closeReason,
        anyOf(PLYCloseReason.backSystem, PLYCloseReason.programmatic,
            PLYCloseReason.button),
      );
      debugPrint('default dismiss handler (via display) → '
          'closeReason=${globalOutcome!.closeReason} '
          'presentation=${globalOutcome!.presentation?.screenId}');
    });
  });
}
