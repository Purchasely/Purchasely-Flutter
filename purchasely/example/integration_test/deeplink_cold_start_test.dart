// E2E: cold-start deeplink wired through the start builder.
//
// Proves the full Dart -> native -> SDK chain for the v6 builder modifier
// `PurchaselyBuilder.handleDeeplink(url)`: a deeplink captured at launch is
// handed to `.start()` and the SDK resolves it AUTOMATICALLY once configured,
// with NO separate `Purchasely.handleDeeplink(...)` call.
//
// Platform-agnostic (pure Dart, no host driver): the SDK opens the paywall on
// its own, so we only assert on the analytics events that prove it happened.
//
// Event reality (verified against the native iOS/Android SDKs): a deeplink that
// opens a presentation fires DEEPLINK_OPENED -> PRESENTATION_LOADED ->
// PRESENTATION_VIEWED. PRESENTATION_OPENED is NOT emitted for a deeplink open —
// it only fires when an in-paywall action button opens another presentation.
// We therefore assert:
//   * DEEPLINK_OPENED       -> the cold-start deeplink reached and was parsed by
//                              the native SDK (carries `deeplink_identifier`).
//   * PRESENTATION_VIEWED /  -> the deeplink actually opened the paywall.
//     PRESENTATION_LOADED
//
// Run:
//   flutter test integration_test/deeplink_cold_start_test.dart -d <device>

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

import 'helpers/e2e_start.dart';

const String kApiKey = '0ad0594b-3b3d-4fea-8ee1-4b5df91efe87';
const String kPlacementAudiences = 'integration_test_audiences';
const String kColdStartDeeplink = 'ply://ply/placements/$kPlacementAudiences';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'cold-start handleDeeplink auto-opens the paywall (DEEPLINK_OPENED + PRESENTATION_VIEWED)',
      (tester) async {
    await tester.runAsync(() async {
      // Record the arrival order of the three events that make up the
      // deeplink-open lifecycle, so we can assert the exact sequence
      // DEEPLINK_OPENED -> PRESENTATION_LOADED -> PRESENTATION_VIEWED.
      final order = <PLYEventName>[];
      final byName = <PLYEventName, PLYEvent>{};
      const expectedLifecycle = {
        PLYEventName.DEEPLINK_OPENED,
        PLYEventName.PRESENTATION_LOADED,
        PLYEventName.PRESENTATION_VIEWED,
      };
      // PRESENTATION_OPENED is watched too, but it is NOT part of the
      // lifecycle we wait for — it must never fire for a deeplink-only open
      // (that event is reserved for in-paywall action buttons opening
      // another presentation). See assertion 5 below.
      const tracked = {
        ...expectedLifecycle,
        PLYEventName.PRESENTATION_OPENED,
      };

      // Subscribe BEFORE start: the cold-start deeplink resolves right after the
      // SDK configures, so the listener must be live to avoid missing the burst.
      Purchasely.listenToEvents((event) {
        if (tracked.contains(event.name) && !byName.containsKey(event.name)) {
          byName[event.name] = event;
          order.add(event.name);
        }
      });

      // The whole point of the feature: the deeplink is passed to the builder,
      // NOT replayed by a manual Purchasely.handleDeeplink(...) call.
      final configured = await startWithRetry(() => Purchasely.apiKey(kApiKey)
          .runningMode(PLYRunningMode.full)
          .logLevel(PLYLogLevel.debug)
          .allowDeeplink(true)
          .handleDeeplink(kColdStartDeeplink)
          .stores([PLYStore.google]).start());
      expect(configured, isTrue,
          reason: 'SDK should configure against the real backend');

      // Poll until the full lifecycle arrived (network fetch + render take a
      // moment). PRESENTATION_OPENED is deliberately excluded from the wait
      // condition since it must never fire.
      final sw = Stopwatch()..start();
      while (!expectedLifecycle.every(byName.containsKey) &&
          sw.elapsed < const Duration(seconds: 60)) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }

      debugPrint('cold-start deeplink → event order: '
          '${order.map((e) => e.toString().split('.').last).join(' → ')}');

      // 1. All three lifecycle events fired.
      expect(byName.keys.toSet(), containsAll(expectedLifecycle),
          reason: 'cold-start deeplink must produce the full lifecycle '
              '{DEEPLINK_OPENED, PRESENTATION_LOADED, PRESENTATION_VIEWED}, '
              'got: $order');

      // 2. Ordering. The robust cross-platform invariant is that the paywall is
      //    VIEWED last — after the deeplink was recognized AND the screen was
      //    loaded. The relative order of DEEPLINK_OPENED vs PRESENTATION_LOADED
      //    is platform-specific (iOS: DEEPLINK_OPENED → LOADED; Android: LOADED →
      //    DEEPLINK_OPENED), so we assert only what holds on both.
      final iDeeplink = order.indexOf(PLYEventName.DEEPLINK_OPENED);
      final iLoaded = order.indexOf(PLYEventName.PRESENTATION_LOADED);
      final iViewed = order.indexOf(PLYEventName.PRESENTATION_VIEWED);
      expect(iDeeplink, lessThan(iViewed),
          reason: 'DEEPLINK_OPENED must precede PRESENTATION_VIEWED');
      expect(iLoaded, lessThan(iViewed),
          reason: 'PRESENTATION_LOADED must precede PRESENTATION_VIEWED');

      // 3. The processed deeplink is the one we passed to start().
      final deeplinkOpened = byName[PLYEventName.DEEPLINK_OPENED]!;
      expect(deeplinkOpened.properties.deeplink_identifier, isNotNull);
      expect(deeplinkOpened.properties.deeplink_identifier,
          contains(kPlacementAudiences),
          reason: 'the processed deeplink must be the one passed to start()');

      // 4. The rendered paywall carries identifying properties.
      final viewed = byName[PLYEventName.PRESENTATION_VIEWED]!;
      expect(viewed.properties.sdk_version, isNotNull);
      expect(viewed.properties.sdk_version, isNotEmpty);

      // 5. A deeplink open must NOT emit PRESENTATION_OPENED — that event is
      //    reserved for an in-paywall action button opening another
      //    presentation, not for the SDK auto-opening one via a deeplink.
      //    Give the asynchronous event channel a short settle window after
      //    VIEWED; checking immediately at the first complete lifecycle could
      //    otherwise false-pass if a forbidden event arrived just afterward.
      await Future<void>.delayed(const Duration(seconds: 2));
      expect(order.contains(PLYEventName.PRESENTATION_OPENED), isFalse,
          reason: 'a deeplink open must not emit PRESENTATION_OPENED');

      Purchasely.stopListeningToEvents();
    });
  });
}
