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
    await _channel.invokeMethod('startWithApiKey', <String, dynamic>{
      'apiKey': apiKey,
      'stores': stores,
      'userId': userId,
      'logLevel': logLevel.index
    });
  }

  static Future<Map<dynamic, dynamic>> presentPresentationWithIdentifier(
      String presentationVendorId, String contentId) async {
    return await _channel.invokeMethod(
        'presentPresentationWithIdentifier', <String, dynamic>{
      'presentationVendorId': presentationVendorId,
      'contentId': contentId
    });
  }

  static Future<Map<dynamic, dynamic>> presentProductWithIdentifier(
      String productVendorId,
      String presentationVendorId,
      String contentId) async {
    return await _channel
        .invokeMethod('presentPresentationWithIdentifier', <String, dynamic>{
      'productVendorId': productVendorId,
      'presentationVendorId': presentationVendorId,
      'contentId': contentId
    });
  }

  static Future<Map<dynamic, dynamic>> presentPlanWithIdentifier(
      String planVendorId,
      String presentationVendorId,
      String contentId) async {
    return await _channel
        .invokeMethod('presentPresentationWithIdentifier', <String, dynamic>{
      'planVendorId': planVendorId,
      'presentationVendorId': presentationVendorId,
      'contentId': contentId
    });
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

  static Future<bool> isReadyToPurchase(bool readyToPurchase) async {
    final bool restored = await _channel.invokeMethod('isReadyToPurchase',
        <String, dynamic>{'readyToPurchase': readyToPurchase});
    return restored;
  }

  static Future<Map<dynamic, dynamic>> productWithIdentifier(
      String vendorId) async {
    final Map<dynamic, dynamic> product = await _channel.invokeMethod(
        'productWithIdentifier', <String, dynamic>{'vendorId': vendorId});
    return product;
  }

  static Future<Map<dynamic, dynamic>> planWithIdentifier(
      String vendorId) async {
    final Map<dynamic, dynamic> product = await _channel.invokeMethod(
        'planWithIdentifier', <String, dynamic>{'vendorId': vendorId});
    return product;
  }

  static Future<Map<dynamic, dynamic>> purchaseWithPlanVendorId(
      String vendorId, String contentId) async {
    final Map<dynamic, dynamic> product = await _channel.invokeMethod(
        'purchaseWithPlanVendorId', <String, dynamic>{
          'vendorId': vendorId,
          'contentId': contentId
        });
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
    final List subscriptions = await _channel.invokeMethod('userSubscriptions');
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

  static Future<Map<dynamic, dynamic>>
      setDefaultPresentationResultHandler() async {
    return await _channel.invokeMethod('setDefaultPresentationResultHandler');
  }

  static Future<Map<dynamic, dynamic>> purchasedSubscription() async {
    return await _channel.invokeMethod('purchasedSubscription');
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
    return await _channel.invokeMethod('processToPayment', <String, dynamic>{
      'processToPaymesetLoginTappedCallbacknt': processToPayment
    });
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
