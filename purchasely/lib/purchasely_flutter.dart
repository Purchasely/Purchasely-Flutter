import 'dart:async';
import 'dart:developer';

import 'package:flutter/services.dart';

import 'src/action_interceptor.dart'
    show PLYPresentationActionKind, PLYActionInterceptorHandler;
import 'src/bridge.dart' show PurchaselyBridge;
import 'src/ply_models.dart';
import 'src/ply_transformers.dart';
import 'src/presentation.dart' show PLYPresentation, PLYPresentationType;
import 'src/presentation_outcome.dart' show PLYPresentationOutcome;
import 'src/purchasely_builder.dart' show PLYLogLevel, PurchaselyBuilder;
import 'src/web_redemption.dart' as web_redemption
    show
        PLYWebRedemptionListener,
        PLYWebRedemptionResult,
        addWebRedemptionListener,
        removeWebRedemptionListener,
        webRedemptionResultFromMap,
        webRedemptionSubscription;

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
export 'src/ply_models.dart';
export 'src/presentation.dart';
export 'src/presentation_builder.dart';
export 'src/presentation_outcome.dart';
export 'src/presentation_request.dart';
export 'src/purchasely_builder.dart';
export 'src/transition.dart';
export 'src/web_redemption.dart'
    show
        PLYWebRedemptionContext,
        PLYWebRedemptionListener,
        PLYWebRedemptionResult;

class Purchasely {
  static const MethodChannel _channel = const MethodChannel('purchasely');
  static const EventChannel _stream = EventChannel('purchasely-events');
  static const EventChannel _purchases = EventChannel('purchasely-purchases');
  static const EventChannel _userAttributesChannel =
      EventChannel('purchasely-user-attributes');

  static UserAttributeListener? _userAttributeListener;

  static StreamSubscription<dynamic>? events;
  static StreamSubscription<dynamic>? purchases;

  /// The live Web2App redemption subscription, or null when no listener is
  /// registered. Owned by `src/web_redemption.dart`, which both this class and
  /// [PurchaselyBuilder.webRedemptionListener] register through.
  static StreamSubscription<dynamic>? get webRedemptions =>
      web_redemption.webRedemptionSubscription;

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
  static PurchaselyBuilder apiKey(String key) => PurchaselyBuilder.apiKey(key);

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

  /// Removes the global dismiss handler previously registered with
  /// [setDefaultPresentationDismissHandler].
  static Future<void> removeDefaultPresentationDismissHandler() =>
      PurchaselyBridge.ensureInstalled()
          .removeDefaultPresentationDismissHandler();

  /// Closes every currently displayed Purchasely presentation, regardless of
  /// how it was opened (PAR-19 / FLT-W-02 comment). For closing a single
  /// [PLYPresentation] instead, prefer [PLYPresentation.close].
  static Future<void> closeAllScreens() async {
    await _channel.invokeMethod('closeAllScreens');
  }

  // --- Client paywalls ---

  /// Notifies Purchasely that a paywall rendered by your own code (a
  /// presentation of type [PLYPresentationType.client]) is displayed.
  ///
  /// Pass the [PLYPresentation] returned by
  /// `PLYPresentationBuilder…build().preload()`.
  static Future<void> clientPresentationDisplayed(
      PLYPresentation presentation) async {
    return await _channel.invokeMethod('clientPresentationDisplayed',
        <String, dynamic>{'presentation': presentation.toMap()});
  }

  /// Notifies Purchasely that a paywall rendered by your own code (a
  /// presentation of type [PLYPresentationType.client]) is closed.
  ///
  /// Pass the same [PLYPresentation] given to [clientPresentationDisplayed].
  static Future<void> clientPresentationClosed(
      PLYPresentation presentation) async {
    return await _channel.invokeMethod('clientPresentationClosed',
        <String, dynamic>{'presentation': presentation.toMap()});
  }

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

  /// Maps the native wire type string to [PLYUserAttributeType]. Never
  /// throws — an unrecognized type (or a genuinely new native case, e.g. the
  /// real iOS `.dictionary` case) logs and maps to
  /// [PLYUserAttributeType.unknown] instead of raising an uncaught
  /// `ArgumentError` inside the listener's `.listen()` callback
  /// (REC-09 / FLT-W-04 / ENM-08).
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
    } else if (type == "DICTIONARY") {
      return PLYUserAttributeType.dictionary;
    } else {
      log('Purchasely: unknown user attribute type "$type", mapping to '
          'PLYUserAttributeType.unknown');
      return PLYUserAttributeType.unknown;
    }
  }

  /// Restores every purchase previously made by the user (App Store /
  /// Google Play restore flow).
  ///
  /// On a device without a working store (e.g. an emulator without Google
  /// Play), the native call may never resolve — pass [timeout] to fail with a
  /// [TimeoutException] instead of awaiting forever.
  static Future<bool> restoreAllProducts({Duration? timeout}) async {
    final call = _channel.invokeMethod('restoreAllProducts');
    final dynamic restored =
        await (timeout == null ? call : call.timeout(timeout));
    return restored == true;
  }

  /// Silent variant of [restoreAllProducts] (no store sign-in prompt on iOS).
  /// Same [timeout] semantics.
  static Future<bool> silentRestoreAllProducts({Duration? timeout}) async {
    final call = _channel.invokeMethod('silentRestoreAllProducts');
    final dynamic restored =
        await (timeout == null ? call : call.timeout(timeout));
    return restored == true;
  }

  /// Forces a synchronization of the user's purchases with the Purchasely
  /// servers.
  ///
  /// Since the 6.0 native SDKs expose success/error callbacks on
  /// `synchronize()`, the returned [Future] resolves with `true` once the
  /// synchronization actually completes and throws a [PlatformException] if it
  /// failed — instead of the previous fire-and-forget behaviour. `await` it
  /// before chaining a follow-up presentation that targets subscribers.
  ///
  /// Resolves `false` when the receipt is still pending store/backend
  /// validation (deferred purchase, Android) — a normal transient state, not
  /// a failure.
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

  /// Logs the current user out.
  ///
  /// [clearUserAttributes] also clears locally-stored user attributes.
  /// Defaults to `true`, matching the native default (PAR-30).
  static Future<void> userLogout({bool clearUserAttributes = true}) async {
    return await _channel.invokeMethod("userLogout",
        <String, dynamic>{'clearUserAttributes': clearUserAttributes});
  }

  /// Sets the SDK log level. Wire-encoded as `.name` (e.g. `"debug"`), the
  /// same encoding [PurchaselyBuilder.logLevel] uses for `start()` — PAR-27,
  /// standardizing PLYLogLevel's wire format so both entry points agree.
  static Future<bool> setLogLevel(PLYLogLevel logLevel) async {
    final bool restored = await _channel.invokeMethod(
        'setLogLevel', <String, dynamic>{'logLevel': logLevel.name});
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

  /// Signs a StoreKit promotional offer for `storeProductId`/`storeOfferId`.
  ///
  /// iOS-only — StoreKit has no direct Google Play Billing equivalent. On
  /// Android this is a no-op that resolves with an empty map rather than
  /// throwing (FLT-W-01 / REC-04); it never rejects, so calling it
  /// cross-platform is safe, but the result is only meaningful on iOS.
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

  /// Fetches the user's active subscriptions.
  ///
  /// [invalidateCache] forces a refresh instead of returning a cached result
  /// (PAR-29). Defaults to `false`, matching the native default.
  static Future<List<PLYSubscription>> userSubscriptions(
      {bool invalidateCache = false}) async {
    final List<dynamic> result = await _channel.invokeMethod(
        'userSubscriptions',
        <String, dynamic>{'invalidateCache': invalidateCache});

    return result
        .map((element) =>
            plySubscriptionFromMap(element as Map<dynamic, dynamic>))
        .toList();
  }

  /// Fetches the user's subscription history (includes cancelled/expired
  /// subscriptions plus revenue/duration aggregates).
  ///
  /// [invalidateCache] forces a refresh instead of returning a cached result
  /// (PAR-29). Defaults to `false`, matching the native default.
  static Future<List<PLYSubscription>> userSubscriptionsHistory(
      {bool invalidateCache = false}) async {
    final List<dynamic> result = await _channel.invokeMethod(
        'userSubscriptionsHistory',
        <String, dynamic>{'invalidateCache': invalidateCache});

    return result
        .map((element) =>
            plySubscriptionFromMap(element as Map<dynamic, dynamic>))
        .toList();
  }

  /// Hands a deeplink to the SDK; returns `true` when the SDK handled it
  /// (e.g. by opening the targeted placement/presentation).
  ///
  /// A handled deeplink fires `DEEPLINK_OPENED` and `PRESENTATION_LOADED` /
  /// `PRESENTATION_VIEWED` (never `PRESENTATION_OPENED`), but the relative
  /// order of `DEEPLINK_OPENED` and `PRESENTATION_LOADED` differs between the
  /// native SDKs (iOS emits `DEEPLINK_OPENED` first, Android may emit
  /// `PRESENTATION_LOADED` first) — don't rely on their ordering.
  static Future<bool> handleDeeplink(String deepLink) async {
    return await _channel.invokeMethod(
        'handleDeeplink', <String, dynamic>{'deeplink': deepLink});
  }

  static void listenToEvents(Function(PLYEvent) block) {
    events = _stream.receiveBroadcastStream().listen((event) {
      final eventName = _eventNameFromWire(event['name'] as String?);
      block(PLYEvent(
          eventName, transformToPLYEventProperties(event['properties'])));
    });
  }

  static void stopListeningToEvents() {
    events?.cancel();
  }

  /// Alias for [listenToEvents] — `addEventListener`/`removeEventListener`
  /// are the shared naming anchor across the Purchasely cross-platform
  /// bridges (REC-18 / PAR-18).
  static void addEventListener(Function(PLYEvent) block) =>
      listenToEvents(block);

  /// Alias for [stopListeningToEvents].
  static void removeEventListener() => stopListeningToEvents();

  /// Registers [block] for the outcome of a Web2App redemption
  /// (`{scheme}://ply/redeem/{token}`), replacing any listener already
  /// registered.
  ///
  /// **Prefer [PurchaselyBuilder.webRedemptionListener] on the start chain.**
  /// This is the secondary, runtime path, for an app that has to replace the
  /// listener while the SDK already runs. Its trade-off: a redemption that
  /// settles during `start()` — a cold start the `ply/redeem` link itself
  /// triggered, or a token a previous launch left pending — is missed, because
  /// nothing was listening yet. The chain modifier subscribes before `start()`
  /// is even called, so it cannot miss one.
  ///
  /// The SDK calls [block] on the main thread, exactly once per settled
  /// redemption, on success and on failure alike.
  ///
  /// [PurchaselyBuilder.appHandlesRedemptionAlert] decides *when*:
  ///
  /// - `false` (the default): the SDK shows its own popin and calls the
  ///   listener after the user acknowledges it, so the app acts on a screen the
  ///   user already dismissed.
  /// - `true`: the SDK shows nothing and calls the listener as soon as the
  ///   redemption settles. The app must then show its own result screen.
  ///
  /// Three more behaviours to know:
  ///
  /// - [PLYWebRedemptionResult.replay] is `true` when the **server** reports
  ///   the token was redeemed before. The SDK keeps no cache and calls the
  ///   server every time, so this is a verdict about the token, not an
  ///   observation of the user.
  /// - A redemption deeplink is **not** subject to `allowDeeplink`. The native
  ///   SDK intercepts `ply/redeem` out of band, before the routing branch the
  ///   gate sits behind. A redemption still completes with
  ///   `allowDeeplink(false)`.
  /// - [PLYWebRedemptionResult.errorMessage] for an expired link **can carry a
  ///   masked email address, on both iOS and Android**, so the app can tell the
  ///   user where the fresh link went. Show that text to the user. **Never**
  ///   forward it to an analytics stack or to a crash reporter, and do not gate
  ///   that rule on a platform check — it is personal data on every platform.
  ///   The analytics event drops the hint, so only this channel carries it.
  static void addWebRedemptionListener(
          web_redemption.PLYWebRedemptionListener block) =>
      web_redemption.addWebRedemptionListener(block);

  /// Removes the listener registered with [addWebRedemptionListener] or with
  /// [PurchaselyBuilder.webRedemptionListener].
  static void removeWebRedemptionListener() =>
      web_redemption.removeWebRedemptionListener();

  /// Maps the wire body of a `purchasely-web-redemption` event to a
  /// [PLYWebRedemptionResult]. Exposed for a host that captured a body itself;
  /// the listeners above are the normal entry points.
  static web_redemption.PLYWebRedemptionResult webRedemptionResultFromMap(
          Map<dynamic, dynamic> body) =>
      web_redemption.webRedemptionResultFromMap(body);

  static void listenToPurchases(Function block) {
    purchases = _purchases.receiveBroadcastStream().listen((event) {
      block(event);
    });
  }

  static void stopListeningToPurchases() {
    purchases?.cancel();
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
    } catch (_) {
      // Not a date: broad catch is intentional — DateTime.parse throws
      // FormatException on a bad string and TypeError on a non-string value
      // (int/bool/null). Either way, keep the original value.
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
      } catch (_) {
        // Not a date: broad catch is intentional — DateTime.parse throws
        // FormatException on a bad string and TypeError on a non-string value
        // (int/bool/null). Either way, keep the original value.
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

  /// Reads a single built-in (SDK-computed) user attribute by [key] — the
  /// read counterpart of the built-in attributes the SDK tracks internally
  /// (PAR-07).
  static Future<dynamic> getBuiltInAttribute(String key) async {
    dynamic value = await _channel
        .invokeMethod('getBuiltInAttribute', <String, dynamic>{'key': key});

    try {
      value = DateTime.parse(value);
    } catch (_) {
      // Not a date: broad catch is intentional — DateTime.parse throws
      // FormatException on a bad string and TypeError on a non-string value
      // (int/bool/null). Either way, keep the original value.
    }

    return value;
  }

  /// Reads all built-in (SDK-computed) user attributes (PAR-07).
  static Future<Map<dynamic, dynamic>> getBuiltInAttributes() async {
    Map<dynamic, dynamic> attributes =
        await _channel.invokeMethod('getBuiltInAttributes');

    return attributes.map((key, value) {
      dynamic attributeValue = value;
      try {
        attributeValue = DateTime.parse(value);
      } catch (_) {
        // Not a date: broad catch is intentional — DateTime.parse throws
        // FormatException on a bad string and TypeError on a non-string value
        // (int/bool/null). Either way, keep the original value.
      }
      return MapEntry(key, attributeValue);
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
      'offerVendorId': offering.offerVendorId,
      'billingPlanType': offering.billingPlanType.wire
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
          reference,
          planVendorId,
          offering['offerVendorId'],
          plyBillingPlanTypeFromWire(offering['billingPlanType'])));
    });
    return dynamicOfferings;
  }

  static PLYEventProperties transformToPLYEventProperties(
      Map<dynamic, dynamic> properties) {
    final eventName = _eventNameFromWire(properties['event_name'] as String?);

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
      // v6 iOS sends placement_id; v5 sent source_identifier. Accept both.
      properties['source_identifier'] ?? properties['placement_id'],
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
    )..redemption = _redemptionFromMap(properties['redemption']);
  }

  /// Maps the `redemption` block of a `REDEMPTION_CONSUMED` /
  /// `REDEMPTION_FAILED` event. Returns null for any other event, which carries
  /// no such block.
  static PLYEventPropertyRedemption? _redemptionFromMap(dynamic raw) {
    if (raw is! Map) return null;

    final receipt = raw['receipt'];
    final context = raw['purchase_context'];

    return PLYEventPropertyRedemption(
      raw['token'] as String?,
      receipt is Map
          ? PLYEventPropertyRedemptionReceipt(
              receipt['id'] as String?, receipt['validation_status'] as String?)
          : null,
      (raw['subscriptions'] as List?)
          ?.whereType<Map>()
          .map((s) => PLYEventPropertyRedemptionSubscription(
              s['public_id'] as String?,
              s['plan_id'] as String?,
              s['store_type'] as String?,
              s['subscription_status'] as String?,
              s['environment'] as String?))
          .toList(),
      context is Map
          ? PLYEventPropertyRedemptionPurchaseContext(
              context['version'] as int?,
              context['source'] as String?,
              context['sandbox'] as bool?,
              context['replay'] as bool?,
              _redemptionAttributes(context['built_in_attributes']),
              _redemptionAttributes(context['custom_attributes']))
          : null,
      raw['error_code'] as String?,
    );
  }

  static List<PLYEventPropertyRedemptionAttribute>? _redemptionAttributes(
      dynamic raw) {
    return (raw as List?)
        ?.whereType<Map>()
        .map((a) => PLYEventPropertyRedemptionAttribute(
            a['key'] as String?, a['type'] as String?, a['value']))
        .toList();
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

/// Maps a native event name string to [PLYEventName]. Falls back to
/// [PLYEventName.UNKNOWN] (logging the mismatch) instead of silently
/// misclassifying an unrecognized event as [PLYEventName.APP_CONFIGURED]
/// (REC-13 / EVT-01) — shared by [Purchasely.listenToEvents] and
/// [Purchasely.transformToPLYEventProperties] so the fallback only lives in
/// one place.
PLYEventName _eventNameFromWire(String? wire) {
  for (final name in PLYEventName.values) {
    if (name.name == wire) return name;
  }
  log('Purchasely: unknown event name "$wire", mapping to PLYEventName.UNKNOWN');
  return PLYEventName.UNKNOWN;
}

// -- ENUMS --

// WARNING: This enum must be strictly identical (same case names, same
// order) to FlutterPLYAttribute on both native bridges
// (ios/Classes/SwiftPurchaselyFlutterPlugin.swift and
// android/.../PurchaselyFlutterPlugin.kt's companion object). All 3 map by
// case *name* to the native `Purchasely.PLYAttribute`/`Attribute`, never by
// raw ordinal — the two native SDKs' own attribute enums are NOT
// ordinal-aligned with each other (iOS has `oneSignalPlayerId`, which this
// Dart enum deliberately does NOT declare, at a different position; Android
// has no such case at all), so an ordinal-based bridge mapping would
// silently cross-wire attributes. Add new cases here AND in both native
// enums in lockstep (REC-11 / ENM-03).
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
  oneSignalUserId,
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

/// Native SDK event names forwarded over the `purchasely-events` channel.
///
/// 53 cases: 52 correspond to a real native event name (including
/// [PLACEMENT_OPENED] and [PURCHASE_FROM_STORE_TAPPED], added for parity —
/// REC-13 / EVT-01), plus [UNKNOWN] — a Dart-only fallback sentinel never
/// sent by the native SDKs. Keep this count comment accurate when adding
/// cases; a stale count here previously masked exactly this kind of gap.
/// [_eventNameFromWire] matches by exact case name, never by ordinal.
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
  PLACEMENT_OPENED,
  PRESENTATION_VIEWED,
  PRESENTATION_OPENED,
  PRESENTATION_SELECTED,
  PRESENTATION_LOADED,
  PRESENTATION_CLOSED,
  PROMO_CODE_TAPPED,
  PURCHASE_CANCELLED,
  PURCHASE_FROM_STORE_TAPPED,
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
  WEB_CHECKOUT_TIMED_OUT,

  /// A Web2App redemption granted its content. New in 6.1.0 on both native
  /// platforms. A replayed link reports this event too — read
  /// `properties.redemption?.purchase_context?.replay` to tell a first
  /// redemption from a repeat.
  REDEMPTION_CONSUMED,

  /// A Web2App redemption failed. New in 6.1.0 on both native platforms. Read
  /// `properties.redemption?.error_code` and `properties.error_message`.
  REDEMPTION_FAILED,

  /// Sentinel for a native event name this enum doesn't (yet) declare a case
  /// for. Never silently misclassified as [APP_CONFIGURED] — see
  /// [_eventNameFromWire].
  UNKNOWN,
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

  /// Native iOS's `PLYUserAttributeType.dictionary` case (confirmed real,
  /// not hypothetical — see FLT-W-04). Value is passed through as-is; no
  /// dedicated Dart model, same as every other case here.
  dictionary,

  /// Sentinel for a native wire type this enum doesn't (yet) declare a case
  /// for. [Purchasely.mapType] never throws — see its doc comment.
  unknown,
}

// -- CLASSES --

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

  /// Set on `REDEMPTION_CONSUMED` and `REDEMPTION_FAILED`, null otherwise. New
  /// in 6.1.0. Assigned after construction, like [PLYPlan.commitmentInfo], so
  /// the positional constructor stays source-compatible.
  PLYEventPropertyRedemption? redemption;

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

/// The receipt a redemption validated.
class PLYEventPropertyRedemptionReceipt {
  String? id;

  /// Uppercase, e.g. `'COMPLETED'`.
  String? validation_status;

  PLYEventPropertyRedemptionReceipt(this.id, this.validation_status);
}

/// One subscription a redemption transferred, as `REDEMPTION_CONSUMED` reports
/// it. The SDK reports active subscriptions and non-consumables only. An
/// expired subscription is absent: a redemption grants, it does not report
/// history.
class PLYEventPropertyRedemptionSubscription {
  String? public_id;
  String? plan_id;
  String? store_type;
  String? subscription_status;
  String? environment;

  PLYEventPropertyRedemptionSubscription(this.public_id, this.plan_id,
      this.store_type, this.subscription_status, this.environment);
}

/// One attribute a redemption restored. [value] stays the JSON the backend
/// sent, so the event reports it exactly as [type] declares it.
class PLYEventPropertyRedemptionAttribute {
  String? key;
  String? type;
  dynamic value;

  PLYEventPropertyRedemptionAttribute(this.key, this.type, this.value);
}

/// The web journey behind a redemption. The SDK reports what it applied, not
/// the raw response: a block the SDK does not consume is absent here too.
class PLYEventPropertyRedemptionPurchaseContext {
  int? version;
  String? source;
  bool? sandbox;

  /// `true` when the same redemption link is consumed again.
  bool? replay;
  List<PLYEventPropertyRedemptionAttribute>? built_in_attributes;
  List<PLYEventPropertyRedemptionAttribute>? custom_attributes;

  PLYEventPropertyRedemptionPurchaseContext(
      this.version,
      this.source,
      this.sandbox,
      this.replay,
      this.built_in_attributes,
      this.custom_attributes);
}

/// What a Web2App redemption reports. `REDEMPTION_CONSUMED` carries [token],
/// [receipt], [subscriptions] and [purchase_context]. `REDEMPTION_FAILED`
/// carries [token] and [error_code], with the reason in the top-level
/// [PLYEventProperties.error_message].
///
/// The masked email hint of an expired link never reaches this event, on either
/// platform: both native SDKs drop it when they build `REDEMPTION_FAILED`. The
/// hint goes to the web redemption listener only — see
/// [Purchasely.addWebRedemptionListener], and do not log it.
///
/// Every field is optional: the SDK omits a key it has no value for.
class PLYEventPropertyRedemption {
  /// The redemption link token this event reports on.
  String? token;
  PLYEventPropertyRedemptionReceipt? receipt;
  List<PLYEventPropertyRedemptionSubscription>? subscriptions;
  PLYEventPropertyRedemptionPurchaseContext? purchase_context;

  /// Backend error code, on `REDEMPTION_FAILED` only. Known values:
  /// `'EXPIRED_REDEMPTION_TOKEN'`, `'INVALID_REDEMPTION_TOKEN'`. A transport
  /// failure or a parsing failure carries no code.
  String? error_code;

  PLYEventPropertyRedemption(this.token, this.receipt, this.subscriptions,
      this.purchase_context, this.error_code);
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

  /// Apple billing plan type to force for this offering (iOS 26.4+). Ignored on
  /// Android and other platforms. Defaults to [PLYBillingPlanType.unspecified].
  PLYBillingPlanType billingPlanType;

  PLYDynamicOffering(this.reference, this.planVendorId, this.offerVendorId,
      [this.billingPlanType = PLYBillingPlanType.unspecified]);

  Map<String, dynamic> toJson() => {
        'reference': reference,
        'planVendorId': planVendorId,
        'offerVendorId': offerVendorId,
        'billingPlanType': billingPlanType.wire,
      };

  @override
  String toString() {
    return 'PLYDynamicOffering(reference: $reference, planVendorId: $planVendorId, offerVendorId: $offerVendorId, billingPlanType: $billingPlanType)';
  }
}
