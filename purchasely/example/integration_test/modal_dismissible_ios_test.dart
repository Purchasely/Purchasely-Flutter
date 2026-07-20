// E2E: iOS `PLYTransition.modal(dismissible:)` regression guard (PR #136 —
// "modal dismissible iOS ignoré") PLUS the missing interactive-swipe-dismiss
// coverage.
//
// Before the fix, `SwiftPurchaselyFlutterPlugin.parseTransition` returned the
// static `.modal` case and dropped the Dart-side `dismissible` flag, so a
// modal declared non-dismissible was still swipe-dismissible on iOS. This
// suite has two tests:
//   1. `dismissible: false` — an interactive swipe-down must be a no-op:
//      display() stays pending and no PRESENTATION_CLOSED fires. Only a
//      programmatic `presentation.close()` may dismiss it.
//   2. `dismissible: true` (the default) — an interactive swipe-down MUST
//      resolve display() with a dismissed outcome. This is new coverage: no
//      existing suite drove an interactive swipe against a *dismissible*
//      modal and asserted on the resulting outcome.
//
// Uses PLYStore.apple, host-opened via `preload()` + fire-and-forget
// `display()` (pattern of default_dismiss_via_display_ios_test.dart). A
// concurrent host-side driver (tools/swipe_dismiss_ios.sh) uses idb to send
// interactive swipe-down gestures once the paywall renders — it does NOT
// assert the outcome itself, that's this Dart suite's job.
//
// Run together with the driver — one invocation per test (the file has two
// separate display() cycles), chained so the second waits for the first to
// finish:
//   (bash .../swipe_dismiss_ios.sh <sim-udid> 2 ; \
//    bash .../swipe_dismiss_ios.sh <sim-udid> 2) &
//   flutter test integration_test/modal_dismissible_ios_test.dart -d <sim-udid>

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
      'modal(dismissible: false) ignores an interactive swipe-dismiss (M1 regression guard)',
      (tester) async {
    await tester.runAsync(() async {
      PLYEvent? closedEvent;
      Purchasely.listenToEvents((event) {
        if (event.name == PLYEventName.PRESENTATION_CLOSED) {
          closedEvent = event;
        }
      });

      // onPresented is set on the BUILDER (like T7/T9 in dart_ios_bridge_test.dart
      // / interceptor_trigger_ios_test.dart), not reassigned on the PLYPresentation
      // returned by preload(): the bridge re-derives a fresh PLYPresentation
      // from the request's callbacks on the very first onPresented dispatch
      // (bridge.dart:_handleOnPresented), so a callback assigned directly on
      // the preloaded handle is silently dropped for that first event.
      var presented = false;
      final request = PLYPresentationBuilder.placement(kPlacementAudiences)
          .onPresented((p, e) => presented = true)
          .build();
      final presentation = await request.preload();

      PLYPresentationOutcome? outcome;
      // Fire-and-forget, like default_dismiss_via_display_ios_test.dart: we
      // need to keep polling `outcome` rather than block on the future, since
      // the whole point of this test is to prove it stays pending.
      // ignore: unawaited_futures
      presentation
          .display(const PLYTransition.modal(dismissible: false))
          .then((o) => outcome = o);

      // 40s, not 20s: observed locally that Xcode (re)build + SDK start() +
      // preload()'s backend round trip can push first-render past a tighter
      // window, especially on a cold simulator. Widening this deadline only
      // relaxes HOW LONG we wait for onPresented — it does not touch what's
      // being asserted.
      final presentSw = Stopwatch()..start();
      while (!presented && presentSw.elapsed < const Duration(seconds: 40)) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      expect(presented, isTrue, reason: 'modal paywall should present');

      // The concurrent driver (tools/swipe_dismiss_ios.sh) sends 2 interactive
      // swipe-down gestures around now. PR #136 fixed iOS `parseTransition`
      // to forward `dismissible: false` into `.modal(dismissible:)` — before
      // the fix, the transition was ALWAYS `.modal` (swipe-dismissible)
      // regardless of the Dart flag. Give the driver time to act, then assert
      // nothing moved. (10s, not 5s: the driver's own AX-tree poll runs on a
      // slower cadence than onPresented, so it needs headroom to notice the
      // paywall and complete 2 swipe gestures after onPresented already
      // fired.)
      await Future<void>.delayed(const Duration(seconds: 10));

      expect(outcome, isNull,
          reason: 'a non-dismissible modal must ignore the interactive swipe — '
              'display() must still be pending');
      expect(closedEvent, isNull,
          reason: 'PRESENTATION_CLOSED must not fire for an ignored swipe');

      // Only a programmatic close should be able to dismiss it.
      await presentation.close();
      final closeSw = Stopwatch()..start();
      while (outcome == null && closeSw.elapsed < const Duration(seconds: 15)) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }

      expect(outcome, isNotNull,
          reason: 'presentation.close() should resolve the pending display()');
      expect(outcome!.error, isNull);
      expect(
        outcome!.closeReason,
        anyOf(PLYCloseReason.programmatic, PLYCloseReason.button,
            PLYCloseReason.backSystem),
      );
      debugPrint('modal(dismissible:false) → swipe ignored, programmatic '
          'close → closeReason=${outcome!.closeReason}');
    });
  });

  testWidgets(
      'modal(dismissible: true) resolves via an interactive swipe-dismiss',
      (tester) async {
    await tester.runAsync(() async {
      // See the sibling test above: onPresented must be set on the BUILDER,
      // not reassigned on the preloaded PLYPresentation handle.
      var presented = false;
      final request = PLYPresentationBuilder.placement(kPlacementAudiences)
          .onPresented((p, e) => presented = true)
          .build();
      final presentation = await request.preload();

      PLYPresentationOutcome? outcome;
      Object? displayError;
      StackTrace? displayStack;
      // Fire-and-forget: the interactive swipe (not a Dart-side call) is what
      // must resolve this future.
      // ignore: unawaited_futures
      presentation
          .display(const PLYTransition.modal(dismissible: true))
          .then((o) => outcome = o, onError: (Object e, StackTrace st) {
        displayError = e;
        displayStack = st;
      });

      // See the sibling test above for why this is 40s, not 20s.
      final presentSw = Stopwatch()..start();
      while (!presented && presentSw.elapsed < const Duration(seconds: 40)) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      expect(presented, isTrue, reason: 'modal paywall should present');

      // The concurrent driver (tools/swipe_dismiss_ios.sh) sends 1-2
      // interactive swipe-down gestures. A dismissible modal must let this
      // dismiss it and resolve display().
      final sw = Stopwatch()..start();
      while (outcome == null &&
          displayError == null &&
          sw.elapsed < const Duration(seconds: 40)) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }

      if (displayError != null) {
        // Known local-only flake (iOS 26.5 sim): an interactive swipe
        // dismiss has previously made display() fail outright instead of
        // resolving. Log the full stack rather than weakening the
        // assertions below — a persistent local failure here needs CI
        // arbitration, not a softer test.
        debugPrint('interactive swipe-dismiss → display() ERRORED: '
            '$displayError\n$displayStack');
      }
      expect(displayError, isNull,
          reason: 'display() must not error on an interactive swipe-dismiss');
      expect(outcome, isNotNull,
          reason: 'a dismissible modal should resolve display() when swiped '
              'away — driver: tools/swipe_dismiss_ios.sh');
      expect(outcome!.error, isNull);
      expect(
        outcome!.closeReason,
        anyOf(PLYCloseReason.backSystem, PLYCloseReason.button,
            PLYCloseReason.programmatic),
      );
      debugPrint('modal(dismissible:true) interactive swipe → '
          'closeReason=${outcome!.closeReason}');
    });
  });
}
