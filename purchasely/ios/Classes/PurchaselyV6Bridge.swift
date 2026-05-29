//
//  PurchaselyV6Bridge.swift
//  purchasely_flutter
//
//  v6 bridge — wires the Dart-side v6 façade (`lib/src/`) to the v6 Purchasely
//  iOS SDK (PLYPresentationBuilder, Purchasely.apiKey(...).start, interceptAction).
//
//  Wiring contract — cf. `reports/v6-presentation-comparison-v3-claude/BRIDGE-CONTRACT.md`:
//   - Methods are dispatched from the shared `purchasely` MethodChannel with the
//     `v6/` prefix (e.g. `v6/start`, `v6/preload`, `v6/display`).
//   - Lifecycle callbacks (`onLoaded`, `onPresented`, `onCloseRequested`,
//     `onDismissed`) and interceptor invocations are emitted on the dedicated
//     `purchasely/v6-events` EventChannel — one stream, discriminated by the
//     `event` key. Each event carries `requestId` so Dart can route back.
//   - The iOS SDK's `PLYPresentationOutcome` only exposes 2 fields
//     (`purchaseResult`, `plan`). The 5-field contract (`presentation`,
//     `closeReason`, `error`) is synthesised here per BRIDGE-CONTRACT P0.2.
//   - `display()` Promise on the Dart side resolves at *dismiss* time — the
//     bridge waits for `onDismissed` rather than the SDK's display completion
//     handler (which fires at trigger time).
//   - Per BRIDGE-CONTRACT P0.4 the bridge synthesises `onPresented(nil, error)`
//     when the SDK's display/preload completion handler hands back an error.

import Flutter
import Foundation
import Purchasely
import UIKit

// MARK: - V6 EventChannel handler

final class PurchaselyV6EventHandler: NSObject, FlutterStreamHandler {
    private var sink: FlutterEventSink?

    func onListen(withArguments _: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        return nil
    }

    func onCancel(withArguments _: Any?) -> FlutterError? {
        sink = nil
        return nil
    }

    func emit(_ payload: [String: Any?]) {
        DispatchQueue.main.async { [weak self] in
            self?.sink?(payload.compactMapValues { $0 })
        }
    }
}

// MARK: - V6 bridge

final class PurchaselyV6Bridge {

    // requestId -> live PLYPresentationRequest
    private var requests: [String: PLYPresentationRequest] = [:]
    // requestId -> loaded PLYPresentation handle (kept so close/back/display can find it)
    private var presentations: [String: PLYPresentation] = [:]
    // invocationId -> SDK interceptor completion. Single-shot, removed on resolve.
    private var pendingInterceptors: [String: (PLYInterceptResult) -> Void] = [:]

    private let events: PurchaselyV6EventHandler

    init(events: PurchaselyV6EventHandler) {
        self.events = events
    }

    /// Returns true if the method was handled by the v6 bridge.
    func handle(_ method: String, arguments: [String: Any]?, result: @escaping FlutterResult) -> Bool {
        switch method {
        case "v6/start":
            v6Start(arguments, result: result); return true
        case "v6/preload":
            v6Preload(arguments, result: result); return true
        case "v6/display":
            v6Display(arguments, result: result); return true
        case "v6/close":
            v6Close(arguments, result: result); return true
        case "v6/back":
            v6Back(arguments, result: result); return true
        case "v6/registerInterceptor":
            v6RegisterInterceptor(arguments, result: result); return true
        case "v6/removeInterceptor":
            v6RemoveInterceptor(arguments, result: result); return true
        case "v6/removeAllInterceptors":
            v6RemoveAllInterceptors(result: result); return true
        case "v6/interceptorResolve":
            v6InterceptorResolve(arguments, result: result); return true
        default:
            return false
        }
    }

    // MARK: - start

    private func v6Start(_ args: [String: Any]?, result: @escaping FlutterResult) {
        guard let apiKey = args?["apiKey"] as? String, !apiKey.isEmpty else {
            result(FlutterError(code: "ARG_INVALID", message: "apiKey is required", details: nil))
            return
        }

        var builder = Purchasely.apiKey(apiKey)
            .appTechnology(.flutter)

        if let userId = args?["appUserId"] as? String, !userId.isEmpty {
            builder = builder.appUserId(userId)
        }

        if let mode = args?["runningMode"] as? String {
            switch mode {
            case "full":     builder = builder.runningMode(.full)
            case "observer": builder = builder.runningMode(.observer)
            default:         break
            }
        }

        if let logLevel = args?["logLevel"] as? String {
            switch logLevel {
            case "debug": builder = builder.logLevel(.debug)
            case "info":  builder = builder.logLevel(.info)
            case "warn":  builder = builder.logLevel(.warn)
            default:      builder = builder.logLevel(.error)
            }
        }

        if let storekit = args?["storekitVersion"] as? String {
            switch storekit {
            case "storeKit1": builder = builder.storekitSettings(.storeKit1)
            case "storeKit2": builder = builder.storekitSettings(.storeKit2)
            default:          break
            }
        }

        // `allowDeeplink` / `allowCampaigns` live as class-level setters on
        // iOS, not on PurchaselyBuilder. Apply them outside the builder chain
        // before kicking off start().
        if let allow = args?["allowDeeplink"] as? Bool { Purchasely.allowDeeplink(allow) }
        if let allow = args?["allowCampaigns"] as? Bool { Purchasely.allowCampaigns(allow) }

        builder.start { error in
            if let error = error {
                result(FlutterError(code: "V6_START",
                                    message: error.localizedDescription,
                                    details: String(describing: error)))
            } else {
                result(true)
            }
        }
    }

    // MARK: - preload / display

    private func buildRequest(_ args: [String: Any], requestId: String) -> PLYPresentationRequest {
        let source = args["source"] as? [String: Any]
        let kind = (source?["kind"] as? String) ?? "defaultSource"
        let id = source?["id"] as? String
        let contentId = args["contentId"] as? String

        // BRIDGE-CONTRACT P1.1 — Dart-side `screen(screenId)` maps to iOS
        // `from(presentationId:)`. Once the native iOS SDK exposes
        // `from(screenId:)` natively this rename will drop.
        let builder: PLYPresentationBuilder = {
            switch kind {
            case "placementId":
                return id.map { PLYPresentationBuilder.from(placementId: $0) } ?? .default()
            case "screenId":
                return id.map { PLYPresentationBuilder.from(presentationId: $0) } ?? .default()
            default:
                return .default()
            }
        }()

        if let contentId = contentId { _ = builder.contentId(contentId) }
        if let hex = args["backgroundColor"] as? String, let color = UIColor.ply_from(hex: hex) {
            _ = builder.backgroundColor(color)
        }
        if let hex = args["progressColor"] as? String, let color = UIColor.ply_from(hex: hex) {
            _ = builder.progressColor(color)
        }

        // Builder-seeded callbacks are transferred onto the loaded PLYPresentation
        // automatically by the SDK. They run on the main actor; we emit on the
        // EventChannel sink (main queue) directly.
        _ = builder.onPresented { [weak self] presentation, error in
            self?.events.emit([
                "event": "onPresented",
                "requestId": requestId,
                "presentation": presentation.map { self?.presentationToMap($0, requestId: requestId) ?? [:] } as Any?,
                "error": error.map { Self.errorToMap($0) } as Any?,
            ])
        }

        _ = builder.onClose { [weak self] in
            // BRIDGE-CONTRACT P0.1 — iOS exposes `onClose` (close-requested
            // semantics). Renamed to `onCloseRequested` on the wire so the
            // Dart-side façade matches the cross-platform contract.
            self?.events.emit([
                "event": "onCloseRequested",
                "requestId": requestId,
            ])
        }

        _ = builder.onDismissed { [weak self] outcome in
            // BRIDGE-CONTRACT P0.2 — synthesise the 5-field outcome from the
            // 2-field native outcome. `closeReason` stays nil until iOS exposes
            // it natively. `error` is nil here (the dismiss path doesn't carry
            // one); the error case is synthesised in display/preload completion.
            let presentation = self?.presentations[requestId]
            self?.events.emit([
                "event": "onDismissed",
                "requestId": requestId,
                "outcome": self?.outcomeToMap(outcome, presentation: presentation, error: nil, requestId: requestId) as Any?,
            ])
        }

        let request = builder.build()
        requests[requestId] = request
        return request
    }

    private func v6Preload(_ args: [String: Any]?, result: @escaping FlutterResult) {
        guard let args = args, let requestId = args["requestId"] as? String else {
            result(FlutterError(code: "ARG_INVALID", message: "requestId required", details: nil))
            return
        }
        let request = buildRequest(args, requestId: requestId)
        request.preload { [weak self] presentation, error in
            guard let self = self else { return }
            if let presentation = presentation {
                self.presentations[requestId] = presentation
                self.events.emit([
                    "event": "onLoaded",
                    "requestId": requestId,
                    "presentation": self.presentationToMap(presentation, requestId: requestId),
                ])
                result(self.presentationToMap(presentation, requestId: requestId))
            } else {
                let errMap = error.map { Self.errorToMap($0) } ?? ["code": "Unknown", "message": "unknown"]
                self.events.emit([
                    "event": "onLoaded",
                    "requestId": requestId,
                    "error": errMap,
                ])
                result(FlutterError(code: "V6_PRELOAD",
                                    message: error?.localizedDescription ?? "preload failed",
                                    details: errMap))
            }
        }
    }

    private func v6Display(_ args: [String: Any]?, result: @escaping FlutterResult) {
        guard let args = args, let requestId = args["requestId"] as? String else {
            result(FlutterError(code: "ARG_INVALID", message: "requestId required", details: nil))
            return
        }
        let request = requests[requestId] ?? buildRequest(args, requestId: requestId)

        let transitionMap = args["transition"] as? [String: Any]
        let displayMode = Self.parseTransition(transitionMap)

        request.display(transition: displayMode) { [weak self] presentation, error in
            guard let self = self else { return }
            // BRIDGE-CONTRACT P0.3 — the Dart-side `.display()` Future resolves
            // at *dismiss* time, not here. We don't `result(...)` with the
            // outcome — that's emitted via the `onDismissed` event and the Dart
            // façade resolves its Future from there. We do however acknowledge
            // the dispatch via `result(true)` so PlatformException doesn't fire
            // on success, and synthesise the error-path callbacks per P0.4.
            if let presentation = presentation {
                self.presentations[requestId] = presentation
                result(true)
            } else if let error = error {
                // P0.4 — synthesise onPresented(nil, error) so the Dart-side
                // builder onPresented handler fires uniformly across platforms.
                self.events.emit([
                    "event": "onPresented",
                    "requestId": requestId,
                    "presentation": nil as Any?,
                    "error": Self.errorToMap(error),
                ])
                // Also synthesise onDismissed with the 5-field error outcome.
                let outcome = self.outcomeToMap(
                    PLYPresentationOutcome(purchaseResult: .none, plan: nil),
                    presentation: nil,
                    error: error,
                    requestId: requestId
                )
                self.events.emit([
                    "event": "onDismissed",
                    "requestId": requestId,
                    "outcome": outcome,
                ])
                result(FlutterError(code: "V6_DISPLAY",
                                    message: error.localizedDescription,
                                    details: Self.errorToMap(error)))
            } else {
                result(true)
            }
        }
    }

    private func v6Close(_ args: [String: Any]?, result: @escaping FlutterResult) {
        let requestId = args?["requestId"] as? String
        if let id = requestId, let presentation = presentations[id] {
            presentation.close()
        } else {
            // No per-request handle — fall back to closing the topmost paywall
            // (best-effort; the iOS SDK doesn't expose a global "closeAll").
            presentations.values.forEach { $0.close() }
        }
        result(true)
    }

    private func v6Back(_ args: [String: Any]?, result: @escaping FlutterResult) {
        let requestId = args?["requestId"] as? String
        if let id = requestId, let presentation = presentations[id] {
            presentation.back()
        }
        result(true)
    }

    // MARK: - Interceptors

    private func v6RegisterInterceptor(_ args: [String: Any]?, result: @escaping FlutterResult) {
        guard let kindWire = args?["kind"] as? String,
              let action = Self.actionFromWire(kindWire) else {
            result(FlutterError(code: "ARG_INVALID", message: "unknown action kind", details: nil))
            return
        }

        Purchasely.interceptAction(action) { [weak self] info, params, completion in
            guard let self = self else { completion(.notHandled); return }
            let id = "ply_ic_\(Int.random(in: 0..<Int.max))"
            self.pendingInterceptors[id] = completion
            self.events.emit([
                "event": "interceptorTriggered",
                "requestId": id,
                "kind": kindWire,
                "info": Self.interceptorInfoToMap(info),
                "payload": Self.actionParamsToMap(params),
            ])
        }

        result(true)
    }

    private func v6RemoveInterceptor(_ args: [String: Any]?, result: @escaping FlutterResult) {
        if let kindWire = args?["kind"] as? String,
           let action = Self.actionFromWire(kindWire) {
            Purchasely.removeActionInterceptor(action)
        }
        result(true)
    }

    private func v6RemoveAllInterceptors(result: @escaping FlutterResult) {
        Purchasely.removeAllActionInterceptors()
        result(true)
    }

    private func v6InterceptorResolve(_ args: [String: Any]?, result: @escaping FlutterResult) {
        let id = args?["invocationId"] as? String
        let value = args?["result"] as? String
        let ply: PLYInterceptResult = {
            switch value {
            case "success": return .success
            case "failed":  return .failed
            default:        return .notHandled
            }
        }()
        if let id = id, let completion = pendingInterceptors.removeValue(forKey: id) {
            completion(ply)
        }
        result(true)
    }

    // MARK: - Serializers

    private func presentationToMap(_ p: PLYPresentation, requestId: String) -> [String: Any] {
        return [
            "requestId": requestId,
            // BRIDGE-CONTRACT P1.1 — iOS `id` maps to wire `screenId`. The Dart
            // factory tolerates both keys; we send `screenId` for forward
            // compatibility with the contract.
            "screenId": p.id,
            "placementId": p.placementId as Any,
            "contentId": NSNull(),
            "audienceId": p.audienceId as Any,
            "abTestId": p.abTestId as Any,
            "abTestVariantId": p.abTestVariantId as Any,
            "campaignId": p.campaignId as Any,
            "flowId": p.flowId as Any,
            "language": p.language,
            "type": p.type.rawValue,
            "height": p.height,
            "plans": p.plans.map { plan -> [String: Any?] in
                [
                    "planVendorId": plan.planVendorId,
                    "storeProductId": plan.storeProductId,
                    "basePlanId": nil as Any?,  // iOS doesn't expose basePlanId on PLYPresentationPlan
                    "offerId": plan.offerId,
                ]
            },
        ]
    }

    private func outcomeToMap(_ outcome: PLYPresentationOutcome,
                              presentation: PLYPresentation?,
                              error: Error?,
                              requestId: String) -> [String: Any?] {
        let purchaseResult: String? = {
            switch outcome.purchaseResult {
            case .purchased: return "purchased"
            case .cancelled: return "cancelled"
            case .restored:  return "restored"
            case .none:      return nil
            @unknown default: return nil
            }
        }()

        var planMap: [String: Any?]? = nil
        if let plan = outcome.plan {
            planMap = [
                "vendorId": plan.vendorId,
                "productId": plan.appleProductId as Any?,
            ]
        }

        return [
            "presentation": presentation.map { presentationToMap($0, requestId: requestId) } as Any?,
            "purchaseResult": purchaseResult,
            "plan": planMap as Any?,
            // BRIDGE-CONTRACT P0.2 — iOS SDK doesn't surface closeReason yet.
            "closeReason": nil as Any?,
            "error": error.map { Self.errorToMap($0) } as Any?,
        ]
    }

    private static func errorToMap(_ error: Error) -> [String: Any] {
        let ns = error as NSError
        return [
            "code": "\(ns.domain).\(ns.code)",
            "message": ns.localizedDescription,
        ]
    }

    private static func interceptorInfoToMap(_ info: PLYInterceptorInfo) -> [String: Any?] {
        // `PLYInterceptorInfo` on iOS exposes `contentId`, `presentation`, etc.
        // Mirror Android's shape — only the keys consumed by the Dart façade.
        return [
            "contentId": info.contentId,
            "presentation": info.presentation.map { p in
                [
                    "screenId": p.id,
                    "placementId": p.placementId as Any,
                ]
            } as Any?,
        ]
    }

    private static func actionParamsToMap(_ params: PLYPresentationActionParameters?) -> [String: Any]? {
        guard let params = params else { return nil }
        var map: [String: Any] = [:]
        if let url = params.url?.absoluteString { map["url"] = url }
        if let title = params.title { map["title"] = title }
        if let plan = params.plan {
            map["plan"] = [
                "vendorId": plan.vendorId as Any,
                "productId": plan.appleProductId as Any?,
            ]
        }
        if let presentationId = params.presentation { map["presentationId"] = presentationId }
        if let placementId = params.placement { map["placementId"] = placementId }
        // `webCheckoutProvider` is a non-optional enum with `.none` sentinel;
        // forward the raw value so the Dart side can treat .none as "absent".
        map["webCheckoutProvider"] = params.webCheckoutProvider.rawValue
        if let clientRef = params.clientReferenceId { map["clientReferenceId"] = clientRef }
        if let queryParam = params.queryParameterKey { map["queryParameterKey"] = queryParam }
        return map
    }

    private static func actionFromWire(_ wire: String) -> PLYPresentationAction? {
        switch wire {
        case "close":             return .close
        case "close_all":         return .closeAll
        case "login":             return .login
        case "navigate":          return .navigate
        case "purchase":          return .purchase
        case "restore":           return .restore
        case "open_presentation": return .openPresentation
        case "open_placement":    return .openPlacement
        case "promo_code":        return .promoCode
        case "web_checkout":      return .webCheckout
        default: return nil
        }
    }

    private static func parseTransition(_ map: [String: Any]?) -> PLYDisplayMode? {
        guard let map = map, let type = map["type"] as? String else { return nil }
        switch type {
        case "fullScreen":    return .fullScreen
        case "push":          return .push
        case "modal":         return .modal
        // `drawer`/`popin` are static factory functions on PLYDisplayMode in
        // v6 (they take height/dismissible params); the others are static vars.
        case "drawer":        return .drawer()
        case "popin":         return .popin()
        case "inlinePaywall": return .inlinePaywall
        default: return nil
        }
    }
}

// MARK: - UIColor helper

private extension UIColor {
    static func ply_from(hex: String) -> UIColor? {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8 else { return nil }
        if s.count == 6 { s = "FF" + s }
        var rgba: UInt64 = 0
        guard Scanner(string: s).scanHexInt64(&rgba) else { return nil }
        let a = CGFloat((rgba >> 24) & 0xFF) / 255.0
        let r = CGFloat((rgba >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgba >> 8)  & 0xFF) / 255.0
        let b = CGFloat( rgba        & 0xFF) / 255.0
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}
