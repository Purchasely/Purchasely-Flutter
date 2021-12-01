import Flutter
import UIKit
import Purchasely

public class SwiftPurchaselyFlutterPlugin: NSObject, FlutterPlugin {
    
    let eventChannel: FlutterEventChannel
    let eventHandler: SwiftEventHandler
    
    let purchaseChannel: FlutterEventChannel
    let purchaseHandler: SwiftPurchaseHandler
    
    var presentedPresentationViewController: UIViewController?
    
    var loginClosedHandler: ((Bool) -> Void)?
    var authorizedPurchaseHandler: ((Bool) -> Void)?
    
    public init(with registrar: FlutterPluginRegistrar) {
        self.eventChannel = FlutterEventChannel(name: "purchasely-events",
                                           binaryMessenger: registrar.messenger())
        self.eventHandler = SwiftEventHandler()
        self.eventChannel.setStreamHandler(self.eventHandler)
        
        self.purchaseChannel = FlutterEventChannel(name: "purchasely-purchases",
                                                   binaryMessenger: registrar.messenger())
        self.purchaseHandler = SwiftPurchaseHandler()
        self.purchaseChannel.setStreamHandler(self.purchaseHandler)
        
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
        print("method called: \(call.method)")
        switch call.method {
        case "startWithApiKey":
            startWithApiKey(arguments: call.arguments as? [String: Any], result: result)
        case "close":
            DispatchQueue.main.async {
                result(true)
            }
        case "setDefaultPresentationResultHandler":
            setDefaultPresentationResultHandler(result: result)
        case "presentPresentationWithIdentifier":
            presentPresentationWithIdentifier(arguments: arguments, result: result)
        case "presentProductWithIdentifier":
            presentProductWithIdentifier(arguments: arguments, result: result)
        case "presentPlanWithIdentifier":
            presentPlanWithIdentifier(arguments: arguments, result: result)
        case "restoreAllProducts":
            restoreAllProducts(result)
        case "getAnonymousUserId":
            DispatchQueue.main.async { [weak self] in
                guard let `self` = self else { return }
                result(self.getAnonymousUserId())
            }
        case "userLogin":
            userLogin(arguments: arguments, result: result)
        case "userLogout":
            userLogout()
        case "isReadytoPurchase":
            let parameter = arguments?["readyToPurchase"] as? Bool
            isReadyToPurchase(readyToPurchase: parameter)
        case "setLogLevel":
            let parameter = (arguments?["logLevel"] as? Int) ?? PLYLogger.LogLevel.debug.rawValue
            let logLevel = PLYLogger.LogLevel(rawValue: parameter) ?? PLYLogger.LogLevel.debug
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
        case "handle":
            let parameter = arguments?["deeplink"] as? String
            handle(parameter, result: result)
        case "userSubscriptions":
            userSubscriptions(result)
        case "presentSubscriptions":
            presentSubscriptions()
        case "setAttribute":
            setAttribute(arguments: arguments)
        case "setLoginTappedHandler":
            setLoginTappedHandler(result: result)
        case "onUserLoggedIn":
            let parameter = arguments?["userLoggedIn"] as? Bool
            onUserLoggedIn(parameter ?? false)
        case "setConfirmPurchaseHandler":
            setConfirmPurchaseHandler(result: result)
        case "processToPayment":
            let parameter = arguments?["processToPayment"] as? Bool
            processToPayment(parameter ?? false)
        case "synchronize", "displaySubscriptionCancellationInstruction":
            result(FlutterMethodNotImplemented)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func startWithApiKey(arguments: [String: Any]?, result: @escaping FlutterResult) {
        guard let arguments = arguments, let apiKey = arguments["apiKey"] as? String else {
            result(FlutterError.failedArgumentField("apiKey", type: String.self))
            return
        }
        
        Purchasely.setEnvironment(.staging)
        Purchasely.setAppTechnology(PLYAppTechnology.flutter)
        
        
        let logLevel = PLYLogger.LogLevel(rawValue: (arguments["logLevel"] as? Int) ?? PLYLogger.LogLevel.debug.rawValue) ?? PLYLogger.LogLevel.debug
        let userId = arguments["userId"] as? String
        DispatchQueue.main.async {
            Purchasely.start(withAPIKey: apiKey,
                             appUserId: userId,
                             observerMode: false,
                             logLevel: logLevel) { success, error in
                if success {
                    result(success)
                } else {
                    result(FlutterError.error(code: "0", message: "Purchasely SDK not configured", error: error))
                }
            }
        }
    }
    
    private func presentPresentationWithIdentifier(arguments: [String: Any]?, result: @escaping FlutterResult) {

        let presentationVendorId = arguments?["presentationVendorId"] as? String
        let contentId = arguments?["contentId"] as? String
        
        let controller = Purchasely.presentationController(with: presentationVendorId, contentId: contentId) { productResult, plan in
            let value: [String: Any] = ["result": productResult.rawValue, "plan": plan?.toMap ?? [:]]
            DispatchQueue.main.async {
                result(value)
            }
        }
        
        let navCtrl = UINavigationController(rootViewController: controller)
        navCtrl.navigationBar.isTranslucent = true
        navCtrl.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navCtrl.navigationBar.shadowImage = UIImage()
        navCtrl.navigationBar.tintColor = UIColor.white
        
        self.presentedPresentationViewController = navCtrl
        
        DispatchQueue.main.async {
            Purchasely.showController(navCtrl, type: .productPage)
        }
    }
    
    private func presentProductWithIdentifier(arguments: [String: Any]?, result: @escaping FlutterResult) {
        
        guard let arguments = arguments, let productVendorId = arguments["productVendorId"] as? String else {
            result(FlutterError.error(code: "-1", message: "product vendor id must not be nil", error: nil))
            return
        }
        let presentationVendorId = arguments["presentationVendorId"] as? String
        let contentId = arguments["contentId"] as? String
        
        let controller = Purchasely.productController(for: productVendorId, with: presentationVendorId, contentId: contentId) { productResult, plan in
            let value: [String: Any] = ["result": productResult.rawValue, "plan": plan?.toMap ?? [:]]
            DispatchQueue.main.async {
                result(value)
            }
        }
        
        let navCtrl = UINavigationController(rootViewController: controller)
        navCtrl.navigationBar.isTranslucent = true
        navCtrl.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navCtrl.navigationBar.shadowImage = UIImage()
        navCtrl.navigationBar.tintColor = UIColor.white
        
        self.presentedPresentationViewController = navCtrl
        
        DispatchQueue.main.async {
            Purchasely.showController(navCtrl, type: .productPage)
        }
    }
    
    private func presentPlanWithIdentifier(arguments: [String: Any]?, result: @escaping FlutterResult) {
        
        guard let arguments = arguments, let planVendorId = arguments["planVendorId"] as? String else {
            result(FlutterError.error(code: "-1", message: "plan vendor id must not be nil", error: nil))
            return
        }
        let presentationVendorId = arguments["presentationVendorId"] as? String
        let contentId = arguments["contentId"] as? String
        
        let controller = Purchasely.planController(for: planVendorId, with: presentationVendorId, contentId: contentId) { productResult, plan in
            let value: [String: Any] = ["result": productResult.rawValue, "plan": plan?.toMap ?? [:]]
            DispatchQueue.main.async {
                result(value)
            }
        }
        
        let navCtrl = UINavigationController(rootViewController: controller)
        navCtrl.navigationBar.isTranslucent = true
        navCtrl.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navCtrl.navigationBar.shadowImage = UIImage()
        navCtrl.navigationBar.tintColor = UIColor.white
        
        self.presentedPresentationViewController = navCtrl
        
        DispatchQueue.main.async {
            Purchasely.showController(navCtrl, type: .productPage)
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
    
    private func getAnonymousUserId() -> String {
        return Purchasely.anonymousUserId
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
    
    private func userLogout() {
        Purchasely.userLogout()
    }
    
    private func isReadyToPurchase(readyToPurchase: Bool?) {
        Purchasely.isReadyToPurchase(readyToPurchase ?? true)
    }
    
    private func setDefaultPresentationResultHandler(result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            Purchasely.setDefaultPresentationResultHandler { productResult, plan in
                let value: [String: Any] = ["result": productResult.rawValue, "plan": plan?.toMap ?? [:]]
                result(value)
            }
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
    
    private func purchaseWithPlanVendorId(arguments: [String: Any]?, result: @escaping FlutterResult) {
        guard let arguments = arguments, let vendorId = arguments["vendorId"] as? String else {
            result(FlutterError.error(code: "-1", message: "plan vendor id must not be nil", error: nil))
            return
        }
        
        let contentId = arguments["contentId"] as? String
        
        DispatchQueue.main.async {
            Purchasely.plan(with: vendorId) { plan in
                Purchasely.purchase(plan: plan, contentId: contentId) {
                    result(plan.toMap)
                } failure: { error in
                    result(FlutterError.error(code:"-1", message:"purchase failed", error: error))
                }
                
            } failure: { error in
                result(FlutterError.error(code:"-1", message:"plan \(vendorId) not found", error: error))
            }
        }
    }
    
    private func handle(_ deeplink: String?, result: @escaping FlutterResult) {
        guard let deeplink = deeplink, let url = URL(string: deeplink) else {
            result(FlutterError.error(code: "-1", message: "deeplink must not be nil", error: nil))
            return
        }
        
        DispatchQueue.main.async {
            result(Purchasely.handle(deeplink: url))
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
    
    private func presentSubscriptions() {
        let controller = Purchasely.subscriptionsController()
        
        let navCtrl = UINavigationController.init(rootViewController: controller)
        navCtrl.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: navCtrl, action: #selector(UIViewController.close))
        
        DispatchQueue.main.async {
            Purchasely.showController(controller, type: .subscriptionList)
        }
    }
    
    private func setAttribute(arguments: [String: Any]?) {
        guard let arguments = arguments, let value = arguments["value"] as? String, let attribute = arguments["attribute"] as? Int, let attr = Purchasely.PLYAttribute(rawValue: attribute) else {
            return
        }
        
        Purchasely.setAttribute(attr, value: value)
    }
    
    private func setLoginTappedHandler(result: @escaping FlutterResult) {
        
        DispatchQueue.main.async {
            Purchasely.setLoginTappedHandler { [weak self] controller, userLoggedIn in
                guard let `self` = self else { return }
                self.loginClosedHandler = userLoggedIn
                
                self.presentedPresentationViewController?.dismiss(animated: true, completion: {
                    result(nil)
                })
            }
        }
    }
    
    private func onUserLoggedIn(_ onUserLoggedIn: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self, let presentedViewController = self.presentedPresentationViewController else { return }
            Purchasely.showController(presentedViewController, type: .productPage)
            self.loginClosedHandler?(onUserLoggedIn)
        }
    }
    
    private func setConfirmPurchaseHandler(result: @escaping FlutterResult) {
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }
            Purchasely.setConfirmPurchaseHandler { controller, authorizePurchase in
                self.authorizedPurchaseHandler = authorizePurchase
                self.presentedPresentationViewController?.dismiss(animated: true, completion: {
                    result(nil)
                })
            }
        }
    }
    
    private func processToPayment(_ processToPayment: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self, let presentedViewController = self.presentedPresentationViewController else { return }
            Purchasely.showController(presentedViewController, type: .productPage)
            self.authorizedPurchaseHandler?(processToPayment)
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
        Purchasely.setEventDelegate(self)
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        Purchasely.setEventDelegate(nil)
        return nil
    }
    
    func eventTriggered(_ event: PLYEvent, properties: [String : Any]?) {
        guard let eventSink = self.eventSink else { return }
        DispatchQueue.main.async {
            print("event: \(["name": event.name, "properties": properties ?? [:]])")
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

extension UIViewController {
    
    @objc func close() {
        self.dismiss(animated: true, completion: nil)
    }
    
}
