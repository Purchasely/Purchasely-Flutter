// Bridge-contract tests for the 6.1.0 start options.
//
// SCOPE, and its limit: these assert what crosses into the native `start` call
// — the exact key/value shape of the `start` argument map, and the order in
// which the Dart layer talks to the platform. They do NOT assert that a native
// SDK's resolved API host actually changed, or that a real redemption was
// delivered: that is SDK-internal state a Dart test harness cannot observe.
// The native unit suites cover each bridge's own decoding, and
// `example/integration_test/redemption_proxy_identity_test.dart` covers the
// live path.
//
// The three proxy states get the most attention on purpose. Collapsing
// "cleared" into "never called" is the defect the React Native bridge shipped
// with, and both collapses are silent.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';
import 'package:purchasely_flutter/src/bridge.dart' show PurchaselyBridge;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('purchasely');
  const redemptionChannel = EventChannel('purchasely-web-redemption');

  /// Everything the Dart layer sends to the platform, in order. The redemption
  /// EventChannel's `listen` and the MethodChannel's `start` land in the same
  /// list so a test can assert their relative order.
  final platformLog = <String>[];
  final methodCalls = <MethodCall>[];

  setUp(() {
    platformLog.clear();
    methodCalls.clear();

    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      platformLog.add(call.method);
      methodCalls.add(call);
      return true;
    });
    messenger.setMockStreamHandler(
      redemptionChannel,
      MockStreamHandler.inline(onListen: (arguments, sink) {
        platformLog.add('web-redemption:listen');
      }),
    );
    PurchaselyBridge.debugReset();
  });

  tearDown(() {
    Purchasely.removeWebRedemptionListener();
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockStreamHandler(redemptionChannel, null);
    PurchaselyBridge.debugReset();
  });

  MethodCall startCall() => methodCalls.firstWhere((c) => c.method == 'start');

  // ---------------------------------------------------------------------------
  // proxy: three states
  // ---------------------------------------------------------------------------

  group('proxy — the three states are distinct on the wire', () {
    test('set: the key carries the url', () async {
      await Purchasely.apiKey('k').proxy('https://svc.purchasely.io').start();

      expect(startCall().arguments.containsKey('proxy'), isTrue);
      expect(startCall().arguments['proxy'], 'https://svc.purchasely.io');
    });

    test('cleared: the key is PRESENT and its value is null', () async {
      await Purchasely.apiKey('k').proxy(null).start();

      // Both halves matter. A missing key would read as "never called" on the
      // native side and skip the clear; a non-null value would set a proxy.
      expect(startCall().arguments.containsKey('proxy'), isTrue,
          reason: 'proxy(null) must reach native as an explicit clear');
      expect(startCall().arguments['proxy'], isNull);
    });

    test('never called: the key is ABSENT', () async {
      await Purchasely.apiKey('k').start();

      expect(startCall().arguments.containsKey('proxy'), isFalse,
          reason: 'an absent key leaves the native setting untouched; a '
              'present null would clear it on every start');
    });

    test('never-called and cleared produce different payloads', () async {
      await Purchasely.apiKey('k').start();
      final never = Map<Object?, Object?>.from(
          startCall().arguments as Map<Object?, Object?>);

      methodCalls.clear();
      PurchaselyBridge.debugReset();
      await Purchasely.apiKey('k').proxy(null).start();
      final cleared = Map<Object?, Object?>.from(
          startCall().arguments as Map<Object?, Object?>);

      // Asserted against each other, not just against a literal: this is the
      // exact pair a bridge that drops nulls renders identical.
      expect(cleared, isNot(equals(never)));
      expect(never.containsKey('proxy'), isFalse);
      expect(cleared.containsKey('proxy'), isTrue);
      expect(cleared['proxy'], isNull);
    });

    test('the last call wins: set then clear ends cleared', () async {
      await Purchasely.apiKey('k')
          .proxy('https://svc.purchasely.io')
          .proxy(null)
          .start();

      expect(startCall().arguments.containsKey('proxy'), isTrue);
      expect(startCall().arguments['proxy'], isNull);
    });

    test('the last call wins: clear then set ends set', () async {
      await Purchasely.apiKey('k')
          .proxy(null)
          .proxy('https://svc.purchasely.io')
          .start();

      expect(startCall().arguments['proxy'], 'https://svc.purchasely.io');
    });

    test('the bridge does not validate the scheme or the host', () async {
      // Native refuses a non-https value, logs it and keeps the production
      // host. The Dart layer must forward it verbatim rather than pre-judge it,
      // so the two platforms stay the single source of truth on what is legal.
      await Purchasely.apiKey('k').proxy('http://insecure.example').start();

      expect(startCall().arguments['proxy'], 'http://insecure.example');
    });
  });

  // ---------------------------------------------------------------------------
  // anonymousUserId
  // ---------------------------------------------------------------------------

  group('anonymousUserId', () {
    const uuid = '3f2504e0-4f89-11d3-9a0c-0305e82c3301';

    test('forwards the id and an explicit override', () async {
      await Purchasely.apiKey('k')
          .anonymousUserId(uuid, override: true)
          .start();

      expect(startCall().arguments['anonymousUserId'], uuid);
      expect(startCall().arguments['anonymousUserIdOverride'], isTrue);
    });

    test('override defaults to false', () async {
      await Purchasely.apiKey('k').anonymousUserId(uuid).start();

      expect(startCall().arguments['anonymousUserIdOverride'], isFalse);
    });

    test('the override flag is absent when no id is set', () async {
      await Purchasely.apiKey('k').start();

      expect(startCall().arguments.containsKey('anonymousUserId'), isFalse);
      expect(
          startCall().arguments.containsKey('anonymousUserIdOverride'), isFalse,
          reason: 'an override flag without an id would be meaningless');
    });

    test('a non-canonical string still crosses; each bridge rejects it',
        () async {
      // Dart has no UUID type, so validation lives in the two native bridges,
      // which log and skip. The Dart layer must not silently drop the value:
      // that would hide the typo instead of surfacing it in the device log.
      await Purchasely.apiKey('k').anonymousUserId('1-2-3-4-5').start();

      expect(startCall().arguments['anonymousUserId'], '1-2-3-4-5');
    });

    test('the last call wins', () async {
      await Purchasely.apiKey('k')
          .anonymousUserId(uuid)
          .anonymousUserId('11111111-2222-3333-4444-555555555555',
              override: true)
          .start();

      expect(startCall().arguments['anonymousUserId'],
          '11111111-2222-3333-4444-555555555555');
      expect(startCall().arguments['anonymousUserIdOverride'], isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // appHandlesRedemptionAlert + the chain listener
  // ---------------------------------------------------------------------------

  group('webRedemptionListener on the start chain', () {
    test('the subscription happens BEFORE the native start call', () async {
      await Purchasely.apiKey('k').webRedemptionListener((_) {}).start();

      // The whole point of putting the listener on the chain: a redemption can
      // settle during start(), so the EventChannel must already be listening
      // when the native start runs.
      expect(platformLog, ['web-redemption:listen', 'start']);
    });

    test('the subscription exists before start is even invoked', () async {
      final builder = Purchasely.apiKey('k').webRedemptionListener((_) {});

      // Synchronous proof, independent of platform-message ordering.
      expect(Purchasely.webRedemptions, isNotNull);
      expect(methodCalls.where((c) => c.method == 'start'), isEmpty);

      await builder.start();
      expect(methodCalls.where((c) => c.method == 'start'), hasLength(1));
    });

    test('the optional second argument sets appHandlesRedemptionAlert',
        () async {
      await Purchasely.apiKey('k').webRedemptionListener((_) {}, true).start();

      expect(startCall().arguments['appHandlesRedemptionAlert'], isTrue);
    });

    test('omitting the second argument sets nothing', () async {
      await Purchasely.apiKey('k').webRedemptionListener((_) {}).start();

      expect(startCall().arguments.containsKey('appHandlesRedemptionAlert'),
          isFalse,
          reason: 'an unset flag lets the native default (SDK popin) apply');
    });

    test('false is forwarded, and is not the same as omitting it', () async {
      await Purchasely.apiKey('k').webRedemptionListener((_) {}, false).start();

      expect(startCall().arguments.containsKey('appHandlesRedemptionAlert'),
          isTrue);
      expect(startCall().arguments['appHandlesRedemptionAlert'], isFalse);
    });

    test('the standalone appHandlesRedemptionAlert modifier still works',
        () async {
      await Purchasely.apiKey('k').appHandlesRedemptionAlert(true).start();

      expect(startCall().arguments['appHandlesRedemptionAlert'], isTrue);
    });

    test('a later appHandlesRedemptionAlert overrides the shorthand', () async {
      await Purchasely.apiKey('k')
          .webRedemptionListener((_) {}, true)
          .appHandlesRedemptionAlert(false)
          .start();

      expect(startCall().arguments['appHandlesRedemptionAlert'], isFalse);
    });

    test('the chain listener receives events', () async {
      final received = <PLYWebRedemptionResult>[];
      messenger.setMockStreamHandler(
        redemptionChannel,
        MockStreamHandler.inline(onListen: (arguments, sink) {
          platformLog.add('web-redemption:listen');
          sink.success(const <String, Object?>{
            'isSuccess': true,
            'context': null,
            'replay': false,
            'errorCode': null,
            'errorMessage': null,
          });
        }),
      );

      await Purchasely.apiKey('k').webRedemptionListener(received.add).start();
      await pumpEventQueue();

      expect(received, hasLength(1));
      expect(received.single.isSuccess, isTrue);
    });

    test('registering twice replaces the listener instead of doubling it',
        () async {
      final first = <PLYWebRedemptionResult>[];
      final second = <PLYWebRedemptionResult>[];
      messenger.setMockStreamHandler(
        redemptionChannel,
        MockStreamHandler.inline(onListen: (arguments, sink) {
          sink.success(const <String, Object?>{
            'isSuccess': false,
            'context': null,
            'replay': false,
            'errorCode': 'INVALID_REDEMPTION_TOKEN',
            'errorMessage': 'nope',
          });
        }),
      );

      Purchasely.addWebRedemptionListener(first.add);
      Purchasely.addWebRedemptionListener(second.add);
      await pumpEventQueue();

      // `first` staying empty is the assertion: registering again cancelled its
      // subscription, so an app that swaps listeners never gets both called.
      // `second`'s exact count is a harness artifact — the mock emits once per
      // `listen` message and every live subscription on the channel name sees
      // each emission — so only "it received something" is meaningful here.
      expect(first, isEmpty, reason: 'the first listener must be replaced');
      expect(second, isNotEmpty);
      expect(second.first.errorCode, 'INVALID_REDEMPTION_TOKEN');
    });

    test('removeWebRedemptionListener clears the handle', () async {
      Purchasely.addWebRedemptionListener((_) {});
      expect(Purchasely.webRedemptions, isNotNull);

      Purchasely.removeWebRedemptionListener();
      expect(Purchasely.webRedemptions, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // The 6.1.0 options do not disturb the pre-existing ones
  // ---------------------------------------------------------------------------

  group('the whole 6.1.0 chain together', () {
    test('every option lands with its own key', () async {
      await Purchasely.apiKey('k')
          .appUserId('user-1')
          .runningMode(PLYRunningMode.full)
          .logLevel(PLYLogLevel.debug)
          .allowDeeplink(false)
          .allowCampaigns(false)
          .automaticDeeplinkHandling(false)
          .anonymousUserId('3f2504e0-4f89-11d3-9a0c-0305e82c3301',
              override: true)
          .proxy('https://svc.purchasely.io')
          .webRedemptionListener((_) {}, true)
          .stores([PLYStore.google, PLYStore.amazon])
          .storekitVersion(PLYStorekitVersion.storeKit1)
          .start();

      final args = startCall().arguments as Map<Object?, Object?>;
      expect(args['apiKey'], 'k');
      expect(args['appUserId'], 'user-1');
      expect(args['runningMode'], 'full');
      expect(args['logLevel'], 'debug');
      expect(args['allowDeeplink'], isFalse);
      expect(args['allowCampaigns'], isFalse);
      expect(args['automaticDeeplinkHandling'], isFalse);
      expect(args['anonymousUserId'], '3f2504e0-4f89-11d3-9a0c-0305e82c3301');
      expect(args['anonymousUserIdOverride'], isTrue);
      expect(args['proxy'], 'https://svc.purchasely.io');
      expect(args['appHandlesRedemptionAlert'], isTrue);
      expect(args['stores'], ['google', 'amazon']);
      expect(args['storekitVersion'], 'storeKit1');
    });

    test('a bare chain sends none of the 6.1.0 keys', () async {
      await Purchasely.apiKey('k').start();

      final args = startCall().arguments as Map<Object?, Object?>;
      for (final key in [
        'proxy',
        'anonymousUserId',
        'anonymousUserIdOverride',
        'appHandlesRedemptionAlert',
      ]) {
        expect(args.containsKey(key), isFalse,
            reason: '$key must stay absent so the native default applies');
      }
    });
  });
}
