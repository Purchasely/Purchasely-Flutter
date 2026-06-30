import Flutter
import UIKit
import Purchasely

public class SwiftPurchaselyFlutterPlugin: NSObject, FlutterPlugin {

    private static var isStarted: Bool = false

    // Presentation/interceptor state shared with the inline NativeView. Keyed by
    // the Dart-side `requestId` so close/back/display and the platform view can
    // find the right handle. Retained after dismissal to support re-displaying a
    // Dart Presentation handle; there is no native dispose API yet.
    static var requests: [String: PLYPresentationRequest] = [:]
    static var loadedPresentations: [String: PLYPresentation] = [:]
    // invocationId -> SDK interceptor completion. Single-shot, removed on resolve.
    private static var pendingInterceptors: [String: (PLYInterceptResult) -> Void] = [:]

    // The live plugin instance, so the inline NativeView can reach the shared
    // `purchasely-presentation-events` sink and surface the same `onDismissed`
    // envelope as the full-screen path.
    private(set) static weak var shared: SwiftPurchaselyFlutterPlugin?

    let eventChannel: FlutterEventChannel
    let eventHandler: SwiftEventHandler

    let purchaseChannel: FlutterEventChannel
    let purchaseHandler: SwiftPurchaseHandler

    let userAttributesChannel: FlutterEventChannel
    let userAttributesHandler: UserAttributesHandler

    // Presentation/interceptor lifecycle events flow over a dedicated stream,
    // discriminated by the `event` key; each carries a `requestId` so Dart can
    // route back.
    let presentationChannel: FlutterEventChannel
    let presentationEventHandler: PresentationEventHandler

    var presentedPresentationViewController: UIViewController?

    public init(with registrar: FlutterPluginRegistrar) {
        self.eventChannel = FlutterEventChannel(name: "purchasely-events",
                                           binaryMessenger: registrar.messenger())
        self.eventHandler = SwiftEventHandler()
        self.eventChannel.setStreamHandler(self.eventHandler)

        self.purchaseChannel = FlutterEventChannel(name: "purchasely-purchases",
                                                   binaryMessenger: registrar.messenger())
        self.purchaseHandler = SwiftPurchaseHandler()
        self.purchaseChannel.setStreamHandler(self.purchaseHandler)

        self.userAttributesChannel = FlutterEventChannel(name: "purchasely-user-attributes",
                                                      binaryMessenger: registrar.messenger())
        self.userAttributesHandler = UserAttributesHandler()
        self.userAttributesChannel.setStreamHandler(self.userAttributesHandler)

        self.presentationChannel = FlutterEventChannel(name: "purchasely-presentation-events",
                                                       binaryMessenger: registrar.messenger())
        self.presentationEventHandler = PresentationEventHandler()
        self.presentationChannel.setStreamHandler(self.presentationEventHandler)

        super.init()
        SwiftPurchaselyFlutterPlugin.shared = self
    }

    /// Emits a presentation lifecycle envelope onto the shared
    /// `purchasely-presentation-events` sink. Used by the inline NativeView so
    /// the embedded path surfaces the same `{ event, requestId, outcome }`
    /// envelopes as the full-screen path.
    static func emitPresentationEvent(_ payload: [String: Any?]) {
        shared?.presentationEventHandler.emit(payload)
    }

    /// Static accessor to the outcome serializer so the inline NativeView emits
    /// the exact same `outcome` shape as the full-screen path.
    static func outcomeMap(_ outcome: PLYPresentationOutcome,
                           presentation: PLYPresentation?,
                           error: Error?,
                           requestId: String) -> [String: Any?] {
        return shared?.outcomeToMap(outcome,
                                    presentation: presentation,
                                    error: error,
                                    requestId: requestId) ?? [:]
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "purchasely",
                                           binaryMessenger: registrar.messenger())

        let instance = SwiftPurchaselyFlutterPlugin(with: registrar)
        registrar.addMethodCallDelegate(instance, channel: channel)

        let factory = NativeViewFactory(messenger: registrar.messenger())
        registrar.register(factory, withId: "io.purchasely.purchasely_flutter/native_view")
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? [String: Any]
        switch call.method {
        // --- start ---
        case "start":
            start(arguments: arguments, result: result)

        // --- presentation lifecycle ---
        case "preload":
            preload(arguments, result: result)
        case "display":
            display(arguments, result: result)
        case "close":
            closePresentation(arguments, result: result)
        case "back":
            back(arguments, result: result)

        // --- action interceptor ---
        case "registerInterceptor":
            registerInterceptor(arguments, result: result)
        case "removeInterceptor":
            removeInterceptor(arguments, result: result)
        case "removeAllInterceptors":
            removeAllInterceptors(result: result)
        case "interceptorResolve":
            interceptorResolve(arguments, result: result)

        // --- kept v5 surface ---
        case "restoreAllProducts":
            restoreAllProducts(result)
        case "silentRestoreAllProducts":
            silentRestoreAllProducts(result)
        case "synchronize":
            synchronize(result)
        case "getAnonymousUserId":
            DispatchQueue.main.async { [weak self] in
                guard let `self` = self else { return }
                result(self.getAnonymousUserId())
            }
        case "userLogin":
            userLogin(arguments: arguments, result: result)
        case "userLogout":
            userLogout(result: result)
        case "allowDeeplink":
            let parameter = arguments?["allowDeeplink"] as? Bool
            allowDeeplink(allowDeeplink: parameter)
            result(true)
        case "allowCampaigns":
            let parameter = arguments?["allowCampaigns"] as? Bool
            allowCampaigns(allowCampaigns: parameter)
            result(true)
        case "setDefaultPresentationDismissHandler":
            setDefaultPresentationDismissHandler(result: result)
        case "removeDefaultPresentationDismissHandler":
            removeDefaultPresentationDismissHandler(result: result)
        case "setLogLevel":
            let parameter = (arguments?["logLevel"] as? Int) ?? PLYLogger.PLYLogLevel.debug.rawValue
            let logLevel = PLYLogger.PLYLogLevel(rawValue: parameter) ?? PLYLogger.PLYLogLevel.debug
            Purchasely.setLogLevel(logLevel)
            DispatchQueue.main.async {
                result(true)
            }
        case "productWithIdentifier":
            productWithIdentifier(arguments: arguments, result: result)
        case "planWithIdentifier":
            planWithIdentifier(arguments: arguments, result: result)
        case "allProducts":
            allProducts(result)
        case "purchaseWithPlanVendorId":
            purchaseWithPlanVendorId(arguments: arguments, result: result)
        case "handleDeeplink":
            let parameter = arguments?["deeplink"] as? String
            handleDeeplink(parameter, result: result)
        case "userSubscriptions":
            userSubscriptions(result)
        case "userSubscriptionsHistory":
            userSubscriptionsHistory(result)
        case "setThemeMode":
            setThemeMode(arguments: arguments)
            result(true)
        case "setAttribute":
            setAttribute(arguments: arguments)
            result(true)
        case "setLanguage":
            let parameter = arguments?["language"] as? String
            setLanguage(with: parameter)
        case "userDidConsumeSubscriptionContent":
            userDidConsumeSubscriptionContent()
            result(true)
        case "setUserAttributeWithString":
            setUserAttributeWithString(arguments: arguments)
        case "setUserAttributeWithInt":
            setUserAttributeWithInt(arguments: arguments)
        case "setUserAttributeWithDouble":
            setUserAttributeWithDouble(arguments: arguments)
        case "setUserAttributeWithBoolean":
            setUserAttributeWithBoolean(arguments: arguments)
        case "setUserAttributeWithDate":
            setUserAttributeWithDate(arguments: arguments)
        case "setUserAttributeWithStringArray":
            setUserAttributeWithStringArray(arguments: arguments)
        case "setUserAttributeWithIntArray":
            setUserAttributeWithIntArray(arguments: arguments)
        case "setUserAttributeWithDoubleArray":
            setUserAttributeWithDoubleArray(arguments: arguments)
        case "setUserAttributeWithBooleanArray":
            setUserAttributeWithBooleanArray(arguments: arguments)
        case "incrementUserAttribute":
            incrementUserAttribute(arguments: arguments)
        case "decrementUserAttribute":
            decrementUserAttribute(arguments: arguments)
        case "userAttribute":
            getUserAttribute(arguments: arguments, result: result)
        case "userAttributes":
            getUserAttributes(result: result)
        case "clearUserAttribute":
            clearUserAttribute(arguments: arguments)
        case "clearUserAttributes":
            clearUserAttributes()
        case "clearBuiltInAttributes":
            clearBuiltInAttributes()
        case "displaySubscriptionCancellationInstruction":
            // iOS has no dedicated cancellation-instruction screen; no-op.
            result(true)
        case "isAnonymous":
            isAnonymous(result: result)
        case "signPromotionalOffer":
            signPromotionalOffer(arguments: arguments, result: result)
        case "isEligibleForIntroOffer":
            isEligibleForIntroOffer(arguments: arguments, result: result)
        case "setDynamicOffering":
            setDynamicOffering(arguments: arguments, result: result)
        case "getDynamicOfferings":
            getDynamicOfferings(result: result)
        case "removeDynamicOffering":
            removeDynamicOffering(arguments: arguments)
        case "clearDynamicOfferings":
            clearDynamicOfferings()
        case "revokeDataProcessingConsent":
            revokeDataProcessingConsent(arguments: arguments)
        case "setDebugMode":
            setDebugMode(arguments: arguments)
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - start

    private func start(arguments: [String: Any]?, result: @escaping FlutterResult) {

        guard let arguments = arguments, let apiKey = arguments["apiKey"] as? String, !apiKey.isEmpty else {
            result(FlutterError.failedArgumentField("apiKey", type: String.self))
            return
        }

        guard !SwiftPurchaselyFlutterPlugin.isStarted else {
            result(true)
            return
        }

        var builder = Purchasely.apiKey(apiKey)
            .appTechnology(.flutter)
            .sdkBridgeVersion("6.0.0-rc.2")

        if let userId = (arguments["appUserId"] as? String) ?? (arguments["userId"] as? String), !userId.isEmpty {
            builder = builder.appUserId(userId)
        }

        builder = builder.runningMode(Self.runningMode(from: arguments["runningMode"]))
        builder = builder.logLevel(Self.logLevel(from: arguments["logLevel"]))
        builder = builder.storekitSettings(Self.storekitSettings(from: arguments))

        // Cold-start deeplink: the builder resolves it automatically once
        // started, so the host does not need a separate handleDeeplink() call.
        if let deeplink = arguments["deeplink"] as? String, let url = URL(string: deeplink) {
            builder = builder.handleDeeplink(url)
        }

        if let allowDeeplink = arguments["allowDeeplink"] as? Bool {
            Purchasely.allowDeeplink(allowDeeplink)
        }
        if let allowCampaigns = arguments["allowCampaigns"] as? Bool {
            Purchasely.allowCampaigns(allowCampaigns)
        }

        DispatchQueue.main.async {
            builder.start { error in
                if let error = error {
                    result(FlutterError.error(code: "0", message: "Purchasely SDK not configured", error: error))
                } else {
                    SwiftPurchaselyFlutterPlugin.isStarted = true
                    result(true)
                }
            }
        }
    }

    // MARK: - Presentation lifecycle

    /// Build a `PLYPresentationRequest` from a Dart-side request map. The map
    /// shape mirrors `PresentationRequest.toMap()` in
    /// `lib/src/presentation_request.dart`.
    private func buildRequest(_ args: [String: Any], requestId: String) -> PLYPresentationRequest {
        let source = args["source"] as? [String: Any]
        let kind = (source?["kind"] as? String) ?? "defaultSource"
        let id = source?["id"] as? String
        let contentId = args["contentId"] as? String

        let builder: PLYPresentationBuilder = {
            switch kind {
            case "placementId":
                return id.map { PLYPresentationBuilder.from(placementId: $0) } ?? .default()
            case "screenId":
                return id.map { PLYPresentationBuilder.from(screenId: $0) } ?? .default()
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

        // Builder-seeded callbacks are transferred onto the loaded presentation
        // automatically by the SDK. They run on the main actor; we emit on the
        // EventChannel sink (main queue) directly.
        _ = builder.onPresented { [weak self] presentation, error in
            self?.presentationEventHandler.emit([
                "event": "onPresented",
                "requestId": requestId,
                "presentation": presentation.map { self?.presentationToMap($0, requestId: requestId) ?? [:] } as Any?,
                "error": error.map { Self.errorToMap($0) } as Any?,
            ])
        }

        _ = builder.onClose { [weak self] in
            // iOS exposes `onClose` (close-requested semantics). Renamed to
            // `onCloseRequested` on the wire so the Dart-side façade matches
            // the cross-platform contract.
            self?.presentationEventHandler.emit([
                "event": "onCloseRequested",
                "requestId": requestId,
            ])
        }

        _ = builder.onDismissed { [weak self] outcome in
            let presentation = SwiftPurchaselyFlutterPlugin.loadedPresentations[requestId]
            self?.presentationEventHandler.emit([
                "event": "onDismissed",
                "requestId": requestId,
                "outcome": self?.outcomeToMap(outcome, presentation: presentation, error: nil, requestId: requestId) as Any?,
            ])
        }

        let request = builder.build()
        SwiftPurchaselyFlutterPlugin.requests[requestId] = request
        return request
    }

    private func preload(_ args: [String: Any]?, result: @escaping FlutterResult) {
        guard let args = args, let requestId = args["requestId"] as? String, !requestId.isEmpty else {
            result(FlutterError(code: "ARG_INVALID", message: "requestId required", details: nil))
            return
        }
        let request = buildRequest(args, requestId: requestId)
        request.preload { [weak self] presentation, error in
            guard let self = self else { return }
            if let presentation = presentation {
                SwiftPurchaselyFlutterPlugin.loadedPresentations[requestId] = presentation
                self.presentationEventHandler.emit([
                    "event": "onLoaded",
                    "requestId": requestId,
                    "presentation": self.presentationToMap(presentation, requestId: requestId),
                ])
                result(self.presentationToMap(presentation, requestId: requestId))
            } else {
                let errMap = error.map { Self.errorToMap($0) } ?? ["code": "Unknown", "message": "unknown"]
                self.presentationEventHandler.emit([
                    "event": "onLoaded",
                    "requestId": requestId,
                    "error": errMap,
                ])
                result(FlutterError(code: "PRELOAD",
                                    message: error?.localizedDescription ?? "preload failed",
                                    details: errMap))
            }
        }
    }

    private func display(_ args: [String: Any]?, result: @escaping FlutterResult) {
        guard let args = args, let requestId = args["requestId"] as? String, !requestId.isEmpty else {
            result(FlutterError(code: "ARG_INVALID", message: "requestId required", details: nil))
            return
        }
        let request = SwiftPurchaselyFlutterPlugin.requests[requestId] ?? buildRequest(args, requestId: requestId)

        let transitionMap = args["transition"] as? [String: Any]
        let displayMode = Self.parseTransition(transitionMap)

        request.display(transition: displayMode) { [weak self] presentation, error in
            guard let self = self else { return }
            // The Dart-side `.display()` Future resolves at *dismiss* time, not
            // here. We don't `result(...)` with the outcome — that's emitted via
            // the `onDismissed` event and the Dart façade resolves its Future
            // from there. We acknowledge the dispatch via `result(true)` on
            // success, and synthesise the error-path callbacks on failure.
            if let presentation = presentation {
                SwiftPurchaselyFlutterPlugin.loadedPresentations[requestId] = presentation
                result(true)
            } else if let error = error {
                // Synthesise onPresented(nil, error) so the Dart-side builder
                // onPresented handler fires uniformly across platforms.
                self.presentationEventHandler.emit([
                    "event": "onPresented",
                    "requestId": requestId,
                    "presentation": nil as Any?,
                    "error": Self.errorToMap(error),
                ])
                // Also synthesise onDismissed with the error outcome.
                let outcome = self.outcomeToMap(
                    PLYPresentationOutcome(),
                    presentation: nil,
                    error: error,
                    requestId: requestId
                )
                self.presentationEventHandler.emit([
                    "event": "onDismissed",
                    "requestId": requestId,
                    "outcome": outcome,
                ])
                result(true)
            } else {
                result(true)
            }
        }
    }

    private func closePresentation(_ args: [String: Any]?, result: @escaping FlutterResult) {
        let requestId = args?["requestId"] as? String
        if let id = requestId, let presentation = SwiftPurchaselyFlutterPlugin.loadedPresentations[id] {
            presentation.close()
        } else {
            // No per-request handle — fall back to closing every loaded
            // presentation (best-effort; the iOS SDK doesn't expose a global
            // "closeAll").
            SwiftPurchaselyFlutterPlugin.loadedPresentations.values.forEach { $0.close() }
        }
        result(true)
    }

    private func back(_ args: [String: Any]?, result: @escaping FlutterResult) {
        let requestId = args?["requestId"] as? String
        if let id = requestId, let presentation = SwiftPurchaselyFlutterPlugin.loadedPresentations[id] {
            presentation.back()
        }
        result(true)
    }

    // MARK: - Action interceptor

    private func registerInterceptor(_ args: [String: Any]?, result: @escaping FlutterResult) {
        guard let kindWire = args?["kind"] as? String,
              let action = Self.actionFromWire(kindWire) else {
            result(FlutterError(code: "ARG_INVALID", message: "unknown action kind", details: nil))
            return
        }

        Purchasely.interceptAction(action) { [weak self] info, params, completion in
            guard let self = self else { completion(.notHandled); return }
            let id = "ply_ic_\(Int.random(in: 0..<Int.max))"
            SwiftPurchaselyFlutterPlugin.pendingInterceptors[id] = completion
            self.presentationEventHandler.emit([
                "event": "interceptorTriggered",
                "requestId": id,
                "kind": kindWire,
                "info": Self.interceptorInfoToMap(info),
                "payload": Self.actionParamsToMap(params),
            ])
        }

        result(true)
    }

    private func removeInterceptor(_ args: [String: Any]?, result: @escaping FlutterResult) {
        if let kindWire = args?["kind"] as? String,
           let action = Self.actionFromWire(kindWire) {
            Purchasely.removeActionInterceptor(action)
        }
        result(true)
    }

    private func removeAllInterceptors(result: @escaping FlutterResult) {
        Purchasely.removeAllActionInterceptors()
        result(true)
    }

    private func interceptorResolve(_ args: [String: Any]?, result: @escaping FlutterResult) {
        let id = args?["invocationId"] as? String
        let value = args?["result"] as? String
        let ply: PLYInterceptResult = {
            switch value {
            case "success": return .success
            case "failed":  return .failed
            default:        return .notHandled
            }
        }()
        if let id = id, let completion = SwiftPurchaselyFlutterPlugin.pendingInterceptors.removeValue(forKey: id) {
            DispatchQueue.main.async {
                completion(ply)
            }
        }
        result(true)
    }

    // MARK: - Presentation serializers

    private static func runningMode(from raw: Any?) -> PLYRunningMode {
        if let value = raw as? Int {
            return PLYRunningMode(rawValue: value) ?? .observer
        }
        if let value = raw as? String, value.lowercased() == "full" {
            return .full
        }
        return .observer
    }

    private static func logLevel(from raw: Any?) -> PLYLogger.PLYLogLevel {
        if let value = raw as? Int {
            return PLYLogger.PLYLogLevel(rawValue: value) ?? .error
        }
        if let value = raw as? String {
            switch value.lowercased() {
            case "debug": return .debug
            case "info": return .info
            case "warn": return .warn
            default: return .error
            }
        }
        return .error
    }

    private static func storekitSettings(from arguments: [String: Any]) -> StorekitSettings {
        if let value = arguments["storekitVersion"] as? String {
            return value == "storeKit1" ? .storeKit1 : .storeKit2
        }
        let storeKit1 = arguments["storeKit1"] as? Bool ?? false
        return storeKit1 ? .storeKit1 : .storeKit2
    }

    private func presentationToMap(_ p: PLYPresentation, requestId: String) -> [String: Any] {
        return [
            "requestId": requestId,
            // iOS `id` maps to wire `screenId`. The Dart factory tolerates both
            // keys; we send `screenId` for forward compatibility with the
            // contract.
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

        // Serialize the full PLYPlan (same shape as products/plans elsewhere) so
        // the Dart side can parse it into a fully-typed PLYPlan via plyPlanFromMap.
        let planMap: [String: Any]? = outcome.plan?.toMap

        // iOS v6 exposes `closeReason` on PLYPresentationOutcome. Serialize via
        // `rawDescription`, which matches Android's wire strings — interactive
        // dismiss stringifies to "back_system" for cross-platform parity.
        // `.none` means no close happened (e.g. a purchase/restore outcome) → send null.
        let closeReason: String? = {
            switch outcome.closeReason {
            case .none: return nil
            default:    return outcome.closeReason.rawDescription
            }
        }()

        let outcomePresentation = outcome.presentation ?? presentation

        return [
            "presentation": outcomePresentation.map { presentationToMap($0, requestId: requestId) } as Any?,
            "purchaseResult": purchaseResult,
            "plan": planMap as Any?,
            "closeReason": closeReason as Any?,
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

    /// Parses a Dart transition dimension `{ "type": "pixel"|"percentage", "value": <Double> }`
    /// into a native `PLYDimension` (`.value(Int)` for pixels, `.percentage(Float)` for
    /// ratios). Returns `nil` (→ "hug" / size-to-content) when absent or malformed.
    private static func parseDimension(_ raw: Any?) -> PLYDimension? {
        guard let map = raw as? [String: Any],
              let value = (map["value"] as? NSNumber)?.doubleValue else { return nil }
        switch map["type"] as? String {
        case "pixel":      return .value(Int(value.rounded()))
        case "percentage": return .percentage(Float(value))
        default:           return .percentage(Float(value))
        }
    }

    private static func parseTransition(_ map: [String: Any]?) -> PLYDisplayMode? {
        guard let map = map, let type = map["type"] as? String else { return nil }
        let dismissible = map["dismissible"] as? Bool ?? true
        // v6 models drawer/popin size as PLYDimension (width is popin-only, height
        // drives drawer + popin). `nil` means "hug" — size to content.
        let width = parseDimension(map["width"])
        let height = parseDimension(map["height"])
        switch type {
        case "fullScreen":    return .fullScreen
        case "push":          return .push
        case "modal":         return .modal
        case "drawer":        return .drawer(height: height, dismissible: dismissible)
        case "popin":         return .popin(width: width, height: height, dismissible: dismissible)
        case "inlinePaywall": return .inlinePaywall
        default: return nil
        }
    }

    // MARK: - Inline native view support

    /// Resolves the controller for the inline platform view. Mirrors Android:
    /// the inline view is built from a presentation that was already loaded
    /// (via `preload`) and is keyed by the Dart `requestId`.
    /// Creation-param contract: `{ "requestId": <String> }`.
    static func presentationController(for args: Any?) -> UIViewController? {
        guard let creationParams = args as? [String: Any],
              let requestId = creationParams["requestId"] as? String,
              let presentation = loadedPresentations[requestId] else {
            return nil
        }
        return presentation.controller
    }

    // MARK: - Kept v5 surface

    private func isAnonymous(result: @escaping FlutterResult) {
        result(Purchasely.isAnonymous())
    }

    private func isEligibleForIntroOffer(arguments: [String: Any]?, result: @escaping FlutterResult) {
        guard let arguments = arguments, let planVendorId = arguments["planVendorId"] as? String else {
            result(FlutterError.failedArgumentField("planVendorId", type: String.self))
            return
        }

        DispatchQueue.main.async {
            Purchasely.plan(with: planVendorId) { plan in
                plan.isUserEligibleForIntroductoryOffer { res in
                    result(res)
                }
            } failure: { error in
                result(FlutterError.error(code:"-1", message:"plan \(planVendorId) not found", error: error))
            }
        }
    }

    private func restoreAllProducts(_ result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            Purchasely.restoreAllProducts {
                result(true)
            } failure: { error in
                result(FlutterError.error(code: "-1", message: "Restore failed", error: error))
            }
        }
    }

    private func silentRestoreAllProducts(_ result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            Purchasely.synchronize {
                result(true)
            } failure: { error in
                result(FlutterError.error(code: "-1", message: "Restore failed", error: error))
            }
        }
    }

    private func synchronize(_ result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            // v6 exposes success/failure callbacks on synchronize(). The Dart
            // `Purchasely.synchronize()` Future now resolves on success and throws
            // (PlatformException) on failure, instead of the old fire-and-forget.
            Purchasely.synchronize {
                result(true)
            } failure: { error in
                result(FlutterError.error(code: "-1", message: "Synchronization failed", error: error))
            }
        }
    }

    private func getAnonymousUserId() -> String {
        return Purchasely.anonymousUserId
    }

    private func setLanguage(with language: String?) {
        guard let language = language else { return }
        let locale = Locale(identifier: language)
        Purchasely.setLanguage(from: locale)
    }

    private func userLogin(arguments: [String: Any]?, result: @escaping FlutterResult) {
        guard let arguments = arguments, let userId = arguments["userId"] as? String else {
            result(FlutterError.error(code: "-1", message: "user id must not be nil", error: nil))
            return
        }
        DispatchQueue.main.async {
            Purchasely.userLogin(with: userId) { refresh in
                result(refresh)
            }
        }
    }

    private func userLogout(result: @escaping FlutterResult) {
        Purchasely.userLogout()
        result(true)
    }

    private func allowDeeplink(allowDeeplink: Bool?) {
        Purchasely.allowDeeplink(allowDeeplink ?? true)
    }

    private func allowCampaigns(allowCampaigns: Bool?) {
        Purchasely.allowCampaigns(allowCampaigns ?? true)
    }

    private func setDefaultPresentationDismissHandler(result: @escaping FlutterResult) {
        DispatchQueue.main.async { [weak self] in
            Purchasely.setDefaultPresentationDismissHandler { [weak self] outcome in
                guard let self = self else { return }
                self.presentationEventHandler.emit([
                    "event": "onDefaultPresentationDismissed",
                    "outcome": self.outcomeToMap(
                        outcome,
                        presentation: nil,
                        error: nil,
                        requestId: ""
                    ),
                ])
            }
            result(true)
        }
    }

    private func removeDefaultPresentationDismissHandler(result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            Purchasely.setDefaultPresentationDismissHandler(nil)
            result(true)
        }
    }

    private func productWithIdentifier(arguments: [String: Any]?, result: @escaping FlutterResult) {
        guard let arguments = arguments, let vendorId = arguments["vendorId"] as? String else {
            result(FlutterError.error(code: "-1", message: "product vendor id must not be nil", error: nil))
            return
        }

        DispatchQueue.main.async {
            Purchasely.product(with: vendorId) { product in
                let productDict: [String: Any] = product.toMap
                result(productDict)
            } failure: { error in
                result(FlutterError.error(code:"-1", message:"product \(vendorId) not found", error: error))
            }
        }
    }

    private func planWithIdentifier(arguments: [String: Any]?, result: @escaping FlutterResult) {
        guard let arguments = arguments, let vendorId = arguments["vendorId"] as? String else {
            result(FlutterError.error(code: "-1", message: "plan vendor id must not be nil", error: nil))
            return
        }

        DispatchQueue.main.async {
            Purchasely.plan(with: vendorId) { plan in
                result(plan.toMap)
            } failure: { error in
                result(FlutterError.error(code:"-1", message:"plan \(vendorId) not found", error: error))
            }
        }
    }

    private func allProducts(_ result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            Purchasely.allProducts { products in
                result(products.compactMap { $0.toMap })
            } failure: { error in
                result(FlutterError.error(code:"-1", message:"failed to fetch all products", error: error))
            }
        }
    }

    private func signPromotionalOffer(arguments: [String: Any]?, result: @escaping FlutterResult) {
        guard let arguments = arguments,
              let storeProductId = arguments["storeProductId"] as? String,
              let storeOfferId = arguments["storeOfferId"] as? String else {
            result(FlutterError.error(code: "-1", message: "storeProductId and storeOfferId must not be nil", error: nil))
            return
        }

        DispatchQueue.main.async {
            if #available(iOS 12.2, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
                Purchasely.signPromotionalOffer(storeProductId: storeProductId, storeOfferId: storeOfferId) { signature in
                    result(signature.toMap)
                } failure: { error in
                    result(FlutterError.error(code:"-1", message:"signature failed", error: error))
                }
            } else {
                result(FlutterError.error(code:"-1", message:"Promotional offers signature are only available for iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0", error: nil))
            }
        }
    }

    private func purchaseWithPlanVendorId(arguments: [String: Any]?, result: @escaping FlutterResult) {
        guard let arguments = arguments, let vendorId = arguments["vendorId"] as? String else {
            result(FlutterError.error(code: "-1", message: "plan vendor id must not be nil", error: nil))
            return
        }

        let contentId = arguments["contentId"] as? String

        DispatchQueue.main.async {
            Purchasely.plan(with: vendorId) { plan in

                if let offerId = arguments["offerId"] as? String,
                   let storeOfferId = plan.promoOffers.first(where: { $0.vendorId == offerId })?.storeOfferId,
                   #available(iOS 12.2, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {

                    Purchasely.purchaseWithPromotionalOffer(plan: plan, contentId: contentId, storeOfferId: storeOfferId) {
                        result(plan.toMap)
                    } failure: { error in
                        result(FlutterError.error(code:"-1", message:"purchase failed", error: error))
                    }
                } else {
                    Purchasely.purchase(plan: plan, contentId: contentId) {
                        result(plan.toMap)
                    } failure: { error in
                        result(FlutterError.error(code:"-1", message:"purchase failed", error: error))
                    }
                }
            } failure: { error in
                result(FlutterError.error(code:"-1", message:"plan \(vendorId) not found", error: error))
            }
        }
    }

    private func handleDeeplink(_ deeplink: String?, result: @escaping FlutterResult) {
        guard let deeplink = deeplink, let url = URL(string: deeplink) else {
            result(FlutterError.error(code: "-1", message: "deeplink must not be nil", error: nil))
            return
        }

        DispatchQueue.main.async {
            result(Purchasely.handleDeeplink(url))
        }
    }

    private func userSubscriptions(_ result: @escaping FlutterResult) {

        DispatchQueue.main.async {
            Purchasely.userSubscriptions { subscriptions in
                result((subscriptions ?? []).compactMap { $0.toMap })
            } failure: { error in
                result(FlutterError.error(code:"-1", message:"failed to fetch user subscriptions", error: error))
            }
        }
    }

    private func userSubscriptionsHistory(_ result: @escaping FlutterResult) {

        DispatchQueue.main.async {
            Purchasely.userSubscriptionsHistory { subscriptions in
                result((subscriptions ?? []).compactMap { $0.toMap })
            } failure: { error in
                result(FlutterError.error(code:"-1", message:"failed to fetch user subscriptions history", error: error))
            }
        }
    }

    private func setThemeMode(arguments: [String: Any]?) {
        guard let arguments = arguments, let mode = arguments["mode"] as? Int, let themeMode = Purchasely.PLYThemeMode(rawValue: mode) else {
            return
        }

        Purchasely.setThemeMode(themeMode)
    }

    private func setAttribute(arguments: [String: Any]?) {
        guard let arguments = arguments,
            let value = arguments["value"] as? String,
            let attribute = arguments["attribute"] as? Int,
            let flutterAttribute = FlutterPLYAttribute(rawValue: attribute) else {
            return
        }

        let attr: Purchasely.PLYAttribute? = {
            switch flutterAttribute {
            case .firebaseAppInstanceId:
                return .firebaseAppInstanceId
            case .airshipChannelId:
                return .airshipChannelId
            case .airshipUserId:
                return .airshipUserId
            case .batchInstallationId:
                return .batchInstallationId
            case .adjustId:
                return .adjustId
            case .appsflyerId:
                return .appsflyerId
            case .mixpanelDistinctId:
                return .mixpanelDistinctId
            case .cleverTapId:
                return .clevertapId
            case .sendinblueUserEmail:
                return .sendinblueUserEmail
            case .iterableUserEmail:
                return .iterableUserEmail
            case .iterableUserId:
                return .iterableUserId
            case .atInternetIdClient:
                return .atInternetIdClient
            case .mParticleUserId:
                return .mParticleUserId
            case .customerioUserId:
                return .customerioUserId
            case .customerioUserEmail:
                return .customerioUserEmail
            case .branchUserDeveloperIdentity:
                return .branchUserDeveloperIdentity
            case .amplitudeUserId:
                return .amplitudeUserId
            case .amplitudeDeviceId:
                return .amplitudeDeviceId
            case .moengageUniqueId:
                return .moengageUniqueId
            case .oneSignalExternalId:
                return .oneSignalExternalId
            case .batchCustomUserId:
                return .batchCustomUserId
            }
        }()

        guard let attributeKey = attr else { return }
        Purchasely.setAttribute(attributeKey, value: value)
    }

    private func setUserAttributeWithString(arguments: [String: Any]?) {
        guard let (key, value, processingLegalBasis) = mapUserAttributesCallArguments(arguments: arguments, type: String.self) else {
            return
        }
        Purchasely.setUserAttribute(withStringValue: value, forKey: key, processingLegalBasis: processingLegalBasis)
    }

    private func setUserAttributeWithStringArray(arguments: [String: Any]?) {
        guard let (key, value, processingLegalBasis) = mapUserAttributesCallArguments(arguments: arguments, type: [String].self) else {
            return
        }
        Purchasely.setUserAttribute(withStringArray: value, forKey: key, processingLegalBasis: processingLegalBasis)
    }

    private func setUserAttributeWithInt(arguments: [String: Any]?) {
        guard let (key, value, processingLegalBasis) = mapUserAttributesCallArguments(arguments: arguments, type: Int.self) else {
            return
        }
        Purchasely.setUserAttribute(withIntValue: value, forKey: key, processingLegalBasis: processingLegalBasis)
    }

    private func setUserAttributeWithIntArray(arguments: [String: Any]?) {
        guard let (key, value, processingLegalBasis) = mapUserAttributesCallArguments(arguments: arguments, type: [Int].self) else {
            return
        }
        Purchasely.setUserAttribute(withIntArray: value, forKey: key, processingLegalBasis: processingLegalBasis)
    }

    private func setUserAttributeWithDouble(arguments: [String: Any]?) {
        guard let (key, value, processingLegalBasis) = mapUserAttributesCallArguments(arguments: arguments, type: Double.self) else {
            return
        }
        Purchasely.setUserAttribute(withDoubleValue: value, forKey: key, processingLegalBasis: processingLegalBasis)
    }

    private func setUserAttributeWithDoubleArray(arguments: [String: Any]?) {
        guard let (key, value, processingLegalBasis) = mapUserAttributesCallArguments(arguments: arguments, type: [Double].self) else {
            return
        }
        Purchasely.setUserAttribute(withDoubleArray: value, forKey: key, processingLegalBasis: processingLegalBasis)
    }

    private func setUserAttributeWithBoolean(arguments: [String: Any]?) {
        guard let (key, value, processingLegalBasis) = mapUserAttributesCallArguments(arguments: arguments, type: Bool.self) else {
            return
        }
        Purchasely.setUserAttribute(withBoolValue: value, forKey: key, processingLegalBasis: processingLegalBasis)
    }

    private func setUserAttributeWithBooleanArray(arguments: [String: Any]?) {
        guard let (key, value, processingLegalBasis) = mapUserAttributesCallArguments(arguments: arguments, type: [Bool].self) else {
            return
        }
        Purchasely.setUserAttribute(withBoolArray: value, forKey: key, processingLegalBasis: processingLegalBasis)
    }

    private func setUserAttributeWithDate(arguments: [String: Any]?) {
        guard let (key, value, processingLegalBasis) = mapUserAttributesCallArguments(arguments: arguments, type: String.self) else {
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(identifier: "GMT")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        if let date = dateFormatter.date(from: value) {
            Purchasely.setUserAttribute(withDateValue: date, forKey: key, processingLegalBasis: processingLegalBasis)
        } else {
            print("Purchasely", "Cannot save date attribute for key \(key)")
        }
    }

    private func incrementUserAttribute(arguments: [String: Any]?) {
        guard let (key, value, processingLegalBasis) = mapUserAttributesCallArguments(arguments: arguments, type: Int.self) else {
            return
        }
        Purchasely.incrementUserAttribute(withKey: key, value: value, processingLegalBasis: processingLegalBasis)
    }

    private func decrementUserAttribute(arguments: [String: Any]?) {
        guard let (key, value, processingLegalBasis) = mapUserAttributesCallArguments(arguments: arguments, type: Int.self) else {
            return
        }
        Purchasely.decrementUserAttribute(withKey: key, value: value, processingLegalBasis: processingLegalBasis)
    }

    private func mapUserAttributesCallArguments<T>(arguments: [String: Any]?, type: T.Type) -> (key: String, value: T, processingLegalBasis: PLYDataProcessingLegalBasis)? {
        guard let arguments = arguments, let value = arguments["value"] as? T, let key = arguments["key"] as? String else {
            return nil
        }
        let processingLegalBasisArg = arguments["processingLegalBasis"] as? String
        let processingLegalBasis: PLYDataProcessingLegalBasis = processingLegalBasisArg == "ESSENTIAL" ? .essential : .optional

        return (key, value, processingLegalBasis)
    }

    private func clearUserAttribute(arguments: [String: Any]?) {
        guard let arguments = arguments, let key = arguments["key"] as? String else {
            return
        }
        Purchasely.clearUserAttribute(forKey: key)
    }

    private func clearUserAttributes() {
        Purchasely.clearUserAttributes()
    }

    private func clearBuiltInAttributes() {
        Purchasely.clearBuiltInAttributes()
    }

    private func getUserAttribute(arguments: [String: Any]?, result: @escaping FlutterResult) {
        guard let arguments = arguments, let key = arguments["key"] as? String else {
            result(FlutterError.error(code: "-1", message: "key must not be nil", error: nil))
            return
        }

        let attribute = getUserAttributeForFlutter(with: Purchasely.getUserAttribute(for: key))
        DispatchQueue.main.async {
            result(attribute)
        }
    }

    private func getUserAttributes(result: @escaping FlutterResult) {

        let resultAttributes = Purchasely.userAttributes.mapValues { getUserAttributeForFlutter(with: $0) }
        DispatchQueue.main.async {
            result(resultAttributes)
        }
    }

    private func userDidConsumeSubscriptionContent() {
        Purchasely.userDidConsumeSubscriptionContent()
    }

    private func setDynamicOffering(arguments: [String: Any]?, result: @escaping FlutterResult) {
        guard let arguments = arguments,
              let reference = arguments["reference"] as? String,
              let planVendorId = arguments["planVendorId"] as? String else {
            result(FlutterError.error(code: "-1", message: "reference and planVendorId must not be nil", error: nil))
            return
        }

        let offerVendorId = arguments["offerVendorId"] as? String

        DispatchQueue.main.async {
            Purchasely.setDynamicOffering(reference: reference, planVendorId: planVendorId, offerVendorId: offerVendorId, completion: { success in
                result(success)
            })
        }
    }

    private func getDynamicOfferings(result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            Purchasely.getDynamicOfferings { offerings in
                // create new empty list
                var list: [[String: String]] = []
                offerings.forEach(  { offering in
                    // create new dictionary for each offering
                    var map = [String: String]()

                    map["reference"] = offering.reference
                    map["planVendorId"] = offering.planId

                    if let offerId = offering.offerId {
                        map["offerVendorId"] = offerId
                    }

                    list.append(map)
                })
                result(list)
            }
        }
    }

    private func removeDynamicOffering(arguments: [String: Any]?) {
        guard let arguments = arguments,
              let reference = arguments["reference"] as? String else {
            return
        }

        Purchasely.removeDynamicOffering(reference: reference)
    }

    private func clearDynamicOfferings() {
        Purchasely.clearDynamicOfferings()
    }

    private func revokeDataProcessingConsent(arguments: [String: Any]?) {
        guard let arguments, let purposesArg = arguments["purposes"] as? [String] else {
            return
        }
        let purposes: Set<PLYDataProcessingPurpose> = if purposesArg.contains("ALL_NON_ESSENTIALS") {
            Set([PLYDataProcessingPurpose.allNonEssentials])
        } else {
            Set(purposesArg.compactMap { (value: String) -> PLYDataProcessingPurpose? in
                switch value {
                    case "ANALYTICS": .analytics
                    case "IDENTIFIED_ANALYTICS": .identifiedAnalytics
                    case "CAMPAIGNS": .campaigns
                    case "PERSONALIZATION": .personalization
                    case "THIRD_PARTY_INTEGRATIONS": .thirdPartyIntegrations
                    default: nil
                }
            })
        }
        Purchasely.revokeDataProcessingConsent(for: purposes)
    }

    private func setDebugMode(arguments: [String: Any]?) {
        guard let arguments, let enabled = arguments["debugMode"] as? Bool else {
            return
        }

        Purchasely.setDebugMode(enabled: enabled)
    }
}

// MARK: - Presentation EventChannel handler

final class PresentationEventHandler: NSObject, FlutterStreamHandler {
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

extension FlutterError {
    static let nilArgument = FlutterError(
        code: "argument.nil",
        message: "Expect an argument when invoking channel method, but it is nil.",
        details: nil
    )

    static func failedArgumentField<T>(_ fieldName: String, type: T.Type) -> FlutterError {
        return .init(
            code: "argument.failedField",
            message: "Expect a `\(fieldName)` field with type <\(type)> in the argument, " +
            "but it is missing or type not matched.",
            details: fieldName)
    }

    static func error(code: String, message: String?, error: Error?) -> FlutterError {
        return .init(
            code: code,
            message: message,
            details: error?.localizedDescription)
    }
}

class SwiftEventHandler: NSObject, FlutterStreamHandler, PLYEventDelegate {

    var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        // Use the closure-based v6 API (setEventCallback) — more reliable than
        // the ObjC delegate API (setEventDelegate) in SDK v6 RC+.
        Purchasely.setEventCallback { [weak self] event, properties in
            guard let self = self, let sink = self.eventSink else { return }
            let name = NSString.fromPLYEvent(event)
            DispatchQueue.main.async {
                sink(["name": name, "properties": properties ?? [:]])
            }
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        Purchasely.removeEventDelegate()
        return nil
    }

    func eventTriggered(_ event: PLYEvent, properties: [String : Any]?) {
        guard let eventSink = self.eventSink else { return }
        let name = NSString.fromPLYEvent(event)
        DispatchQueue.main.async {
            eventSink(["name": name, "properties": properties ?? [:]])
        }
    }
}

class SwiftPurchaseHandler: NSObject, FlutterStreamHandler {

    var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events

        NotificationCenter.default.addObserver(self, selector: #selector(purchasePerformed), name: .ply_purchasedSubscription, object: nil)

        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        NotificationCenter.default.removeObserver(self, name: .ply_purchasedSubscription, object: nil)
        return nil
    }

    @objc func purchasePerformed() {
        self.eventSink?(nil)
    }

}

class UserAttributesHandler: NSObject, FlutterStreamHandler, PLYUserAttributeDelegate {

    var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        Purchasely.setUserAttributeDelegate(self)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        //Purchasely.setUserAttributeDelegate(nil)
        return nil
    }

    func onUserAttributeSet(key: String, type: PLYUserAttributeType, value: Any?, source: PLYUserAttributeSource) {
        guard let eventSink = self.eventSink else { return }

        var formattedType = ""
        switch type {
        case .string:
            formattedType = "STRING"
        case .bool:
            formattedType = "BOOLEAN"
        case .int:
            formattedType = "INT"
        case .double:
            formattedType = "FLOAT"
        case .date:
            formattedType = "DATE"
        case .stringArray:
            formattedType = "STRING_ARRAY"
        case .intArray:
            formattedType = "INT_ARRAY"
        case .doubleArray:
            formattedType = "FLOAT_ARRAY"
        case .boolArray:
            formattedType = "BOOLEAN_ARRAY"
        case .dictionary:
            formattedType = "DICTIONARY"
        case .unknown:
            formattedType = ""
        @unknown default:
            formattedType = ""
        }

        DispatchQueue.main.async {
            eventSink([
                "event": "set",
                "key": key,
                "type": formattedType,
                "value": getUserAttributeForFlutter(with: value),
                "source": source.rawValue
            ])
        }
    }

    func onUserAttributeRemoved(key: String, source: PLYUserAttributeSource) {
        guard let eventSink = self.eventSink else { return }
        DispatchQueue.main.async {
            eventSink([
                "event": "removed",
                "key": key,
                "source": source.rawValue
            ])
        }
    }
}

fileprivate func getDateFormatter() -> DateFormatter {
    let dateFormatter = DateFormatter()
    dateFormatter.timeZone = TimeZone(identifier: "GMT")
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
    return dateFormatter
}

fileprivate func getUserAttributeForFlutter(with value: Any?) -> Any? {

    if let dateValue = value as? Date {
        let dateFormatter = getDateFormatter()
        return dateFormatter.string(from: dateValue)
    }

    return value
}

extension UIViewController {

    @objc func close() {
        self.dismiss(animated: true, completion: nil)
    }

}

// MARK: - UIColor helper

extension UIColor {
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

// WARNING: This enum must be strictly identical to the one in the Flutter side (purchasely_flutter.PLYAttribute).
enum FlutterPLYAttribute: Int {
    case firebaseAppInstanceId
    case airshipChannelId
    case airshipUserId
    case batchInstallationId
    case adjustId
    case appsflyerId
    case mixpanelDistinctId
    case cleverTapId
    case sendinblueUserEmail
    case iterableUserEmail
    case iterableUserId
    case atInternetIdClient
    case mParticleUserId
    case customerioUserId
    case customerioUserEmail
    case branchUserDeveloperIdentity
    case amplitudeUserId
    case amplitudeDeviceId
    case moengageUniqueId
    case oneSignalExternalId
    case batchCustomUserId
}
