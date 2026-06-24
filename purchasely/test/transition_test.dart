// Unit tests for `lib/src/transition.dart` — the v6 transition + dimension
// model that replaced the legacy `heightPercentage` field.

import 'package:flutter_test/flutter_test.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

void main() {
  group('PLYTransitionDimension', () {
    test('percentage serializes type + value', () {
      expect(
        const PLYTransitionDimension.percentage(0.5).toMap(),
        <String, Object?>{'type': 'percentage', 'value': 0.5},
      );
    });

    test('pixel serializes type + value', () {
      expect(
        const PLYTransitionDimension.pixel(320).toMap(),
        <String, Object?>{'type': 'pixel', 'value': 320.0},
      );
    });

    test('generic constructor keeps the explicit type', () {
      const dim =
          PLYTransitionDimension(type: PLYDimensionType.pixel, value: 12);
      expect(dim.type, PLYDimensionType.pixel);
      expect(dim.toMap()['type'], 'pixel');
    });
  });

  group('Transition.toMap', () {
    test('modal forwards type + dismissible, omits dimensions', () {
      final map = const Transition.modal(dismissible: false).toMap();
      expect(map['type'], 'modal');
      expect(map['dismissible'], false);
      expect(map.containsKey('width'), isFalse);
      expect(map.containsKey('height'), isFalse);
    });

    test('fullScreen forwards just the type', () {
      final map = const Transition.fullScreen().toMap();
      expect(map['type'], 'fullScreen');
      expect(map.containsKey('width'), isFalse);
      expect(map.containsKey('height'), isFalse);
    });

    test('popin serializes width + height as dimension maps', () {
      final map = const Transition(
        type: TransitionType.popin,
        width: PLYTransitionDimension.pixel(320),
        height: PLYTransitionDimension.percentage(0.5),
        dismissible: true,
      ).toMap();

      expect(map['type'], 'popin');
      expect(map['width'], <String, Object?>{'type': 'pixel', 'value': 320.0});
      expect(
        map['height'],
        <String, Object?>{'type': 'percentage', 'value': 0.5},
      );
      expect(map['dismissible'], true);
    });

    test('drawer serializes only the provided height', () {
      final map = const Transition(
        type: TransitionType.drawer,
        height: PLYTransitionDimension.percentage(0.6),
      ).toMap();

      expect(map['type'], 'drawer');
      expect(
        map['height'],
        <String, Object?>{'type': 'percentage', 'value': 0.6},
      );
      expect(map.containsKey('width'), isFalse);
      // dismissible omitted when not set.
      expect(map.containsKey('dismissible'), isFalse);
    });
  });
}
