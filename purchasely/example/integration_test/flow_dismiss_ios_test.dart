// E2E: Flow display + dismiss coverage (S2) — iOS. Mirror of
// flow_dismiss_test.dart (Android).
//
// Exercises the `integration_test_flow` placement (flow id
// `integration_test_v_1`), reusing the SAME backend app/API key as the
// native Android `integration-tests` module (see
// `../Android/integration-tests/src/androidTest/java/com/purchasely/integration/FlowTests.kt`
// and `scenarios/FLOWS.md`, FLOW-01/FLOW-06).
//
// AXLabel discovery (idb ui describe-all --json, iPhone 17 Pro / iOS 26.5 —
// see task-4 report for the full transcript): the "calm" initial step's
// full accessibility tree is 11 StaticText elements, no button/image and NO
// close control at all:
//   "What brings you to Calm?" (title)
//   "We'll personalize recommendations based on your goals." (subtitle)
//   "Reduce Stress" / "Better Sleep" / "Develop Gratitude" / "Reduce
//     Anxiety" / "Increase Happiness" / "Improve Performance" /
//     "Build Self Esteem" (the 7 option labels — all always rendered, no
//     Android-style select/hide state visible in the AX tree)
//   "Continue" (the validate control — unlike Android, always present, not
//     hidden until a selection)
// This matches the Android finding (close_all is NOT on the calm screen
// either — every native FlowTests.kt scenario that taps close_all first
// navigates at least one step away from calm). So on iOS too, closing
// directly from "calm" has no UI control to drive — the programmatic
// fallback below is the CORRECT path here, not a workaround.
//
// tools/tap_label_ios.sh is still wired up (and usable by any suite that
// finds a real close/other control label at runtime), but this suite does
// not attempt one-step navigation past "calm": an exploratory coordinate
// tap on "Continue" (from the same AX dump) backgrounded the app instead of
// navigating — a distinct iOS-only flakiness on top of the Android
// close_all/purchase-CTA collision already discovered for that path (see
// task-4 report). Per the brief's "if unstable, leave it out and say so"
// clause, no nav is attempted here.
//
// Bridge gap check (do NOT invent fields): `PLYEventProperties`
// (lib/purchasely_flutter.dart:1146-1209) does NOT expose `flowId`,
// `flowSessionId`, `flowStepId` or `fromStepId` on either platform. What IS
// mapped to Dart is `PLYPresentation.flowId` (lib/src/presentation.dart:97,
// populated by the shared `presentationToMap` on both preload and outcome —
// iOS SwiftPurchaselyFlutterPlugin.swift:658/735), so this suite asserts
// flow identity via the PRESENTATION handle rather than via event
// properties.
//
// Run with:
//   flutter test integration_test/flow_dismiss_ios_test.dart -d <udid>
// (no driver process needed — closing is via Purchasely.closeAllScreens(),
// documented above).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

import 'helpers/e2e_start.dart';

const String kApiKey = '0ad0594b-3b3d-4fea-8ee1-4b5df91efe87';
const String kPlacementFlow = 'integration_test_flow';
const String kFlowId = 'integration_test_v_1';

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
    expect(configured, isTrue,
        reason: 'SDK should configure against the real backend');
  });

  testWidgets('flow displays its initial step and dismisses via close',
      (tester) async {
    await tester.runAsync(() async {
      final viewedScreens = <String?>[];
      final closedEvents = <PLYEvent>[];
      Purchasely.listenToEvents((event) {
        switch (event.name) {
          case PLYEventName.PRESENTATION_VIEWED:
            viewedScreens.add(event.properties.displayed_presentation);
            break;
          case PLYEventName.PRESENTATION_CLOSED:
            closedEvents.add(event);
            break;
          default:
            break;
        }
      });

      var presented = false;
      Object? presentError;
      // onPresented MUST be set on the BUILDER (see Task 2 report /
      // re_display_ios_test.dart) — reassigning it on the handle after
      // preload() is silently dropped for the first display cycle.
      final request =
          PLYPresentationBuilder.placement(kPlacementFlow).onPresented((p, e) {
        presented = true;
        presentError = e;
      }).build();
      final presentation = await request.preload();

      // Preload proof: real live screen, not deactivated/fallback. The flow
      // may resolve to a dedicated type on native — log the REAL value
      // rather than assuming `normal`.
      debugPrint('preload → type=${presentation.type} '
          'screenId=${presentation.screenId} '
          'placementId=${presentation.placementId} '
          'flowId=${presentation.flowId}');
      expect(
        presentation.type,
        isNot(anyOf(
            PLYPresentationType.deactivated, PLYPresentationType.fallback)),
        reason: 'integration_test_flow must resolve to a live screen, not a '
            'deactivated/fallback placement, for this suite to be meaningful',
      );
      expect(presentation.flowId, equals(kFlowId),
          reason: 'PLYPresentation.flowId is the one flow identity field the '
              'Dart bridge DOES map (unlike PLYEventProperties — see file '
              'header)');

      // --- Display: PRESENTATION_VIEWED for the "calm" initial step -------
      PLYPresentationOutcome? outcome;
      Object? displayError;
      // ignore: unawaited_futures
      presentation.display().then((o) => outcome = o,
          onError: (Object e, StackTrace st) => displayError = e);

      var sw = Stopwatch()..start();
      while (!presented &&
          displayError == null &&
          sw.elapsed < const Duration(seconds: 40)) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      expect(displayError, isNull,
          reason: 'display() must not error before presenting');
      expect(presentError, isNull,
          reason: 'onPresented must not deliver an error');
      expect(presented, isTrue, reason: 'flow should present');

      sw = Stopwatch()..start();
      while (
          viewedScreens.isEmpty && sw.elapsed < const Duration(seconds: 40)) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      expect(viewedScreens, isNotEmpty,
          reason: 'PRESENTATION_VIEWED should fire for the initial step');
      expect(viewedScreens.first, equals('calm'),
          reason: 'the flow\'s initial step is the "calm" selection screen '
              '(see native FlowTests.kt FLOW-01)');
      debugPrint('PRESENTATION_VIEWED screens so far: $viewedScreens');

      // --- Close: driver taps the discovered close label, else fallback ---
      sw = Stopwatch()..start();
      while (outcome == null &&
          displayError == null &&
          sw.elapsed < const Duration(seconds: 40)) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      if (outcome == null) {
        // Fallback: driver couldn't find/tap a close control (or none was
        // run). Close programmatically so the suite still proves the
        // dismiss contract, with an honest note in the log (NOT a silently
        // invented pass).
        debugPrint('close control not observed closing the flow within '
            '40s — falling back to Purchasely.closeAllScreens() '
            '(programmatic; driver tap was not confirmed)');
        await Purchasely.closeAllScreens();
        sw = Stopwatch()..start();
        while (outcome == null &&
            displayError == null &&
            sw.elapsed < const Duration(seconds: 20)) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      }
      expect(displayError, isNull, reason: 'display() must not error on close');
      expect(outcome, isNotNull,
          reason: 'display() should resolve once the flow is closed');
      expect(outcome!.error, isNull);
      expect(
        outcome!.closeReason,
        anyOf(PLYCloseReason.button, PLYCloseReason.backSystem,
            PLYCloseReason.programmatic),
      );
      debugPrint('outcome → closeReason=${outcome!.closeReason} '
          'purchaseResult=${outcome!.purchaseResult}');

      sw = Stopwatch()..start();
      while (closedEvents.isEmpty && sw.elapsed < const Duration(seconds: 10)) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      expect(closedEvents, isNotEmpty,
          reason: 'PRESENTATION_CLOSED should be observed on the event '
              'stream in addition to the display() outcome');
      debugPrint('PRESENTATION_CLOSED displayed_presentation='
          '${closedEvents.first.properties.displayed_presentation}');

      Purchasely.stopListeningToEvents();
    });
  });
}
