import Foundation
import Flutter
import UIKit
import Purchasely


class NativeView: NSObject, FlutterPlatformView {
    private var _view: UIView?
    private var controller: UIViewController?
    
    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger?
    ) {
        super.init()
        if let creationParams = args as? [String: Any] {
            let presentationId = creationParams["presentationId"] as? String
            let placementId = creationParams["placementId"] as? String
            
            print("presentationId: \(String(describing: presentationId))")
            print("placementId: \(String(describing: placementId))")
            
            _view = createNativeView(presentationId: presentationId, placementId: placementId)
        }
    }
    
    
    func view() -> UIView {
        return _view ?? UIView()
    }
    
    func createNativeView(presentationId: String?, placementId: String?) -> UIView? {
        if let presentationId = presentationId {
            controller = Purchasely.presentationController(
                with: presentationId,
                loaded: nil,
                completion: nil
            )
        }
        else if let placementId = placementId {
            controller = Purchasely.presentationController(
                for: placementId,
                loaded: nil,
                completion: nil
            )
        }
        
        return controller?.view
    }
}


