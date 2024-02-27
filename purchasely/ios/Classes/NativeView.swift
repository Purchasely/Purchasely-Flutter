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
        self.controller = SwiftPurchaselyFlutterPlugin.getPresentationController(for: args, with: channel)
        self._view = self.controller?.view
    }
    
    func view() -> UIView {
        return _view ?? UIView()
    }
}
