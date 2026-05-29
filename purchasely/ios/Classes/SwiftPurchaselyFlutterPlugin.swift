import Flutter
import UIKit
import Purchasely

public class SwiftPurchaselyFlutterPlugin: NSObject, FlutterPlugin {

    let eventChannel: FlutterEventChannel
    let eventHandler: SwiftEventHandler

    let purchaseChannel: FlutterEventChannel
    let purchaseHandler: SwiftPurchaseHandler

    let userAttributesChannel: FlutterEventChannel
    let userAttributesHandler: UserAttributesHandler

    // v6 bridge — handles `v6/*` MethodChannel calls and emits lifecycle/interceptor
    // events on the `purchasely/v6-events` EventChannel.
    let v6EventChannel: FlutterEventChannel
    let v6EventHandler: PurchaselyV6EventHandler
    let v6Bridge: PurchaselyV6Bridge

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

        self.v6EventChannel = FlutterEventChannel(name: "purchasely/v6-events",
                                                  binaryMessenger: registrar.messenger())
        self.v6EventHandler = PurchaselyV6EventHandler()
        self.v6EventChannel.setStreamHandler(self.v6EventHandler)
        self.v6Bridge = PurchaselyV6Bridge(events: self.v6EventHandler)

        super.init()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "purchasely",
                                           binaryMessenger: registrar.messenger())

        let instance = SwiftPurchaselyFlutterPlugin(with: registrar)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? [String: Any]
        // v6 bridge gets first dispatch — handles every method prefixed with
        // "v6/". Returns false otherwise so the legacy v5 switch below keeps
        // handling everything else.
        if v6Bridge.handle(call.method, arguments: arguments, result: result) {
            return
        }
        switch call.method {
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
        case "readyToOpenDeeplink":
            let parameter = arguments?["readyToOpenDeeplink"] as? Bool
            readyToOpenDeeplink(readyToOpenDeeplink: parameter)
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
        case "isDeeplinkHandled":
            let parameter = arguments?["deeplink"] as? String
            isDeeplinkHandled(parameter, result: result)
        case "userSubscriptions":
            userSubscriptions(result)
        case "userSubscriptionsHistory":
            userSubscriptionsHistory(result)
        case "presentSubscriptions":
            presentSubscriptions()
        case "setThemeMode":
            setThemeMode(arguments: arguments)
        case "setAttribute":
            setAttribute(arguments: arguments)
        case "setLanguage":
            let parameter = arguments?["language"] as? String
            setLanguage(with: parameter)
        case "userDidConsumeSubscriptionContent":
            userDidConsumeSubscriptionContent()
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
            result(FlutterMethodNotImplemented)
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
        default:
            result(FlutterMethodNotImplemented)
        }
    }

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
            Purchasely.synchronize {
                //result(true)
            } failure: { error in
                //result(FlutterError.error(code: "-1", message: "Synchronization failed", error: error))
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

    private func readyToOpenDeeplink(readyToOpenDeeplink: Bool?) {
        Purchasely.readyToOpenDeeplink(readyToOpenDeeplink ?? true)
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

    private func isDeeplinkHandled(_ deeplink: String?, result: @escaping FlutterResult) {
        guard let deeplink = deeplink, let url = URL(string: deeplink) else {
            result(FlutterError.error(code: "-1", message: "deeplink must not be nil", error: nil))
            return
        }

        DispatchQueue.main.async {
            result(Purchasely.isDeeplinkHandled(deeplink: url))
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

    private func presentSubscriptions() {
        if let controller = Purchasely.subscriptionsController() {
            let navCtrl = UINavigationController.init(rootViewController: controller)
            navCtrl.navigationBar.topItem?.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: navCtrl, action: #selector(UIViewController.close))

            DispatchQueue.main.async {
                Purchasely.showController(navCtrl, type: .subscriptionList)
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
        Purchasely.setEventDelegate(self)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        Purchasely.removeEventDelegate()
        return nil
    }

    func eventTriggered(_ event: PLYEvent, properties: [String : Any]?) {
        guard let eventSink = self.eventSink else { return }
        DispatchQueue.main.async {
            eventSink(["name": event.name, "properties": properties ?? [:]])
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
