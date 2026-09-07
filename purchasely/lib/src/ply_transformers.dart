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
  if (raw is! List) return [];
  return raw.whereType<Map>().map(_commitmentInfoFromJson).toList();
}

PLYCommitmentInfo _commitmentInfoFromJson(Map<dynamic, dynamic> json) =>
    PLYCommitmentInfo(
      billingPlanType: plyBillingPlanTypeFromWire(json['billingPlanType']),
      billingPrice: _toDouble(json['billingPrice']),
      billingPeriod: json['billingPeriod'] as String?,
      totalPrice: _toDouble(json['totalPrice']),
      totalPeriod: json['totalPeriod'] as String?,
      totalDuration: _toInt(json['totalDuration']),
    );

/// Parses the Apple commitment progress object (iOS 26.4+). Returns null when
/// absent (Android and other platforms never send it).
PLYCommitmentProgress? plyCommitmentProgressFromMap(dynamic raw) {
  if (raw is! Map || raw.isEmpty) return null;
  return PLYCommitmentProgress(
    billingPeriodNumber: _toInt(raw['billingPeriodNumber']),
    totalBillingPeriods: _toInt(raw['totalBillingPeriods']),
    commitmentExpiresDate: raw['commitmentExpiresDate'] as String?,
    commitmentPrice: _toDouble(raw['commitmentPrice']),
  );
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

/// Tolerantly maps the wire `billingPlanType` to [PLYBillingPlanType]. Accepts
/// the native string form (`"up_front"` / `"monthly"`) and, defensively, the
/// legacy Int rawValue (0/1/2). Unknown / null falls back to unspecified.
PLYBillingPlanType plyBillingPlanTypeFromWire(dynamic raw) {
  if (raw is int && raw >= 0 && raw < PLYBillingPlanType.values.length) {
    return PLYBillingPlanType.values[raw];
  }
  if (raw is String) {
    switch (raw) {
      case 'up_front':
        return PLYBillingPlanType.upFront;
      case 'monthly':
        return PLYBillingPlanType.monthly;
      default:
        return PLYBillingPlanType.unspecified;
    }
  }
  return PLYBillingPlanType.unspecified;
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

int? _toInt(dynamic value) => value is num ? value.toInt() : null;

/// Maps the wire `subscriptionSource` to [PLYSubscriptionSource]. Android sends
/// null for a store type outside the 4 known ones (or a missing / out-of-range
/// index) — falls back to [PLYSubscriptionSource.none] instead of an uncaught
/// `List` index error (REC-09 / FLT-W-07).
PLYSubscriptionSource plySubscriptionSourceFromWire(dynamic raw) {
  if (raw is int && raw >= 0 && raw < PLYSubscriptionSource.values.length) {
    return PLYSubscriptionSource.values[raw];
  }
  return PLYSubscriptionSource.none;
}

/// Maps one wire subscription map to a [PLYSubscription].
///
/// Shared by `Purchasely.userSubscriptions`,
/// `Purchasely.userSubscriptionsHistory` and
/// `PLYWebRedemptionContext.subscription`, whose native counterparts all use the
/// same mapper, so the three report one subscription shape.
///
/// The revenue/duration aggregates are read unconditionally: they are absent
/// from the iOS wire map, and an absent key reads as null.
PLYSubscription plySubscriptionFromMap(Map<dynamic, dynamic> element) {
  final List<PLYPlan?> plans = [];

  PLYProduct? product;
  final rawProduct = element['product'];
  if (rawProduct is Map) {
    (rawProduct['plans'] as Map?)
        ?.forEach((k, plan) => plans.add(plyPlanFromMap(plan)));

    // `PLYProduct.name`/`vendorId` are non-nullable, but the wire values are
    // not: neither native mapper guarantees them. A null used to throw a
    // TypeError here, and this mapper now feeds three paths — including a
    // redemption context, whose products may not be loaded yet. Empty string
    // rather than a throw: a caller sees "no name", not a crashed listener.
    product = PLYProduct(rawProduct['name'] as String? ?? '',
        rawProduct['vendorId'] as String? ?? '', plans.nonNulls.toList());
  }

  return PLYSubscription(
    element['purchaseToken'],
    plySubscriptionSourceFromWire(element['subscriptionSource']),
    element['nextRenewalDate'],
    element['cancelledDate'],
    plyPlanFromMap(element['plan']),
    product,
    _toDouble(element['cumulatedRevenuesInUSD']),
    _toInt(element['subscriptionDurationInDays']),
    _toInt(element['subscriptionDurationInWeeks']),
    _toInt(element['subscriptionDurationInMonths']),
  )..commitmentProgress =
      plyCommitmentProgressFromMap(element['commitmentProgress']);
}
