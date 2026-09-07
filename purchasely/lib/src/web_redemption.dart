// Purchasely SDK — Web2App redemption outcome (6.1.0).
//
// Its own module on purpose. `purchasely_builder.dart` needs the listener so
// `PurchaselyBuilder.webRedemptionListener(...)` can subscribe at chain time,
// and `purchasely_flutter.dart` needs it for the standalone
// `Purchasely.addWebRedemptionListener(...)` runtime path. Both import this
// file; importing the package entry point from the builder would be a cycle.

import 'dart:async';

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

/// A `const EventChannel` is inert: it holds a name and a codec and sends
/// nothing. The `listen` platform message goes out only on the first
/// `receiveBroadcastStream().listen(...)`, so merely importing this module
/// costs nothing and needs no platform channel in a unit test.
const EventChannel _channel = EventChannel('purchasely-web-redemption');

StreamSubscription<dynamic>? _subscription;

/// The live subscription, or null when no listener is registered. Exposed so a
/// host can inspect or cancel it directly, matching `Purchasely.events` and
/// `Purchasely.purchases`.
StreamSubscription<dynamic>? get webRedemptionSubscription => _subscription;

/// Registers [listener] for the outcome of a Web2App redemption
/// (`{scheme}://ply/redeem/{token}`), replacing any listener already
/// registered.
///
/// Prefer `PurchaselyBuilder.webRedemptionListener(...)` on the start chain.
/// This standalone entry point exists for the runtime case, where an app has to
/// replace the listener while the SDK already runs. Its trade-off: a redemption
/// that settles during `start()` — a cold start the `ply/redeem` link itself
/// triggered, or a token a previous launch left pending — is missed, because
/// nothing was listening yet.
///
/// The SDK calls [listener] on the main thread, exactly once per settled
/// redemption, on success and on failure alike.
void addWebRedemptionListener(PLYWebRedemptionListener listener) {
  _subscription?.cancel();
  _subscription = _channel.receiveBroadcastStream().listen((event) =>
      listener(webRedemptionResultFromMap(event as Map<dynamic, dynamic>)));
}

/// Removes the listener registered with [addWebRedemptionListener] or with
/// `PurchaselyBuilder.webRedemptionListener`.
void removeWebRedemptionListener() {
  _subscription?.cancel();
  _subscription = null;
}

/// Maps the wire body of a `purchasely-web-redemption` event to a
/// [PLYWebRedemptionResult].
///
/// The two levels stay separately nullable: a `context` key holding null is a
/// success with nothing to describe, and a `context` holding a null
/// `subscription` is a success that granted no subscription.
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
