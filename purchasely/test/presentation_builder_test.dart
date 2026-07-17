// Unit tests for `lib/src/presentation_builder.dart` and
// `lib/src/presentation_request.dart` — the fluent builder and the wire
// shape (`toMap()`) it produces for `preload()`/`display()`.
//
// These are pure Dart-model tests: no MethodChannel mock is needed since we
// only assert on `PLYPresentationRequest.toMap()` / `PLYPresentationSource.toMap()`
// directly (the same map `PurchaselyBridge._argsForRequest` forwards verbatim).

import 'package:flutter_test/flutter_test.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

void main() {
  // PLYPresentationBuilder.build() calls PurchaselyBridge.ensureInstalled(),
  // which needs a live binding to open the EventChannel broadcast stream.
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => PurchaselyBridge.debugReset());

  group('PLYPresentationSource.toMap', () {
    test('placement', () {
      expect(
        const PLYPresentationSource.placement('home').toMap(),
        <String, Object?>{'kind': 'placementId', 'id': 'home'},
      );
    });

    test('screen', () {
      expect(
        const PLYPresentationSource.screen('screen_1').toMap(),
        <String, Object?>{'kind': 'screenId', 'id': 'screen_1'},
      );
    });

    test('defaultSource omits id', () {
      final map = const PLYPresentationSource.defaultSource().toMap();
      expect(map['kind'], 'defaultSource');
      expect(map.containsKey('id'), isFalse);
    });
  });

  group('PLYPresentationBuilder.build()', () {
    test('generates a stable ply_-prefixed hex requestId', () {
      final request = PLYPresentationBuilder.placement('home').build();
      expect(request.requestId, startsWith('ply_'));
      expect(
        RegExp(r'^ply_[0-9a-f]{32}$').hasMatch(request.requestId),
        isTrue,
        reason: 'requestId: ${request.requestId}',
      );
    });

    test('two builds never collide on requestId', () {
      final a = PLYPresentationBuilder.placement('home').build();
      final b = PLYPresentationBuilder.placement('home').build();
      expect(a.requestId, isNot(b.requestId));
    });

    test('defaults: cosmetic options are omitted from toMap() when unset', () {
      final request = PLYPresentationBuilder.placement('home').build();
      final map = request.toMap();

      expect(map.containsKey('contentId'), isFalse);
      expect(map.containsKey('backgroundColor'), isFalse);
      expect(map.containsKey('progressColor'), isFalse);
      expect(map.containsKey('displayCloseButton'), isFalse);
      expect(map.containsKey('displayBackButton'), isFalse);
    });

    test('every cosmetic builder option forwards its exact wire key', () {
      final request = PLYPresentationBuilder.placement('home')
          .contentId('article-42')
          .backgroundColor('#000000')
          .progressColor('#FFFFFF')
          .displayCloseButton(true)
          .displayBackButton(false)
          .build();

      final map = request.toMap();
      expect(map['contentId'], 'article-42');
      expect(map['backgroundColor'], '#000000');
      expect(map['progressColor'], '#FFFFFF');
      expect(map['displayCloseButton'], true);
      expect(map['displayBackButton'], false);
      // Source + requestId are always present alongside the cosmetic options.
      expect(map['requestId'], request.requestId);
      expect((map['source'] as Map)['id'], 'home');
    });

    test('contentId(null) is treated the same as never calling it', () {
      final request =
          PLYPresentationBuilder.placement('home').contentId(null).build();
      expect(request.toMap().containsKey('contentId'), isFalse);
    });

    test('screen() and defaultSource() sources round-trip through toMap()', () {
      final screenReq = PLYPresentationBuilder.screen('s1').build();
      expect((screenReq.toMap()['source'] as Map)['kind'], 'screenId');

      final defaultReq = PLYPresentationBuilder.defaultSource().build();
      expect((defaultReq.toMap()['source'] as Map)['kind'], 'defaultSource');
    });
  });
}
