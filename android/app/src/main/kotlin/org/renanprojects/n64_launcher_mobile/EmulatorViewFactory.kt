package org.renanprojects.n64_launcher_mobile

import android.content.Context
import android.view.View
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class EmulatorViewFactory(private val bridge: EmulatorBridge) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val surface = EmulatorSurfaceView(context)
        bridge.attachSurface(surface)
        return EmulatorPlatformView(surface, bridge)
    }
}

class EmulatorPlatformView(
    private val surface: EmulatorSurfaceView,
    private val bridge: EmulatorBridge,
) : PlatformView {

    override fun getView(): View = surface

    override fun dispose() {
        surface.shutdown()
        bridge.detachSurface()
    }
}
