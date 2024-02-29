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
        channel: FlutterMethodChannel
    ) {
        super.init()
        Purchasely.setEventDelegate(self)
        controller = SwiftPurchaselyFlutterPlugin.getPresentationController(for: args, with: channel)
        self._view = controller?.view
    }
    
    func view() -> UIView {
        return _view ?? UIView()
    }
    
    private func findFirstController(from viewController: UIViewController?) -> UIViewController? {
        var currentViewController = viewController
        
        // Iterate over the parent view controllers until we find a UINavigationController or reach the root view controller
        while let parentViewController = currentViewController?.parent {
            // Move to the next parent view controller
            currentViewController = parentViewController
        }
        
        // Did not find a UINavigationController
        return currentViewController
    }
}

extension NativeView: PLYEventDelegate {
    func eventTriggered(_ event: PLYEvent, properties: [String : Any]?) {
        if event == .presentationClosed {
            print("TUTU")
            
            DispatchQueue.main.async {
                self.controller?.view.removeFromSuperview()
//                if let navController = self.controller?.navigationController {
//                    print("POP1")
//                    navController.popViewController(animated: false)
//                } else if let firstController = self.findFirstController(from: self.controller) {
//                    print("POP2")
//                    firstController.dismiss(animated: false)
//                    firstController.removeFromParent()
//                } else {
//                    print("DISMISS")
//                    self.controller?.dismiss(animated: false)
//                }
            }
            
        }
    }
}
