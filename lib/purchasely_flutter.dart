import 'dart:async';

import 'package:flutter/services.dart';
import 'package:collection/collection.dart';

class Purchasely {
  static const MethodChannel _channel = const MethodChannel('purchasely');
  static const EventChannel _stream = EventChannel('purchasely-events');
  static const EventChannel _purchases = EventChannel('purchasely-purchases');

  static var events;
  static var purchases;

  static Future<bool> startWithApiKey(String apiKey, List<String> stores,
      String? userId, PLYLogLevel logLevel, PLYRunningMode runningMode) async {
    return await _channel.invokeMethod('startWithApiKey', <String, dynamic>{
      'apiKey': apiKey,
      'stores': stores,
      'userId': userId,
      'logLevel': logLevel.index,
      'runningMode': runningMode.index
    });
  }

  static Future<PresentPresentationResult> presentPresentationWithIdentifier(
      String? presentationVendorId,
      [String? contentId]) async {
    final result = await _channel.invokeMethod(
        'presentPresentationWithIdentifier', <String, dynamic>{
      'presentationVendorId': presentationVendorId,
      'contentId': contentId
    });
    return PresentPresentationResult(PLYPurchaseResult.values[result['result']],
        transformToPLYPlan(result['plan']));
  }

  static Future<PresentPresentationResult> presentProductWithIdentifier(
      String productVendorId,
      [String? presentationVendorId,
      String? contentId]) async {
    final result = await _channel
        .invokeMethod('presentPresentationWithIdentifier', <String, dynamic>{
      'productVendorId': productVendorId,
      'presentationVendorId': presentationVendorId,
      'contentId': contentId
    });
    PLYPlan? plan;
    if (!result['plan'].isEmpty) plan = transformToPLYPlan(result['plan']);

    return PresentPresentationResult(
        PLYPurchaseResult.values[result['result']], plan);
  }

  static Future<PresentPresentationResult> presentPlanWithIdentifier(
      String planVendorId,
      [String? presentationVendorId,
      String? contentId]) async {
    final result = await _channel
        .invokeMethod('presentPresentationWithIdentifier', <String, dynamic>{
      'planVendorId': planVendorId,
      'presentationVendorId': presentationVendorId,
      'contentId': contentId
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

  static Future<void> isReadyToPurchase(bool readyToPurchase) async {
    _channel.invokeMethod('isReadyToPurchase',
        <String, dynamic>{'readyToPurchase': readyToPurchase});
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

  static Future<Map<dynamic, dynamic>> purchaseWithPlanVendorId(String vendorId,
      [String? contentId]) async {
    final Map<dynamic, dynamic> product = await _channel.invokeMethod(
        'purchaseWithPlanVendorId',
        <String, dynamic>{'vendorId': vendorId, 'contentId': contentId});
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
      element['product']['plans']
          .forEach((k, plan) => plans.add(transformToPLYPlan(plan)));

      subscriptions.add(PLYSubscription(
          element['purchaseToken'],
          PLYSubscriptionSource.values[element['subscriptionSource']],
          element['nextRenewalDate'],
          element['cancelledDate'],
          transformToPLYPlan(element['plan']),
          PLYProduct(element['product']['name'], element['product']['vendorId'],
              plans.whereNotNull().toList())));
    });
    return subscriptions;
  }

  static Future<bool> handle(String deepLink) async {
    return await _channel
        .invokeMethod('handle', <String, dynamic>{'deeplink': deepLink});
  }

  static void listenToEvents(Function(PLYEvent) block) {
    events = _stream.receiveBroadcastStream().listen((event) {
      PLYEventName eventName = PLYEventName.APP_CONFIGURED;
      try {
        eventName = PLYEventName.values
            .firstWhere((e) => e.toString() == 'PLYEventName.' + event['name']);
      } catch (e) {
        print(e);
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

  static Future<void> synchronize() async {
    return await _channel.invokeMethod('synchronize');
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
    return PaywallActionInterceptorResult(
        PLYPaywallInfo(
            result['info']['contentId'], result['info']['presentationId']),
        PLYPaywallAction.values.firstWhere(
            (e) => e.toString() == 'PLYPaywallAction.' + result['action']),
        PLYPaywallActionParameters(
            result['parameters']['url'],
            result['parameters']['title'],
            plan != null ? transformToPLYPlan(plan) : null,
            result['parameters']['presentation']));
  }

  static Future<void> onProcessAction(bool processAction) async {
    return await _channel.invokeMethod(
        'onProcessAction', <String, dynamic>{'processAction': processAction});
  }

  static Future<void> closePaywall() async {
    return await _channel.invokeMethod('closePaywall');
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
    properties['carousels']?.forEach((element) => carousels.add(
        PLYEventPropertyCarousel(
            element['selected_slide'],
            element['number_of_slides'],
            element['is_carousel_auto_playing'],
            element['default_slide'],
            element['previous_slide'])));

    List<PLYEventPropertySubscription> subscriptions =
        new List.empty(growable: true);
    properties['running_subscriptions']?.forEach((element) => subscriptions.add(
        PLYEventPropertySubscription(element['plan'], element['product'])));

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
        subscriptions);
  }
}

enum PLYLogLevel { debug, info, warn, error }
enum PLYRunningMode {
  transactionOnly,
  observer,
  paywallOnly,
  paywallObserver,
  full
}
enum PLYAttribute {
  amplitude_session_id,
  firebase_app_instance_id,
  airship_channel_id,
  batch_installation_id
}
enum PLYPurchaseResult { purchased, cancelled, restored }
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

class PLYPlan {
  String? vendorId;
  String? productId;
  String? name;
  PLYPlanType type;
  double? amount;
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

  PLYSubscription(this.purchaseToken, this.subscriptionSource,
      this.nextRenewalDate, this.cancelledDate, this.plan, this.product);
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
  String? presentation;

  PLYPaywallActionParameters(
      this.url, this.title, this.plan, this.presentation);
}

class PLYPaywallInfo {
  String? contentId;
  String? presentationId;

  PLYPaywallInfo(this.contentId, this.presentationId);
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
  PURCHASE_CANCELLED_BY_APP,
  CAROUSEL_SLIDE_SWIPED,
  DEEPLINK_OPENED,
  LINK_OPENED,
  LOGIN_TAPPED,
  PLAN_SELECTED,
  PRESENTATION_VIEWED,
  PRESENTATION_OPENED,
  PRESENTATION_SELECTED,
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
  SUBSCRIPTIONS_LIST_VIEWED,
  SUBSCRIPTION_DETAILS_VIEWED,
  SUBSCRIPTION_CANCEL_TAPPED,
  SUBSCRIPTION_PLAN_TAPPED,
  SUBSCRIPTIONS_TRANSFERRED,
  USER_LOGGED_IN,
  USER_LOGGED_OUT
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
  String? intro_duration;
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
      this.running_subscriptions);
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
