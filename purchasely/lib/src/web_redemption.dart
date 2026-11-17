// Purchasely SDK — Web2App redemption outcome (6.1.0).
//
// Its own module because both `purchasely_builder.dart` and the package entry point need
// it, and builder -> entry point would be an import cycle.

import 'dart:async';
import 'dart:developer';

import 'package:flutter/services.dart';

import 'ply_models.dart';
import 'ply_transformers.dart';

/// What a Web2App redemption granted.
///
/// Both levels are nullable. The context is null when the server's 200 response
/// carried nothing to describe. A present context can still hold a null
/// [subscription]: the receipt validated and the SDK refreshed the
/// entitlements, but the response carried no subscription, or the products
/// behind it are not loaded yet. Both cases stay a success — call
/// `Purchasely.userSubscriptions()` from the listener for the full picture.
class PLYWebRedemptionContext {
  final PLYSubscription? subscription;

  PLYWebRedemptionContext({this.subscription});
}

/// Outcome of one Web2App redemption, delivered to the listener registered with
/// `PurchaselyBuilder.webRedemptionListener` or
/// `Purchasely.addWebRedemptionListener`.
///
/// Read [isSuccess] first: it decides which fields hold a value. The shape is
/// flat because it mirrors the native iOS `PLYWebRedemptionResult` object and
/// the Android `PLYWebRedemptionResult` sealed class through one bridge event.
class PLYWebRedemptionResult {
  /// `true` for a granted redemption, `false` for a failed one.
  final bool isSuccess;

  /// Null on failure, and nullable on success — see [PLYWebRedemptionContext].
  final PLYWebRedemptionContext? context;

  /// `true` when the server reports the token was redeemed before. The SDK
  /// keeps no cache and calls the server on every attempt, so this is a verdict
  /// about the token, not an observation of the user. Always `false` on
  /// failure.
  final bool replay;

  /// Backend error code. Null on success, and null on a failure that never
  /// reached the server. Known values: `'EXPIRED_REDEMPTION_TOKEN'`,
  /// `'INVALID_REDEMPTION_TOKEN'`.
  final String? errorCode;

  /// Human-readable reason, in English. Null on success. It never contains the
  /// token.
  ///
  /// An expired link puts the backend's masked email hint here, e.g.
  /// `'Redemption link has expired. A new link was sent to j***@example.com.'`,
  /// so the app can tell the user where the fresh link went.
  ///
  /// **This happens on BOTH iOS and Android.** Verified against the released
  /// 6.1.0 tags: Android `RedemptionOutcome.Expired.toResult()` appends
  /// `error.emailHint`, and the iOS `.expired(emailHint:)` branch appends the
  /// same string. The Android source comments that field as
  /// "masked email = PII".
  ///
  /// So: show this text to the user, and **never** send it to an analytics
  /// stack or to a crash reporter. Do **not** gate that rule on `Platform.isIOS`
  /// or any other platform check — an integrator who does that ships personal
  /// data on the other platform. The `REDEMPTION_FAILED` event drops the hint on
  /// both platforms, so this field is the only place it ever appears.
  final String? errorMessage;

  PLYWebRedemptionResult({
    required this.isSuccess,
    required this.context,
    required this.replay,
    required this.errorCode,
    required this.errorMessage,
  });

  @override
  String toString() => 'PLYWebRedemptionResult('
      'isSuccess: $isSuccess, '
      'replay: $replay, '
      'errorCode: $errorCode, '
      'errorMessage: $errorMessage)';
}

/// Callback signature for a settled Web2App redemption.
typedef PLYWebRedemptionListener = void Function(PLYWebRedemptionResult result);

/// `const` is inert — the `listen` message goes out only on the first
/// `receiveBroadcastStream().listen(...)`, so importing this costs a unit test nothing.
const EventChannel _channel = EventChannel('purchasely-web-redemption');

StreamSubscription<dynamic>? _subscription;

/// The live subscription, or null when no listener is registered. Exposed so a
/// host can inspect or cancel it directly, matching `Purchasely.events` and
/// `Purchasely.purchases`.
StreamSubscription<dynamic>? get webRedemptionSubscription => _subscription;

/// Registers [listener] for a Web2App redemption outcome, replacing any existing one.
///
/// Prefer `PurchaselyBuilder.webRedemptionListener(...)`: this runtime path misses a
/// redemption that settles during `start()`. The SDK calls [listener] on the main
/// thread, exactly once per settled redemption.
void addWebRedemptionListener(PLYWebRedemptionListener listener) {
  _subscription?.cancel();
  _subscription = _channel.receiveBroadcastStream().listen(
    (event) =>
        listener(webRedemptionResultFromMap(event as Map<dynamic, dynamic>)),
    // Otherwise a PlatformException becomes an uncaught async error in the host's zone.
    // Keep the subscription alive — the next redemption must still arrive.
    onError: (Object error, StackTrace stack) {
      log('Purchasely: web redemption channel error: $error');
    },
  );
}

/// Removes the listener registered with [addWebRedemptionListener] or with
/// `PurchaselyBuilder.webRedemptionListener`.
void removeWebRedemptionListener() {
  _subscription?.cancel();
  _subscription = null;
}

/// The two nullability levels stay separate: a null `context` is a success with nothing
/// to describe; a `context` with a null `subscription` granted none.
PLYWebRedemptionResult webRedemptionResultFromMap(Map<dynamic, dynamic> body) {
  final rawContext = body['context'];
  return PLYWebRedemptionResult(
    isSuccess: body['isSuccess'] == true,
    context: rawContext is Map
        ? PLYWebRedemptionContext(
            subscription: rawContext['subscription'] is Map
                ? plySubscriptionFromMap(
                    rawContext['subscription'] as Map<dynamic, dynamic>)
                : null)
        : null,
    replay: body['replay'] == true,
    errorCode: body['errorCode'] as String?,
    errorMessage: body['errorMessage'] as String?,
  );
}
