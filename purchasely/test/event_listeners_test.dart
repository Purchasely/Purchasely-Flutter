// Unit tests for the three EventChannel-backed public callbacks:
//   * Purchasely.listenToEvents        (channel 'purchasely-events')
//   * Purchasely.listenToPurchases     (channel 'purchasely-purchases')
//   * Purchasely.setUserAttributeListener (channel 'purchasely-user-attributes')
//   * Purchasely.addWebRedemptionListener (channel 'purchasely-web-redemption')
//
// These exercise the Dart-side decoding/dispatch of native events deterministically
// (no device) by driving each EventChannel with a MockStreamHandler. They close the
// gap where these listener callbacks were only exercised in E2E (events) or not at
// all (purchases, user-attributes).

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  // Registers a mock stream handler that emits [events] in order as soon as the
  // SDK subscribes to [channel].
  void emitOnListen(EventChannel channel, List<Object?> events) {
    messenger.setMockStreamHandler(
      channel,
      MockStreamHandler.inline(onListen: (arguments, sink) {
        for (final e in events) {
          sink.success(e);
        }
      }),
    );
  }

  tearDown(() {
    messenger.setMockStreamHandler(
        const EventChannel('purchasely-events'), null);
    messenger.setMockStreamHandler(
        const EventChannel('purchasely-purchases'), null);
    messenger.setMockStreamHandler(
        const EventChannel('purchasely-user-attributes'), null);
    messenger.setMockStreamHandler(
        const EventChannel('purchasely-web-redemption'), null);
  });

  group('listenToEvents', () {
    test('decodes a native event into a typed PLYEvent', () async {
      emitOnListen(const EventChannel('purchasely-events'), [
        {
          'name': 'PRESENTATION_VIEWED',
          'properties': {
            'sdk_version': '6.0.0',
            'event_name': 'PRESENTATION_VIEWED',
            'event_created_at': '2026-06-29T10:00:00Z',
            'displayed_presentation': 'pres_123',
            'source_identifier': 'placement_abc',
          },
        },
      ]);

      final received = <PLYEvent>[];
      Purchasely.listenToEvents(received.add);
      await pumpEventQueue();

      expect(received, hasLength(1));
      expect(received.first.name, PLYEventName.PRESENTATION_VIEWED);
      expect(received.first.properties.sdk_version, '6.0.0');
      expect(received.first.properties.displayed_presentation, 'pres_123');
      expect(received.first.properties.source_identifier, 'placement_abc');
      // The static subscription handle is exposed so a host can inspect/cancel
      // it directly instead of only going through stopListeningToEvents().
      expect(Purchasely.events, isNotNull);

      Purchasely.stopListeningToEvents();
    });

    test(
        'falls back to UNKNOWN (not APP_CONFIGURED) for an unrecognized '
        'event name (REC-13 / EVT-01)', () async {
      emitOnListen(const EventChannel('purchasely-events'), [
        {
          'name': 'NOT_A_REAL_EVENT',
          'properties': {
            'event_name': 'NOT_A_REAL_EVENT',
            'event_created_at': '2026-06-29T10:00:00Z',
          },
        },
      ]);

      PLYEvent? received;
      Purchasely.listenToEvents((e) => received = e);
      await pumpEventQueue();

      expect(received, isNotNull);
      expect(received!.name, PLYEventName.UNKNOWN);
      expect(received!.properties.event_name, PLYEventName.UNKNOWN);

      Purchasely.stopListeningToEvents();
    });

    test(
        'decodes the PLACEMENT_OPENED and PURCHASE_FROM_STORE_TAPPED '
        'parity additions (REC-13 / EVT-01)', () async {
      emitOnListen(const EventChannel('purchasely-events'), [
        {
          'name': 'PLACEMENT_OPENED',
          'properties': {
            'event_name': 'PLACEMENT_OPENED',
            'event_created_at': '2026-06-29T10:00:00Z',
          },
        },
        {
          'name': 'PURCHASE_FROM_STORE_TAPPED',
          'properties': {
            'event_name': 'PURCHASE_FROM_STORE_TAPPED',
            'event_created_at': '2026-06-29T10:00:00Z',
          },
        },
      ]);

      final received = <PLYEvent>[];
      Purchasely.listenToEvents(received.add);
      await pumpEventQueue();

      expect(received, hasLength(2));
      expect(received[0].name, PLYEventName.PLACEMENT_OPENED);
      expect(received[1].name, PLYEventName.PURCHASE_FROM_STORE_TAPPED);

      Purchasely.stopListeningToEvents();
    });
  });

  group('addEventListener / removeEventListener aliases', () {
    test(
        'addEventListener/removeEventListener delegate to '
        'listenToEvents/stopListeningToEvents (REC-18 / PAR-18)', () async {
      emitOnListen(const EventChannel('purchasely-events'), [
        {
          'name': 'APP_STARTED',
          'properties': {
            'event_name': 'APP_STARTED',
            'event_created_at': '2026-06-29T10:00:00Z',
          },
        },
      ]);

      final received = <PLYEvent>[];
      Purchasely.addEventListener(received.add);
      await pumpEventQueue();

      expect(received, hasLength(1));
      expect(received.first.name, PLYEventName.APP_STARTED);
      // Same static subscription handle as listenToEvents.
      expect(Purchasely.events, isNotNull);

      // Must not throw — delegates to stopListeningToEvents().
      Purchasely.removeEventListener();
    });
  });

  group('listenToPurchases', () {
    test('forwards the native purchase event to the callback', () async {
      emitOnListen(const EventChannel('purchasely-purchases'), ['purchased']);

      final received = <dynamic>[];
      Purchasely.listenToPurchases(received.add);
      await pumpEventQueue();

      expect(received, ['purchased']);
      expect(Purchasely.purchases, isNotNull);

      Purchasely.stopListeningToPurchases();
    });
  });

  group('addWebRedemptionListener (6.1.0)', () {
    test('decodes a granted redemption, subscription included', () async {
      emitOnListen(const EventChannel('purchasely-web-redemption'), [
        {
          'isSuccess': true,
          'replay': true,
          'errorCode': null,
          'errorMessage': null,
          'context': {
            'subscription': {
              'purchaseToken': 'token-1',
              'subscriptionSource': 1, // googlePlayStore
              'nextRenewalDate': '2026-10-01T10:00:00Z',
              'plan': {'vendorId': 'plan_monthly'},
              'product': {
                'name': 'Premium',
                'vendorId': 'product_premium',
                'plans': <String, dynamic>{},
              },
            },
          },
        },
      ]);

      final received = <PLYWebRedemptionResult>[];
      Purchasely.addWebRedemptionListener(received.add);
      await pumpEventQueue();

      expect(received, hasLength(1));
      final result = received.first;
      expect(result.isSuccess, true);
      // `replay` is a verdict about the token, and stays independent of success.
      expect(result.replay, true);
      expect(result.errorCode, isNull);
      expect(result.errorMessage, isNull);
      expect(result.context?.subscription?.purchaseToken, 'token-1');
      expect(result.context?.subscription?.subscriptionSource,
          PLYSubscriptionSource.googlePlayStore);
      expect(result.context?.subscription?.plan?.vendorId, 'plan_monthly');
      expect(
          result.context?.subscription?.product?.vendorId, 'product_premium');

      Purchasely.removeWebRedemptionListener();
    });

    test('a success can carry a context with no subscription', () async {
      emitOnListen(const EventChannel('purchasely-web-redemption'), [
        {
          'isSuccess': true,
          'replay': false,
          'context': {'subscription': null},
          'errorCode': null,
          'errorMessage': null,
        },
      ]);

      final received = <PLYWebRedemptionResult>[];
      Purchasely.addWebRedemptionListener(received.add);
      await pumpEventQueue();

      expect(received.first.isSuccess, true);
      expect(received.first.context, isNotNull);
      expect(received.first.context?.subscription, isNull);

      Purchasely.removeWebRedemptionListener();
    });

    test('decodes a failure: no context, replay false, code + message',
        () async {
      emitOnListen(const EventChannel('purchasely-web-redemption'), [
        {
          'isSuccess': false,
          'replay': false,
          'context': null,
          'errorCode': 'EXPIRED_REDEMPTION_TOKEN',
          'errorMessage': 'A new link was sent to j***@example.com.',
        },
      ]);

      final received = <PLYWebRedemptionResult>[];
      Purchasely.addWebRedemptionListener(received.add);
      await pumpEventQueue();

      final result = received.single;
      expect(result.isSuccess, false);
      expect(result.context, isNull);
      expect(result.replay, false);
      expect(result.errorCode, 'EXPIRED_REDEMPTION_TOKEN');
      expect(result.errorMessage, 'A new link was sent to j***@example.com.');

      Purchasely.removeWebRedemptionListener();
    });

    test('removeWebRedemptionListener clears the subscription handle',
        () async {
      emitOnListen(const EventChannel('purchasely-web-redemption'), []);

      Purchasely.addWebRedemptionListener((_) {});
      expect(Purchasely.webRedemptions, isNotNull);

      Purchasely.removeWebRedemptionListener();
      expect(Purchasely.webRedemptions, isNull);
    });
  });

  group('redemption analytics events (6.1.0)', () {
    test('decodes REDEMPTION_CONSUMED with its redemption payload', () async {
      emitOnListen(const EventChannel('purchasely-events'), [
        {
          'name': 'REDEMPTION_CONSUMED',
          'properties': {
            'event_name': 'REDEMPTION_CONSUMED',
            'event_created_at': '2026-09-07T10:00:00Z',
            'redemption': {
              'token': 'tok_abc',
              'receipt': {
                'id': 'rcpt_1',
                'validation_status': 'COMPLETED',
              },
              'subscriptions': [
                {
                  'public_id': 'subs_1',
                  'plan_id': 'plan_monthly',
                  'store_type': 'GOOGLE_PLAY_STORE',
                  'subscription_status': 'ACTIVE',
                  'environment': 'PRODUCTION',
                },
              ],
              'purchase_context': {
                'version': 1,
                'source': 'web',
                'sandbox': false,
                'replay': true,
                'custom_attributes': [
                  {'key': 'plan', 'type': 'string', 'value': 'gold'},
                ],
              },
            },
          },
        },
      ]);

      final received = <PLYEvent>[];
      Purchasely.listenToEvents(received.add);
      await pumpEventQueue();

      final redemption = received.single.properties.redemption;
      expect(received.single.name, PLYEventName.REDEMPTION_CONSUMED);
      expect(redemption?.token, 'tok_abc');
      expect(redemption?.receipt?.id, 'rcpt_1');
      expect(redemption?.receipt?.validation_status, 'COMPLETED');
      expect(redemption?.subscriptions?.single.public_id, 'subs_1');
      expect(redemption?.subscriptions?.single.store_type, 'GOOGLE_PLAY_STORE');
      expect(redemption?.purchase_context?.version, 1);
      expect(redemption?.purchase_context?.replay, true);
      expect(redemption?.purchase_context?.built_in_attributes, isNull);
      expect(redemption?.purchase_context?.custom_attributes?.single.value,
          'gold');
      expect(redemption?.error_code, isNull);

      Purchasely.stopListeningToEvents();
    });

    test(
        'decodes REDEMPTION_FAILED: error_code in the payload, the reason in '
        'the top-level error_message', () async {
      emitOnListen(const EventChannel('purchasely-events'), [
        {
          'name': 'REDEMPTION_FAILED',
          'properties': {
            'event_name': 'REDEMPTION_FAILED',
            'event_created_at': '2026-09-07T10:00:00Z',
            'error_message': 'This redemption link has expired.',
            'redemption': {
              'token': 'tok_abc',
              'error_code': 'EXPIRED_REDEMPTION_TOKEN',
            },
          },
        },
      ]);

      final received = <PLYEvent>[];
      Purchasely.listenToEvents(received.add);
      await pumpEventQueue();

      expect(received.single.name, PLYEventName.REDEMPTION_FAILED);
      expect(received.single.properties.error_message,
          'This redemption link has expired.');
      expect(received.single.properties.redemption?.error_code,
          'EXPIRED_REDEMPTION_TOKEN');
      expect(received.single.properties.redemption?.receipt, isNull);
      expect(received.single.properties.redemption?.subscriptions, isNull);

      Purchasely.stopListeningToEvents();
    });

    test('an event without a redemption block reports a null redemption',
        () async {
      emitOnListen(const EventChannel('purchasely-events'), [
        {
          'name': 'APP_STARTED',
          'properties': {
            'event_name': 'APP_STARTED',
            'event_created_at': '2026-09-07T10:00:00Z',
          },
        },
      ]);

      final received = <PLYEvent>[];
      Purchasely.listenToEvents(received.add);
      await pumpEventQueue();

      expect(received.single.properties.redemption, isNull);

      Purchasely.stopListeningToEvents();
    });
  });

  group('setUserAttributeListener', () {
    test('routes set / removed events with mapped type + source', () async {
      emitOnListen(const EventChannel('purchasely-user-attributes'), [
        {
          'event': 'set',
          'key': 'favorite_sport',
          'type': 'STRING',
          'value': 'football',
          'source': 0, // purchasely
        },
        {
          'event': 'removed',
          'key': 'favorite_sport',
          'source': 1, // client
        },
      ]);

      final setCalls = <List<Object?>>[];
      final removedCalls = <List<Object?>>[];
      Purchasely.setUserAttributeListener(
        _RecordingAttributeListener(setCalls, removedCalls),
      );
      await pumpEventQueue();

      expect(setCalls, hasLength(1));
      expect(setCalls.first[0], 'favorite_sport');
      expect(setCalls.first[1], PLYUserAttributeType.string);
      expect(setCalls.first[2], 'football');
      expect(setCalls.first[3], PLYUserAttributeSource.purchasely);

      expect(removedCalls, hasLength(1));
      expect(removedCalls.first[0], 'favorite_sport');
      expect(removedCalls.first[1], PLYUserAttributeSource.client);

      Purchasely.clearUserAttributeListener();
    });
  });
}

class _RecordingAttributeListener extends UserAttributeListener {
  _RecordingAttributeListener(this.setCalls, this.removedCalls);

  final List<List<Object?>> setCalls;
  final List<List<Object?>> removedCalls;

  @override
  void onUserAttributeSet(String key, PLYUserAttributeType type, dynamic value,
      PLYUserAttributeSource source) {
    setCalls.add([key, type, value, source]);
  }

  @override
  void onUserAttributeRemoved(String key, PLYUserAttributeSource source) {
    removedCalls.add([key, source]);
  }
}
