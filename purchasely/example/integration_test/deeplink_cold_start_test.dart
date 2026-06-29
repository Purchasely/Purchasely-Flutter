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

const String kApiKey = '0ad0594b-3b3d-4fea-8ee1-4b5df91efe87';
const String kPlacementAudiences = 'integration_test_audiences';
const String kColdStartDeeplink = 'ply://ply/placements/$kPlacementAudiences';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'cold-start handleDeeplink auto-opens the paywall (DEEPLINK_OPENED + PRESENTATION_VIEWED)',
      (tester) async {
    await tester.runAsync(() async {
      PLYEvent? deeplinkOpened;
      PLYEvent? paywallEvent;

      // Subscribe BEFORE start: the cold-start deeplink resolves right after the
      // SDK configures, so the listener must be live to avoid missing the burst.
      Purchasely.listenToEvents((event) {
        if (event.name == PLYEventName.DEEPLINK_OPENED) {
          deeplinkOpened ??= event;
        } else if (event.name == PLYEventName.PRESENTATION_VIEWED ||
            event.name == PLYEventName.PRESENTATION_LOADED) {
          paywallEvent ??= event;
        }
      });

      // The whole point of the feature: the deeplink is passed to the builder,
      // NOT replayed by a manual Purchasely.handleDeeplink(...) call.
      final configured = await Purchasely.apiKey(kApiKey)
          .runningMode(PLYRunningMode.full)
          .logLevel(PLYLogLevel.debug)
          .allowDeeplink(true)
          .handleDeeplink(kColdStartDeeplink)
          .stores([PLYStore.google]).start();
      expect(configured, isTrue,
          reason: 'SDK should configure against the real backend');

      // Poll for both events (network fetch + render can take a few seconds).
      final sw = Stopwatch()..start();
      while ((deeplinkOpened == null || paywallEvent == null) &&
          sw.elapsed < const Duration(seconds: 45)) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }

      // 1. The cold-start deeplink reached the native SDK and was parsed.
      expect(deeplinkOpened, isNotNull,
          reason:
              'cold-start .handleDeeplink(url) must be processed by the SDK '
              '(DEEPLINK_OPENED)');
      expect(deeplinkOpened!.properties.deeplink_identifier, isNotNull);
      expect(deeplinkOpened!.properties.deeplink_identifier, isNotEmpty);
      expect(deeplinkOpened!.properties.deeplink_identifier,
          contains(kPlacementAudiences),
          reason:
              'the processed deeplink must be the one we passed to start()');

      // 2. The deeplink actually opened the paywall.
      expect(paywallEvent, isNotNull,
          reason: 'the cold-start deeplink must auto-open the paywall '
              '(PRESENTATION_VIEWED / PRESENTATION_LOADED)');
      expect(paywallEvent!.properties.sdk_version, isNotNull);
      expect(paywallEvent!.properties.sdk_version, isNotEmpty);

      debugPrint('cold-start deeplink → '
          'DEEPLINK_OPENED deeplink_identifier='
          '${deeplinkOpened!.properties.deeplink_identifier} ; '
          '${paywallEvent!.name} '
          'displayed_presentation='
          '${paywallEvent!.properties.displayed_presentation}');

      Purchasely.stopListeningToEvents();
    });
  });
}
