// Unit tests for `lib/src/bridge.dart` — the Dart-side dispatcher that
// wires the v6 façade to the native MethodChannel/EventChannel.
//
// These tests don't need the native plugin: a fake EventChannel binary
// messenger is installed so we can both observe MethodChannel calls and
// inject events from the "native" side.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PurchaselyV6Bridge', () {
    const methodChannelName = 'purchasely';
    const eventChannelName = 'purchasely/v6-events';

    late List<MethodCall> calls;
    late TestDefaultBinaryMessenger messenger;

    /// Helper: emit an EventChannel event as if it were sent by the native
    /// side. EventChannel events flow through the platform-default codec,
    /// targeted at a channel named identically to the EventChannel, on the
    /// reply channel (no name in Flutter < 3 — handled by the test
    /// messenger via handlePlatformMessage on the EventChannel name).
    Future<void> emitEvent(Map<String, Object?> envelope) async {
      const codec = StandardMethodCodec();
      final data = codec.encodeSuccessEnvelope(envelope);
      await messenger.handlePlatformMessage(
        eventChannelName,
        data,
        (_) {},
      );
    }

    setUp(() {
      calls = <MethodCall>[];
      messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

      messenger.setMockMethodCallHandler(
        const MethodChannel(methodChannelName),
        (call) async {
          calls.add(call);
          switch (call.method) {
            case 'v6/preload':
              return <String, Object?>{
                'screenId': 'screen_42',
                'placementId': (call.arguments as Map?)?['source']?['id'],
                'height': 600,
                'type': 0,
                'plans': <Map<String, Object?>>[],
              };
            case 'v6/display':
              return true;
            case 'v6/close':
            case 'v6/back':
              return true;
            case 'v6/registerInterceptor':
            case 'v6/removeInterceptor':
            case 'v6/removeAllInterceptors':
            case 'v6/interceptorResolve':
              return true;
            case 'v6/start':
              return true;
            default:
              return null;
          }
        },
      );

      // Mock the EventChannel so `receiveBroadcastStream()` resolves to a
      // stream we can pump events into via emitEvent().
      messenger.setMockMessageHandler(eventChannelName, (message) async {
        // Flutter calls `listen`/`cancel` on the event channel — return null
        // for either; we'll drive events via handlePlatformMessage instead.
        return null;
      });

      // Force-install the bridge with the default channels so the singletons
      // get wired against the test messenger.
      PurchaselyV6Bridge.debugReset();
      PurchaselyV6Bridge.ensureInstalled();
    });

    tearDown(() {
      PurchaselyV6Bridge.debugReset();
      messenger.setMockMethodCallHandler(
          const MethodChannel(methodChannelName), null);
      messenger.setMockMessageHandler(eventChannelName, null);
    });

    test('preload() invokes v6/preload and returns a Presentation', () async {
      final request = PresentationBuilder.placement('home').build();
      final presentation = await request.preload();

      expect(calls, hasLength(1));
      expect(calls.single.method, 'v6/preload');
      final args = calls.single.arguments as Map;
      expect(args['requestId'], request.requestId);
      expect((args['source'] as Map)['kind'], 'placementId');
      expect((args['source'] as Map)['id'], 'home');

      expect(presentation.screenId, 'screen_42');
      expect(presentation.placementId, 'home');
      expect(presentation.requestId, request.requestId);
    });

    test('display() awaits the onDismissed event before resolving', () async {
      final request = PresentationBuilder.placement('home').build();
      // Pre-register the request via preload so the dispatcher tracks it
      // (display() uses the same requestId).
      await request.preload();
      calls.clear();

      final futureOutcome = request.display(const Transition.modal());
      // The display call should have been invoked.
      // Give the microtask queue a tick so the awaited invokeMethod resolves.
      await Future<void>.delayed(Duration.zero);
      expect(calls.map((c) => c.method).toList(), <String>['v6/display']);

      // Fire the onDismissed event from the "native" side.
      await emitEvent(<String, Object?>{
        'event': 'onDismissed',
        'requestId': request.requestId,
        'outcome': <String, Object?>{
          'purchaseResult': 'purchased',
          'closeReason': null,
        },
      });

      final outcome = await futureOutcome;
      expect(outcome.purchaseResult, PurchaseResult.purchased);
    });

    test('onLoaded event tires the builder callback', () async {
      Presentation? loaded;
      PresentationError? capturedErr;
      final request = PresentationBuilder.placement('home').onLoaded((p, e) {
        loaded = p;
        capturedErr = e;
      }).build();

      // Kick off preload but don't await — we want to emit the event after
      // the request is registered.
      final f = request.preload();
      await Future<void>.delayed(Duration.zero);

      await emitEvent(<String, Object?>{
        'event': 'onLoaded',
        'requestId': request.requestId,
        'presentation': <String, Object?>{
          'screenId': 'home_screen',
          'placementId': 'home',
          'height': 800,
          'type': 0,
          'plans': <Map<String, Object?>>[],
        },
      });

      await f;
      expect(loaded, isNotNull);
      expect(loaded!.screenId, 'home_screen');
      expect(capturedErr, isNull);
    });

    test('display() with a Transition forwards the wire payload', () async {
      final request = PresentationBuilder.screen('paywall_42').build();
      // Don't await — just check the MethodCall arguments.
      // ignore: unawaited_futures
      request.display(const Transition.modal(dismissible: false));
      await Future<void>.delayed(Duration.zero);

      final displayCall = calls.firstWhere((c) => c.method == 'v6/display');
      final args = displayCall.arguments as Map;
      expect((args['source'] as Map)['kind'], 'screenId');
      expect((args['source'] as Map)['id'], 'paywall_42');
      expect((args['transition'] as Map)['type'], 'modal');
      expect((args['transition'] as Map)['dismissible'], false);
    });
  });
}
