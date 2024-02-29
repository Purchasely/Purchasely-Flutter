import Foundation
import Flutter
import UIKit
import Purchasely


class NativeView: NSObject, FlutterPlatformView {
    private var _view: UIView?
    private var _controller: UIViewController?
    private var _channel: FlutterMethodChannel?
    
    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        channel: FlutterMethodChannel
    ) {
        super.init()
        Purchasely.setEventDelegate(self)
        self._controller = SwiftPurchaselyFlutterPlugin.getPresentationController(for: args, with: channel)
        self._view = _controller?.view
        self._channel = channel
    }
    
    func view() -> UIView {
        return _view ?? UIView()
    }
}

extension NativeView: PLYEventDelegate {
    func eventTriggered(_ event: PLYEvent, properties: [String : Any]?) {
        if event == .presentationClosed {
            DispatchQueue.main.async {
                self._channel?.invokeMethod("onPresentationResult", arguments: ["result": properties,
                                                                          "plan": nil])
                self._controller?.view.removeFromSuperview()
            }
        }
    }
}
