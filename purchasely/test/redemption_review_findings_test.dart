// Regression tests for the defects two reviews of the React Native 6.1.0 pull
// request found after its implementation looked finished. Each group names the
// defect it locks out, because the value of these tests is entirely in the
// specific silent failure they prevent.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';
import 'package:purchasely_flutter/src/ply_transformers.dart'
    show plySubscriptionFromMap, plySubscriptionSourceFromWire;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const redemptionChannel = EventChannel('purchasely-web-redemption');
  const eventsChannel = EventChannel('purchasely-events');

  tearDown(() {
    Purchasely.removeWebRedemptionListener();
    Purchasely.stopListeningToEvents();
    messenger.setMockStreamHandler(redemptionChannel, null);
    messenger.setMockStreamHandler(eventsChannel, null);
  });

  // ---------------------------------------------------------------------------
  // Review item 2 — a stale subscription handle must never be released twice.
  //
  // On React Native a remove-all path tore the redemption listener down without
  // clearing the cached handle, so the next registration released the same
  // listener a second time. The native listener count went one too low, hit
  // zero, and the platform's "no more listeners" hook cleared the flag gating
  // EVERY event the module emitted.
  // ---------------------------------------------------------------------------

  group('review 2 — the cached subscription handle is cleared on every path',
      () {
    test('register → remove → register never cancels one handle twice',
        () async {
      var listens = 0;
      var cancels = 0;
      messenger.setMockStreamHandler(
        redemptionChannel,
        MockStreamHandler.inline(
          onListen: (arguments, sink) => listens++,
          onCancel: (arguments) => cancels++,
        ),
      );

      Purchasely.addWebRedemptionListener((_) {});
      final firstHandle = Purchasely.webRedemptions;
      expect(firstHandle, isNotNull);

      Purchasely.removeWebRedemptionListener();
      // The handle must be gone, not merely cancelled. A non-null handle here
      // is what let the next registration release the same subscription again.
      expect(Purchasely.webRedemptions, isNull);

      Purchasely.addWebRedemptionListener((_) {});
      final secondHandle = Purchasely.webRedemptions;
      expect(secondHandle, isNotNull);
      expect(secondHandle, isNot(same(firstHandle)));

      await pumpEventQueue();

      // Two registrations, two listens. One removal, one cancel — plus the
      // teardown of the second subscription, which has not happened yet.
      expect(listens, 2);
      expect(cancels, 1,
          reason: 'a second cancel for the first handle would drive the '
              'platform listener count below zero');
    });

    test('removing twice in a row sends only one cancel', () async {
      var cancels = 0;
      messenger.setMockStreamHandler(
        redemptionChannel,
        MockStreamHandler.inline(
          onListen: (arguments, sink) {},
          onCancel: (arguments) => cancels++,
        ),
      );

      Purchasely.addWebRedemptionListener((_) {});
      Purchasely.removeWebRedemptionListener();
      Purchasely.removeWebRedemptionListener();
      await pumpEventQueue();

      expect(cancels, 1);
      expect(Purchasely.webRedemptions, isNull);
    });

    test('re-registering replaces the subscription with exactly one cancel',
        () async {
      var listens = 0;
      var cancels = 0;
      messenger.setMockStreamHandler(
        redemptionChannel,
        MockStreamHandler.inline(
          onListen: (arguments, sink) => listens++,
          onCancel: (arguments) => cancels++,
        ),
      );

      Purchasely.addWebRedemptionListener((_) {});
      Purchasely.addWebRedemptionListener((_) {});
      Purchasely.addWebRedemptionListener((_) {});
      await pumpEventQueue();

      expect(listens, 3);
      expect(cancels, 2, reason: 'each replacement cancels exactly one handle');
      expect(Purchasely.webRedemptions, isNotNull);
    });

    test('redemption churn does not silence the shared event stream', () async {
      // The consequence the React Native bug actually had. Flutter gives each
      // EventChannel its own handler and its own sink, with no module-wide
      // "shouldEmit" gate, so this asserts that independence holds rather than
      // being taken on faith.
      messenger.setMockStreamHandler(
        redemptionChannel,
        MockStreamHandler.inline(
            onListen: (arguments, sink) {}, onCancel: (arguments) {}),
      );
      final received = <PLYEvent>[];
      messenger.setMockStreamHandler(
        eventsChannel,
        MockStreamHandler.inline(onListen: (arguments, sink) {
          sink.success(const <String, Object?>{
            'name': 'APP_STARTED',
            'properties': <String, Object?>{
              'event_name': 'APP_STARTED',
              'event_created_at': '2026-09-07T10:00:00Z',
            },
          });
        }),
      );

      Purchasely.listenToEvents(received.add);
      Purchasely.addWebRedemptionListener((_) {});
      Purchasely.removeWebRedemptionListener();
      Purchasely.addWebRedemptionListener((_) {});
      Purchasely.removeWebRedemptionListener();
      await pumpEventQueue();

      expect(received, isNotEmpty,
          reason: 'analytics must keep flowing through redemption churn');
      expect(received.first.name, PLYEventName.APP_STARTED);
    });
  });

  // ---------------------------------------------------------------------------
  // Review item 3 — the web checkout subscription source was dropped.
  //
  // A Web2App redemption grants subscriptions from exactly that source, so
  // `PLYWebRedemptionContext.subscription` is the payload most likely to carry
  // it. Index 4 used to decode to `none`.
  // ---------------------------------------------------------------------------

  group('review 3 — the web checkout source decodes', () {
    test('the enum order is the wire contract both natives agree on', () {
      // Pinned as literals. Android StoreType and iOS PLYSubscriptionSource
      // both use this order at their released 6.1.0 tags.
      expect(PLYSubscriptionSource.values.map((s) => s.index).toList(),
          [0, 1, 2, 3, 4, 5]);
      expect(PLYSubscriptionSource.appleAppStore.index, 0);
      expect(PLYSubscriptionSource.googlePlayStore.index, 1);
      expect(PLYSubscriptionSource.amazonAppstore.index, 2);
      expect(PLYSubscriptionSource.huaweiAppGallery.index, 3);
      expect(PLYSubscriptionSource.webCheckoutStripe.index, 4);
      expect(PLYSubscriptionSource.none.index, 5);
    });

    test('wire index 4 decodes to webCheckoutStripe, not none', () {
      expect(plySubscriptionSourceFromWire(4),
          PLYSubscriptionSource.webCheckoutStripe);
      expect(
          plySubscriptionSourceFromWire(4), isNot(PLYSubscriptionSource.none));
    });

    test('every wire index round-trips to its own case', () {
      for (final source in PLYSubscriptionSource.values) {
        expect(plySubscriptionSourceFromWire(source.index), source);
      }
    });

    test('an out-of-range or missing index still falls back to none', () {
      expect(plySubscriptionSourceFromWire(null), PLYSubscriptionSource.none);
      expect(plySubscriptionSourceFromWire(-1), PLYSubscriptionSource.none);
      expect(plySubscriptionSourceFromWire(6), PLYSubscriptionSource.none);
      expect(plySubscriptionSourceFromWire('GOOGLE_PLAY_STORE'),
          PLYSubscriptionSource.none);
    });

    test('a redemption context reports a web checkout subscription', () async {
      // The exact reachable path: the source arrives through the API this
      // release introduces.
      final received = <PLYWebRedemptionResult>[];
      messenger.setMockStreamHandler(
        redemptionChannel,
        MockStreamHandler.inline(onListen: (arguments, sink) {
          sink.success(const <String, Object?>{
            'isSuccess': true,
            'replay': false,
            'errorCode': null,
            'errorMessage': null,
            'context': <String, Object?>{
              'subscription': <String, Object?>{
                'subscriptionSource': 4, // WEB_CHECKOUT_STRIPE / stripe
                'plan': <String, Object?>{'vendorId': 'plan_monthly'},
              },
            },
          });
        }),
      );

      Purchasely.addWebRedemptionListener(received.add);
      await pumpEventQueue();

      expect(received.single.context?.subscription?.subscriptionSource,
          PLYSubscriptionSource.webCheckoutStripe);
    });
  });

  // ---------------------------------------------------------------------------
  // Review item 4 — optional is not the same as nullable, and the two natives
  // disagree on which one they send.
  //
  // Android `PLYSubscription.toMap()` assigns the key unconditionally from a
  // nullable field, so the host receives the key with an explicit null. The iOS
  // bridge omits the key entirely. A decoder must accept both, must not throw,
  // and must not coerce either to an empty string.
  // ---------------------------------------------------------------------------

  group('review 4 — an explicit null and an omitted key decode identically',
      () {
    test('the Android shape: keys present with an explicit null', () {
      final subscription = plySubscriptionFromMap(const <String, Object?>{
        'purchaseToken': null,
        'nextRenewalDate': null,
        'cancelledDate': null,
        'subscriptionSource': 1,
      });

      expect(subscription.purchaseToken, isNull);
      expect(subscription.nextRenewalDate, isNull);
      expect(subscription.cancelledDate, isNull);
      // Never coerced. An empty string would read as "a date I have" to a
      // caller doing a null check.
      expect(subscription.purchaseToken, isNot(''));
      expect(subscription.nextRenewalDate, isNot(''));
      expect(subscription.cancelledDate, isNot(''));
    });

    test('the iOS shape: the keys are simply absent', () {
      final subscription = plySubscriptionFromMap(const <String, Object?>{
        'subscriptionSource': 0,
      });

      expect(subscription.purchaseToken, isNull);
      expect(subscription.nextRenewalDate, isNull);
      expect(subscription.cancelledDate, isNull);
    });

    test('both shapes produce the same three nulls', () {
      final android = plySubscriptionFromMap(const <String, Object?>{
        'purchaseToken': null,
        'nextRenewalDate': null,
        'cancelledDate': null,
        'subscriptionSource': 0,
      });
      final ios = plySubscriptionFromMap(
          const <String, Object?>{'subscriptionSource': 0});

      expect(
        [android.purchaseToken, android.nextRenewalDate, android.cancelledDate],
        equals([ios.purchaseToken, ios.nextRenewalDate, ios.cancelledDate]),
      );
    });

    test('an explicit null product does not throw', () {
      final subscription = plySubscriptionFromMap(const <String, Object?>{
        'product': null,
        'plan': null,
        'commitmentProgress': null,
        'cumulatedRevenuesInUSD': null,
        'subscriptionDurationInDays': null,
      });

      expect(subscription.product, isNull);
      expect(subscription.plan, isNull);
      expect(subscription.commitmentProgress, isNull);
      expect(subscription.cumulatedRevenuesInUSD, isNull);
      expect(subscription.subscriptionDurationInDays, isNull);
    });

    test('a redemption context tolerates a fully-null Android subscription',
        () async {
      final received = <PLYWebRedemptionResult>[];
      messenger.setMockStreamHandler(
        redemptionChannel,
        MockStreamHandler.inline(onListen: (arguments, sink) {
          sink.success(const <String, Object?>{
            'isSuccess': true,
            'replay': false,
            'errorCode': null,
            'errorMessage': null,
            'context': <String, Object?>{
              'subscription': <String, Object?>{
                'purchaseToken': null,
                'nextRenewalDate': null,
                'cancelledDate': null,
                'subscriptionSource': null,
                'product': null,
                'plan': null,
              },
            },
          });
        }),
      );

      Purchasely.addWebRedemptionListener(received.add);
      await pumpEventQueue();

      final subscription = received.single.context?.subscription;
      expect(subscription, isNotNull);
      expect(subscription!.purchaseToken, isNull);
      expect(subscription.nextRenewalDate, isNull);
      expect(subscription.cancelledDate, isNull);
      expect(subscription.subscriptionSource, PLYSubscriptionSource.none);
    });
  });

  // ---------------------------------------------------------------------------
  // Review item 1 — the masked email hint is not iOS-only. Nothing in the code
  // branches on it, so what is testable is that no shipped doc string claims it
  // is; the runtime behaviour is the native SDKs'.
  // ---------------------------------------------------------------------------

  group('review 1 — the failure message is carried verbatim on any platform',
      () {
    test('errorMessage is passed through unmodified and never logged by us',
        () async {
      const hint = 'Redemption link has expired. '
          'A new link was sent to j***@example.com.';
      final received = <PLYWebRedemptionResult>[];
      messenger.setMockStreamHandler(
        redemptionChannel,
        MockStreamHandler.inline(onListen: (arguments, sink) {
          sink.success(const <String, Object?>{
            'isSuccess': false,
            'context': null,
            'replay': false,
            'errorCode': 'EXPIRED_REDEMPTION_TOKEN',
            'errorMessage': hint,
          });
        }),
      );

      Purchasely.addWebRedemptionListener(received.add);
      await pumpEventQueue();

      // Verbatim: the bridge must not truncate or scrub the hint, because it is
      // the only copy the app will ever see. Keeping it out of analytics is the
      // integrator's job, and the docs state that unconditionally.
      expect(received.single.errorMessage, hint);
      expect(received.single.errorCode, 'EXPIRED_REDEMPTION_TOKEN');
    });

    test('the REDEMPTION_FAILED event carries no hint field at all', () {
      // The event type has no member for it, on either platform. Both natives
      // drop the hint in `toEvent`, so there is nowhere for it to land.
      final redemption = PLYEventPropertyRedemption(
          'tok', null, null, null, 'EXPIRED_REDEMPTION_TOKEN');
      expect(redemption.error_code, 'EXPIRED_REDEMPTION_TOKEN');
      expect(redemption.receipt, isNull);
      expect(redemption.subscriptions, isNull);
    });
  });
}
