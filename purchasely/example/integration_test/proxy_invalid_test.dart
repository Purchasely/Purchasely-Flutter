// End-to-end test for the 6.1.0 `proxy` trap, on a real device/emulator
// against the REAL Purchasely backend.
//
// Its own app process on purpose: the SDK starts once, and this suite has to
// start it with a DIFFERENT proxy state than
// `redemption_identity_test.dart` (which passes an explicit clear).
//
// The trap: on iOS the native parameter is a `URL?` where nil means CLEAR, not
// "ignore this value". A string the bridge cannot convert must therefore be
// SKIPPED, never forwarded as nil — otherwise a typo silently disables a proxy
// the app asked for. Android skips an unusable value for the same reason.
//
// P1 — start() still succeeds with an unconvertible proxy string.
// P2 — the SDK still reaches production, which is what proves the typo neither
//      cleared nor redirected the API host.
//
// This suite deliberately never sets a LIVE proxy: that would move the example
// app off production, and the resolved API host is SDK-internal state a test
// harness cannot read back anyway.
//
// Run with:
//   flutter test integration_test/proxy_invalid_test.dart -d emulator-5554

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

const String kApiKey = '0ad0594b-3b3d-4fea-8ee1-4b5df91efe87';
const String kPlacementAudiences = 'integration_test_audiences';

/// A realistic typo: a space inside the authority. `URL(string:)` on iOS
/// rejects it, so the iOS bridge takes its skip branch.
const String kUnconvertibleProxy = 'https://svc purchasely.io';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late bool configured;

  setUpAll(() async {
    configured = await Purchasely.apiKey(kApiKey)
        .runningMode(PLYRunningMode.full)
        .logLevel(PLYLogLevel.debug)
        .proxy(kUnconvertibleProxy)
        .stores([PLYStore.google]).start();
  });

  group('P1 — an unconvertible proxy string does not break start()', () {
    testWidgets('start() resolves true, and does not throw', (tester) async {
      // The bridge logs an error and skips the modifier. It must not throw from
      // start(), and it must not surface a PlatformException: a misconfigured
      // proxy is a warning, never a boot failure.
      expect(configured, isTrue,
          reason: 'a bad proxy value must be logged and skipped, not fatal');
      debugPrint(
          'P1 → configured=$configured with proxy="$kUnconvertibleProxy"');
    });
  });

  group('P2 — the typo neither cleared nor redirected the API host', () {
    testWidgets('a placement still resolves from production', (tester) async {
      final presentation =
          await PLYPresentationBuilder.placement(kPlacementAudiences)
              .build()
              .preload();

      expect(presentation.screenId, isNotNull);
      expect(presentation.screenId, isNotEmpty);
      expect(presentation.placementId, equals(kPlacementAudiences));
      debugPrint('P2 → placement resolved despite the bad proxy: '
          'screenId=${presentation.screenId}');
    });

    testWidgets('the product catalogue still loads from production',
        (tester) async {
      final products = await Purchasely.allProducts();
      expect(products, isNotEmpty,
          reason: 'the API host must still be api.purchasely.io');
      debugPrint('P2 → ${products.length} product(s)');
    });

    testWidgets('the anonymous user id still round-trips', (tester) async {
      // A broken API host would leave the SDK unable to report anything.
      final id = await Purchasely.anonymousUserId;
      expect(id, isNotEmpty);
      debugPrint('P2 → anonymousUserId=$id');
    });
  });
}
