// End-to-end tests for the 6.1.0 start options, on a real device/emulator
// against the REAL Purchasely backend.
//
// Covers, in one app process (the SDK starts once):
//   R1 — anonymousUserId: a fixed UUID passed on the chain is the id the SDK
//        reports back, uppercased.
//   R2 — proxy(null): an explicit CLEAR is a supported operation. The SDK still
//        configures and still resolves a placement from production, which is
//        what proves the API host stayed on `api.purchasely.io`.
//   R3 — webRedemptionListener on the chain subscribes BEFORE start(), so a
//        redemption settling during start() cannot be missed.
//   R4 — a `ply/redeem/<bogus>` deeplink round-trips to the server and the
//        listener receives a Failure, on the main thread, exactly once. Requires
//        `appHandlesRedemptionAlert: true` — see the chain below.
//
// Same API key and placements as the native Android `integration-tests` module.
//
// Run with:
//   flutter test integration_test/redemption_identity_test.dart -d emulator-5554

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

const String kApiKey = '0ad0594b-3b3d-4fea-8ee1-4b5df91efe87';
const String kPlacementAudiences = 'integration_test_audiences';

/// A canonical UUID this suite pins the device to, so R1 asserts an exact value
/// instead of a shape. `override: true` is required: the device already holds an
/// SDK-generated id from any previous run.
const String kFixedAnonymousUserId = '3f2504e0-4f89-11d3-9a0c-0305e82c3301';

/// A redemption token the backend cannot resolve. Its scheme matches the
/// example app's registered Purchasely scheme (`ply://`, same as
/// `deeplink_cold_start_test.dart`).
const String kBogusRedeemDeeplink =
    'ply://ply/redeem/e2e-not-a-real-redemption-token';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Every redemption outcome the listener received, in order.
  final redemptions = <PLYWebRedemptionResult>[];

  /// Snapshot of "was the redemption channel already subscribed?" taken between
  /// building the chain and calling start(). R3 asserts on it.
  late bool subscribedBeforeStart;

  setUpAll(() async {
    final builder = Purchasely.apiKey(kApiKey)
        .runningMode(PLYRunningMode.full)
        .logLevel(PLYLogLevel.debug)
        // R1 — pin the anonymous user id. override: true because the device
        // already holds an id from an earlier run.
        .anonymousUserId(kFixedAnonymousUserId, override: true)
        // R2 — an explicit CLEAR, which both native SDKs support. It keeps this
        // suite on production, unlike setting a live proxy, while still driving
        // the native `proxy(nil)` / `proxy(null)` code path for real.
        .proxy(null)
        // R3 — on the chain, so the subscription happens here, not in start().
        //
        // The `true` is NOT decoration: it is `appHandlesRedemptionAlert`, and a
        // headless test cannot work without it. With the native default (false)
        // the SDK shows its own popin and calls the listener only once the user
        // ACKNOWLEDGES it — so in CI, where nobody taps OK, the listener never
        // fires and R4 fails with an empty list. `true` suppresses the popin and
        // delivers as soon as the redemption settles.
        //
        // Consequence for coverage, stated plainly: the default popin path is
        // NOT covered end to end, because it is not observable without driving
        // native UI. Only the `true` path is.
        .webRedemptionListener(redemptions.add, true)
        .stores([PLYStore.google]);

    // Read the state the chain left behind, BEFORE start() runs.
    subscribedBeforeStart = Purchasely.webRedemptions != null;

    final configured = await builder.start();
    expect(configured, isTrue,
        reason: 'the SDK must configure with a cleared proxy and a redemption '
            'listener on the chain');
  });

  group('R1 — anonymousUserId round-trips through the native bridge', () {
    testWidgets('the SDK reports the id the chain pinned, uppercased',
        (tester) async {
      final id = await Purchasely.anonymousUserId;

      // Both native SDKs store the id uppercase. Compared case-insensitively as
      // well, so the test states the contract rather than depending on it.
      expect(id.toLowerCase(), equals(kFixedAnonymousUserId.toLowerCase()),
          reason: 'the pinned anonymous user id must reach the native SDK');
      expect(id, equals(kFixedAnonymousUserId.toUpperCase()),
          reason: 'the SDK stores the anonymous user id uppercase');
      debugPrint('R1 → anonymousUserId=$id');
    });

    testWidgets('the pinned id is the one the analytics events carry',
        (tester) async {
      await tester.runAsync(() async {
        PLYEvent? event;
        Purchasely.listenToEvents((e) => event ??= e);

        final presentation =
            await PLYPresentationBuilder.placement(kPlacementAudiences)
                .build()
                .preload();

        final sw = Stopwatch()..start();
        while (event == null && sw.elapsed < const Duration(seconds: 15)) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
        Purchasely.stopListeningToEvents();

        expect(event, isNotNull, reason: 'an SDK event must fire on preload');
        final reported = event!.properties.anonymous_user_id;
        expect(reported, isNotNull);
        expect(reported!.toLowerCase(),
            equals(kFixedAnonymousUserId.toLowerCase()),
            reason: 'the pinned id must be the one reported to analytics');
        debugPrint('R1 → event anonymous_user_id=$reported '
            'screenId=${presentation.screenId}');
      });
    });
  });

  group('R2 — proxy(null) is a supported clear, not an error', () {
    testWidgets('the SDK still resolves a placement from production',
        (tester) async {
      // The assertion that matters: after an explicit clear the API host is
      // back on `api.purchasely.io`, so a placement resolves. A clear that
      // instead pointed the SDK at nothing would fail here.
      final presentation =
          await PLYPresentationBuilder.placement(kPlacementAudiences)
              .build()
              .preload();

      expect(presentation.screenId, isNotNull);
      expect(presentation.screenId, isNotEmpty);
      expect(presentation.placementId, equals(kPlacementAudiences));
      debugPrint('R2 → cleared proxy, placement resolved: '
          'screenId=${presentation.screenId}');
    });

    testWidgets('the product catalogue still loads from production',
        (tester) async {
      final products = await Purchasely.allProducts();
      expect(products, isNotEmpty,
          reason: 'a cleared proxy must leave the API host on production');
      debugPrint('R2 → ${products.length} product(s) after the clear');
    });
  });

  group('R3 — the chain subscribes before start()', () {
    testWidgets('the redemption channel was live before start() was called',
        (tester) async {
      expect(subscribedBeforeStart, isTrue,
          reason: 'webRedemptionListener() on the chain must subscribe at '
              'chain time — a redemption can settle during start()');
      expect(Purchasely.webRedemptions, isNotNull,
          reason: 'the subscription must survive start()');
      debugPrint('R3 → subscribed before start ✓');
    });
  });

  group('R4 — a bogus redeem deeplink reaches the listener as a Failure', () {
    testWidgets('handleDeeplink(ply/redeem/<bogus>) → isSuccess false + a code',
        (tester) async {
      await tester.runAsync(() async {
        redemptions.clear();

        // A redemption deeplink is NOT subject to allowDeeplink: the native SDK
        // intercepts `ply/redeem` out of band. Turning the gate off first makes
        // that explicit rather than incidental.
        await Purchasely.allowDeeplink(false);

        // The SDK validates the token against the real backend, so this makes a
        // network round-trip before it settles.
        await Purchasely.handleDeeplink(kBogusRedeemDeeplink)
            .timeout(const Duration(seconds: 20), onTimeout: () => false);

        final sw = Stopwatch()..start();
        while (
            redemptions.isEmpty && sw.elapsed < const Duration(seconds: 25)) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }

        expect(redemptions, isNotEmpty,
            reason: 'the SDK must call the listener once the redemption '
                'settles, even with allowDeeplink(false). An empty list here '
                'with appHandlesRedemptionAlert unset means the SDK is waiting '
                'for someone to acknowledge its popin — pass true instead.');

        final result = redemptions.first;
        expect(result.isSuccess, isFalse,
            reason: 'an unresolvable token cannot grant anything');
        // The shape must not change between the two branches.
        expect(result.context, isNull);
        expect(result.replay, isFalse);
        // The server reports a code; a transport failure carries none, so this
        // accepts null rather than pinning one value.
        expect(
            result.errorCode,
            anyOf(isNull, 'INVALID_REDEMPTION_TOKEN',
                'EXPIRED_REDEMPTION_TOKEN'));
        debugPrint('R4 → isSuccess=${result.isSuccess} '
            'code=${result.errorCode} message=${result.errorMessage}');

        // Exactly once per settled redemption.
        await Future<void>.delayed(const Duration(seconds: 3));
        expect(redemptions, hasLength(1),
            reason: 'the SDK must call the listener exactly once');

        await Purchasely.allowDeeplink(true);
      });
    });

    testWidgets('removeWebRedemptionListener stops the delivery',
        (tester) async {
      await tester.runAsync(() async {
        Purchasely.removeWebRedemptionListener();
        expect(Purchasely.webRedemptions, isNull);

        redemptions.clear();
        await Purchasely.handleDeeplink(kBogusRedeemDeeplink)
            .timeout(const Duration(seconds: 20), onTimeout: () => false);
        await Future<void>.delayed(const Duration(seconds: 8));

        expect(redemptions, isEmpty,
            reason: 'a removed listener must receive nothing');
        debugPrint('R4 → listener removed, no delivery ✓');
      });
    });
  });
}
