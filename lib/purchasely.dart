import 'dart:async';

import 'package:flutter/services.dart';

class Purchasely {
  static const MethodChannel _channel = const MethodChannel('purchasely');
  static const EventChannel _stream = EventChannel('purchasely-events');

  static var subscription;

  static Future<void> startWithApiKey(String apiKey, List<String> stores,
      String userId, LogLevel logLevel) async {
    await _channel.invokeMethod('startWithApiKey', <String, dynamic>{
      'apiKey': apiKey,
      'stores': stores,
      'userId': userId,
      'logLevel': logLevel.toString().split('.').last
    });
  }

  static Future<Map<dynamic, dynamic>> presentProductWithIdentifier(
      String productVendorId, String presentationVendorId) async {
    return await _channel.invokeMethod(
        'presentProductWithIdentifier', <String, dynamic>{
      'productVendorId': productVendorId,
      'presentationVendorId': presentationVendorId
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
    final bool restored = await _channel.invokeMethod('setLogLevel',
        <String, dynamic>{'logLevel': logLevel.toString().split('.').last});
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
      String vendorId) async {
    final Map<dynamic, dynamic> product = await _channel.invokeMethod(
        'purchaseWithPlanVendorId', <String, dynamic>{'vendorId': vendorId});
    return product;
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

  static void listenToEvents() {
    subscription = _stream.receiveBroadcastStream().listen((event) {
      print('Event $event');
    });
  }

  static void stopListeningToEvents() {
    subscription.cancel();
  }
}

enum LogLevel { debug, info, warn, error }
