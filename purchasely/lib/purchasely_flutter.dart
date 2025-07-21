import 'dart:async';
import 'dart:developer';

import 'package:flutter/services.dart';
import 'package:collection/collection.dart';

import 'native_view_widget.dart';

class Purchasely {
  static const MethodChannel _channel = const MethodChannel('purchasely');
  static const EventChannel _stream = EventChannel('purchasely-events');
  static const EventChannel _purchases = EventChannel('purchasely-purchases');
  static const EventChannel _userAttributesChannel =
      EventChannel('purchasely-user-attributes');

  static UserAttributeListener? _userAttributeListener;

  static var events;
  static var purchases;

  // --- Public Methods ---

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

  static Future<bool> start(
      {required final String apiKey,
      final List<String>? androidStores = const ['Google'],
      required bool storeKit1,
      final String? userId,
      final PLYLogLevel logLevel = PLYLogLevel.error,
      final PLYRunningMode runningMode = PLYRunningMode.full}) async {
    return await _channel.invokeMethod('start', <String, dynamic>{
      'apiKey': apiKey,
      'stores': androidStores,
      'storeKit1': storeKit1,
      'userId': userId,
      'logLevel': logLevel.index,
      'runningMode': runningMode.index
    });
  }

  static Future<PLYPresentation?> fetchPresentation(String? placementId,
      {String? presentationId, String? contentId}) async {
    final result =
        await _channel.invokeMethod('fetchPresentation', <String, dynamic>{
      'placementVendorId': placementId,
      'presentationVendorId': presentationId,
      'contentId': contentId
    });

    return transformToPLYPresentation(result);
  }

  static Future<void> display(PLYPresentation? presentation) async {
    return await _channel.invokeMethod('display', <String, dynamic>{
      'presentation': transformPLYPresentationToMap(presentation)
    });
  }

  static Future<PresentPresentationResult> presentPresentation(
      PLYPresentation? presentation,
      {bool isFullscreen = false}) async {
    final result =
        await _channel.invokeMethod('presentPresentation', <String, dynamic>{
      'presentation': transformPLYPresentationToMap(presentation),
      'isFullscreen': isFullscreen
    });
    return PresentPresentationResult(PLYPurchaseResult.values[result['result']],
        transformToPLYPlan(result['plan']));
  }

  static PLYPresentationView? getPresentationView({
    PLYPresentation? presentation,
    String? presentationId,
    String? placementId,
    String? contentId,
    Function(PresentPresentationResult)? callback,
  }) {
    return PLYPresentationView(
        presentation: presentation,
        presentationId: presentationId,
        placementId: placementId,
        contentId: contentId,
        callback: callback);
  }

  static Future<void> clientPresentationDisplayed(
      PLYPresentation presentation) async {
    return await _channel.invokeMethod(
        'clientPresentationDisplayed', <String, dynamic>{
      'presentation': transformPLYPresentationToMap(presentation)
    });
  }

  static Future<void> clientPresentationClosed(
      PLYPresentation presentation) async {
    return await _channel.invokeMethod(
        'clientPresentationClosed', <String, dynamic>{
      'presentation': transformPLYPresentationToMap(presentation)
    });
  }

  static Future<PresentPresentationResult> presentPresentationWithIdentifier(
      String? presentationVendorId,
      {String? contentId,
      bool isFullscreen = false}) async {
    final result = await _channel
        .invokeMethod('presentPresentationWithIdentifier', <String, dynamic>{
      'presentationVendorId': presentationVendorId,
      'contentId': contentId,
      'isFullscreen': isFullscreen
    });
    return PresentPresentationResult(PLYPurchaseResult.values[result['result']],
        transformToPLYPlan(result['plan']));
  }

  static Future<PresentPresentationResult> presentPresentationForPlacement(
      String? placementVendorId,
      {String? contentId,
      bool isFullscreen = false}) async {
    final result = await _channel
        .invokeMethod('presentPresentationForPlacement', <String, dynamic>{
      'placementVendorId': placementVendorId,
      'contentId': contentId,
      'isFullscreen': isFullscreen
    });
    return PresentPresentationResult(PLYPurchaseResult.values[result['result']],
        transformToPLYPlan(result['plan']));
  }

  static Future<PresentPresentationResult> presentProductWithIdentifier(
      String productVendorId,
      {String? presentationVendorId,
      String? contentId,
      bool isFullscreen = false}) async {
    final result = await _channel
        .invokeMethod('presentProductWithIdentifier', <String, dynamic>{
      'productVendorId': productVendorId,
      'presentationVendorId': presentationVendorId,
      'contentId': contentId,
      'isFullscreen': isFullscreen
    });
    PLYPlan? plan;
    if (!result['plan'].isEmpty) plan = transformToPLYPlan(result['plan']);

    return PresentPresentationResult(
        PLYPurchaseResult.values[result['result']], plan);
  }

  static Future<PresentPresentationResult> presentPlanWithIdentifier(
      String planVendorId,
      {String? presentationVendorId,
      String? contentId,
      bool isFullscreen = false}) async {
    final result = await _channel
        .invokeMethod('presentPlanWithIdentifier', <String, dynamic>{
      'planVendorId': planVendorId,
      'presentationVendorId': presentationVendorId,
      'contentId': contentId,
      'isFullscreen': isFullscreen
    });
    return PresentPresentationResult(PLYPurchaseResult.values[result['result']],
        transformToPLYPlan(result['plan']));
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

  static Future<void> synchronize() async {
    return await _channel.invokeMethod('synchronize');
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

  static Future<void> readyToOpenDeeplink(bool readyToOpenDeeplink) async {
    _channel.invokeMethod('readyToOpenDeeplink',
        <String, dynamic>{'readyToOpenDeeplink': readyToOpenDeeplink});
  }

  static Future<void> setLanguage(String language) async {
    _channel
        .invokeMethod('setLanguage', <String, dynamic>{'language': language});
  }

  static Future<void> close() async {
    _channel.invokeMethod('close');
  }

  static Future<PLYProduct> productWithIdentifier(String vendorId) async {
    final Map<dynamic, dynamic> result = await _channel.invokeMethod(
        'productWithIdentifier', <String, dynamic>{'vendorId': vendorId});
    final List<PLYPlan?> plans = new List.empty(growable: true);
    result['plans'].forEach((k, plan) => {plans.add(transformToPLYPlan(plan))});
    return PLYProduct(
        result['name'], result['vendorId'], plans.whereNotNull().toList());
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
          element['name'], element['vendorId'], plans.whereNotNull().toList()));
    });
    return products;
  }

  static Future<void> presentSubscriptions() async {
    _channel.invokeMethod('presentSubscriptions');
  }

  static Future<void> displaySubscriptionCancellationInstruction() async {
    _channel.invokeMethod('displaySubscriptionCancellationInstruction');
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
            element['product']['vendorId'], plans.whereNotNull().toList());
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
            element['product']['vendorId'], plans.whereNotNull().toList());
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

  static Future<bool> isDeeplinkHandled(String deepLink) async {
    return await _channel.invokeMethod(
        'isDeeplinkHandled', <String, dynamic>{'deeplink': deepLink});
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

  static Future<PresentPresentationResult>
      setDefaultPresentationResultHandler() async {
    final result =
        await _channel.invokeMethod('setDefaultPresentationResultHandler');
    return PresentPresentationResult(PLYPurchaseResult.values[result['result']],
        transformToPLYPlan(result['plan']));
  }

  static Future<PaywallActionInterceptorResult>
      setPaywallActionInterceptor() async {
    final result = await _channel.invokeMethod('setPaywallActionInterceptor');
    final Map<dynamic, dynamic>? plan = result['parameters']['plan'];
    final Map<dynamic, dynamic>? offer = result['parameters']['offer'];
    final Map<dynamic, dynamic>? subscriptionOffer =
        result['parameters']['subscriptionOffer'];
    return PaywallActionInterceptorResult(
        PLYPaywallInfo(
            result['info']['contentId'],
            result['info']['presentationId'],
            result['info']['placementId'],
            result['info']['abTestId'],
            result['info']['abTestVariantId']),
        PLYPaywallAction.values.firstWhere(
            (e) => e.toString() == 'PLYPaywallAction.' + result['action']),
        PLYPaywallActionParameters(
            result['parameters']['url'],
            result['parameters']['title'],
            plan != null ? transformToPLYPlan(plan) : null,
            offer != null ? transformToPLYPromoOffer(offer) : null,
            subscriptionOffer != null
                ? transformToPLYSubscription(subscriptionOffer)
                : null,
            result['parameters']['presentation']));
  }

  static Future<void> onProcessAction(bool processAction) async {
    return await _channel.invokeMethod(
        'onProcessAction', <String, dynamic>{'processAction': processAction});
  }

  static Future<void> closePresentation() async {
    return await _channel.invokeMethod('closePresentation');
  }

  static Future<void> hidePresentation() async {
    return await _channel.invokeMethod('hidePresentation');
  }

  static Future<void> showPresentation() async {
    return await _channel.invokeMethod('showPresentation');
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

  static Future<void> setUserAttributeWithString(
      String key, String value) async {
    _channel.invokeMethod('setUserAttributeWithString',
        <String, dynamic>{'key': key, 'value': value});
  }

  static Future<void> setUserAttributeWithInt(String key, int value) async {
    _channel.invokeMethod('setUserAttributeWithInt',
        <String, dynamic>{'key': key, 'value': value});
  }

  static Future<void> setUserAttributeWithDouble(
      String key, double value) async {
    _channel.invokeMethod('setUserAttributeWithDouble',
        <String, dynamic>{'key': key, 'value': value});
  }

  static Future<void> setUserAttributeWithBoolean(
      String key, bool value) async {
    _channel.invokeMethod('setUserAttributeWithBoolean',
        <String, dynamic>{'key': key, 'value': value});
  }

  static Future<void> setUserAttributeWithStringArray(
      String key, List<String> value) async {
    _channel.invokeMethod('setUserAttributeWithStringArray',
        <String, dynamic>{'key': key, 'value': value});
  }

  static Future<void> setUserAttributeWithIntArray(
      String key, List<int> value) async {
    _channel.invokeMethod('setUserAttributeWithIntArray',
        <String, dynamic>{'key': key, 'value': value});
  }

  static Future<void> setUserAttributeWithDoubleArray(
      String key, List<double> value) async {
    _channel.invokeMethod('setUserAttributeWithDoubleArray',
        <String, dynamic>{'key': key, 'value': value});
  }

  static Future<void> setUserAttributeWithBooleanArray(
      String key, List<bool> value) async {
    _channel.invokeMethod('setUserAttributeWithBooleanArray',
        <String, dynamic>{'key': key, 'value': value});
  }

  static Future<void> setUserAttributeWithDate(
      String key, DateTime value) async {
    DateTime date = DateTime(value.year, value.month, value.day, value.hour,
            value.minute, value.second, value.millisecond)
        .toUtc();
    _channel.invokeMethod('setUserAttributeWithDate',
        <String, dynamic>{'key': key, 'value': date.toIso8601String()});
  }

  static Future<void> incrementUserAttribute(String key,
      {int value = 1}) async {
    _channel.invokeMethod('incrementUserAttribute',
        <String, dynamic>{'key': key, 'value': value});
  }

  static Future<void> decrementUserAttribute(String key,
      {int value = 1}) async {
    _channel.invokeMethod('decrementUserAttribute',
        <String, dynamic>{'key': key, 'value': value});
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

  static void setDefaultPresentationResultCallback(Function callback) {
    setDefaultPresentationResultHandler().then((value) {
      setDefaultPresentationResultCallback(callback);
      try {
        callback();
      } catch (e) {
        print(
            '[Purchasely] Error with callback for default presentation result handler: $e');
      }
    });
  }

  static void setPaywallActionInterceptorCallback(Function callback) {
    setPaywallActionInterceptor().then((value) {
      setPaywallActionInterceptorCallback(callback);
      try {
        callback(value);
      } catch (e) {
        print(
            '[Purchasely] Error with callback for paywall action interceptor handler: $e');
      }
    });
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

  // -- Private Methods --

  static PLYPlan? transformToPLYPlan(Map<dynamic, dynamic> plan) {
    if (plan.isEmpty) return null;

    PLYPlanType type = PLYPlanType.unknown;
    try {
      type = PLYPlanType.values[plan['type']];
    } catch (e) {
      print(e);
    }
    return PLYPlan(
        plan['vendorId'],
        plan['productId'],
        plan['name'],
        type,
        plan['amount'],
        plan['localizedAmount'],
        plan['currencyCode'],
        plan['currencySymbol'],
        plan['price'],
        plan['period'],
        plan['hasIntroductoryPrice'],
        plan['introPrice'],
        plan['introAmount'],
        plan['introDuration'],
        plan['introPeriod'],
        plan['hasFreeTrial']);
  }

  static PLYPromoOffer? transformToPLYPromoOffer(Map<dynamic, dynamic> offer) {
    if (offer.isEmpty) return null;

    return PLYPromoOffer(
      offer['vendorId'],
      offer['storeOfferId'],
    );
  }

  static PLYSubscriptionOffer? transformToPLYSubscription(
      Map<dynamic, dynamic> subscriptionOffer) {
    if (subscriptionOffer.isEmpty) return null;

    return PLYSubscriptionOffer(
      subscriptionOffer['subscriptionId'],
      subscriptionOffer['basePlanId'],
      subscriptionOffer['offerToken'],
      subscriptionOffer['offerId'],
    );
  }

  static PLYPresentation? transformToPLYPresentation(
      Map<dynamic, dynamic> presentation) {
    if (presentation.isEmpty) return null;

    PLYPresentationType type = PLYPresentationType.normal;
    try {
      type = PLYPresentationType.values[presentation['type']];
    } catch (e) {
      print(e);
    }

    List<PLYPresentationPlan> plans = (presentation['plans'] as List)
        .map((e) => PLYPresentationPlan(e['planVendorId'], e['storeProductId'],
            e['basePlanId'], e['offerId']))
        .toList();

    Map<String, dynamic> metadata = {};
    presentation['metadata']?.forEach((key, value) {
      metadata[key] = value;
    });

    return PLYPresentation(
        presentation['id'],
        presentation['placementId'],
        presentation['audienceId'],
        presentation['abTestId'],
        presentation['abTestVariantId'],
        presentation['language'],
        presentation['height'] ?? 0,
        type,
        plans,
        metadata);
  }

  static Map<dynamic, dynamic> transformPLYPresentationToMap(
      PLYPresentation? presentation) {
    var presentationMap = new Map();

    presentationMap['id'] = presentation?.id;
    presentationMap['placementId'] = presentation?.placementId;
    presentationMap['audienceId'] = presentation?.audienceId;
    presentationMap['abTestId'] = presentation?.abTestId;
    presentationMap['abTestVariantId'] = presentation?.abTestVariantId;
    presentationMap['language'] = presentation?.language;
    presentationMap['type'] = presentation?.type.index;

    // Need to convert to list of map if we want to send it over to native bridge
    //presentationMap['plans'] = presentation?.plans;

    // No need to send metadata
    //presentationMap['metadata'] = presentation?.metadata;

    return presentationMap;
  }

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
    );
  }
}

// -- ENUMS --

enum PLYLogLevel { debug, info, warn, error }

enum PLYRunningMode { transactionOnly, observer, paywallObserver, full }

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

enum PLYThemeMode { light, dark, system }

enum PLYPurchaseResult { purchased, cancelled, restored }

enum PLYPresentationType { normal, fallback, deactivated, client }

enum PLYSubscriptionSource {
  appleAppStore,
  googlePlayStore,
  amazonAppstore,
  huaweiAppGallery,
  none
}

enum PLYPlanType {
  consumable,
  nonConsumable,
  autoRenewingSubscription,
  nonRenewingSubscription,
  unknown
}

enum PLYPaywallAction {
  close,
  login,
  navigate,
  purchase,
  restore,
  open_presentation,
  promo_code,
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
  USER_LOGGED_OUT
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

class PLYPlan {
  String? vendorId;
  String? productId;
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
      this.hasFreeTrial);
}

class PLYPromoOffer {
  String? vendorId;
  String? storeOfferId;

  PLYPromoOffer(this.vendorId, this.storeOfferId);
}

class PLYSubscriptionOffer {
  String subscriptionId;
  String? basePlanId;
  String? offerToken;
  String? offerId;

  PLYSubscriptionOffer(
      this.subscriptionId, this.basePlanId, this.offerToken, this.offerId);
}

class PLYProduct {
  String name;
  String vendorId;
  List<PLYPlan> plans;

  PLYProduct(this.name, this.vendorId, this.plans);
}

class PLYPresentationPlan {
  String? planVendorId;
  String? storeProductId;
  String? basePlanId;
  String? offerId;

  PLYPresentationPlan(
      this.planVendorId, this.storeProductId, this.basePlanId, this.offerId);

  Map<String, dynamic> toMap() {
    return {
      'planVendorId': planVendorId,
      'storeProductId': storeProductId,
      'basePlanId': basePlanId,
      'offerId': offerId,
    };
  }
}

class PLYPresentation {
  String? id;
  String? placementId;
  String? audienceId;
  String? abTestId;
  String? abTestVariantId;
  String language;
  int height = 0;
  PLYPresentationType type;
  List<PLYPresentationPlan>? plans;
  Map<String, dynamic> metadata;

  PLYPresentation(
      this.id,
      this.placementId,
      this.audienceId,
      this.abTestId,
      this.abTestVariantId,
      this.language,
      this.height,
      this.type,
      this.plans,
      this.metadata);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'placementId': placementId,
      'audienceId': audienceId,
      'abTestId': abTestId,
      'abTestVariantId': abTestVariantId,
      'language': language,
      'height': height,
      'type': type.toString(),
      'plans': plans?.map((plan) => plan.toMap()).toList(),
      'metadata': metadata,
    };
  }
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

class PresentPresentationResult {
  PLYPurchaseResult result;
  PLYPlan? plan;

  PresentPresentationResult(this.result, this.plan);
}

class PaywallActionInterceptorResult {
  PLYPaywallInfo info;
  PLYPaywallAction action;
  PLYPaywallActionParameters parameters;

  PaywallActionInterceptorResult(this.info, this.action, this.parameters);
}

class PLYPaywallActionParameters {
  String? url;
  String? title;
  PLYPlan? plan;
  PLYPromoOffer? offer;
  PLYSubscriptionOffer? subscriptionOffer;
  String? presentation;

  PLYPaywallActionParameters(this.url, this.title, this.plan, this.offer,
      this.subscriptionOffer, this.presentation);
}

class PLYPaywallInfo {
  String? contentId;
  String? presentationId;
  String? placementId;
  String? abTestId;
  String? abTestVariantId;

  PLYPaywallInfo(this.contentId, this.presentationId, this.placementId,
      this.abTestId, this.abTestVariantId);
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
      this.displayed_options);
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
