// Purchasely SDK — PLYPresentation outcome models.

import 'ply_models.dart';
import 'presentation.dart';

/// Result of the purchase action triggered from a presentation.
enum PLYPurchaseResult { purchased, cancelled, restored }

/// Reason a presentation was closed when no error occurred.
///
/// Mutually exclusive with [PLYPresentationOutcome.error] — when [error] is
/// non null, [closeReason] is `null`.
///
/// Mirrors the native `PLYCloseReason` wire contract shared by iOS and
/// Android: `button` (`"button"`), `backSystem` (`"back_system"` — Android
/// system back / iOS interactive swipe-down or nav-pop), and `programmatic`
/// (`"programmatic"`).
enum PLYCloseReason { button, backSystem, programmatic }

/// Error returned by the native SDK when a presentation could not be displayed.
class PLYPresentationError implements Exception {
  /// Native error code (`code` field from `PLYError`).
  final String? code;

  /// Human-readable message.
  final String? message;

  /// Optional payload (e.g. underlying exception description, native stack).
  final dynamic details;

  const PLYPresentationError({this.code, this.message, this.details});

  @override
  String toString() => 'PLYPresentationError(code: $code, message: $message)';
}

/// The outcome of a presentation session, delivered when the presentation is
/// dismissed (or fails before display).
///
/// Five fields, matching the cross-platform contract:
///  * [presentation] — the presentation that produced this outcome, or `null`
///    if the presentation never reached the displayed state (pre-display
///    failure).
///  * [purchaseResult] — the purchase action result. `null` when no purchase
///    happened.
///  * [plan] — the plan involved in the purchase action (if any).
///  * [closeReason] — why the presentation was closed. `null` when an [error]
///    occurred or when no close happened (e.g. a purchase/restore outcome).
///  * [error] — display error when the presentation could not be shown.
///    Mutually exclusive with [closeReason].
class PLYPresentationOutcome {
  final PLYPresentation? presentation;
  final PLYPurchaseResult? purchaseResult;
  final PLYPlan? plan;
  final PLYCloseReason? closeReason;
  final PLYPresentationError? error;

  const PLYPresentationOutcome({
    this.presentation,
    this.purchaseResult,
    this.plan,
    this.closeReason,
    this.error,
  });

  @override
  String toString() =>
      'PLYPresentationOutcome(purchaseResult: $purchaseResult, closeReason: $closeReason, error: $error)';
}

PLYPurchaseResult? purchaseResultFromString(String? value) {
  switch (value) {
    case 'purchased':
      return PLYPurchaseResult.purchased;
    case 'cancelled':
      return PLYPurchaseResult.cancelled;
    case 'restored':
      return PLYPurchaseResult.restored;
    case null:
    case '':
    case 'none':
      return null;
    default:
      return null;
  }
}

PLYCloseReason? closeReasonFromString(String? value) {
  switch (value) {
    case 'button':
      return PLYCloseReason.button;
    case 'back_system':
      return PLYCloseReason.backSystem;
    case 'programmatic':
      return PLYCloseReason.programmatic;
    default:
      return null;
  }
}
