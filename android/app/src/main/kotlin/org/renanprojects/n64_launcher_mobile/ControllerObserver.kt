package org.renanprojects.n64_launcher_mobile

import android.content.Context
import android.hardware.input.InputManager
import android.os.Handler
import android.os.Looper
import android.view.InputDevice
import io.flutter.plugin.common.EventChannel

class ControllerObserver(context: Context) :
    EventChannel.StreamHandler, InputManager.InputDeviceListener {

    private val inputManager =
        context.getSystemService(Context.INPUT_SERVICE) as InputManager
    private val handler = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        inputManager.registerInputDeviceListener(this, handler)
        emit()
    }

    override fun onCancel(arguments: Any?) {
        inputManager.unregisterInputDeviceListener(this)
        sink = null
    }

    override fun onInputDeviceAdded(deviceId: Int) = emit()

    override fun onInputDeviceRemoved(deviceId: Int) = emit()

    override fun onInputDeviceChanged(deviceId: Int) = emit()

    fun currentCount(): Int {
        var count = 0
        for (id in InputDevice.getDeviceIds()) {
            val device = InputDevice.getDevice(id) ?: continue
            if (device.isVirtual) continue
            val sources = device.sources
            // Require SOURCE_GAMEPAD: real game controllers (Xbox, PS, 8BitDo,
            // generic Bluetooth/USB pads) all report it. Reject phantom devices
            // that only advertise SOURCE_JOYSTICK, such as the Qualcomm headset
            // "Button Jack" present on this and many other phones.
            val isGamepad =
                sources and InputDevice.SOURCE_GAMEPAD == InputDevice.SOURCE_GAMEPAD
            if (isGamepad) count++
        }
        return count
    }

    private fun emit() {
        handler.post { sink?.success(currentCount()) }
    }

    fun release() {
        inputManager.unregisterInputDeviceListener(this)
        sink = null
    }
}
