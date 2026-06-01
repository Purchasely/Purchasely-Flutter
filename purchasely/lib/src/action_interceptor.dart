// Purchasely SDK — Action interceptor API.
//
// Sealed class hierarchy for typed action payloads. Each action carries its
// own parameters. Register a per-action handler with
// `Purchasely.interceptAction(kind, handler)`. The
// handler returns an `InterceptResult` (or a `Future<InterceptResult>`) to let
// the SDK know how the action was handled.

import 'dart:async';

import 'presentation.dart';

/// Kind of action triggered from a presentation.
enum PresentationActionKind {
  close,
  closeAll,
  login,
  navigate,
  purchase,
  restore,
  openPresentation,
  openPlacement,
  promoCode,
  webCheckout,
}

extension PresentationActionKindWire on PresentationActionKind {
  String get wire {
    switch (this) {
      case PresentationActionKind.close:
        return 'close';
      case PresentationActionKind.closeAll:
        return 'close_all';
      case PresentationActionKind.login:
        return 'login';
      case PresentationActionKind.navigate:
        return 'navigate';
      case PresentationActionKind.purchase:
        return 'purchase';
      case PresentationActionKind.restore:
        return 'restore';
      case PresentationActionKind.openPresentation:
        return 'open_presentation';
      case PresentationActionKind.openPlacement:
        return 'open_placement';
      case PresentationActionKind.promoCode:
        return 'promo_code';
      case PresentationActionKind.webCheckout:
        return 'web_checkout';
    }
  }

  static PresentationActionKind? fromWire(String? value) {
    switch (value) {
      case 'close':
        return PresentationActionKind.close;
      case 'close_all':
        return PresentationActionKind.closeAll;
      case 'login':
        return PresentationActionKind.login;
      case 'navigate':
        return PresentationActionKind.navigate;
      case 'purchase':
        return PresentationActionKind.purchase;
      case 'restore':
        return PresentationActionKind.restore;
      case 'open_presentation':
        return PresentationActionKind.openPresentation;
      case 'open_placement':
        return PresentationActionKind.openPlacement;
      case 'promo_code':
        return PresentationActionKind.promoCode;
      case 'web_checkout':
        return PresentationActionKind.webCheckout;
      default:
        return null;
    }
  }
}

/// Result returned by an interceptor to the SDK.
enum InterceptResult { success, failed, notHandled }

extension InterceptResultWire on InterceptResult {
  String get wire {
    switch (this) {
      case InterceptResult.success:
        return 'success';
      case InterceptResult.failed:
        return 'failed';
      case InterceptResult.notHandled:
        return 'notHandled';
    }
  }
}

/// Contextual information passed to every interceptor.
class InterceptorInfo {
  final String? contentId;
  final Presentation? presentation;

  const InterceptorInfo({this.contentId, this.presentation});

  factory InterceptorInfo.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const InterceptorInfo();
    final presentationMap = map['presentation'];
    return InterceptorInfo(
      contentId: map['contentId'] as String?,
      presentation:
          presentationMap is Map ? Presentation.fromMap(presentationMap) : null,
    );
  }
}

/// Sealed-ish hierarchy of action payloads. Dart doesn't have sealed classes
/// in stable yet for all SDK versions; we use abstract + `kind` discriminator
/// and downcast via `is` for type-safe access.
abstract class ActionPayload {
  PresentationActionKind get kind;
  const ActionPayload();
}

class NavigatePayload extends ActionPayload {
  final String url;
  final String? title;
  const NavigatePayload({required this.url, this.title});
  @override
  PresentationActionKind get kind => PresentationActionKind.navigate;
}

class PurchasePayload extends ActionPayload {
  final Map<String, dynamic> plan;
  final Map<String, dynamic>? subscriptionOffer;
  final Map<String, dynamic>? offer;
  const PurchasePayload({
    required this.plan,
    this.subscriptionOffer,
    this.offer,
  });
  @override
  PresentationActionKind get kind => PresentationActionKind.purchase;
}

class ClosePayload extends ActionPayload {
  final String closeReason;
  const ClosePayload({required this.closeReason});
  @override
  PresentationActionKind get kind => PresentationActionKind.close;
}

class CloseAllPayload extends ActionPayload {
  final String closeReason;
  const CloseAllPayload({required this.closeReason});
  @override
  PresentationActionKind get kind => PresentationActionKind.closeAll;
}

class OpenPresentationPayload extends ActionPayload {
  final String presentationId;
  const OpenPresentationPayload({required this.presentationId});
  @override
  PresentationActionKind get kind => PresentationActionKind.openPresentation;
}

class OpenPlacementPayload extends ActionPayload {
  final String placementId;
  const OpenPlacementPayload({required this.placementId});
  @override
  PresentationActionKind get kind => PresentationActionKind.openPlacement;
}

class WebCheckoutPayload extends ActionPayload {
  final String url;
  final String clientReferenceId;
  final String queryParameterKey;
  final String webCheckoutProvider;
  const WebCheckoutPayload({
    required this.url,
    required this.clientReferenceId,
    required this.queryParameterKey,
    required this.webCheckoutProvider,
  });
  @override
  PresentationActionKind get kind => PresentationActionKind.webCheckout;
}

/// Payload-less actions (login, restore, promoCode) reuse this sentinel.
class _EmptyPayload extends ActionPayload {
  final PresentationActionKind _kind;
  const _EmptyPayload(this._kind);
  @override
  PresentationActionKind get kind => _kind;
}

/// Parse an action payload sent by the bridge.
ActionPayload? actionPayloadFromMap(
    PresentationActionKind kind, Map<dynamic, dynamic>? rawParameters) {
  final parameters = rawParameters ?? const {};

  Map<String, dynamic>? _stringMap(Object? value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  switch (kind) {
    case PresentationActionKind.navigate:
      final url = parameters['url'] as String?;
      if (url == null) return null;
      return NavigatePayload(
        url: url,
        title: parameters['title'] as String?,
      );
    case PresentationActionKind.purchase:
      final plan = _stringMap(parameters['plan']);
      if (plan == null) return null;
      return PurchasePayload(
        plan: plan,
        subscriptionOffer: _stringMap(parameters['subscriptionOffer']),
        offer: _stringMap(parameters['offer']),
      );
    case PresentationActionKind.close:
      return ClosePayload(
          closeReason:
              (parameters['closeReason'] as String?) ?? 'programmatic');
    case PresentationActionKind.closeAll:
      return CloseAllPayload(
          closeReason:
              (parameters['closeReason'] as String?) ?? 'programmatic');
    case PresentationActionKind.openPresentation:
      final id = (parameters['presentationId'] ?? parameters['presentation'])
          as String?;
      if (id == null) return null;
      return OpenPresentationPayload(presentationId: id);
    case PresentationActionKind.openPlacement:
      final id =
          (parameters['placementId'] ?? parameters['placement']) as String?;
      if (id == null) return null;
      return OpenPlacementPayload(placementId: id);
    case PresentationActionKind.webCheckout:
      final url = parameters['url'] as String?;
      final clientReferenceId = parameters['clientReferenceId'] as String?;
      final queryParameterKey = parameters['queryParameterKey'] as String?;
      final provider = parameters['webCheckoutProvider'] as String?;
      if (url == null ||
          clientReferenceId == null ||
          queryParameterKey == null ||
          provider == null) {
        return null;
      }
      return WebCheckoutPayload(
        url: url,
        clientReferenceId: clientReferenceId,
        queryParameterKey: queryParameterKey,
        webCheckoutProvider: provider,
      );
    case PresentationActionKind.login:
    case PresentationActionKind.restore:
    case PresentationActionKind.promoCode:
      return _EmptyPayload(kind);
  }
}

/// Signature of an action interceptor handler. May return synchronously or
/// asynchronously.
typedef ActionInterceptorHandler = FutureOr<InterceptResult> Function(
  InterceptorInfo info,
  ActionPayload? payload,
);
