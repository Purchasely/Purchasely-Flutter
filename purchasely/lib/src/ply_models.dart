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

  /// Apple commitment installment details (iOS 26.4+ "monthly subscription with
  /// N-month commitment"). Empty on Android and other platforms — Apple-only.
  List<PLYCommitmentInfo> commitmentInfo = [];

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

/// Apple billing plan type for a commitment (iOS 26.4+). Apple-only; other
/// platforms always report [PLYBillingPlanType.unspecified].
enum PLYBillingPlanType { unspecified, upFront, monthly }

extension PLYBillingPlanTypeWire on PLYBillingPlanType {
  /// Wire value sent to the native bridge, matching the iOS SDK's wire form.
  String get wire {
    switch (this) {
      case PLYBillingPlanType.upFront:
        return 'up_front';
      case PLYBillingPlanType.monthly:
        return 'monthly';
      case PLYBillingPlanType.unspecified:
        return 'unspecified';
    }
  }
}

/// Commitment installment details for an Apple "monthly subscription with
/// N-month commitment" plan (iOS 26.4+). Apple-only.
class PLYCommitmentInfo {
  final PLYBillingPlanType billingPlanType;

  /// Per-billing-cycle price (e.g. 9.99 for a monthly-billed plan).
  final double? billingPrice;

  /// ISO 8601 duration of each billing cycle, e.g. "P1M".
  final String? billingPeriod;

  /// Total price over the full commitment (e.g. 119.88 for 12 × 9.99).
  final double? totalPrice;

  /// ISO 8601 duration of the full commitment, e.g. "P1Y".
  final String? totalPeriod;

  /// Number of billing cycles in the commitment (1 for up-front, 12 for a
  /// 12-month monthly commitment).
  final int? totalDuration;

  PLYCommitmentInfo({
    required this.billingPlanType,
    this.billingPrice,
    this.billingPeriod,
    this.totalPrice,
    this.totalPeriod,
    this.totalDuration,
  });

  @override
  String toString() => 'PLYCommitmentInfo('
      'billingPlanType: $billingPlanType, '
      'billingPrice: $billingPrice, '
      'billingPeriod: $billingPeriod, '
      'totalPrice: $totalPrice, '
      'totalPeriod: $totalPeriod, '
      'totalDuration: $totalDuration)';
}

/// A subscriber's progress through an Apple monthly-commitment plan
/// (iOS 26.4+). Null on Android and other platforms — Apple-only.
class PLYCommitmentProgress {
  /// The current billing period number within the commitment (1-based).
  final int? billingPeriodNumber;

  /// The total number of billing periods in the commitment.
  final int? totalBillingPeriods;

  /// ISO 8601 date at which the commitment expires.
  final String? commitmentExpiresDate;

  /// The price charged for this billing period.
  final double? commitmentPrice;

  PLYCommitmentProgress({
    this.billingPeriodNumber,
    this.totalBillingPeriods,
    this.commitmentExpiresDate,
    this.commitmentPrice,
  });

  @override
  String toString() => 'PLYCommitmentProgress('
      'billingPeriodNumber: $billingPeriodNumber, '
      'totalBillingPeriods: $totalBillingPeriods, '
      'commitmentExpiresDate: $commitmentExpiresDate, '
      'commitmentPrice: $commitmentPrice)';
}

/// Store a subscription was bought from.
///
/// **The declaration order is the wire contract.** Both native SDKs send this as
/// an Int index, and both agree: `appleAppStore` 0, `googlePlayStore` 1,
/// `amazonAppstore` 2, `huaweiAppGallery` 3, `webCheckoutStripe` 4, `none` 5.
/// Verified at the released 6.1.0 tags — Android `StoreType` and iOS
/// `PLYSubscriptionSource`. Never reorder these cases, and never insert one in
/// the middle: [plySubscriptionSourceFromWire] maps by index.
enum PLYSubscriptionSource {
  appleAppStore,
  googlePlayStore,
  amazonAppstore,
  huaweiAppGallery,

  /// A subscription bought through Purchasely web checkout (Stripe).
  ///
  /// New in 6.1.0 on the Dart side. Android calls it
  /// `StoreType.WEB_CHECKOUT_STRIPE`, iOS calls it
  /// `PLYSubscriptionSource.stripe`; both sit at index 4. Before this case
  /// existed a web-checkout subscription decoded to [none] on iOS (index 4 used
  /// to be `none`) and to [none] on Android (the bridge mapped it to null), so
  /// the source was silently unusable.
  ///
  /// A Web2App redemption grants subscriptions from exactly this source, so
  /// `PLYWebRedemptionContext.subscription` is the payload most likely to carry
  /// it.
  webCheckoutStripe,
  none
}

class PLYProduct {
  String name;
  String vendorId;
  List<PLYPlan> plans;

  PLYProduct(this.name, this.vendorId, this.plans);
}

class PLYSubscription {
  /// **Android-only.** The native iOS `PLYSubscription` has no purchase token
  /// property, so the iOS bridge cannot emit this key and never did. Read it
  /// with a null guard: it is always null on iOS, on
  /// [Purchasely.userSubscriptions] and [Purchasely.userSubscriptionsHistory]
  /// alike, not only on a redemption context.
  String? purchaseToken;
  PLYSubscriptionSource? subscriptionSource;

  /// Null when the subscription has no renewal date. The iOS bridge omits the
  /// key when the native date is nil, so read it as nullable rather than as an
  /// empty string.
  String? nextRenewalDate;

  /// Null when the subscription is not cancelled. See [nextRenewalDate].
  String? cancelledDate;
  PLYPlan? plan;
  PLYProduct? product;
  double? cumulatedRevenuesInUSD = null;
  int? subscriptionDurationInDays = null;
  int? subscriptionDurationInWeeks = null;
  int? subscriptionDurationInMonths = null;

  /// Apple monthly-commitment progress (iOS 26.4+). Null on Android and other
  /// platforms — Apple-only.
  PLYCommitmentProgress? commitmentProgress;

  PLYSubscription(
      this.purchaseToken,
      this.subscriptionSource,
      this.nextRenewalDate,
      this.cancelledDate,
      this.plan,
      this.product,
      this.cumulatedRevenuesInUSD,
      this.subscriptionDurationInDays,
      this.subscriptionDurationInWeeks,
      this.subscriptionDurationInMonths);
}
