// Purchasely SDK — shared public models used by the Dart API.

/// Product distribution type for a Purchasely plan.
enum PLYPlanType {
  consumable,
  nonConsumable,
  autoRenewingSubscription,
  nonRenewingSubscription,
  unknown
}

class PLYPlan {
  String? vendorId;
  String? productId;
  String? basePlanId;
  String? name;
  PLYPlanType type;
  double? amount;
  String? localizedAmount;
  String? currencyCode;
  String? currencySymbol;
  String? price;
  String? period;
  bool? hasIntroductoryPrice;
  String? introPrice;
  double? introAmount;
  String? introDuration;
  String? introPeriod;
  bool? hasFreeTrial;
  bool? hasOfferPrice;
  String? offerPrice;
  double? offerAmount;
  String? offerDuration;
  String? offerPeriod;

  PLYPlan(
      this.vendorId,
      this.productId,
      this.name,
      this.type,
      this.amount,
      this.localizedAmount,
      this.currencyCode,
      this.currencySymbol,
      this.price,
      this.period,
      this.hasIntroductoryPrice,
      this.introPrice,
      this.introAmount,
      this.introDuration,
      this.introPeriod,
      this.hasFreeTrial,
      [this.hasOfferPrice,
      this.offerPrice,
      this.offerAmount,
      this.offerDuration,
      this.offerPeriod,
      this.basePlanId]) {
    hasOfferPrice ??= hasIntroductoryPrice;
    offerPrice ??= introPrice;
    offerAmount ??= introAmount;
    offerDuration ??= introDuration;
    offerPeriod ??= introPeriod;
  }

  @override
  String toString() {
    return 'PLYPlan('
        'vendorId: $vendorId, '
        'productId: $productId, '
        'basePlanId: $basePlanId, '
        'name: $name, '
        'type: $type, '
        'amount: $amount, '
        'localizedAmount: $localizedAmount, '
        'currencyCode: $currencyCode, '
        'currencySymbol: $currencySymbol, '
        'price: $price, '
        'period: $period, '
        'hasIntroductoryPrice: $hasIntroductoryPrice, '
        'introPrice: $introPrice, '
        'introAmount: $introAmount, '
        'introDuration: $introDuration, '
        'introPeriod: $introPeriod, '
        'hasFreeTrial: $hasFreeTrial, '
        'hasOfferPrice: $hasOfferPrice, '
        'offerPrice: $offerPrice, '
        'offerAmount: $offerAmount, '
        'offerDuration: $offerDuration, '
        'offerPeriod: $offerPeriod)';
  }
}

class PLYPromoOffer {
  String? vendorId;
  String? storeOfferId;
  String? publicId;

  PLYPromoOffer(this.vendorId, this.storeOfferId, [this.publicId]);
}

class PLYSubscriptionOffer {
  String subscriptionId;
  String? basePlanId;
  String? offerToken;
  String? offerId;

  PLYSubscriptionOffer(
      this.subscriptionId, this.basePlanId, this.offerToken, this.offerId);
}
