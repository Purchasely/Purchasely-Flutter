// Unit tests for `lib/src/presentation.dart` — `PLYPresentation.fromMap()` /
// `.toMap()` and `PLYPresentationPlan`. Pure Dart map-parsing tests: no
// MethodChannel involved.
//
// Fills a gap where several wire fields (contentId, audienceId, abTestId,
// abTestVariantId, flowId, language, metadata) were never asserted anywhere,
// even though `PLYPresentation.fromMap` has read them since v6.

import 'package:flutter_test/flutter_test.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

void main() {
  group('PLYPresentation.fromMap', () {
    test('parses every metadata-ish field from the wire map', () {
      final presentation = PLYPresentation.fromMap(<String, Object?>{
        'requestId': 'req_1',
        'screenId': 'screen_1',
        'placementId': 'placement_1',
        'contentId': 'content_42',
        'audienceId': 'aud_1',
        'abTestId': 'ab_1',
        'abTestVariantId': 'variant_a',
        'campaignId': 'cmp_1',
        'flowId': 'flow_1',
        'language': 'fr',
        'height': 640,
        'type': 0,
        'plans': <Map<String, Object?>>[],
        'metadata': <String, Object?>{'foo': 'bar', 'count': 3},
      });

      expect(presentation.requestId, 'req_1');
      expect(presentation.screenId, 'screen_1');
      expect(presentation.placementId, 'placement_1');
      expect(presentation.contentId, 'content_42');
      expect(presentation.audienceId, 'aud_1');
      expect(presentation.abTestId, 'ab_1');
      expect(presentation.abTestVariantId, 'variant_a');
      expect(presentation.campaignId, 'cmp_1');
      expect(presentation.flowId, 'flow_1');
      expect(presentation.language, 'fr');
      expect(presentation.height, 640);
      expect(
          presentation.metadata, <String, Object?>{'foo': 'bar', 'count': 3});
    });

    test('screenId falls back to the legacy "id" key when absent', () {
      final presentation = PLYPresentation.fromMap(<String, Object?>{
        'requestId': 'req_1',
        'id': 'legacy_screen',
      });
      expect(presentation.screenId, 'legacy_screen');
    });

    test('screenId prefers the v6 key over the legacy one when both present',
        () {
      final presentation = PLYPresentation.fromMap(<String, Object?>{
        'requestId': 'req_1',
        'screenId': 'v6_screen',
        'id': 'legacy_screen',
      });
      expect(presentation.screenId, 'v6_screen');
    });

    test('type parses from an int index', () {
      final presentation = PLYPresentation.fromMap(<String, Object?>{
        'requestId': 'req_1',
        'type': 3,
      });
      expect(presentation.type, PLYPresentationType.client);
    });

    test('type parses from the string form, case-insensitively', () {
      for (final entry in <String, PLYPresentationType>{
        'normal': PLYPresentationType.normal,
        'FALLBACK': PLYPresentationType.fallback,
        'Deactivated': PLYPresentationType.deactivated,
        'client': PLYPresentationType.client,
      }.entries) {
        final presentation = PLYPresentation.fromMap(<String, Object?>{
          'requestId': 'req_1',
          'type': entry.key,
        });
        expect(presentation.type, entry.value, reason: 'type: ${entry.key}');
      }
    });

    test('type defaults to normal for null, unrecognized or out-of-range', () {
      for (final rawType in <Object?>[null, 'not_a_type', 99, -1]) {
        final presentation = PLYPresentation.fromMap(<String, Object?>{
          'requestId': 'req_1',
          'type': rawType,
        });
        expect(presentation.type, PLYPresentationType.normal,
            reason: 'type: $rawType');
      }
    });

    test('height defaults to 0 when absent', () {
      final presentation =
          PLYPresentation.fromMap(<String, Object?>{'requestId': 'req_1'});
      expect(presentation.height, 0);
    });

    test('plans list is parsed via PLYPresentationPlan.fromMap', () {
      final presentation = PLYPresentation.fromMap(<String, Object?>{
        'requestId': 'req_1',
        'plans': <Map<String, Object?>>[
          <String, Object?>{
            'planVendorId': 'monthly',
            'storeProductId': 'com.app.monthly',
            'basePlanId': 'base_monthly',
            'offerId': 'intro',
          },
        ],
      });

      expect(presentation.plans, hasLength(1));
      expect(presentation.plans.single.planVendorId, 'monthly');
      expect(presentation.plans.single.storeProductId, 'com.app.monthly');
      expect(presentation.plans.single.basePlanId, 'base_monthly');
      expect(presentation.plans.single.offerId, 'intro');
    });

    test('metadata ignores non-String keys and absent map', () {
      final withNonStringKey = PLYPresentation.fromMap(<dynamic, dynamic>{
        'requestId': 'req_1',
        'metadata': <dynamic, dynamic>{1: 'skipped', 'kept': 'value'},
      });
      expect(withNonStringKey.metadata, <String, Object?>{'kept': 'value'});

      final withoutMetadata =
          PLYPresentation.fromMap(<String, Object?>{'requestId': 'req_1'});
      expect(withoutMetadata.metadata, isEmpty);
    });
  });

  group('PLYPresentation.toMap', () {
    test('round-trips the type as its int index', () {
      final presentation = PLYPresentation(
        requestId: 'req_1',
        type: PLYPresentationType.fallback,
      );
      expect(presentation.toMap()['type'], PLYPresentationType.fallback.index);
    });
  });

  group('PLYPresentationPlan', () {
    test('toMap() serializes all four fields', () {
      const plan = PLYPresentationPlan(
        planVendorId: 'monthly',
        storeProductId: 'com.app.monthly',
        basePlanId: 'base_monthly',
        offerId: 'intro',
      );
      expect(plan.toMap(), <String, Object?>{
        'planVendorId': 'monthly',
        'storeProductId': 'com.app.monthly',
        'basePlanId': 'base_monthly',
        'offerId': 'intro',
      });
    });

    test('fromMap() tolerates a fully empty map', () {
      final plan = PLYPresentationPlan.fromMap(<String, Object?>{});
      expect(plan.planVendorId, isNull);
      expect(plan.storeProductId, isNull);
      expect(plan.basePlanId, isNull);
      expect(plan.offerId, isNull);
    });
  });
}
