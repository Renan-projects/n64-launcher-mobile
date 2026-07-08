import Flutter
import UIKit
import GLKit
import OpenGLES

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

final class EmulatorPlatformView: NSObject, FlutterPlatformView, GLKViewDelegate {
    private let glkView: GLKView
    private let context: EAGLContext
    private var displayLink: CADisplayLink?
    private var glReady = false

    init(frame: CGRect) {
        context = EAGLContext(api: .openGLES3) ?? EAGLContext(api: .openGLES2)!
        glkView = GLKView(frame: frame, context: context)
        super.init()
        glkView.drawableDepthFormat = .format24
        glkView.drawableStencilFormat = .format8
        glkView.drawableColorFormat = .RGBA8888
        glkView.enableSetNeedsDisplay = false
        glkView.contentScaleFactor = UIScreen.main.scale
        glkView.delegate = self
        glkView.backgroundColor = .black

        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.preferredFramesPerSecond = 60
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func tick() {
        glkView.display()
    }

    func glkView(_ view: GLKView, drawIn rect: CGRect) {
        EAGLContext.setCurrent(context)
        if !glReady {
            n64_on_gl_ready()
            glReady = true
        }
        n64_set_view_size(Int32(view.drawableWidth), Int32(view.drawableHeight))
        n64_run_frame()
    }

    func view() -> UIView {
        glkView
    }

    func dispose() {
        displayLink?.invalidate()
        displayLink = nil
        glkView.deleteDrawable()
        n64_teardown()
    }
}
