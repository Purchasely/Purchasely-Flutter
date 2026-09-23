// E2E (iOS): a Console drawer closed by a real tap — port of React Native T31.
//
// Regression guard for Purchasely-iOS#790, fixed in iOS SDK 6.1.2. A drawer
// the Console configures, opened with `display()` and NO transition (as a
// client app does), then closed by its own close button or by a tap on the
// scrim, left the SDK window alive, invisible and on top of the app. The app
// took no more taps, and PRESENTATION_CLOSED never fired.
//
// Two passes, `button` then `outside`. Each pass:
//   1. preload() + display() with no transition → PRESENTATION_VIEWED.
//   2. Prints `T31-DRAWER-READY:<mode>`; the host driver taps the close
//      button (button) or the scrim above the drawer (outside).
//   3. Asserts PRESENTATION_CLOSED.
//   4. Shows a full-screen Flutter probe, prints `T31-PROBE-READY:<n>`; the
//      host taps the centre of the screen BY COORDINATES. The probe tap is the
//      symptom itself: with a leftover SDK window on top, the OS tap never
//      reaches Flutter.
//   5. Asserts display() resolved (closeReason `button` for the button pass).
//
// Driver: tools/drawer_close_driver_ios.sh (chained in
// transition_batch_driver_ios.sh). Run alone:
//   (SUITE_LOG=/tmp/t31.log bash integration_test/tools/drawer_close_driver_ios.sh <udid>) &
//   flutter test integration_test/drawer_close_ios_test.dart -d <udid> | tee /tmp/t31.log

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

import 'helpers/e2e_start.dart';

const String kApiKey = '0ad0594b-3b3d-4fea-8ee1-4b5df91efe87';
// A screen the Console itself displays as a 70% drawer, with a close button.
const String kPlacementDrawer = 'integration_test_drawer';

Future<void> _pumpUntil(
    WidgetTester tester, bool Function() done, Duration timeout) async {
  final sw = Stopwatch()..start();
  while (!done() && sw.elapsed < timeout) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  // The host taps are real OS taps; the live test binding drops them unless
  // told otherwise. Set before the test starts: the binding asserts the value
  // is unchanged when the test body ends.
  IntegrationTestWidgetsFlutterBinding.ensureInitialized()
      .shouldPropagateDevicePointerEvents = true;

  setUpAll(() async {
    final configured = await startWithRetry(() => Purchasely.apiKey(kApiKey)
        .runningMode(PLYRunningMode.full)
        .logLevel(PLYLogLevel.debug)
        .storekitVersion(PLYStorekitVersion.storeKit2)
        .start()
        .timeout(const Duration(seconds: 120),
            onTimeout: () =>
                throw StateError('Purchasely.start() timed out after 120s')));
    expect(configured, isTrue);
  });

  testWidgets(
      'T31 Console drawer closed by a real tap: outcome + CLOSED + app still takes taps',
      (tester) async {
    await tester.runAsync(() async {
      var probeTaps = 0;
      var probeVisible = false;
      Future<void> render() => tester.pumpWidget(MaterialApp(
            home: probeVisible
                ? Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (_) {
                      probeTaps++;
                      debugPrint('T31 probe tapped ($probeTaps)');
                    },
                    child: const ColoredBox(
                        color: Color(0xFF1A237E),
                        child: Center(child: Text('T31 probe'))),
                  )
                : const SizedBox.expand(),
          ));
      await render();

      final reasons = <String>[];
      var pass = 0;
      for (final mode in ['button', 'outside']) {
        pass++;
        PLYEvent? viewed;
        PLYEvent? closed;
        Purchasely.listenToEvents((event) {
          debugPrint('T31 $mode event ${event.name} '
              'placement=${event.properties.source_identifier}');
          if (event.properties.source_identifier != kPlacementDrawer) return;
          if (event.name == PLYEventName.PRESENTATION_VIEWED) viewed = event;
          if (event.name == PLYEventName.PRESENTATION_CLOSED) closed = event;
        });
        try {
          final request =
              PLYPresentationBuilder.placement(kPlacementDrawer).build();
          final presentation =
              await request.preload().timeout(const Duration(seconds: 30));
          PLYPresentationOutcome? outcome;
          Object? displayError;
          // No transition: the Console's drawer display mode applies.
          // ignore: unawaited_futures
          presentation.display().then((o) => outcome = o,
              onError: (Object e) => displayError = e);

          await _pumpUntil(
              tester, () => viewed != null, const Duration(seconds: 30));
          expect(viewed, isNotNull,
              reason: '$mode: the drawer never sent PRESENTATION_VIEWED');
          await Future<void>.delayed(const Duration(milliseconds: 1500));

          debugPrint('T31-DRAWER-READY:$mode');
          await _pumpUntil(
              tester, () => closed != null, const Duration(seconds: 20));

          final tapsBefore = probeTaps;
          probeVisible = true;
          await render();
          await tester.pump(const Duration(milliseconds: 800));
          debugPrint('T31-PROBE-READY:$pass');
          await _pumpUntil(tester, () => probeTaps > tapsBefore,
              const Duration(seconds: 20));
          probeVisible = false;
          await render();

          await _pumpUntil(
              tester,
              () => outcome != null || displayError != null,
              const Duration(seconds: 10));

          // Collect every symptom before failing: on a broken SDK all three
          // show at once, and the message names the cause.
          final errors = <String>[
            if (closed == null) '$mode: no PRESENTATION_CLOSED within 20 s',
            if (probeTaps == tapsBefore)
              '$mode: the OS tap did not reach the app after the close '
                  '(leftover SDK window?)',
            if (displayError != null) '$mode: display() failed: $displayError',
            if (outcome == null && displayError == null)
              '$mode: display() did not resolve within 10 s',
            if (mode == 'button' &&
                outcome != null &&
                outcome!.closeReason != PLYCloseReason.button)
              "button: closeReason expected 'button', got ${outcome!.closeReason}",
          ];
          expect(errors, isEmpty, reason: errors.join('; '));
          reasons.add('$mode=${outcome?.closeReason}');
        } finally {
          Purchasely.stopListeningToEvents();
          if (probeVisible) {
            probeVisible = false;
            await render();
          }
        }
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      debugPrint('T31 PASS: drawer closed by a real tap, CLOSED sent, app '
          'still takes taps (${reasons.join(', ')})');
    });
  });
}
