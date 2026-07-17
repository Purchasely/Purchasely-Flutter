// Unit tests for the interceptor payload parsing (`actionPayloadFromMap`) and the
// action-kind wire mapping. Covers every PLYPresentationActionKind so a drift in
// the bridge wire contract (key names, missing-field handling) is caught at unit
// level — previously only the `purchase` payload was exercised (in E2E).

import 'package:flutter_test/flutter_test.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

void main() {
  group('PresentationActionKindWire round-trip', () {
    test('every kind maps to a wire string and back', () {
      for (final kind in PLYPresentationActionKind.values) {
        final wire = kind.wire;
        expect(wire, isNotEmpty);
        expect(PresentationActionKindWire.fromWire(wire), kind,
            reason: 'wire "$wire" must round-trip back to $kind');
      }
    });

    test('unknown wire string returns null', () {
      expect(PresentationActionKindWire.fromWire('not_an_action'), isNull);
      expect(PresentationActionKindWire.fromWire(null), isNull);
    });
  });

  group('actionPayloadFromMap', () {
    test('navigate parses url + title; null url → null payload', () {
      final p = actionPayloadFromMap(
        PLYPresentationActionKind.navigate,
        {'url': 'https://example.com', 'title': 'Help'},
      );
      expect(p, isA<PLYNavigatePayload>());
      final nav = p as PLYNavigatePayload;
      expect(nav.url, 'https://example.com');
      expect(nav.title, 'Help');
      expect(nav.kind, PLYPresentationActionKind.navigate);

      expect(
          actionPayloadFromMap(PLYPresentationActionKind.navigate, {}), isNull);
    });

    test('purchase parses plan (+ optional offers); null plan → null payload',
        () {
      final p = actionPayloadFromMap(
        PLYPresentationActionKind.purchase,
        {
          'plan': {'vendorId': 'plan_x', 'type': 2},
          'subscriptionOffer': {'subscriptionId': 'sub_1'},
          'offer': {'vendorId': 'offer_1'},
        },
      );
      expect(p, isA<PLYPurchasePayload>());
      final pur = p as PLYPurchasePayload;
      expect(pur.plan.vendorId, 'plan_x');
      expect(pur.subscriptionOffer?.subscriptionId, 'sub_1');
      expect(pur.offer?.vendorId, 'offer_1');
      expect(pur.kind, PLYPresentationActionKind.purchase);

      expect(
          actionPayloadFromMap(PLYPresentationActionKind.purchase, {}), isNull);
    });

    test('close / closeAll parse closeReason and default to programmatic', () {
      final close = actionPayloadFromMap(
              PLYPresentationActionKind.close, {'closeReason': 'button'})
          as PLYClosePayload;
      expect(close.closeReason, 'button');
      expect(close.kind, PLYPresentationActionKind.close);

      final closeAllDefault =
          actionPayloadFromMap(PLYPresentationActionKind.closeAll, {})
              as PLYCloseAllPayload;
      expect(closeAllDefault.closeReason, 'programmatic');
      expect(closeAllDefault.kind, PLYPresentationActionKind.closeAll);
    });

    test('openPresentation accepts presentationId or presentation key', () {
      final byId = actionPayloadFromMap(
          PLYPresentationActionKind.openPresentation,
          {'presentationId': 'pres_1'}) as PLYOpenPresentationPayload;
      expect(byId.presentationId, 'pres_1');

      final byAlias = actionPayloadFromMap(
          PLYPresentationActionKind.openPresentation,
          {'presentation': 'pres_2'}) as PLYOpenPresentationPayload;
      expect(byAlias.presentationId, 'pres_2');

      expect(
          actionPayloadFromMap(PLYPresentationActionKind.openPresentation, {}),
          isNull);
    });

    test('openPlacement accepts placementId or placement key', () {
      final byId = actionPayloadFromMap(PLYPresentationActionKind.openPlacement,
          {'placementId': 'place_1'}) as PLYOpenPlacementPayload;
      expect(byId.placementId, 'place_1');

      final byAlias = actionPayloadFromMap(
              PLYPresentationActionKind.openPlacement, {'placement': 'place_2'})
          as PLYOpenPlacementPayload;
      expect(byAlias.placementId, 'place_2');

      expect(actionPayloadFromMap(PLYPresentationActionKind.openPlacement, {}),
          isNull);
    });

    test('webCheckout requires all four fields', () {
      final full = actionPayloadFromMap(
        PLYPresentationActionKind.webCheckout,
        {
          'url': 'https://pay.example.com',
          'clientReferenceId': 'ref_1',
          'queryParameterKey': 'token',
          'webCheckoutProvider': 'stripe',
        },
      );
      expect(full, isA<PLYWebCheckoutPayload>());
      final wc = full as PLYWebCheckoutPayload;
      expect(wc.url, 'https://pay.example.com');
      expect(wc.clientReferenceId, 'ref_1');
      expect(wc.queryParameterKey, 'token');
      expect(wc.webCheckoutProvider, 'stripe');

      // Any missing field → null payload.
      expect(
        actionPayloadFromMap(PLYPresentationActionKind.webCheckout, {
          'url': 'https://pay.example.com',
          'clientReferenceId': 'ref_1',
          'queryParameterKey': 'token',
        }),
        isNull,
      );
    });

    test(
        'webCheckout tolerates a legacy Int webCheckoutProvider (rawValue) '
        'without crashing (FLT-W-08 / REC-01)', () {
      Map<String, Object?> withProvider(Object? provider) => {
            'url': 'https://pay.example.com',
            'clientReferenceId': 'ref_1',
            'queryParameterKey': 'token',
            'webCheckoutProvider': provider,
          };

      // Correct wire format (String, matches Android's `.name` / fixed iOS).
      final fromString =
          actionPayloadFromMap(PLYPresentationActionKind.webCheckout,
              withProvider('STRIPE')) as PLYWebCheckoutPayload;
      expect(fromString.webCheckoutProvider, 'STRIPE');

      // Legacy/regressed Int rawValue (pre-fix iOS): must not throw, and
      // should still map to a usable provider name.
      final fromInt0 = actionPayloadFromMap(
          PLYPresentationActionKind.webCheckout,
          withProvider(0)) as PLYWebCheckoutPayload;
      expect(fromInt0.webCheckoutProvider, 'STRIPE');

      final fromInt1 = actionPayloadFromMap(
          PLYPresentationActionKind.webCheckout,
          withProvider(1)) as PLYWebCheckoutPayload;
      expect(fromInt1.webCheckoutProvider, 'OTHER');

      // Unrecognized Int (e.g. the `.none` sentinel, rawValue 2) → no crash,
      // payload is null because the field is required.
      expect(
        actionPayloadFromMap(
            PLYPresentationActionKind.webCheckout, withProvider(2)),
        isNull,
      );
    });

    test('login / restore / promoCode yield a payload carrying their kind', () {
      for (final kind in [
        PLYPresentationActionKind.login,
        PLYPresentationActionKind.restore,
        PLYPresentationActionKind.promoCode,
      ]) {
        final p = actionPayloadFromMap(kind, null);
        expect(p, isNotNull, reason: '$kind must yield an (empty) payload');
        expect(p!.kind, kind);
      }
    });
  });

  group('PLYInterceptorInfo.fromMap', () {
    test('null map yields an empty info', () {
      final info = PLYInterceptorInfo.fromMap(null);
      expect(info.contentId, isNull);
      expect(info.presentation, isNull);
    });

    test('parses contentId and a presentation map', () {
      final info = PLYInterceptorInfo.fromMap({
        'contentId': 'content_42',
        'presentation': {
          'requestId': 'req_1',
          'screenId': 'screen_1',
          'placementId': 'placement_1',
        },
      });
      expect(info.contentId, 'content_42');
      expect(info.presentation, isNotNull);
      expect(info.presentation!.screenId, 'screen_1');
    });
  });
}
