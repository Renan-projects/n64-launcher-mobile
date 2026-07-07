import Flutter
import UIKit

final class EmulatorViewFactory: NSObject, FlutterPlatformViewFactory {
    private let host: EmulatorHost

    init(host: EmulatorHost) {
        self.host = host
        super.init()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        EmulatorPlatformView(frame: frame)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}

final class EmulatorPlatformView: NSObject, FlutterPlatformView {
    private let container: UIView

    init(frame: CGRect) {
        container = UIView(frame: frame)
        container.backgroundColor = .black
        super.init()
    }

    func view() -> UIView {
        container
    }
}
