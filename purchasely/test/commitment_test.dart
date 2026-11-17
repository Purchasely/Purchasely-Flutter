// Unit tests for the Apple commitment bridge mapping (iOS 26.4+ "monthly
// subscription with N-month commitment"). Covers:
//   - PLYPlan.commitmentInfo parsing (via the public purchase interceptor path
//     and directly via plyPlanFromMap),
//   - PLYCommitmentProgress parsing on a subscription,
//   - PLYBillingPlanType wire mapping (string, legacy int, unknown/null),
//   - Apple-only null/empty behaviour (Android/other platforms send nothing).

import 'package:flutter_test/flutter_test.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';
// Transformers are not part of the public barrel — import src/ directly.
import 'package:purchasely_flutter/src/ply_transformers.dart';

void main() {
  group('PLYBillingPlanType wire mapping', () {
    test('string wire values map to cases', () {
      expect(
          plyBillingPlanTypeFromWire('up_front'), PLYBillingPlanType.upFront);
      expect(plyBillingPlanTypeFromWire('monthly'), PLYBillingPlanType.monthly);
      expect(plyBillingPlanTypeFromWire('unspecified'),
          PLYBillingPlanType.unspecified);
    });

    test('legacy int rawValue maps to cases', () {
      expect(plyBillingPlanTypeFromWire(0), PLYBillingPlanType.unspecified);
      expect(plyBillingPlanTypeFromWire(1), PLYBillingPlanType.upFront);
      expect(plyBillingPlanTypeFromWire(2), PLYBillingPlanType.monthly);
    });

    test('unknown / null / out-of-range falls back to unspecified', () {
      expect(plyBillingPlanTypeFromWire(null), PLYBillingPlanType.unspecified);
      expect(
          plyBillingPlanTypeFromWire('nope'), PLYBillingPlanType.unspecified);
      expect(plyBillingPlanTypeFromWire(99), PLYBillingPlanType.unspecified);
    });

    test('wire round-trips through the extension', () {
      expect(PLYBillingPlanType.upFront.wire, 'up_front');
      expect(PLYBillingPlanType.monthly.wire, 'monthly');
      expect(PLYBillingPlanType.unspecified.wire, 'unspecified');
    });
  });

  group('plyPlanFromMap commitmentInfo', () {
    test('parses a monthly commitment installment array', () {
      final plan = plyPlanFromMap({
        'vendorId': 'plan_x',
        'type': 2,
        'commitmentInfo': [
          {
            'billingPlanType': 'monthly',
            'billingPrice': 9.99,
            'billingPeriod': 'P1M',
            'totalPrice': 119.88,
            'totalPeriod': 'P1Y',
            'totalDuration': 12,
          },
        ],
      });

      expect(plan, isNotNull);
      expect(plan!.commitmentInfo, hasLength(1));
      final info = plan.commitmentInfo.first;
      expect(info.billingPlanType, PLYBillingPlanType.monthly);
      expect(info.billingPrice, 9.99);
      expect(info.billingPeriod, 'P1M');
      expect(info.totalPrice, 119.88);
      expect(info.totalPeriod, 'P1Y');
      expect(info.totalDuration, 12);
    });

    test('absent commitmentInfo (Android/other) yields an empty list', () {
      final plan = plyPlanFromMap({'vendorId': 'plan_x', 'type': 2});
      expect(plan, isNotNull);
      expect(plan!.commitmentInfo, isEmpty);
    });

    test('exposed through the purchase interceptor payload', () {
      final payload = actionPayloadFromMap(
        PLYPresentationActionKind.purchase,
        {
          'plan': {
            'vendorId': 'plan_x',
            'type': 2,
            'commitmentInfo': [
              {
                'billingPlanType': 'up_front',
                'billingPrice': 119.88,
                'billingPeriod': 'P1Y',
                'totalPrice': 119.88,
                'totalPeriod': 'P1Y',
                'totalDuration': 1,
              },
            ],
          },
        },
      ) as PLYPurchasePayload;

      expect(payload.plan.commitmentInfo, hasLength(1));
      expect(payload.plan.commitmentInfo.first.billingPlanType,
          PLYBillingPlanType.upFront);
      expect(payload.plan.commitmentInfo.first.totalDuration, 1);
    });
  });

  group('plyCommitmentProgressFromMap', () {
    test('parses billing progress with an ISO 8601 expiry date', () {
      final progress = plyCommitmentProgressFromMap({
        'billingPeriodNumber': 3,
        'totalBillingPeriods': 12,
        'commitmentExpiresDate': '2027-01-15T00:00:00+0000',
        'commitmentPrice': 9.99,
      });

      expect(progress, isNotNull);
      expect(progress!.billingPeriodNumber, 3);
      expect(progress.totalBillingPeriods, 12);
      expect(progress.commitmentExpiresDate, '2027-01-15T00:00:00+0000');
      expect(progress.commitmentPrice, 9.99);
    });

    test('null / empty map (Android/other) yields null', () {
      expect(plyCommitmentProgressFromMap(null), isNull);
      expect(plyCommitmentProgressFromMap(const {}), isNull);
    });
  });

  group('PLYDynamicOffering billingPlanType', () {
    test('defaults to unspecified and serializes the wire value', () {
      final offering = PLYDynamicOffering('ref', 'plan_x', null);
      expect(offering.billingPlanType, PLYBillingPlanType.unspecified);
      expect(offering.toJson()['billingPlanType'], 'unspecified');

      final monthly =
          PLYDynamicOffering('ref', 'plan_x', null, PLYBillingPlanType.monthly);
      expect(monthly.toJson()['billingPlanType'], 'monthly');
    });
  });
}
