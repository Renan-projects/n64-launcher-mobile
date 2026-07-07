package org.renanprojects.n64_launcher_mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var emulator: EmulatorBridge
    private lateinit var controllers: ControllerObserver

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        emulator = EmulatorBridge(this)
        MethodChannel(messenger, EMULATOR_CHANNEL).setMethodCallHandler(emulator)

        flutterEngine.platformViewsController.registry.registerViewFactory(
            SURFACE_VIEW_TYPE,
            EmulatorViewFactory(emulator),
        )

        controllers = ControllerObserver(this)
        EventChannel(messenger, CONTROLLERS_CHANNEL)
            .setStreamHandler(controllers)
    }

    override fun onDestroy() {
        emulator.release()
        controllers.release()
        super.onDestroy()
    }

    companion object {
        const val EMULATOR_CHANNEL = "org.renanprojects.n64/emulator"
        const val CONTROLLERS_CHANNEL = "org.renanprojects.n64/controllers"
        const val SURFACE_VIEW_TYPE = "org.renanprojects.n64/surface"
    }
}
