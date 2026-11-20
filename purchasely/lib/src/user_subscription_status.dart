// Purchasely SDK — User subscription status listener (6.3.0, MOB-647).
//
// Own module, like `web_redemption.dart`, so the entry point can re-export it.

import 'dart:async';
import 'dart:developer';

import 'package:flutter/services.dart';

import 'ply_models.dart';
import 'ply_transformers.dart';

/// Why the SDK sends a [PLYUserSubscriptionStatus].
enum PLYUserSubscriptionStatusReason {
  /// The user bought a subscription.
  purchased,

  /// The user restored a subscription.
  restored,

  /// A subscription is no longer active.
  expired,

  /// A subscription new for the SDK arrived through a Web2App redemption
  /// (`ply/redeem`).
  webRedeemed,
}

/// The user's subscription status, as the native SDK sends it to the listener
/// registered with `Purchasely.addUserSubscriptionStatusListener`.
class PLYUserSubscriptionStatus {
  /// `true` when the user has one or more active subscriptions. Non-consumables
  /// do not count.
  final bool isActive;

  /// What changed. `null` for a status call: the SDK tells the current status
  /// and nothing changed.
  final PLYUserSubscriptionStatusReason? reason;

  /// The subscription of the call, the same type `Purchasely.userSubscriptions()`
  /// returns. `null` only in a status call for a user with no subscription:
  /// [isActive] is then `false`.
  final PLYSubscription? subscription;

  const PLYUserSubscriptionStatus({
    required this.isActive,
    this.reason,
    this.subscription,
  });

  @override
  String toString() => 'PLYUserSubscriptionStatus('
      'isActive: $isActive, reason: $reason, subscription: $subscription)';
}

/// Callback signature for a user subscription status.
typedef PLYUserSubscriptionStatusListener = void Function(
    PLYUserSubscriptionStatus status);

/// `const` is inert: the `listen` message goes out on the first `listen(...)`.
const EventChannel _channel =
    EventChannel('purchasely-user-subscription-status');

StreamSubscription<dynamic>? _subscription;

/// The live subscription, or null when no listener is registered.
StreamSubscription<dynamic>? get userSubscriptionStatusSubscription =>
    _subscription;

/// Registers [listener], replacing any listener already registered. The native
/// SDK sends the current status first when it knows it, then every change.
void addUserSubscriptionStatusListener(
    PLYUserSubscriptionStatusListener listener) {
  _subscription?.cancel();
  _subscription = _channel.receiveBroadcastStream().listen(
    (event) =>
        listener(userSubscriptionStatusFromMap(event as Map<dynamic, dynamic>)),
    // Keep the subscription alive: the next status must still arrive.
    onError: (Object error, StackTrace stack) {
      log('Purchasely: user subscription status channel error: $error');
    },
  );
}

/// Removes the listener registered with [addUserSubscriptionStatusListener].
void removeUserSubscriptionStatusListener() {
  _subscription?.cancel();
  _subscription = null;
}

PLYUserSubscriptionStatusReason? _reasonFromWire(dynamic raw) {
  switch (raw) {
    case 'PURCHASED':
      return PLYUserSubscriptionStatusReason.purchased;
    case 'RESTORED':
      return PLYUserSubscriptionStatusReason.restored;
    case 'EXPIRED':
      return PLYUserSubscriptionStatusReason.expired;
    case 'WEB_REDEEMED':
      return PLYUserSubscriptionStatusReason.webRedeemed;
    default:
      // null is a status call; an unknown name (a newer native SDK) maps to null too.
      return null;
  }
}

PLYUserSubscriptionStatus userSubscriptionStatusFromMap(
    Map<dynamic, dynamic> body) {
  final subscription = body['subscription'];
  return PLYUserSubscriptionStatus(
    isActive: body['isActive'] == true,
    reason: _reasonFromWire(body['reason']),
    subscription:
        subscription is Map ? plySubscriptionFromMap(subscription) : null,
  );
}
