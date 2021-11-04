import 'dart:async';

import 'package:flutter/services.dart';

class Purchasely {
  static const MethodChannel _channel = const MethodChannel('purchasely');
  static const EventChannel _stream = EventChannel('purchasely-events');
  static const EventChannel _purchases = EventChannel('purchasely-purchases');

  static var events;
  static var purchases;

  static Future<bool> startWithApiKey(String apiKey, List<String> stores,
      String userId, LogLevel logLevel) async {
    return await _channel.invokeMethod('startWithApiKey', <String, dynamic>{
      'apiKey': apiKey,
      'stores': stores,
      'userId': userId,
      'logLevel': logLevel.index
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
    return PresentPresentationResult(PurchaseResult.values[result['result']],
        transformToPurchaselyPlan(result['plan']));
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
    PurchaselyPlan? plan;
    if (!result['plan'].isEmpty)
      plan = transformToPurchaselyPlan(result['plan']);

    return PresentPresentationResult(
        PurchaseResult.values[result['result']], plan);
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
    return PresentPresentationResult(PurchaseResult.values[result['result']],
        transformToPurchaselyPlan(result['plan']));
  }

  static Future<bool> restoreAllProducts() async {
    final bool restored = await _channel.invokeMethod('restoreAllProducts');
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

  static Future<bool> setLogLevel(LogLevel logLevel) async {
    final bool restored = await _channel.invokeMethod(
        'setLogLevel', <String, dynamic>{'logLevel': logLevel.index});
    return restored;
  }

  static Future<void> isReadyToPurchase(bool readyToPurchase) async {
    _channel.invokeMethod('isReadyToPurchase',
        <String, dynamic>{'readyToPurchase': readyToPurchase});
  }

  static Future<PurchaselyProduct> productWithIdentifier(
      String vendorId) async {
    final Map<dynamic, dynamic> result = await _channel.invokeMethod(
        'productWithIdentifier', <String, dynamic>{'vendorId': vendorId});
    final List<PurchaselyPlan> plans = new List.empty(growable: true);
    result['plans']
        .forEach((k, plan) => plans.add(transformToPurchaselyPlan(plan)));
    return PurchaselyProduct(result['name'], result['vendorId'], plans);
  }

  static Future<PurchaselyPlan> planWithIdentifier(String vendorId) async {
    final Map<dynamic, dynamic> result = await _channel.invokeMethod(
        'planWithIdentifier', <String, dynamic>{'vendorId': vendorId});
    return transformToPurchaselyPlan(result);
  }

  static Future<Map<dynamic, dynamic>> purchaseWithPlanVendorId(String vendorId,
      [String? contentId]) async {
    final Map<dynamic, dynamic> product = await _channel.invokeMethod(
        'purchaseWithPlanVendorId',
        <String, dynamic>{'vendorId': vendorId, 'contentId': contentId});
    return product;
  }

  static Future<List> allProducts() async {
    final List products = await _channel.invokeMethod('allProducts');
    return products;
  }

  static Future<void> presentSubscriptions() async {
    _channel.invokeMethod('presentSubscriptions');
  }

  static Future<void> displaySubscriptionCancellationInstruction() async {
    _channel.invokeMethod('displaySubscriptionCancellationInstruction');
  }

  static Future<List> userSubscriptions() async {
    final Map<dynamic, dynamic> result =
        await _channel.invokeMethod('userSubscriptions');

    final List subscriptions = new List.empty(growable: true);
    result.forEach((key, value) {
      final List<PurchaselyPlan> plans = new List.empty(growable: true);
      value['product']['plans']
          .forEach((k, plan) => plans.add(transformToPurchaselyPlan(plan)));

      subscriptions.add(PurchaselySubscription(
          value['purchaseToken'],
          SubscriptionSource.values[value['subscriptionSource']],
          value['nextRenewalDate'],
          value['cancelledDate'],
          transformToPurchaselyPlan(value['plan']),
          PurchaselyProduct(
              value['product']['name'], value['product']['vendorId'], plans)));
    });
    return subscriptions;
  }

  static Future<bool> handle(String deepLink) async {
    return await _channel
        .invokeMethod('handle', <String, dynamic>{'deeplink': deepLink});
  }

  static void listenToEvents(Function block) {
    events = _stream.receiveBroadcastStream().listen((event) {
      block(event);
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

  static Future<void> setAttribute(Attribute attribute, String value) async {
    return await _channel.invokeMethod('setAttribute',
        <String, dynamic>{'attribute': attribute.index, 'value': value});
  }

  static Future<void> synchronize() async {
    return await _channel.invokeMethod('synchronize');
  }

  static Future<PresentPresentationResult> setDefaultPresentationResultHandler() async {
    final result =
        await _channel.invokeMethod('setDefaultPresentationResultHandler');
    return PresentPresentationResult(PurchaseResult.values[result['result']],
        transformToPurchaselyPlan(result['plan']));
  }

  static Future<void> setLoginTappedHandler() async {
    return await _channel.invokeMethod('setLoginTappedHandler');
  }

  static Future<void> onUserLoggedIn(bool userLoggedIn) async {
    return await _channel.invokeMethod(
        'onUserLoggedIn', <String, dynamic>{'userLoggedIn': userLoggedIn});
  }

  static Future<void> setConfirmPurchaseHandler() async {
    return await _channel.invokeMethod('setConfirmPurchaseHandler');
  }

  static Future<void> processToPayment(bool processToPayment) async {
    return await _channel.invokeMethod('processToPayment',
        <String, dynamic>{'processToPayment': processToPayment});
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

  static void setLoginTappedCallback(Function callback) {
    setLoginTappedHandler().then((value) {
      setLoginTappedCallback(callback);
      try {
        callback();
      } catch (e) {
        print('[Purchasely] Error with callback for loggin tapped handler: $e');
      }
    });
  }

  static void setPurchaseCompletionCallback(Function callback) {
    setConfirmPurchaseHandler().then((value) {
      setPurchaseCompletionCallback(callback);
      try {
        callback();
      } catch (e) {
        print(
            '[Purchasely] Error with callback for confirm purchase handler: $e');
      }
    });
  }

  static PurchaselyPlan transformToPurchaselyPlan(Map<dynamic, dynamic> plan) {
    PlanType type = PlanType.unknown;
    try {
      type = PlanType.values[plan['type']];
    } catch (e) {
      print(e);
    }
    return PurchaselyPlan(
        plan['vendorId'],
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
}

enum LogLevel { debug, info, warn, error }
enum Attribute {
  amplitude_session_id,
  firebase_app_instance_id,
  airship_channel_id
}
enum PurchaseResult { purchased, cancelled, restored }
enum SubscriptionSource {
  appleAppStore,
  googlePlayStore,
  amazonAppstore,
  huaweiAppGallery,
  none
}
enum PlanType {
  consumable,
  nonConsumable,
  autoRenewingSubscription,
  nonRenewingSubscription,
  unknown
}

class PurchaselyPlan {
  String vendorId;
  String name;
  PlanType type;
  double amount;
  String currencyCode;
  String currencySymbol;
  String price;
  String period;
  bool hasIntroductoryPrice;
  String introPrice;
  double introAmount;
  String introDuration;
  String introPeriod;
  bool hasFreeTrial;

  PurchaselyPlan(
      this.vendorId,
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

class PurchaselyProduct {
  String name;
  String vendorId;
  List<PurchaselyPlan> plans;

  PurchaselyProduct(this.name, this.vendorId, this.plans);
}

class PurchaselySubscription {
  String? purchaseToken;
  SubscriptionSource subscriptionSource;
  String nextRenewalDate;
  String cancelledDate;
  PurchaselyPlan plan;
  PurchaselyProduct product;

  PurchaselySubscription(this.purchaseToken, this.subscriptionSource,
      this.nextRenewalDate, this.cancelledDate, this.plan, this.product);
}

class PresentPresentationResult {
  PurchaseResult result;
  PurchaselyPlan? plan;

  PresentPresentationResult(this.result, this.plan);
}
