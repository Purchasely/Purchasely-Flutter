// Purchasely SDK — Action interceptor API.
//
// Sealed class hierarchy for typed action payloads. Each action carries its
// own parameters. Register a per-action handler with
// `Purchasely.interceptAction(kind, handler)`. The
// handler returns an `PLYInterceptResult` (or a `Future<PLYInterceptResult>`) to let
// the SDK know how the action was handled.

import 'dart:async';

import 'ply_models.dart';
import 'ply_transformers.dart';
import 'presentation.dart';

/// Kind of action triggered from a presentation.
enum PLYPresentationActionKind {
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

extension PresentationActionKindWire on PLYPresentationActionKind {
  String get wire {
    switch (this) {
      case PLYPresentationActionKind.close:
        return 'close';
      case PLYPresentationActionKind.closeAll:
        return 'close_all';
      case PLYPresentationActionKind.login:
        return 'login';
      case PLYPresentationActionKind.navigate:
        return 'navigate';
      case PLYPresentationActionKind.purchase:
        return 'purchase';
      case PLYPresentationActionKind.restore:
        return 'restore';
      case PLYPresentationActionKind.openPresentation:
        return 'open_presentation';
      case PLYPresentationActionKind.openPlacement:
        return 'open_placement';
      case PLYPresentationActionKind.promoCode:
        return 'promo_code';
      case PLYPresentationActionKind.webCheckout:
        return 'web_checkout';
    }
  }

  static PLYPresentationActionKind? fromWire(String? value) {
    switch (value) {
      case 'close':
        return PLYPresentationActionKind.close;
      case 'close_all':
        return PLYPresentationActionKind.closeAll;
      case 'login':
        return PLYPresentationActionKind.login;
      case 'navigate':
        return PLYPresentationActionKind.navigate;
      case 'purchase':
        return PLYPresentationActionKind.purchase;
      case 'restore':
        return PLYPresentationActionKind.restore;
      case 'open_presentation':
        return PLYPresentationActionKind.openPresentation;
      case 'open_placement':
        return PLYPresentationActionKind.openPlacement;
      case 'promo_code':
        return PLYPresentationActionKind.promoCode;
      case 'web_checkout':
        return PLYPresentationActionKind.webCheckout;
      default:
        return null;
    }
  }
}

/// Result returned by an interceptor to the SDK.
enum PLYInterceptResult { success, failed, notHandled }

extension InterceptResultWire on PLYInterceptResult {
  String get wire {
    switch (this) {
      case PLYInterceptResult.success:
        return 'success';
      case PLYInterceptResult.failed:
        return 'failed';
      case PLYInterceptResult.notHandled:
        return 'notHandled';
    }
  }
}

/// Contextual information passed to every interceptor.
class PLYInterceptorInfo {
  final String? contentId;
  final PLYPresentation? presentation;

  const PLYInterceptorInfo({this.contentId, this.presentation});

  factory PLYInterceptorInfo.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const PLYInterceptorInfo();
    final presentationMap = map['presentation'];
    return PLYInterceptorInfo(
      contentId: map['contentId'] as String?,
      presentation:
          presentationMap is Map ? PLYPresentation.fromMap(presentationMap) : null,
    );
  }
}

/// Sealed-ish hierarchy of action payloads. Dart doesn't have sealed classes
/// in stable yet for all SDK versions; we use abstract + `kind` discriminator
/// and downcast via `is` for type-safe access.
abstract class PLYActionPayload {
  PLYPresentationActionKind get kind;
  const PLYActionPayload();
}

class PLYNavigatePayload extends PLYActionPayload {
  final String url;
  final String? title;
  const PLYNavigatePayload({required this.url, this.title});
  @override
  PLYPresentationActionKind get kind => PLYPresentationActionKind.navigate;
}

class PLYPurchasePayload extends PLYActionPayload {
  final PLYPlan plan;
  final PLYSubscriptionOffer? subscriptionOffer;
  final PLYPromoOffer? offer;
  const PLYPurchasePayload({
    required this.plan,
    this.subscriptionOffer,
    this.offer,
  });
  @override
  PLYPresentationActionKind get kind => PLYPresentationActionKind.purchase;
}

class PLYClosePayload extends PLYActionPayload {
  final String closeReason;
  const PLYClosePayload({required this.closeReason});
  @override
  PLYPresentationActionKind get kind => PLYPresentationActionKind.close;
}

class PLYCloseAllPayload extends PLYActionPayload {
  final String closeReason;
  const PLYCloseAllPayload({required this.closeReason});
  @override
  PLYPresentationActionKind get kind => PLYPresentationActionKind.closeAll;
}

class PLYOpenPresentationPayload extends PLYActionPayload {
  final String presentationId;
  const PLYOpenPresentationPayload({required this.presentationId});
  @override
  PLYPresentationActionKind get kind => PLYPresentationActionKind.openPresentation;
}

class PLYOpenPlacementPayload extends PLYActionPayload {
  final String placementId;
  const PLYOpenPlacementPayload({required this.placementId});
  @override
  PLYPresentationActionKind get kind => PLYPresentationActionKind.openPlacement;
}

class PLYWebCheckoutPayload extends PLYActionPayload {
  final String url;
  final String clientReferenceId;
  final String queryParameterKey;
  final String webCheckoutProvider;
  const PLYWebCheckoutPayload({
    required this.url,
    required this.clientReferenceId,
    required this.queryParameterKey,
    required this.webCheckoutProvider,
  });
  @override
  PLYPresentationActionKind get kind => PLYPresentationActionKind.webCheckout;
}

/// Payload-less actions (login, restore, promoCode) reuse this sentinel.
class _EmptyPayload extends PLYActionPayload {
  final PLYPresentationActionKind _kind;
  const _EmptyPayload(this._kind);
  @override
  PLYPresentationActionKind get kind => _kind;
}

/// Parse an action payload sent by the bridge.
PLYActionPayload? actionPayloadFromMap(
    PLYPresentationActionKind kind, Map<dynamic, dynamic>? rawParameters) {
  final parameters = rawParameters ?? const {};

  Map<dynamic, dynamic>? _map(Object? value) {
    if (value is Map) return value;
    return null;
  }

  switch (kind) {
    case PLYPresentationActionKind.navigate:
      final url = parameters['url'] as String?;
      if (url == null) return null;
      return PLYNavigatePayload(
        url: url,
        title: parameters['title'] as String?,
      );
    case PLYPresentationActionKind.purchase:
      final plan = plyPlanFromMap(_map(parameters['plan']));
      if (plan == null) return null;
      return PLYPurchasePayload(
        plan: plan,
        subscriptionOffer:
            plySubscriptionOfferFromMap(_map(parameters['subscriptionOffer'])),
        offer: plyPromoOfferFromMap(_map(parameters['offer'])),
      );
    case PLYPresentationActionKind.close:
      return PLYClosePayload(
          closeReason:
              (parameters['closeReason'] as String?) ?? 'programmatic');
    case PLYPresentationActionKind.closeAll:
      return PLYCloseAllPayload(
          closeReason:
              (parameters['closeReason'] as String?) ?? 'programmatic');
    case PLYPresentationActionKind.openPresentation:
      final id = (parameters['presentationId'] ?? parameters['presentation'])
          as String?;
      if (id == null) return null;
      return PLYOpenPresentationPayload(presentationId: id);
    case PLYPresentationActionKind.openPlacement:
      final id =
          (parameters['placementId'] ?? parameters['placement']) as String?;
      if (id == null) return null;
      return PLYOpenPlacementPayload(placementId: id);
    case PLYPresentationActionKind.webCheckout:
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
      return PLYWebCheckoutPayload(
        url: url,
        clientReferenceId: clientReferenceId,
        queryParameterKey: queryParameterKey,
        webCheckoutProvider: provider,
      );
    case PLYPresentationActionKind.login:
    case PLYPresentationActionKind.restore:
    case PLYPresentationActionKind.promoCode:
      return _EmptyPayload(kind);
  }
}

/// Signature of an action interceptor handler. May return synchronously or
/// asynchronously.
typedef PLYActionInterceptorHandler = FutureOr<PLYInterceptResult> Function(
  PLYInterceptorInfo info,
  PLYActionPayload? payload,
);
