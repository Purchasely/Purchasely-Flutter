// Unit tests for `lib/src/bridge.dart` — the Dart-side dispatcher that
// wires the presentation façade to the native MethodChannel/EventChannel.
//
// These tests don't need the native plugin: a fake EventChannel binary
// messenger is installed so we can both observe MethodChannel calls and
// inject events from the "native" side.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PurchaselyBridge', () {
    const methodChannelName = 'purchasely';
    const eventChannelName = 'purchasely-presentation-events';

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
            case 'preload':
              return <String, Object?>{
                'screenId': 'screen_42',
                'placementId': (call.arguments as Map?)?['source']?['id'],
                'height': 600,
                'type': 0,
                'plans': <Map<String, Object?>>[],
              };
            case 'display':
              return true;
            case 'close':
            case 'back':
              return true;
            case 'registerInterceptor':
            case 'removeInterceptor':
            case 'removeAllInterceptors':
            case 'interceptorResolve':
              return true;
            case 'start':
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
      PurchaselyBridge.debugReset();
      PurchaselyBridge.ensureInstalled();
    });

    tearDown(() {
      PurchaselyBridge.debugReset();
      messenger.setMockMethodCallHandler(
          const MethodChannel(methodChannelName), null);
      messenger.setMockMessageHandler(eventChannelName, null);
    });

    test('preload() invokes preload and returns a Presentation', () async {
      final request = PresentationBuilder.placement('home').build();
      final presentation = await request.preload();

      expect(calls, hasLength(1));
      expect(calls.single.method, 'preload');
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
      expect(calls.map((c) => c.method).toList(), <String>['display']);

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

    test('onLoaded event fires the builder callback', () async {
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
      final request = PresentationBuilder.screen('screen_42').build();
      // Don't await — just check the MethodCall arguments.
      // ignore: unawaited_futures
      request.display(const Transition.modal(dismissible: false));
      await Future<void>.delayed(Duration.zero);

      final displayCall = calls.firstWhere((c) => c.method == 'display');
      final args = displayCall.arguments as Map;
      expect((args['source'] as Map)['kind'], 'screenId');
      expect((args['source'] as Map)['id'], 'screen_42');
      expect((args['transition'] as Map)['type'], 'modal');
      expect((args['transition'] as Map)['dismissible'], false);
    });

    test('display() outcome carries 5 fields including closeReason (P0.2)',
        () async {
      final request = PresentationBuilder.placement('home').build();
      await request.preload();
      calls.clear();

      // ignore: unawaited_futures
      final futureOutcome = request.display(const Transition.modal());
      await Future<void>.delayed(Duration.zero);

      await emitEvent(<String, Object?>{
        'event': 'onDismissed',
        'requestId': request.requestId,
        'outcome': <String, Object?>{
          'purchaseResult': 'purchased',
          'closeReason': 'button',
          'plan': <String, Object?>{'vendorId': 'monthly'},
        },
      });

      final outcome = await futureOutcome;
      expect(outcome.purchaseResult, PurchaseResult.purchased);
      expect(outcome.closeReason, CloseReason.button);
      expect(outcome.error, isNull);
      expect(outcome.plan, isNotNull);
      expect(outcome.presentation, isNotNull);
    });

    test('display() outcome carries error and null closeReason on failure',
        () async {
      final request = PresentationBuilder.placement('home').build();
      await request.preload();
      calls.clear();

      // ignore: unawaited_futures
      final futureOutcome = request.display(const Transition.modal());
      await Future<void>.delayed(Duration.zero);

      await emitEvent(<String, Object?>{
        'event': 'onDismissed',
        'requestId': request.requestId,
        'outcome': <String, Object?>{
          'error': <String, Object?>{
            'code': 'NETWORK',
            'message': 'offline',
          },
        },
      });

      final outcome = await futureOutcome;
      expect(outcome.error, isNotNull);
      expect(outcome.error!.message, 'offline');
      // P0.2 mutual exclusion: error ⇒ closeReason null
      expect(outcome.closeReason, isNull);
    });

    test('re-display() after dismiss resolves the second future', () async {
      // Regression: after a dismiss the request entry is dropped, so a second
      // display() on the same Presentation handle must re-register the entry —
      // otherwise its dismiss completer is never stored and the future hangs.
      final request = PresentationBuilder.placement('home').build();
      final presentation = await request.preload();
      calls.clear();

      // First display → dismiss.
      // ignore: unawaited_futures
      final firstOutcome = presentation.display(const Transition.modal());
      await Future<void>.delayed(Duration.zero);
      await emitEvent(<String, Object?>{
        'event': 'onDismissed',
        'requestId': presentation.requestId,
        'outcome': <String, Object?>{'purchaseResult': 'cancelled'},
      });
      expect((await firstOutcome).purchaseResult, PurchaseResult.cancelled);

      // Second display on the same handle → dismiss. The future must complete.
      // ignore: unawaited_futures
      final secondOutcome = presentation.display(const Transition.modal());
      await Future<void>.delayed(Duration.zero);
      expect(calls.where((c) => c.method == 'display'), hasLength(2));
      await emitEvent(<String, Object?>{
        'event': 'onDismissed',
        'requestId': presentation.requestId,
        'outcome': <String, Object?>{'purchaseResult': 'purchased'},
      });
      expect((await secondOutcome).purchaseResult, PurchaseResult.purchased);
    });

    test('onCloseRequested fires the builder callback', () async {
      var fired = false;
      final request =
          PresentationBuilder.placement('home').onCloseRequested(() {
        fired = true;
      }).build();

      // ignore: unawaited_futures
      request.preload();
      await Future<void>.delayed(Duration.zero);

      await emitEvent(<String, Object?>{
        'event': 'onCloseRequested',
        'requestId': request.requestId,
      });

      expect(fired, true);
    });

    test('interceptor lifecycle: register → trigger → resolve', () async {
      InterceptorInfo? capturedInfo;
      ActionPayload? capturedPayload;
      await PurchaselyBridge.ensureInstalled().registerInterceptor(
        PresentationActionKind.purchase,
        (info, payload) async {
          capturedInfo = info;
          capturedPayload = payload;
          return InterceptResult.success;
        },
      );

      // The register call must have hit the MethodChannel.
      final registerCall =
          calls.firstWhere((c) => c.method == 'registerInterceptor');
      expect((registerCall.arguments as Map)['kind'], 'purchase');

      // Fire a triggered event from "native".
      await emitEvent(<String, Object?>{
        'event': 'interceptorTriggered',
        'requestId': 'cb-1',
        'kind': 'purchase',
        'info': <String, Object?>{'contentId': 'c1'},
        'payload': <String, Object?>{
          'plan': <String, Object?>{'vendorId': 'monthly'},
        },
      });

      // Let the async handler run.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(capturedInfo, isNotNull);
      expect(capturedInfo!.contentId, 'c1');
      expect(capturedPayload, isA<PurchasePayload>());

      // The bridge must have posted the result back via interceptorResolve.
      final resolveCall =
          calls.firstWhere((c) => c.method == 'interceptorResolve');
      final args = resolveCall.arguments as Map;
      expect(args['invocationId'], 'cb-1');
      expect(args['result'], 'success');
    });

    test('removeInterceptor unregisters the kind on the native side', () async {
      await PurchaselyBridge.ensureInstalled().registerInterceptor(
        PresentationActionKind.login,
        (_, __) async => InterceptResult.success,
      );
      calls.clear();

      await PurchaselyBridge.ensureInstalled()
          .removeInterceptor(PresentationActionKind.login);

      final removeCall =
          calls.firstWhere((c) => c.method == 'removeInterceptor');
      expect((removeCall.arguments as Map)['kind'], 'login');
    });

    test('Purchasely.interceptAction registers via the same channel call',
        () async {
      await Purchasely.interceptAction(
        PresentationActionKind.navigate,
        (_, __) async => InterceptResult.notHandled,
      );

      final registerCall =
          calls.firstWhere((c) => c.method == 'registerInterceptor');
      expect((registerCall.arguments as Map)['kind'], 'navigate');
    });

    test('start() forwards the exact wire contract the native side reads',
        () async {
      // Guards the MethodChannel `start` payload. This regressed before and
      // was not caught because tests mocked start→true without asserting args.
      final ok = await PurchaselyBuilder.apiKey('K')
          .appUserId('U')
          .runningMode(RunningMode.full)
          .logLevel(LogLevel.warn)
          .stores([PLYStore.google]).start();
      expect(ok, isTrue);

      final startCall = calls.firstWhere((c) => c.method == 'start');
      final args = startCall.arguments as Map;
      expect(args['apiKey'], 'K');
      expect(args['appUserId'], 'U');
      expect(args['runningMode'], 'full');
      expect(args['logLevel'], 'warn');
      expect(args['stores'], <String>['google']);
      // The native side also reads these keys — they must be present.
      expect(args.containsKey('allowCampaigns'), isTrue);
      expect(args.containsKey('storekitVersion'), isTrue);
    });
  });
}
