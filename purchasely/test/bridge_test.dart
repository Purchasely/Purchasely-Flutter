// Unit tests for `lib/src/bridge.dart` — the Dart-side dispatcher that
// wires the presentation façade to the native MethodChannel/EventChannel.
//
// These tests don't need the native plugin: a fake EventChannel binary
// messenger is installed so we can both observe MethodChannel calls and
// inject events from the "native" side.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';
// PurchaselyBridge (ensureInstalled/debugReset) is a test-only entry point —
// removed from the public barrel export (PAR-13) — import src/ directly.
import 'package:purchasely_flutter/src/bridge.dart';

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
            case 'setDefaultPresentationDismissHandler':
            case 'removeDefaultPresentationDismissHandler':
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

    test('preload() invokes preload and returns a PLYPresentation', () async {
      final request = PLYPresentationBuilder.placement('home').build();
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
      final request = PLYPresentationBuilder.placement('home').build();
      // Pre-register the request via preload so the dispatcher tracks it
      // (display() uses the same requestId).
      await request.preload();
      calls.clear();

      final futureOutcome = request.display(const PLYTransition.modal());
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
      expect(outcome.purchaseResult, PLYPurchaseResult.purchased);
    });

    test('onLoaded event fires the builder callback', () async {
      PLYPresentation? loaded;
      PLYPresentationError? capturedErr;
      final request = PLYPresentationBuilder.placement('home').onLoaded((p, e) {
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

    test('display() with a PLYTransition forwards the wire payload', () async {
      final request = PLYPresentationBuilder.screen('screen_42').build();
      // Don't await — just check the MethodCall arguments.
      // ignore: unawaited_futures
      request.display(const PLYTransition.modal(dismissible: false));
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
      final request = PLYPresentationBuilder.placement('home').build();
      await request.preload();
      calls.clear();

      // ignore: unawaited_futures
      final futureOutcome = request.display(const PLYTransition.modal());
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
      expect(outcome.purchaseResult, PLYPurchaseResult.purchased);
      expect(outcome.closeReason, PLYCloseReason.button);
      expect(outcome.error, isNull);
      expect(outcome.plan, isA<PLYPlan>());
      expect(outcome.plan!.vendorId, 'monthly');
      expect(outcome.presentation, isNotNull);
    });

    test('display() outcome plan is a fully-typed PLYPlan', () async {
      final request = PLYPresentationBuilder.placement('home').build();
      await request.preload();
      calls.clear();

      // ignore: unawaited_futures
      final futureOutcome = request.display(const PLYTransition.modal());
      await Future<void>.delayed(Duration.zero);

      await emitEvent(<String, Object?>{
        'event': 'onDismissed',
        'requestId': request.requestId,
        'outcome': <String, Object?>{
          'purchaseResult': 'purchased',
          'closeReason': null,
          'plan': <String, Object?>{
            'vendorId': 'yearly',
            'productId': 'yearly-product',
            'basePlanId': 'yearly-base',
            'amount': 59.99,
            'currencyCode': 'USD',
            'hasFreeTrial': true,
          },
        },
      });

      final outcome = await futureOutcome;
      expect(
        outcome.plan,
        isA<PLYPlan>()
            .having((p) => p.vendorId, 'vendorId', 'yearly')
            .having((p) => p.productId, 'productId', 'yearly-product')
            .having((p) => p.basePlanId, 'basePlanId', 'yearly-base')
            .having((p) => p.amount, 'amount', 59.99)
            .having((p) => p.currencyCode, 'currencyCode', 'USD')
            .having((p) => p.hasFreeTrial, 'hasFreeTrial', true),
      );
    });

    test('display() outcome carries error and null closeReason on failure',
        () async {
      final request = PLYPresentationBuilder.placement('home').build();
      await request.preload();
      calls.clear();

      // ignore: unawaited_futures
      final futureOutcome = request.display(const PLYTransition.modal());
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

    test('default presentation dismiss handler receives rich outcome',
        () async {
      PLYPresentationOutcome? captured;

      await Purchasely.setDefaultPresentationDismissHandler((outcome) {
        captured = outcome;
      });

      final registerCall = calls.firstWhere(
          (c) => c.method == 'setDefaultPresentationDismissHandler');
      expect(registerCall.arguments, isNull);

      await emitEvent(<String, Object?>{
        'event': 'onDefaultPresentationDismissed',
        'outcome': <String, Object?>{
          'purchaseResult': 'restored',
          // iOS serializes interactiveDismiss as "back_system" (rawDescription);
          // Android sends BACK_SYSTEM.value == "back_system".
          'closeReason': 'back_system',
          'plan': <String, Object?>{'vendorId': 'monthly'},
          'presentation': <String, Object?>{
            'screenId': 'campaign_screen',
            'placementId': 'campaign_placement',
            'campaignId': 'cmp_123',
            'height': 720,
            'type': 0,
            'plans': <Map<String, Object?>>[],
          },
        },
      });

      expect(captured, isNotNull);
      expect(captured!.purchaseResult, PLYPurchaseResult.restored);
      expect(captured!.closeReason, PLYCloseReason.backSystem);
      expect(captured!.plan?.vendorId, 'monthly');
      expect(captured!.presentation, isNotNull);
      expect(captured!.presentation!.screenId, 'campaign_screen');
      expect(captured!.presentation!.campaignId, 'cmp_123');
    });

    test(
        'removeDefaultPresentationDismissHandler invokes the native verb and '
        'nullifies the handler', () async {
      PLYPresentationOutcome? captured;

      await Purchasely.setDefaultPresentationDismissHandler((outcome) {
        captured = outcome;
      });

      await Purchasely.removeDefaultPresentationDismissHandler();

      expect(
        calls.any((c) => c.method == 'removeDefaultPresentationDismissHandler'),
        isTrue,
      );

      // A subsequent default dismiss event must be ignored now that the handler
      // was removed.
      await emitEvent(<String, Object?>{
        'event': 'onDefaultPresentationDismissed',
        'outcome': <String, Object?>{'purchaseResult': 'purchased'},
      });

      expect(captured, isNull,
          reason: 'removed handler must not receive further outcomes');
    });

    test(
        'display() dismissal falls back to the default handler when no '
        'onDismissed is set', () async {
      PLYPresentationOutcome? viaDefault;
      await Purchasely.setDefaultPresentationDismissHandler((outcome) {
        viaDefault = outcome;
      });

      // No onDismissed on the builder → the dismissal isn't handled locally.
      final request = PLYPresentationBuilder.placement('home').build();
      // Fire-and-forget: display() is intentionally not awaited.
      // ignore: unawaited_futures
      request.display(const PLYTransition.modal());
      await Future<void>.delayed(Duration.zero);

      await emitEvent(<String, Object?>{
        'event': 'onDismissed',
        'requestId': request.requestId,
        'outcome': <String, Object?>{
          'purchaseResult': 'purchased',
          'closeReason': 'button',
        },
      });

      expect(viaDefault, isNotNull,
          reason: 'default handler should catch the unhandled dismissal');
      expect(viaDefault!.purchaseResult, PLYPurchaseResult.purchased);
      expect(viaDefault!.closeReason, PLYCloseReason.button);
    });

    test(
        'display() dismissal uses the local onDismissed and skips the default '
        'handler when both are set', () async {
      PLYPresentationOutcome? viaLocal;
      PLYPresentationOutcome? viaDefault;
      await Purchasely.setDefaultPresentationDismissHandler((outcome) {
        viaDefault = outcome;
      });

      final request = PLYPresentationBuilder.placement('home')
          .onDismissed((outcome) => viaLocal = outcome)
          .build();
      // ignore: unawaited_futures
      request.display(const PLYTransition.modal());
      await Future<void>.delayed(Duration.zero);

      await emitEvent(<String, Object?>{
        'event': 'onDismissed',
        'requestId': request.requestId,
        'outcome': <String, Object?>{
          'purchaseResult': 'cancelled',
          'closeReason': 'button',
        },
      });

      expect(viaLocal, isNotNull);
      expect(viaLocal!.purchaseResult, PLYPurchaseResult.cancelled);
      // The local handler took precedence; the default handler must NOT fire.
      expect(viaDefault, isNull);
    });

    test(
        'await display() returns the outcome to the awaiting caller + local '
        'onDismissed, and the default handler stays silent', () async {
      PLYPresentationOutcome? viaLocal;
      PLYPresentationOutcome? viaDefault;
      await Purchasely.setDefaultPresentationDismissHandler((outcome) {
        viaDefault = outcome;
      });

      final request = PLYPresentationBuilder.placement('home')
          .onDismissed((outcome) => viaLocal = outcome)
          .build();
      await request.preload();
      calls.clear();

      final futureOutcome = request.display(const PLYTransition.modal());
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
      // The awaited display() future resolves with the outcome (local consume).
      expect(outcome.purchaseResult, PLYPurchaseResult.purchased);
      expect(outcome.closeReason, PLYCloseReason.button);
      expect(outcome.plan?.vendorId, 'monthly');
      // The local onDismissed also received it…
      expect(viaLocal, isNotNull);
      expect(viaLocal!.purchaseResult, PLYPurchaseResult.purchased);
      // …and the default handler must NOT fire.
      expect(viaDefault, isNull);
    });

    test('re-display() after dismiss resolves the second future', () async {
      // Regression: after a dismiss the request entry is dropped, so a second
      // display() on the same PLYPresentation handle must re-register the entry —
      // otherwise its dismiss completer is never stored and the future hangs.
      final request = PLYPresentationBuilder.placement('home').build();
      final presentation = await request.preload();
      calls.clear();

      // First display → dismiss.
      // ignore: unawaited_futures
      final firstOutcome = presentation.display(const PLYTransition.modal());
      await Future<void>.delayed(Duration.zero);
      await emitEvent(<String, Object?>{
        'event': 'onDismissed',
        'requestId': presentation.requestId,
        'outcome': <String, Object?>{'purchaseResult': 'cancelled'},
      });
      expect((await firstOutcome).purchaseResult, PLYPurchaseResult.cancelled);

      // Second display on the same handle → dismiss. The future must complete.
      // ignore: unawaited_futures
      final secondOutcome = presentation.display(const PLYTransition.modal());
      await Future<void>.delayed(Duration.zero);
      expect(calls.where((c) => c.method == 'display'), hasLength(2));
      await emitEvent(<String, Object?>{
        'event': 'onDismissed',
        'requestId': presentation.requestId,
        'outcome': <String, Object?>{'purchaseResult': 'purchased'},
      });
      expect((await secondOutcome).purchaseResult, PLYPurchaseResult.purchased);
    });

    test('re-display() resends the source so a native rebuild keeps it',
        () async {
      // Regression (v6 audit M2): after a dismiss the native side may have to
      // rebuild the request from the display args. A handle-based display()
      // must therefore carry the original source, not just the requestId —
      // otherwise the rebuild falls back to the default source.
      final request = PLYPresentationBuilder.placement('home').build();
      final presentation = await request.preload();
      calls.clear();

      // ignore: unawaited_futures
      final outcome = presentation.display(const PLYTransition.modal());
      await Future<void>.delayed(Duration.zero);

      final displayCall = calls.firstWhere((c) => c.method == 'display');
      final args = displayCall.arguments as Map;
      expect(args['requestId'], presentation.requestId);
      expect((args['source'] as Map)['kind'], 'placementId');
      expect((args['source'] as Map)['id'], 'home');

      await emitEvent(<String, Object?>{
        'event': 'onDismissed',
        'requestId': presentation.requestId,
        'outcome': <String, Object?>{'purchaseResult': 'cancelled'},
      });
      await outcome;
    });

    test('onCloseRequested fires the builder callback', () async {
      var fired = false;
      final request =
          PLYPresentationBuilder.placement('home').onCloseRequested(() {
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
      PLYInterceptorInfo? capturedInfo;
      PLYActionPayload? capturedPayload;
      await PurchaselyBridge.ensureInstalled().registerInterceptor(
        PLYPresentationActionKind.purchase,
        (info, payload) async {
          capturedInfo = info;
          capturedPayload = payload;
          return PLYInterceptResult.success;
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
          'plan': <String, Object?>{
            'vendorId': 'monthly',
            'productId': 'monthly-product',
            'basePlanId': 'monthly-base',
          },
          'subscriptionOffer': <String, Object?>{
            'subscriptionId': 'monthly-subscription',
            'basePlanId': 'monthly-base',
            'offerToken': 'intro-token',
            'offerId': 'intro',
          },
          'offer': <String, Object?>{
            'vendorId': 'promo',
            'storeOfferId': 'store-promo',
            'publicId': 'public-promo',
          },
        },
      });

      // Let the async handler run.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(capturedInfo, isNotNull);
      expect(capturedInfo!.contentId, 'c1');
      expect(capturedPayload, isA<PLYPurchasePayload>());
      final purchase = capturedPayload as PLYPurchasePayload;
      expect(
        purchase.plan,
        isA<PLYPlan>()
            .having((plan) => plan.vendorId, 'vendorId', 'monthly')
            .having((plan) => plan.productId, 'productId', 'monthly-product')
            .having((plan) => plan.basePlanId, 'basePlanId', 'monthly-base'),
      );
      expect(
        purchase.subscriptionOffer,
        isA<PLYSubscriptionOffer>()
            .having((offer) => offer.subscriptionId, 'subscriptionId',
                'monthly-subscription')
            .having((offer) => offer.basePlanId, 'basePlanId', 'monthly-base')
            .having((offer) => offer.offerToken, 'offerToken', 'intro-token')
            .having((offer) => offer.offerId, 'offerId', 'intro'),
      );
      expect(
        purchase.offer,
        isA<PLYPromoOffer>()
            .having((offer) => offer.vendorId, 'vendorId', 'promo')
            .having(
                (offer) => offer.storeOfferId, 'storeOfferId', 'store-promo')
            .having((offer) => offer.publicId, 'publicId', 'public-promo'),
      );

      // The bridge must have posted the result back via interceptorResolve.
      final resolveCall =
          calls.firstWhere((c) => c.method == 'interceptorResolve');
      final args = resolveCall.arguments as Map;
      expect(args['invocationId'], 'cb-1');
      expect(args['result'], 'success');
    });

    test('removeActionInterceptor unregisters the kind on the native side',
        () async {
      await PurchaselyBridge.ensureInstalled().registerInterceptor(
        PLYPresentationActionKind.login,
        (_, __) async => PLYInterceptResult.success,
      );
      calls.clear();

      await PurchaselyBridge.ensureInstalled()
          .removeActionInterceptor(PLYPresentationActionKind.login);

      // Wire verb stays `removeInterceptor` (native dispatch unchanged).
      final removeCall =
          calls.firstWhere((c) => c.method == 'removeInterceptor');
      expect((removeCall.arguments as Map)['kind'], 'login');
    });

    test('removeAllActionInterceptors clears all on the native side', () async {
      await PurchaselyBridge.ensureInstalled().registerInterceptor(
        PLYPresentationActionKind.purchase,
        (_, __) async => PLYInterceptResult.success,
      );
      calls.clear();

      await PurchaselyBridge.ensureInstalled().removeAllActionInterceptors();

      // Wire verb stays `removeAllInterceptors` (native dispatch unchanged).
      expect(
        calls.where((c) => c.method == 'removeAllInterceptors'),
        hasLength(1),
      );
    });

    test('Purchasely.interceptAction registers via the same channel call',
        () async {
      await Purchasely.interceptAction(
        PLYPresentationActionKind.navigate,
        (_, __) async => PLYInterceptResult.notHandled,
      );

      final registerCall =
          calls.firstWhere((c) => c.method == 'registerInterceptor');
      expect((registerCall.arguments as Map)['kind'], 'navigate');
    });

    test('onPresented event fires the builder callback', () async {
      PLYPresentation? presented;
      PLYPresentationError? capturedErr;
      final request =
          PLYPresentationBuilder.placement('home').onPresented((p, e) {
        presented = p;
        capturedErr = e;
      }).build();

      // ignore: unawaited_futures
      request.preload();
      await Future<void>.delayed(Duration.zero);

      await emitEvent(<String, Object?>{
        'event': 'onPresented',
        'requestId': request.requestId,
        'presentation': <String, Object?>{
          'screenId': 'home_screen',
          'placementId': 'home',
          'height': 800,
          'type': 0,
          'plans': <Map<String, Object?>>[],
        },
      });

      expect(presented, isNotNull);
      expect(presented!.screenId, 'home_screen');
      expect(capturedErr, isNull);
    });

    test(
        'onLoaded failure (no presentation) falls back to onPresented(null, error)',
        () async {
      PLYPresentation? loaded;
      PLYPresentation? presented;
      PLYPresentationError? presentedErr;
      final request = PLYPresentationBuilder.placement('home')
          .onLoaded((p, e) => loaded = p)
          .onPresented((p, e) {
        presented = p;
        presentedErr = e;
      }).build();

      // ignore: unawaited_futures
      request.preload();
      await Future<void>.delayed(Duration.zero);

      await emitEvent(<String, Object?>{
        'event': 'onLoaded',
        'requestId': request.requestId,
        'error': <String, Object?>{'code': 'NOT_FOUND', 'message': 'no screen'},
      });

      expect(loaded, isNull,
          reason: 'onLoaded itself must not fire without a presentation');
      expect(presented, isNull);
      expect(presentedErr, isNotNull);
      expect(presentedErr!.code, 'NOT_FOUND');
    });

    test('close() invokes the native verb with the requestId', () async {
      final request = PLYPresentationBuilder.placement('home').build();
      final presentation = await request.preload();
      calls.clear();

      await presentation.close();

      final closeCall = calls.firstWhere((c) => c.method == 'close');
      expect((closeCall.arguments as Map)['requestId'], request.requestId);
    });

    test('back() invokes the native verb with the requestId', () async {
      final request = PLYPresentationBuilder.placement('home').build();
      final presentation = await request.preload();
      calls.clear();

      await presentation.back();

      final backCall = calls.firstWhere((c) => c.method == 'back');
      expect((backCall.arguments as Map)['requestId'], request.requestId);
    });

    test(
        'FuturePresentationDisplay sugar: preload().display() chains and '
        'resolves the outcome', () async {
      final request = PLYPresentationBuilder.placement('home').build();

      final futureOutcome =
          request.preload().display(const PLYTransition.modal());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
          calls.map((c) => c.method),
          containsAllInOrder(<String>[
            'preload',
            'display',
          ]));

      await emitEvent(<String, Object?>{
        'event': 'onDismissed',
        'requestId': request.requestId,
        'outcome': <String, Object?>{'purchaseResult': 'purchased'},
      });

      final outcome = await futureOutcome;
      expect(outcome.purchaseResult, PLYPurchaseResult.purchased);
    });

    test('start() forwards the exact wire contract the native side reads',
        () async {
      // Guards the MethodChannel `start` payload. This regressed before and
      // was not caught because tests mocked start→true without asserting args.
      final ok = await Purchasely.apiKey('K')
          .appUserId('U')
          .runningMode(PLYRunningMode.full)
          .logLevel(PLYLogLevel.warn)
          .allowDeeplink(true)
          .allowCampaigns(false)
          .stores([PLYStore.google]).start();
      expect(ok, isTrue);

      final startCall = calls.firstWhere((c) => c.method == 'start');
      final args = startCall.arguments as Map;
      expect(args['apiKey'], 'K');
      expect(args['appUserId'], 'U');
      expect(args['runningMode'], 'full');
      expect(args['logLevel'], 'warn');
      expect(args['stores'], <String>['google']);
      // The native side also reads these keys when the builder sets them.
      expect(args['allowDeeplink'], true);
      expect(args['allowCampaigns'], false);
      expect(args.containsKey('storekitVersion'), isTrue);
    });
  });
}
