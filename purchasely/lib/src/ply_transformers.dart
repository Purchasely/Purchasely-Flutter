// Purchasely SDK — native map to public model transformers.

import 'ply_models.dart';

PLYPlan? plyPlanFromMap(Map<dynamic, dynamic>? plan) {
  if (plan == null || plan.isEmpty) return null;

  final offerPrice = plan['offerPrice'] ?? plan['introPrice'];
  final offerAmount = plan['offerAmount'] ?? plan['introAmount'];
  final offerDuration = plan['offerDuration'] ?? plan['introDuration'];
  final offerPeriod = plan['offerPeriod'] ?? plan['introPeriod'];
  final hasOfferPrice = plan['hasOfferPrice'] ?? plan['hasIntroductoryPrice'];

  return PLYPlan(
    plan['vendorId'],
    plan['productId'],
    plan['name'],
    plyPlanTypeFromWire(plan['type']),
    _toDouble(plan['amount']),
    plan['localizedAmount'],
    plan['currencyCode'],
    plan['currencySymbol'],
    plan['price'],
    plan['period'],
    hasOfferPrice,
    offerPrice,
    _toDouble(offerAmount),
    offerDuration,
    offerPeriod,
    plan['hasFreeTrial'],
    hasOfferPrice,
    offerPrice,
    _toDouble(offerAmount),
    offerDuration,
    offerPeriod,
    plan['basePlanId'],
  )..commitmentInfo = plyCommitmentInfoFromMap(plan['commitmentInfo']);
}

/// Parses the Apple commitment installment array (iOS 26.4+). Returns an empty
/// list when absent (Android and other platforms never send it).
List<PLYCommitmentInfo> plyCommitmentInfoFromMap(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => PLYCommitmentInfo.fromJson(e))
      .toList();
}

/// Parses the Apple commitment progress object (iOS 26.4+). Returns null when
/// absent (Android and other platforms never send it).
PLYCommitmentProgress? plyCommitmentProgressFromMap(dynamic raw) {
  if (raw is! Map || raw.isEmpty) return null;
  return PLYCommitmentProgress.fromJson(raw);
}

PLYPlanType plyPlanTypeFromWire(dynamic rawType) {
  if (rawType is int && rawType >= 0 && rawType < PLYPlanType.values.length) {
    return PLYPlanType.values[rawType];
  }
  if (rawType is String) {
    switch (rawType) {
      case 'CONSUMABLE':
        return PLYPlanType.consumable;
      case 'NON_CONSUMABLE':
        return PLYPlanType.nonConsumable;
      case 'RENEWING_SUBSCRIPTION':
        return PLYPlanType.autoRenewingSubscription;
      case 'NON_RENEWING_SUBSCRIPTION':
        return PLYPlanType.nonRenewingSubscription;
      default:
        return PLYPlanType.unknown;
    }
  }
  return PLYPlanType.unknown;
}

PLYPromoOffer? plyPromoOfferFromMap(Map<dynamic, dynamic>? offer) {
  if (offer == null || offer.isEmpty) return null;

  return PLYPromoOffer(
    offer['vendorId'],
    offer['storeOfferId'],
    offer['publicId'],
  );
}

PLYSubscriptionOffer? plySubscriptionOfferFromMap(
    Map<dynamic, dynamic>? subscriptionOffer) {
  if (subscriptionOffer == null || subscriptionOffer.isEmpty) return null;

  final subscriptionId = subscriptionOffer['subscriptionId'];
  if (subscriptionId is! String || subscriptionId.isEmpty) return null;

  return PLYSubscriptionOffer(
    subscriptionId,
    subscriptionOffer['basePlanId'],
    subscriptionOffer['offerToken'],
    subscriptionOffer['offerId'],
  );
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  return null;
}
