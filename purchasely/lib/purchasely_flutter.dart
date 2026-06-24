import 'dart:async';
import 'dart:developer';

import 'package:flutter/services.dart';

import 'src/action_interceptor.dart'
    show PLYPresentationActionKind, PLYActionInterceptorHandler;
import 'src/bridge.dart' show PurchaselyBridge;
import 'src/ply_models.dart';
import 'src/ply_transformers.dart';
import 'src/presentation_outcome.dart' show PLYPresentationOutcome;
import 'src/purchasely_builder.dart' show PLYLogLevel, PurchaselyBuilder;

// --- Purchasely SDK cross-platform API ---
//
// The presentation API is exposed from `lib/src/` and re-exported here so
// callers can `import 'package:purchasely_flutter/purchasely_flutter.dart';`
// and get both the static `Purchasely` class below (purchases, restore,
// login/logout, attributes, products/plans, subscriptions, events, offerings,
// consent, config) and the builder-based presentation API (`PurchaselyBuilder`,
// `PLYPresentationBuilder`, `PLYPresentation`, `PLYPresentationOutcome`, `PLYTransition`,
// ActionInterceptor…).
export 'src/action_interceptor.dart';
export 'src/bridge.dart' show PurchaselyBridge;
export 'src/ply_models.dart';
export 'src/presentation.dart';
export 'src/presentation_builder.dart';
export 'src/presentation_outcome.dart';
export 'src/presentation_request.dart';
export 'src/purchasely_builder.dart';
export 'src/transition.dart';

class Purchasely {
  static const MethodChannel _channel = const MethodChannel('purchasely');
  static const EventChannel _stream = EventChannel('purchasely-events');
  static const EventChannel _purchases = EventChannel('purchasely-purchases');
  static const EventChannel _userAttributesChannel =
      EventChannel('purchasely-user-attributes');

  static UserAttributeListener? _userAttributeListener;

  static var events;
  static var purchases;

  // --- SDK initialisation ---

  /// Start the SDK configuration chain.
  ///
  /// ```dart
  /// await Purchasely.apiKey('<YOUR_API_KEY>')
  ///     .runningMode(PLYRunningMode.full)
  ///     .logLevel(PLYLogLevel.error)
  ///     .stores([PLYStore.google])
  ///     .start();
  /// ```
  static PurchaselyBuilder apiKey(String key) =>
      PurchaselyBuilder.apiKey(key);

  // --- Action interceptor ---

  /// Registers a typed interceptor for [kind] actions triggered from a
  /// PLYPresentation. The handler returns an `PLYInterceptResult` (or a
  /// `Future<PLYInterceptResult>`). Thin façade over [PurchaselyBridge].
  static Future<void> interceptAction(
    PLYPresentationActionKind kind,
    PLYActionInterceptorHandler handler,
  ) =>
      PurchaselyBridge.ensureInstalled().registerInterceptor(kind, handler);

  /// Removes the action interceptor previously registered for [kind].
  static Future<void> removeActionInterceptor(PLYPresentationActionKind kind) =>
      PurchaselyBridge.ensureInstalled().removeActionInterceptor(kind);

  /// Removes all registered action interceptors.
  static Future<void> removeAllActionInterceptors() =>
      PurchaselyBridge.ensureInstalled().removeAllActionInterceptors();

  /// Registers the global dismiss handler for presentations opened by the SDK
  /// itself (campaigns, deeplinks, promoted in-app purchases).
  ///
  /// The handler receives the rich v6 [PLYPresentationOutcome], including the
  /// [PLYPresentationOutcome.presentation] field so the app can identify which
  /// campaign/deeplink presentation was closed.
  static Future<void> setDefaultPresentationDismissHandler(
    void Function(PLYPresentationOutcome outcome) handler,
  ) =>
      PurchaselyBridge.ensureInstalled()
          .setDefaultPresentationDismissHandler(handler);

  /// Removes the user attribute listener
  static void clearUserAttributeListener() {
    _userAttributeListener = null;
  }

  /// Sets the user attribute listener
  static void setUserAttributeListener(UserAttributeListener listener) {
    _userAttributeListener = listener;

    _userAttributesChannel.receiveBroadcastStream().listen((event) {
      final Map<dynamic, dynamic> map = event;
      final String eventType = map['event'];

      if (eventType == 'set') {
        _userAttributeListener?.onUserAttributeSet(
          map['key'],
          mapType(map['type']),
          map['value'],
          _mapSource(map['source']),
        );
      } else if (eventType == 'removed') {
        _userAttributeListener?.onUserAttributeRemoved(
          map['key'],
          _mapSource(map['source']),
        );
      }
    });
  }

  /// Maps the source string to the enum
  static PLYUserAttributeSource _mapSource(int source) {
    switch (source) {
      case 0:
        return PLYUserAttributeSource.purchasely;
      case 1:
        return PLYUserAttributeSource.client;
      default:
        throw ArgumentError('Unknown source: $source');
    }
  }

  /// Maps the type string to the enum
  static PLYUserAttributeType mapType(String type) {
    if (type == "STRING") {
      return PLYUserAttributeType.string;
    } else if (type == "INT") {
      return PLYUserAttributeType.int;
    } else if (type == "FLOAT") {
      return PLYUserAttributeType.float;
    } else if (type == "BOOLEAN") {
      return PLYUserAttributeType.bool;
    } else if (type == "DATE") {
      return PLYUserAttributeType.date;
    } else if (type == "STRING_ARRAY") {
      return PLYUserAttributeType.stringArray;
    } else if (type == "INT_ARRAY") {
      return PLYUserAttributeType.intArray;
    } else if (type == "FLOAT_ARRAY") {
      return PLYUserAttributeType.floatArray;
    } else if (type == "BOOLEAN_ARRAY") {
      return PLYUserAttributeType.boolArray;
    } else {
      throw ArgumentError('Unknown type: $type');
    }
  }

  static Future<bool> restoreAllProducts() async {
    final bool restored = await _channel.invokeMethod('restoreAllProducts');
    return restored;
  }

  static Future<bool> silentRestoreAllProducts() async {
    final bool restored =
        await _channel.invokeMethod('silentRestoreAllProducts');
    return restored;
  }

  /// Forces a synchronization of the user's purchases with the Purchasely
  /// servers.
  ///
  /// Since the 6.0 native SDKs expose success/error callbacks on
  /// `synchronize()`, the returned [Future] resolves with `true` once the
  /// synchronization actually completes and throws a [PlatformException] if it
  /// failed — instead of the previous fire-and-forget behaviour. `await` it
  /// before chaining a follow-up presentation that targets subscribers.
  static Future<bool> synchronize() async {
    final result = await _channel.invokeMethod('synchronize');
    return result == true;
  }

  static Future<String> get anonymousUserId async {
    final String id = await _channel.invokeMethod('getAnonymousUserId');
    return id;
  }

  static Future<bool> userLogin(String userId) async {
    final bool restored = await _channel
        .invokeMethod('userLogin', <String, dynamic>{'userId': userId});
    return restored;
  }

  static Future<void> userLogout() async {
    return await _channel.invokeMethod("userLogout");
  }

  static Future<bool> setLogLevel(PLYLogLevel logLevel) async {
    final bool restored = await _channel.invokeMethod(
        'setLogLevel', <String, dynamic>{'logLevel': logLevel.index});
    return restored;
  }

  static Future<void> allowDeeplink(bool allowDeeplink) async {
    await _channel.invokeMethod(
        'allowDeeplink', <String, dynamic>{'allowDeeplink': allowDeeplink});
  }

  /// Allows or defers automatic campaign presentation display at runtime.
  ///
  /// This flag is independent from [allowDeeplink]. It defaults to `true` in
  /// the native SDKs; pass `false` during startup/onboarding to queue
  /// campaigns, then `true` when your app is ready to display them.
  static Future<void> allowCampaigns(bool allowCampaigns) async {
    await _channel.invokeMethod(
        'allowCampaigns', <String, dynamic>{'allowCampaigns': allowCampaigns});
  }

  static Future<void> setLanguage(String language) async {
    _channel
        .invokeMethod('setLanguage', <String, dynamic>{'language': language});
  }

  static Future<PLYProduct> productWithIdentifier(String vendorId) async {
    final Map<dynamic, dynamic> result = await _channel.invokeMethod(
        'productWithIdentifier', <String, dynamic>{'vendorId': vendorId});
    final List<PLYPlan?> plans = new List.empty(growable: true);
    result['plans'].forEach((k, plan) => {plans.add(transformToPLYPlan(plan))});
    return PLYProduct(
        result['name'], result['vendorId'], plans.nonNulls.toList());
  }

  static Future<PLYPlan?> planWithIdentifier(String vendorId) async {
    final Map<dynamic, dynamic> result = await _channel.invokeMethod(
        'planWithIdentifier', <String, dynamic>{'vendorId': vendorId});
    return transformToPLYPlan(result);
  }

  static Future<Map<dynamic, dynamic>> signPromotionalOffer(
      String storeProductId, String storeOfferId) async {
    final Map<dynamic, dynamic> result = await _channel.invokeMethod(
        'signPromotionalOffer', <String, dynamic>{
      'storeProductId': storeProductId,
      'storeOfferId': storeOfferId
    });
    return result;
  }

  static Future<Map<dynamic, dynamic>> purchaseWithPlanVendorId(
      {required String vendorId, String? offerId, String? contentId}) async {
    final Map<dynamic, dynamic> product = await _channel.invokeMethod(
        'purchaseWithPlanVendorId', <String, dynamic>{
      'vendorId': vendorId,
      'offerId': offerId,
      'contentId': contentId
    });
    return product;
  }

  static Future<List<PLYProduct>> allProducts() async {
    final List result = await _channel.invokeMethod('allProducts');
    List<PLYProduct> products = new List.empty(growable: true);
    result.forEach((element) {
      final List<PLYPlan?> plans = new List.empty(growable: true);
      element['plans']
          .forEach((k, plan) => {plans.add(transformToPLYPlan(plan))});
      products.add(PLYProduct(
          element['name'], element['vendorId'], plans.nonNulls.toList()));
    });
    return products;
  }

  static Future<void> displaySubscriptionCancellationInstruction() async {
    await _channel.invokeMethod('displaySubscriptionCancellationInstruction');
  }

  static Future<List<PLYSubscription>> userSubscriptions() async {
    final List<dynamic> result =
        await _channel.invokeMethod('userSubscriptions');

    final List<PLYSubscription> subscriptions = new List.empty(growable: true);
    result.forEach((element) {
      final List<PLYPlan?> plans = new List.empty(growable: true);

      var product = null;
      if (element['product'] != null) {
        element['product']['plans']
            ?.forEach((k, plan) => plans.add(transformToPLYPlan(plan)));

        product = PLYProduct(element['product']['name'],
            element['product']['vendorId'], plans.nonNulls.toList());
      }

      subscriptions.add(PLYSubscription(
          element['purchaseToken'],
          PLYSubscriptionSource.values[element['subscriptionSource']],
          element['nextRenewalDate'],
          element['cancelledDate'],
          transformToPLYPlan(element['plan']),
          product,
          null,
          null,
          null,
          null));
    });
    return subscriptions;
  }

  static Future<List<PLYSubscription>> userSubscriptionsHistory() async {
    final List<dynamic> result =
        await _channel.invokeMethod('userSubscriptionsHistory');

    final List<PLYSubscription> subscriptions = new List.empty(growable: true);
    result.forEach((element) {
      final List<PLYPlan?> plans = new List.empty(growable: true);

      var product = null;
      if (element['product'] != null) {
        element['product']['plans']
            ?.forEach((k, plan) => plans.add(transformToPLYPlan(plan)));

        product = PLYProduct(element['product']['name'],
            element['product']['vendorId'], plans.nonNulls.toList());
      }

      subscriptions.add(PLYSubscription(
        element['purchaseToken'],
        PLYSubscriptionSource.values[element['subscriptionSource']],
        element['nextRenewalDate'],
        element['cancelledDate'],
        transformToPLYPlan(element['plan']),
        product,
        element['cumulatedRevenuesInUSD'],
        element['subscriptionDurationInDays'],
        element['subscriptionDurationInWeeks'],
        element['subscriptionDurationInMonths'],
      ));
    });
    return subscriptions;
  }

  static Future<bool> handleDeeplink(String deepLink) async {
    return await _channel.invokeMethod(
        'handleDeeplink', <String, dynamic>{'deeplink': deepLink});
  }

  static void listenToEvents(Function(PLYEvent) block) {
    events = _stream.receiveBroadcastStream().listen((event) {
      PLYEventName eventName = PLYEventName.APP_CONFIGURED;
      try {
        eventName = PLYEventName.values
            .firstWhere((e) => e.toString() == 'PLYEventName.' + event['name']);
      } catch (e) {
        print("Error $e because event ${event['name']} is not found");
      }

      block(PLYEvent(
          eventName, transformToPLYEventProperties(event['properties'])));
    });
  }

  static void stopListeningToEvents() {
    events.cancel();
  }

  static void listenToPurchases(Function block) {
    purchases = _purchases.receiveBroadcastStream().listen((event) {
      block(event);
    });
  }

  static void stopListeningToPurchases() {
    purchases.cancel();
  }

  static Future<void> setAttribute(PLYAttribute attribute, String value) async {
    return await _channel.invokeMethod('setAttribute',
        <String, dynamic>{'attribute': attribute.index, 'value': value});
  }

  static Future<bool> isAnonymous() async {
    final bool isAnonymous = await _channel.invokeMethod('isAnonymous');
    return isAnonymous;
  }

  static Future<bool> isEligibleForIntroOffer(String planVendorId) async {
    final bool isEligible = await _channel.invokeMethod(
        'isEligibleForIntroOffer',
        <String, dynamic>{'planVendorId': planVendorId});
    return isEligible;
  }

  static Future<void> userDidConsumeSubscriptionContent() async {
    return await _channel.invokeMethod('userDidConsumeSubscriptionContent');
  }

  static Future<void> setUserAttributeWithString(String key, String value,
      {PLYDataProcessingLegalBasis processingLegalBasis =
          PLYDataProcessingLegalBasis.optional}) async {
    _channel.invokeMethod('setUserAttributeWithString', <String, dynamic>{
      'key': key,
      'value': value,
      'processingLegalBasis':
          mapDataProcessingLegalBasisToString(processingLegalBasis)
    });
  }

  static Future<void> setUserAttributeWithInt(String key, int value,
      {PLYDataProcessingLegalBasis processingLegalBasis =
          PLYDataProcessingLegalBasis.optional}) async {
    _channel.invokeMethod('setUserAttributeWithInt', <String, dynamic>{
      'key': key,
      'value': value,
      'processingLegalBasis':
          mapDataProcessingLegalBasisToString(processingLegalBasis)
    });
  }

  static Future<void> setUserAttributeWithDouble(String key, double value,
      {PLYDataProcessingLegalBasis processingLegalBasis =
          PLYDataProcessingLegalBasis.optional}) async {
    _channel.invokeMethod('setUserAttributeWithDouble', <String, dynamic>{
      'key': key,
      'value': value,
      'processingLegalBasis':
          mapDataProcessingLegalBasisToString(processingLegalBasis)
    });
  }

  static Future<void> setUserAttributeWithBoolean(String key, bool value,
      {PLYDataProcessingLegalBasis processingLegalBasis =
          PLYDataProcessingLegalBasis.optional}) async {
    _channel.invokeMethod('setUserAttributeWithBoolean', <String, dynamic>{
      'key': key,
      'value': value,
      'processingLegalBasis':
          mapDataProcessingLegalBasisToString(processingLegalBasis)
    });
  }

  static Future<void> setUserAttributeWithStringArray(
      String key, List<String> value,
      {PLYDataProcessingLegalBasis processingLegalBasis =
          PLYDataProcessingLegalBasis.optional}) async {
    _channel.invokeMethod('setUserAttributeWithStringArray', <String, dynamic>{
      'key': key,
      'value': value,
      'processingLegalBasis':
          mapDataProcessingLegalBasisToString(processingLegalBasis)
    });
  }

  static Future<void> setUserAttributeWithIntArray(String key, List<int> value,
      {PLYDataProcessingLegalBasis processingLegalBasis =
          PLYDataProcessingLegalBasis.optional}) async {
    _channel.invokeMethod('setUserAttributeWithIntArray', <String, dynamic>{
      'key': key,
      'value': value,
      'processingLegalBasis':
          mapDataProcessingLegalBasisToString(processingLegalBasis)
    });
  }

  static Future<void> setUserAttributeWithDoubleArray(
      String key, List<double> value,
      {PLYDataProcessingLegalBasis processingLegalBasis =
          PLYDataProcessingLegalBasis.optional}) async {
    _channel.invokeMethod('setUserAttributeWithDoubleArray', <String, dynamic>{
      'key': key,
      'value': value,
      'processingLegalBasis':
          mapDataProcessingLegalBasisToString(processingLegalBasis)
    });
  }

  static Future<void> setUserAttributeWithBooleanArray(
      String key, List<bool> value,
      {PLYDataProcessingLegalBasis processingLegalBasis =
          PLYDataProcessingLegalBasis.optional}) async {
    _channel.invokeMethod('setUserAttributeWithBooleanArray', <String, dynamic>{
      'key': key,
      'value': value,
      'processingLegalBasis':
          mapDataProcessingLegalBasisToString(processingLegalBasis)
    });
  }

  static Future<void> setUserAttributeWithDate(String key, DateTime value,
      {PLYDataProcessingLegalBasis processingLegalBasis =
          PLYDataProcessingLegalBasis.optional}) async {
    DateTime date = DateTime(value.year, value.month, value.day, value.hour,
            value.minute, value.second, value.millisecond)
        .toUtc();
    _channel.invokeMethod('setUserAttributeWithDate', <String, dynamic>{
      'key': key,
      'value': date.toIso8601String(),
      'processingLegalBasis':
          mapDataProcessingLegalBasisToString(processingLegalBasis)
    });
  }

  static Future<void> incrementUserAttribute(String key,
      {int value = 1,
      PLYDataProcessingLegalBasis processingLegalBasis =
          PLYDataProcessingLegalBasis.optional}) async {
    _channel.invokeMethod('incrementUserAttribute', <String, dynamic>{
      'key': key,
      'value': value,
      'processingLegalBasis':
          mapDataProcessingLegalBasisToString(processingLegalBasis)
    });
  }

  static Future<void> decrementUserAttribute(String key,
      {int value = 1,
      PLYDataProcessingLegalBasis processingLegalBasis =
          PLYDataProcessingLegalBasis.optional}) async {
    _channel.invokeMethod('decrementUserAttribute', <String, dynamic>{
      'key': key,
      'value': value,
      'processingLegalBasis':
          mapDataProcessingLegalBasisToString(processingLegalBasis)
    });
  }

  static Future<dynamic> userAttribute(String key) async {
    dynamic value = await _channel
        .invokeMethod('userAttribute', <String, dynamic>{'key': key});

    try {
      value = DateTime.parse(value);
    } catch (FormatException) {
      //do nothing it is not a date
    }

    return value;
  }

  static Future<Map<dynamic, dynamic>> userAttributes() async {
    Map<dynamic, dynamic> attributes =
        await _channel.invokeMethod('userAttributes');

    return attributes.map((key, value) {
      dynamic attributeValue = value;
      try {
        attributeValue = DateTime.parse(value);
      } catch (FormatException) {
        //do nothing it is not a date
      }
      return MapEntry(key, attributeValue);
    });
  }

  static void clearUserAttribute(String key) async {
    _channel.invokeMethod('clearUserAttribute', <String, dynamic>{'key': key});
  }

  static void clearUserAttributes() async {
    _channel.invokeMethod('clearUserAttributes');
  }

  static void clearBuiltInAttributes() async {
    _channel.invokeMethod('clearBuiltInAttributes');
  }

  static Future<void> setThemeMode(PLYThemeMode mode) async {
    return await _channel
        .invokeMethod('setThemeMode', <String, dynamic>{'mode': mode.index});
  }

  static Future<bool> setDynamicOffering(PLYDynamicOffering offering) async {
    return await _channel.invokeMethod('setDynamicOffering', <String, dynamic>{
      'reference': offering.reference,
      'planVendorId': offering.planVendorId,
      'offerVendorId': offering.offerVendorId
    });
  }

  static Future<List<PLYDynamicOffering>> getDynamicOfferings() async {
    return transformToDynamicOfferings(await _channel
        .invokeListMethod<Map<dynamic, dynamic>>('getDynamicOfferings'));
  }

  static void removeDynamicOffering(String reference) async {
    _channel.invokeMethod(
        'removeDynamicOffering', <String, dynamic>{'reference': reference});
  }

  static void clearDynamicOfferings() async {
    _channel.invokeMethod('clearDynamicOfferings');
  }

  static void revokeDataProcessingConsent(
      List<PLYDataProcessingPurpose> purposes) {
    List<String> mappedPurposes = purposes
        .map((purpose) => mapDataProcessingPurposeToString(purpose))
        .toList();
    _channel.invokeMethod('revokeDataProcessingConsent',
        <String, dynamic>{'purposes': mappedPurposes});
  }

  static Future<void> setDebugMode(bool debugMode) async {
    return await _channel.invokeMethod(
        'setDebugMode', <String, dynamic>{'debugMode': debugMode});
  }

  // -- Private Methods --

  static PLYPlan? transformToPLYPlan(Map<dynamic, dynamic> plan) =>
      plyPlanFromMap(plan);

  static PLYPromoOffer? transformToPLYPromoOffer(Map<dynamic, dynamic> offer) =>
      plyPromoOfferFromMap(offer);

  static PLYSubscriptionOffer? transformToPLYSubscription(
          Map<dynamic, dynamic> subscriptionOffer) =>
      plySubscriptionOfferFromMap(subscriptionOffer);

  static List<PLYDynamicOffering> transformToDynamicOfferings(
      List<Map<dynamic, dynamic>>? offerings) {
    if (offerings == null || offerings.isEmpty) return List.empty();

    inspect(offerings);

    print('Transforming dynamic offerings: $offerings');

    List<PLYDynamicOffering> dynamicOfferings = [];
    offerings.forEach((offering) {
      String? reference = offering['reference'];
      String? planVendorId = offering['planVendorId'];

      if (reference == null || planVendorId == null) {
        print('Invalid dynamic offering: $offering');
        return;
      }

      dynamicOfferings.add(PLYDynamicOffering(
          reference, planVendorId, offering['offerVendorId']));
    });
    return dynamicOfferings;
  }

  static PLYEventProperties transformToPLYEventProperties(
      Map<dynamic, dynamic> properties) {
    PLYEventName eventName = PLYEventName.APP_CONFIGURED;
    try {
      eventName = PLYEventName.values.firstWhere(
          (e) => e.toString() == 'PLYEventName.' + properties['event_name']);
    } catch (e) {
      print(e);
    }

    List<PLYEventPropertyPlan> plans = new List.empty(growable: true);
    properties['purchasable_plans']?.forEach((element) => plans.add(
        PLYEventPropertyPlan(
            element['type'],
            element['purchasely_plan_id'],
            element['store'],
            element['store_country'],
            element['store_product_id'],
            element['price_in_customer_currency'],
            element['customer_currency'],
            element['period'],
            element['duration'],
            element['intro_price_in_customer_currency'],
            element['intro_period'],
            element['intro_duration'],
            element['has_free_trial'],
            element['free_trial_period'],
            element['free_trial_duration'],
            element['discount_referent'],
            element['discount_percentage_comparison_to_referent'],
            element['discount_price_comparison_to_referent'],
            element['is_default'])));

    List<PLYEventPropertyCarousel> carousels = new List.empty(growable: true);
    properties['carousels']?.forEach((element) {
      bool isAutoPlaying = element['is_carousel_auto_playing'] ?? false;
      carousels.add(PLYEventPropertyCarousel(
          element['selected_slide'],
          element['number_of_slides'],
          isAutoPlaying,
          element['default_slide'],
          element['previous_slide']));
    });

    List<PLYEventPropertySubscription> subscriptions =
        new List.empty(growable: true);
    properties['running_subscriptions']?.forEach((element) => subscriptions.add(
        PLYEventPropertySubscription(element['plan'], element['product'])));

    final displayedOptions = (properties['displayed_options'] as List?)
        ?.map((e) => e.toString())
        .toList();
    final selectedOptions = (properties['selected_options'] as List?)
        ?.map((e) => e.toString())
        .toList();

    return PLYEventProperties(
      properties['sdk_version'],
      eventName,
      properties['event_created_at'],
      properties['displayed_presentation'],
      properties['user_id'],
      properties['anonymous_user_id'],
      plans,
      properties['deeplink_identifier'],
      properties['source_identifier'],
      properties['selected_plan'],
      properties['previous_selected_plan'],
      properties['selected_presentation'],
      properties['previous_selected_presentation'],
      properties['link_identifier'],
      carousels,
      properties['language'],
      properties['device'],
      properties['os_version'],
      properties['device_type'],
      properties['error_message'],
      properties['cancellation_reason_id'],
      properties['cancellation_reason'],
      properties['plan'],
      properties['selected_product'],
      properties['plan_change_type'],
      subscriptions,
      properties['selected_option_id'],
      selectedOptions,
      displayedOptions,
      properties['web_checkout_provider'],
    );
  }

  static String mapDataProcessingLegalBasisToString(
      PLYDataProcessingLegalBasis processingLegalBasis) {
    switch (processingLegalBasis) {
      case PLYDataProcessingLegalBasis.essential:
        return "ESSENTIAL";
      case PLYDataProcessingLegalBasis.optional:
        return "OPTIONAL";
    }
  }

  static String mapDataProcessingPurposeToString(
      PLYDataProcessingPurpose purpose) {
    switch (purpose) {
      case PLYDataProcessingPurpose.allNonEssentials:
        return "ALL_NON_ESSENTIALS";
      case PLYDataProcessingPurpose.analytics:
        return "ANALYTICS";
      case PLYDataProcessingPurpose.identifiedAnalytics:
        return "IDENTIFIED_ANALYTICS";
      case PLYDataProcessingPurpose.campaigns:
        return "CAMPAIGNS";
      case PLYDataProcessingPurpose.personalization:
        return "PERSONALIZATION";
      case PLYDataProcessingPurpose.thirdPartyIntegrations:
        return "THIRD_PARTY_INTEGRATIONS";
    }
  }
}

// -- ENUMS --

enum PLYAttribute {
  firebase_app_instance_id,
  airship_channel_id,
  airship_user_id,
  batch_installation_id,
  adjust_id,
  appsflyer_id,
  mixpanel_distinct_id,
  clever_tap_id,
  sendinblueUserEmail,
  iterableUserEmail,
  iterableUserId,
  atInternetIdClient,
  mParticleUserId,
  customerioUserId,
  customerioUserEmail,
  branchUserDeveloperIdentity,
  amplitudeUserId,
  amplitudeDeviceId,
  moengageUniqueId,
  oneSignalExternalId,
  batchCustomUserId,
}

enum PLYDataProcessingLegalBasis { essential, optional }

enum PLYDataProcessingPurpose {
  allNonEssentials,
  analytics,
  identifiedAnalytics,
  campaigns,
  personalization,
  thirdPartyIntegrations
}

enum PLYThemeMode { light, dark, system }

enum PLYSubscriptionSource {
  appleAppStore,
  googlePlayStore,
  amazonAppstore,
  huaweiAppGallery,
  none
}

enum PLYEventName {
  APP_INSTALLED,
  APP_CONFIGURED,
  APP_UPDATED,
  APP_STARTED,
  CANCELLATION_REASON_PUBLISHED,
  IN_APP_PURCHASING,
  IN_APP_PURCHASED,
  IN_APP_RESTORED,
  IN_APP_DEFERRED,
  IN_APP_PURCHASE_FAILED,
  IN_APP_NOT_AVAILABLE,
  IN_APP_RENEWED,
  PURCHASE_CANCELLED_BY_APP,
  CAROUSEL_SLIDE_SWIPED,
  DEEPLINK_OPENED,
  LINK_OPENED,
  LOGIN_TAPPED,
  PLAN_SELECTED,
  OPTIONS_SELECTED,
  OPTIONS_VALIDATED,
  PRESENTATION_VIEWED,
  PRESENTATION_OPENED,
  PRESENTATION_SELECTED,
  PRESENTATION_LOADED,
  PRESENTATION_CLOSED,
  PROMO_CODE_TAPPED,
  PURCHASE_CANCELLED,
  PURCHASE_TAPPED,
  RESTORE_TAPPED,
  RECEIPT_CREATED,
  RECEIPT_VALIDATED,
  RECEIPT_FAILED,
  RESTORE_STARTED,
  RESTORE_SUCCEEDED,
  RESTORE_FAILED,
  STORE_PRODUCT_FETCH_FAILED,
  SUBSCRIPTION_CONTENT_USED,
  SUBSCRIPTIONS_LIST_VIEWED,
  SUBSCRIPTION_DETAILS_VIEWED,
  SUBSCRIPTION_CANCEL_TAPPED,
  SUBSCRIPTION_PLAN_TAPPED,
  SUBSCRIPTIONS_TRANSFERRED,
  USER_LOGGED_IN,
  USER_LOGGED_OUT,
  WEB_CHECKOUT_OPENED_IN_WEB_BROWSER,
  WEB_CHECKOUT_ERROR,
  WEB_CHECKOUT_TAPPED,
  WEB_CHECKOUT_TIMED_OUT
}

enum PLYUserAttributeSource {
  purchasely,
  client,
}

enum PLYUserAttributeType {
  string,
  int,
  float,
  bool,
  date,
  stringArray,
  intArray,
  floatArray,
  boolArray,
}

// -- CLASSES --

class PLYProduct {
  String name;
  String vendorId;
  List<PLYPlan> plans;

  PLYProduct(this.name, this.vendorId, this.plans);
}

class PLYSubscription {
  String? purchaseToken;
  PLYSubscriptionSource? subscriptionSource;
  String? nextRenewalDate;
  String? cancelledDate;
  PLYPlan? plan;
  PLYProduct? product;
  double? cumulatedRevenuesInUSD = null;
  int? subscriptionDurationInDays = null;
  int? subscriptionDurationInWeeks = null;
  int? subscriptionDurationInMonths = null;

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

class PLYEventPropertyPlan {
  String? type;
  String? purchasely_plan_id;
  String? store;
  String? store_country;
  String? store_product_id;
  double? price_in_customer_currency;
  String? customer_currency;
  String? period;
  int? duration;
  double? intro_price_in_customer_currency;
  String? intro_period;
  int? intro_duration;
  bool? has_free_trial;
  String? free_trial_period;
  int? free_trial_duration;
  String? discount_referent;
  String? discount_percentage_comparison_to_referent;
  String? discount_price_comparison_to_referent;
  bool? is_default;
  PLYEventPropertyPlan(
      this.type,
      this.purchasely_plan_id,
      this.store,
      this.store_country,
      this.store_product_id,
      this.price_in_customer_currency,
      this.customer_currency,
      this.period,
      this.duration,
      this.intro_price_in_customer_currency,
      this.intro_period,
      this.intro_duration,
      this.has_free_trial,
      this.free_trial_period,
      this.free_trial_duration,
      this.discount_referent,
      this.discount_percentage_comparison_to_referent,
      this.discount_price_comparison_to_referent,
      this.is_default);
}

class PLYEvent {
  PLYEventName name;
  PLYEventProperties properties;

  PLYEvent(this.name, this.properties);
}

class PLYEventProperties {
  String? sdk_version;
  PLYEventName event_name;
  String event_created_at;
  String? displayed_presentation;
  String? user_id;
  String? anonymous_user_id;
  List<PLYEventPropertyPlan>? purchasable_plans;
  String? deeplink_identifier;
  String? source_identifier;
  String? selected_plan;
  String? previous_selected_plan;
  String? selected_presentation;
  String? previous_selected_presentation;
  String? link_identifier;
  List<PLYEventPropertyCarousel> carousels;
  String? language;
  String? device;
  String? os_version;
  String? device_type;
  String? error_message;
  String? cancellation_reason_id;
  String? cancellation_reason;
  String? plan;
  String? selected_product;
  String? plan_change_type;
  List<PLYEventPropertySubscription> running_subscriptions;
  String? selected_option_id;
  List<String>? selected_options;
  List<String>? displayed_options;
  String? webCheckoutProvider;

  PLYEventProperties(
      this.sdk_version,
      this.event_name,
      this.event_created_at,
      this.displayed_presentation,
      this.user_id,
      this.anonymous_user_id,
      this.purchasable_plans,
      this.deeplink_identifier,
      this.source_identifier,
      this.selected_plan,
      this.previous_selected_plan,
      this.selected_presentation,
      this.previous_selected_presentation,
      this.link_identifier,
      this.carousels,
      this.language,
      this.device,
      this.os_version,
      this.device_type,
      this.error_message,
      this.cancellation_reason_id,
      this.cancellation_reason,
      this.plan,
      this.selected_product,
      this.plan_change_type,
      this.running_subscriptions,
      this.selected_option_id,
      this.selected_options,
      this.displayed_options,
      this.webCheckoutProvider);
}

class PLYEventPropertyCarousel {
  int? selected_slide;
  int? number_of_slides;
  bool is_carousel_auto_playing;
  int? default_slide;
  int? previous_slide;

  PLYEventPropertyCarousel(this.selected_slide, this.number_of_slides,
      this.is_carousel_auto_playing, this.default_slide, this.previous_slide);
}

class PLYEventPropertySubscription {
  String? plan;
  String? product;

  PLYEventPropertySubscription(this.plan, this.product);
}

abstract class UserAttributeListener {
  void onUserAttributeSet(String key, PLYUserAttributeType type, dynamic value,
      PLYUserAttributeSource source);

  void onUserAttributeRemoved(String key, PLYUserAttributeSource source);
}

class PLYDynamicOffering {
  String reference;
  String planVendorId;
  String? offerVendorId;

  PLYDynamicOffering(this.reference, this.planVendorId, this.offerVendorId);

  Map<String, dynamic> toJson() => {
        'reference': reference,
        'planVendorId': planVendorId,
        'offerVendorId': offerVendorId,
      };

  @override
  String toString() {
    return 'PLYDynamicOffering(reference: $reference, planVendorId: $planVendorId, offerVendorId: $offerVendorId)';
  }
}
