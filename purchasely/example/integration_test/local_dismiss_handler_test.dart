// E2E: when BOTH a global default dismiss handler AND a per-presentation local
// handler are set, the LOCAL path wins. Here the host awaits display() and also
// sets onDismissed; the dismissal must reach the awaiting caller + the local
// onDismissed, while the default handler stays silent.
//
// Counterpart of default_dismiss_via_display_test.dart (which sets NO local
// handler, so the dismissal falls back to the default handler). Together they
// pin both branches of the dismiss-routing fallback in `_handleOnDismissed`.
//
// A concurrent host-side driver (scripts: press_back.sh) waits for the paywall
// to render, then presses the system BACK button.
//
// Run together with the driver:
//   (bash .../press_back.sh &) ; \
//   flutter test integration_test/local_dismiss_handler_test.dart -d emulator-5554

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
      'awaited display() with a local onDismissed wins over the default handler',
      (tester) async {
    await tester.runAsync(() async {
      PLYPresentationOutcome? defaultOutcome;
      PLYPresentationOutcome? localOutcome;

      // A default handler is registered globally…
      await Purchasely.setDefaultPresentationDismissHandler((outcome) {
        defaultOutcome = outcome;
      });

      // …but this presentation also declares a local onDismissed AND the caller
      // awaits display(): both local channels must receive the outcome and the
      // default handler must NOT fire.
      final request = PLYPresentationBuilder.placement(kPlacementAudiences)
          .onDismissed((outcome) => localOutcome = outcome)
          .build();
      await request.preload();

      // The concurrent driver presses BACK once the paywall renders, which
      // resolves the awaited display() future.
      final outcome = await request.display().timeout(
            const Duration(seconds: 50),
            onTimeout: () => throw StateError(
                'display() did not resolve — the driver may not have dismissed '
                'the paywall'),
          );

      // The awaiting caller received the outcome (local consumption).
      expect(outcome.error, isNull);
      expect(
        outcome.closeReason,
        anyOf(PLYCloseReason.backSystem, PLYCloseReason.programmatic,
            PLYCloseReason.button),
      );
      // The local onDismissed also received it…
      expect(localOutcome, isNotNull,
          reason: 'local onDismissed should receive the outcome');
      // …and the default handler must stay silent.
      expect(defaultOutcome, isNull,
          reason: 'default handler must NOT fire when a local handler is set');

      debugPrint('local dismiss handler → '
          'closeReason=${outcome.closeReason} '
          'presentation=${outcome.presentation?.screenId} '
          'defaultFired=${defaultOutcome != null}');
    });
  });
}
