// E2E: re-display of the SAME preloaded PLYPresentation handle keeps showing
// the ORIGINAL presentation source (PR #136 fix M2 — "re-display iOS perd la
// source").
//
// `bridge.dart`'s `_displayPresentation` (handle-based `PLYPresentation.display()`)
// resends the ORIGINAL request `source` retained in `_originSources`
// (bridge.dart:102-108, 216-219) rather than inferring a source from the
// loaded presentation — inference would pin a dynamic default source to
// whatever screen it happened to resolve to, bypassing updated targeting on a
// native rebuild (commit b0a313c).
//
// Identity signal used below: `PLYPresentationOutcome.presentation`, delivered
// on every `onDismissed` event (`bridge.dart:_outcomeFromMap`) and re-parsed
// from native's wire data on EACH dismiss. This is deliberately NOT the
// `presentation` argument handed to `onPresented`: on a re-display the
// originating request is gone (dropped after the first dismiss), so
// `_handleOnPresented` (bridge.dart:358-369) reuses the cached Dart handle
// as-is instead of re-deriving it from the fresh native payload — comparing
// that field across cycles would trivially always match the SAME Dart object
// and prove nothing about what native actually rendered.
//
// This suite drives TWO display cycles on the same handle, so the driver must
// run TWICE, chained:
//   (bash integration_test/tools/press_back.sh emulator-5554 ; \
//    bash integration_test/tools/press_back.sh emulator-5554) &
//   flutter test integration_test/re_display_test.dart -d emulator-5554

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
        .stores([PLYStore.google]).start());
    expect(configured, isTrue,
        reason: 'SDK should configure against the real backend');
  });

  testWidgets(
      're-display() of the same handle shows the same presentation, not the '
      "placement's default", (tester) async {
    await tester.runAsync(() async {
      // Independent cross-check (secondary to the outcome-based assertion
      // below): PRESENTATION_VIEWED can be deduplicated per session for a
      // screen already shown (observed in dart_android_bridge_test.dart
      // T10), so this is compared, not primary — but it must still be a
      // HARD assertion (guarded below), not a diagnostic no-op, or it would
      // reopen the exact vacuous-comparison hole this suite guards against.
      final viewedIds = <String?>[];
      Purchasely.listenToEvents((event) {
        if (event.name == PLYEventName.PRESENTATION_VIEWED ||
            event.name == PLYEventName.PRESENTATION_LOADED) {
          viewedIds.add(event.properties.displayed_presentation);
        }
      });

      var presented = false;
      // onPresented MUST be set on the BUILDER, not reassigned on the
      // PLYPresentation returned by preload() — a callback reassigned
      // directly on the handle is silently dropped for the very first
      // display cycle (bridge.dart:_handleOnPresented; see Task 2 report).
      final request = PLYPresentationBuilder.placement(kPlacementAudiences)
          .onPresented((p, e) => presented = true)
          .build();
      final presentation = await request.preload();

      expect(presentation.type, PLYPresentationType.normal,
          reason: 'placement must resolve to a live screen (not a '
              'fallback/deactivated one) for this identity test to be '
              'meaningful');
      expect(presentation.screenId, isNotNull);
      expect(presentation.screenId, isNotEmpty);
      expect(presentation.placementId, equals(kPlacementAudiences));
      debugPrint('preload → screenId=${presentation.screenId} '
          'placementId=${presentation.placementId} type=${presentation.type}');

      // --- Cycle 1: display → onPresented → driver closes → outcome -------
      PLYPresentationOutcome? firstOutcome;
      // ignore: unawaited_futures
      presentation.display().then((o) => firstOutcome = o);

      var sw = Stopwatch()..start();
      while (!presented && sw.elapsed < const Duration(seconds: 40)) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      expect(presented, isTrue, reason: 'paywall should present (cycle 1)');

      sw = Stopwatch()..start();
      while (firstOutcome == null && sw.elapsed < const Duration(seconds: 40)) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      expect(firstOutcome, isNotNull,
          reason: 'driver (press_back.sh, 1st invocation) should close the '
              'paywall and resolve display()');
      expect(firstOutcome!.error, isNull);
      expect(firstOutcome!.presentation?.screenId, isNotNull);
      expect(firstOutcome!.presentation?.screenId, isNotEmpty);
      expect(
        firstOutcome!.closeReason,
        anyOf(PLYCloseReason.backSystem, PLYCloseReason.programmatic,
            PLYCloseReason.button),
      );
      debugPrint(
          'cycle 1 (first display) → closeReason=${firstOutcome!.closeReason} '
          'screenId=${firstOutcome!.presentation?.screenId} '
          'placementId=${firstOutcome!.presentation?.placementId}');

      // Snapshot the event stream collected so far so cycle 2's events can
      // be isolated below (list only grows — no restructuring needed).
      final cycle1ViewedIds = List<String?>.from(viewedIds);

      // --- Cycle 2: RE-display the SAME handle ------------------------------
      presented = false;
      PLYPresentationOutcome? secondOutcome;
      // ignore: unawaited_futures
      presentation.display().then((o) => secondOutcome = o);

      sw = Stopwatch()..start();
      while (!presented && sw.elapsed < const Duration(seconds: 40)) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      expect(presented, isTrue,
          reason: 'paywall should present again on re-display (cycle 2)');

      sw = Stopwatch()..start();
      while (
          secondOutcome == null && sw.elapsed < const Duration(seconds: 40)) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      expect(secondOutcome, isNotNull,
          reason: 'driver (press_back.sh, 2nd invocation) should close the '
              're-displayed paywall and resolve display()');
      expect(secondOutcome!.error, isNull);
      expect(
        secondOutcome!.closeReason,
        anyOf(PLYCloseReason.backSystem, PLYCloseReason.programmatic,
            PLYCloseReason.button),
      );
      debugPrint(
          'cycle 2 (re-display) → closeReason=${secondOutcome!.closeReason} '
          'screenId=${secondOutcome!.presentation?.screenId} '
          'placementId=${secondOutcome!.presentation?.placementId}');
      debugPrint('PRESENTATION_VIEWED/LOADED displayed_presentation per '
          'cycle: $viewedIds');

      // --- The M2 assertion: same handle → same screen, every cycle ---------
      // Primary check.
      expect(
        secondOutcome!.presentation?.screenId,
        equals(firstOutcome!.presentation?.screenId),
        reason: 'M2 regression guard: re-displaying the same handle must '
            'show the SAME screen as the first display, not fall back to '
            "the placement's default source",
      );
      expect(
        secondOutcome!.presentation?.placementId,
        equals(firstOutcome!.presentation?.placementId),
      );

      // Independent cross-check via the event stream (not the outcome
      // parsing path being guarded above). Guarded so missing/unusable data
      // FAILS loudly rather than silently no-oping — an independent check
      // that can't fail proves nothing.
      final cycle2ViewedIds = viewedIds.sublist(cycle1ViewedIds.length);
      expect(cycle1ViewedIds, isNotEmpty,
          reason: 'cycle 1 should have produced at least one '
              'PRESENTATION_VIEWED/LOADED event to cross-check against — '
              'if this fails, the event-stream cross-check has no baseline');
      expect(cycle1ViewedIds.last, isNotNull);
      expect(cycle1ViewedIds.last, isNotEmpty);
      expect(cycle2ViewedIds, isNotEmpty,
          reason: 'cycle 2 (re-display) should have produced at least one '
              'PRESENTATION_VIEWED/LOADED event — an event-stream '
              'cross-check with nothing to compare would silently no-op '
              'instead of catching a regression');
      expect(
        cycle2ViewedIds.last,
        equals(cycle1ViewedIds.last),
        reason: 'event-stream cross-check: cycle 2\'s PRESENTATION_VIEWED/'
            'LOADED displayed_presentation id must equal cycle 1\'s '
            '(independent corroboration of the outcome-based assertion '
            'above)',
      );

      Purchasely.stopListeningToEvents();
    });
  });
}
