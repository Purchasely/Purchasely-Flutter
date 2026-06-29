// Unit tests for the three EventChannel-backed public callbacks:
//   * Purchasely.listenToEvents        (channel 'purchasely-events')
//   * Purchasely.listenToPurchases     (channel 'purchasely-purchases')
//   * Purchasely.setUserAttributeListener (channel 'purchasely-user-attributes')
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

      Purchasely.stopListeningToEvents();
    });

    test('falls back to APP_CONFIGURED for an unknown event name', () async {
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
      expect(received!.name, PLYEventName.APP_CONFIGURED);

      Purchasely.stopListeningToEvents();
    });
  });

  group('listenToPurchases', () {
    test('forwards the native purchase event to the callback', () async {
      emitOnListen(const EventChannel('purchasely-purchases'), ['purchased']);

      final received = <dynamic>[];
      Purchasely.listenToPurchases(received.add);
      await pumpEventQueue();

      expect(received, ['purchased']);

      Purchasely.stopListeningToPurchases();
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
