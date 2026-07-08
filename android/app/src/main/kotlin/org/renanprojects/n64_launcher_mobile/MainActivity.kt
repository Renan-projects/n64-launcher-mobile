package org.renanprojects.n64_launcher_mobile

import android.util.Log
import android.view.InputDevice
import android.view.KeyEvent
import android.view.MotionEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs

class MainActivity : FlutterActivity() {
    private lateinit var emulator: EmulatorBridge
    private lateinit var controllers: ControllerObserver

    // Physical controller state (bit layout matches PadButton in pad_button.dart)
    private var padKeys = 0
    private var padMotion = 0
    private var padStickX = 0f
    private var padStickY = 0f

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

    private fun isGamepad(source: Int): Boolean =
        (source and InputDevice.SOURCE_GAMEPAD == InputDevice.SOURCE_GAMEPAD) ||
            (source and InputDevice.SOURCE_JOYSTICK == InputDevice.SOURCE_JOYSTICK)

    private fun keyMask(code: Int): Int = when (code) {
        KeyEvent.KEYCODE_BUTTON_A -> 1 shl 7                                  // N64 A
        KeyEvent.KEYCODE_BUTTON_B -> 1 shl 6                                  // N64 B
        KeyEvent.KEYCODE_BUTTON_Y -> 1 shl 8                                  // C-Up
        KeyEvent.KEYCODE_BUTTON_X -> 1 shl 10                                 // C-Left
        KeyEvent.KEYCODE_BUTTON_L1 -> 1 shl 12                                // L
        KeyEvent.KEYCODE_BUTTON_R1 -> 1 shl 13                                // R
        KeyEvent.KEYCODE_BUTTON_L2, KeyEvent.KEYCODE_BUTTON_THUMBL -> 1 shl 5 // Z
        KeyEvent.KEYCODE_BUTTON_START, KeyEvent.KEYCODE_BUTTON_SELECT -> 1 shl 4
        KeyEvent.KEYCODE_DPAD_UP -> 1 shl 0
        KeyEvent.KEYCODE_DPAD_DOWN -> 1 shl 1
        KeyEvent.KEYCODE_DPAD_LEFT -> 1 shl 2
        KeyEvent.KEYCODE_DPAD_RIGHT -> 1 shl 3
        else -> 0
    }

    private fun pushPad() {
        if (NativeLib.available) NativeLib.nativeSetInput(padKeys or padMotion, padStickX, padStickY)
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.source and InputDevice.SOURCE_GAMEPAD != 0 ||
            event.source and InputDevice.SOURCE_JOYSTICK != 0 ||
            event.source and InputDevice.SOURCE_DPAD != 0) {
            Log.i("n64pad", "KEY src=0x${event.source.toString(16)} code=${event.keyCode} act=${event.action}")
        }
        if (isGamepad(event.source)) {
            val mask = keyMask(event.keyCode)
            if (mask != 0) {
                when (event.action) {
                    KeyEvent.ACTION_DOWN -> padKeys = padKeys or mask
                    KeyEvent.ACTION_UP -> padKeys = padKeys and mask.inv()
                }
                pushPad()
                return true
            }
        }
        return super.dispatchKeyEvent(event)
    }

    override fun dispatchGenericMotionEvent(event: MotionEvent): Boolean {
        Log.i("n64pad", "MOTION src=0x${event.source.toString(16)} act=${event.action} " +
            "x=${event.getAxisValue(MotionEvent.AXIS_X)} y=${event.getAxisValue(MotionEvent.AXIS_Y)} " +
            "z=${event.getAxisValue(MotionEvent.AXIS_Z)} rz=${event.getAxisValue(MotionEvent.AXIS_RZ)} " +
            "hx=${event.getAxisValue(MotionEvent.AXIS_HAT_X)} hy=${event.getAxisValue(MotionEvent.AXIS_HAT_Y)}")
        if (isGamepad(event.source) && event.action == MotionEvent.ACTION_MOVE) {
            val dz = 0.18f
            var x = event.getAxisValue(MotionEvent.AXIS_X)
            var y = event.getAxisValue(MotionEvent.AXIS_Y)
            if (abs(x) < dz) x = 0f
            if (abs(y) < dz) y = 0f
            padStickX = x
            padStickY = -y

            var m = 0
            // D-pad reported as a hat axis
            val hatX = event.getAxisValue(MotionEvent.AXIS_HAT_X)
            val hatY = event.getAxisValue(MotionEvent.AXIS_HAT_Y)
            if (hatX < -0.5f) m = m or (1 shl 2)
            if (hatX > 0.5f) m = m or (1 shl 3)
            if (hatY < -0.5f) m = m or (1 shl 0)
            if (hatY > 0.5f) m = m or (1 shl 1)
            // Right stick -> C buttons
            val rz = event.getAxisValue(MotionEvent.AXIS_Z)
            val rrz = event.getAxisValue(MotionEvent.AXIS_RZ)
            if (rz < -0.5f) m = m or (1 shl 10)
            if (rz > 0.5f) m = m or (1 shl 11)
            if (rrz < -0.5f) m = m or (1 shl 8)
            if (rrz > 0.5f) m = m or (1 shl 9)
            padMotion = m
            pushPad()
            return true
        }
        return super.dispatchGenericMotionEvent(event)
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
