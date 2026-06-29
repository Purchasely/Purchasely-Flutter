// E2E: the user-attribute listener fires end-to-end (Dart -> native SDK ->
// 'purchasely-user-attributes' EventChannel -> Dart callback).
//
// Platform-agnostic (pure Dart, no host driver): setting/clearing an attribute
// makes the native SDK emit a change event that the listener must receive.
//
// Run:
//   flutter test integration_test/user_attribute_listener_test.dart -d <device>

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

const String kApiKey = '0ad0594b-3b3d-4fea-8ee1-4b5df91efe87';
const String kAttrKey = 'e2e_listener_attr';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final configured = await Purchasely.apiKey(kApiKey)
        .runningMode(PLYRunningMode.full)
        .logLevel(PLYLogLevel.debug)
        .stores([PLYStore.google]).start();
    expect(configured, isTrue,
        reason: 'SDK should configure against the real backend');
  });

  testWidgets('setUserAttributeListener receives set then removed events',
      (tester) async {
    await tester.runAsync(() async {
      final listener = _RecordingListener();
      Purchasely.setUserAttributeListener(listener);
      // Give the EventChannel subscription handshake time to complete before
      // the native SDK emits.
      await Future<void>.delayed(const Duration(seconds: 1));

      // --- set ---
      await Purchasely.setUserAttributeWithString(kAttrKey, 'hello');
      final setSw = Stopwatch()..start();
      while (listener.lastSet == null &&
          setSw.elapsed < const Duration(seconds: 15)) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      expect(listener.lastSet, isNotNull,
          reason: 'onUserAttributeSet must fire after setUserAttributeWith*');
      expect(listener.lastSet!.key, kAttrKey);
      expect(listener.lastSet!.value, 'hello');
      expect(listener.lastSet!.type, PLYUserAttributeType.string);
      expect(listener.lastSet!.source, PLYUserAttributeSource.client);

      // --- removed ---
      Purchasely.clearUserAttribute(kAttrKey);
      final rmSw = Stopwatch()..start();
      while (listener.lastRemovedKey == null &&
          rmSw.elapsed < const Duration(seconds: 15)) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      expect(listener.lastRemovedKey, kAttrKey,
          reason: 'onUserAttributeRemoved must fire after clearUserAttribute');

      debugPrint('user-attribute listener → set(${listener.lastSet!.key}='
          '${listener.lastSet!.value}, ${listener.lastSet!.source}) ; '
          'removed(${listener.lastRemovedKey})');

      Purchasely.clearUserAttributeListener();
    });
  });
}

class _SetCall {
  _SetCall(this.key, this.type, this.value, this.source);
  final String key;
  final PLYUserAttributeType type;
  final dynamic value;
  final PLYUserAttributeSource source;
}

class _RecordingListener extends UserAttributeListener {
  _SetCall? lastSet;
  String? lastRemovedKey;

  @override
  void onUserAttributeSet(String key, PLYUserAttributeType type, dynamic value,
      PLYUserAttributeSource source) {
    if (key == kAttrKey) lastSet = _SetCall(key, type, value, source);
  }

  @override
  void onUserAttributeRemoved(String key, PLYUserAttributeSource source) {
    if (key == kAttrKey) lastRemovedKey = key;
  }
}
