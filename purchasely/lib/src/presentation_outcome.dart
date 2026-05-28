// Purchasely SDK v6 — Presentation outcome models.
//
// See `BRIDGE-CONTRACT.md` (`reports/v6-presentation-comparison-v3-claude/`)
// for the cross-platform contract these types implement.

import 'presentation.dart';

/// Result of the purchase action triggered from a presentation.
enum PurchaseResult { purchased, cancelled, restored }

/// Reason a presentation was closed when no error occurred.
///
/// Mutually exclusive with [PresentationOutcome.error] — when [error] is non
/// null, [closeReason] is `null`.
enum CloseReason { button, backSystem, programmatic }

/// Error returned by the native SDK when a presentation could not be displayed.
class PresentationError implements Exception {
  /// Native error code (`code` field from `PLYError`).
  final String? code;

  /// Human-readable message.
  final String? message;

  /// Optional payload (e.g. underlying exception description, native stack).
  final dynamic details;

  const PresentationError({this.code, this.message, this.details});

  @override
  String toString() => 'PresentationError(code: $code, message: $message)';
}

/// The outcome of a presentation session, delivered when the presentation is
/// dismissed (or fails before display).
///
/// Five fields, matching the v6 cross-platform contract:
///  * [presentation] — the presentation that produced this outcome, or `null`
///    if the presentation never reached the displayed state (pre-display
///    failure).
///  * [purchaseResult] — the purchase action result. `null` when no purchase
///    happened.
///  * [plan] — the plan involved in the purchase action (if any).
///  * [closeReason] — why the presentation was closed. iOS sets this to `null`
///    until the native fix lands (see contract P0.2).
///  * [error] — display error when the presentation could not be shown.
///    Mutually exclusive with [closeReason].
class PresentationOutcome {
  final Presentation? presentation;
  final PurchaseResult? purchaseResult;
  final Map<String, dynamic>? plan;
  final CloseReason? closeReason;
  final PresentationError? error;

  const PresentationOutcome({
    this.presentation,
    this.purchaseResult,
    this.plan,
    this.closeReason,
    this.error,
  });

  @override
  String toString() =>
      'PresentationOutcome(purchaseResult: $purchaseResult, closeReason: $closeReason, error: $error)';
}

PurchaseResult? purchaseResultFromString(String? value) {
  switch (value) {
    case 'purchased':
      return PurchaseResult.purchased;
    case 'cancelled':
      return PurchaseResult.cancelled;
    case 'restored':
      return PurchaseResult.restored;
    case null:
    case '':
    case 'none':
      return null;
    default:
      return null;
  }
}

CloseReason? closeReasonFromString(String? value) {
  switch (value) {
    case 'button':
      return CloseReason.button;
    case 'backSystem':
    case 'back_system':
      return CloseReason.backSystem;
    case 'programmatic':
      return CloseReason.programmatic;
    default:
      return null;
  }
}
