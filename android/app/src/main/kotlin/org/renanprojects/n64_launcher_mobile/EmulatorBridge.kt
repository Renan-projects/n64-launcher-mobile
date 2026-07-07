package org.renanprojects.n64_launcher_mobile

import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class EmulatorBridge(private val context: Context) : MethodChannel.MethodCallHandler {

    private val core = LibretroCore()
    private var surface: EmulatorSurfaceView? = null
    private var currentRom: String? = null

    fun attachSurface(view: EmulatorSurfaceView) {
        surface = view
        core.attachSurface(view)
    }

    fun detachSurface() {
        core.detachSurface()
        surface = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isCoreAvailable" -> result.success(core.isAvailable(context))
            "controllerCount" -> result.success(0)
            "start" -> start(call.argument<String>("rom"), result)
            "stop" -> {
                core.stop()
                currentRom = null
                result.success(null)
            }
            "pause" -> {
                core.pause()
                result.success(null)
            }
            "resume" -> {
                core.resume()
                result.success(null)
            }
            "reset" -> {
                core.reset()
                result.success(null)
            }
            "input" -> {
                core.setInput(
                    call.argument<Int>("buttons") ?: 0,
                    (call.argument<Double>("stickX") ?: 0.0).toFloat(),
                    (call.argument<Double>("stickY") ?: 0.0).toFloat(),
                )
                result.success(null)
            }
            "saveState" -> {
                val slot = call.argument<Int>("slot") ?: 0
                core.saveState(slotFile(currentRom, slot))
                result.success(null)
            }
            "loadState" -> {
                val slot = call.argument<Int>("slot") ?: 0
                val ok = core.loadState(slotFile(currentRom, slot))
                result.success(if (ok) "running" else "error")
            }
            "saveSlots" -> result.success(listSlots(call.argument<String>("rom")))
            "deleteSaveSlot" -> {
                val rom = call.argument<String>("rom")
                val slot = call.argument<Int>("slot") ?: 0
                slotFile(rom, slot)?.delete()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun start(rom: String?, result: MethodChannel.Result) {
        if (rom == null) {
            result.success("error")
            return
        }
        if (!core.isAvailable(context)) {
            result.success("missingCore")
            return
        }
        currentRom = rom
        val started = core.start(context, rom)
        result.success(if (started) "running" else "error")
    }

    private fun statesDir(): File {
        val dir = File(context.filesDir, "states")
        if (!dir.exists()) dir.mkdirs()
        return dir
    }

    private fun slotFile(rom: String?, slot: Int): File? {
        val name = rom?.let { File(it).nameWithoutExtension } ?: return null
        return File(statesDir(), "$name.state$slot")
    }

    private fun listSlots(rom: String?): List<Map<String, Any?>> {
        val name = rom?.let { File(it).nameWithoutExtension } ?: return emptyList()
        val slots = ArrayList<Map<String, Any?>>()
        for (i in 0 until 10) {
            val file = File(statesDir(), "$name.state$i")
            val exists = file.exists()
            slots.add(
                mapOf(
                    "index" to i,
                    "isAuto" to false,
                    "filePath" to if (exists) file.absolutePath else null,
                    "modified" to if (exists) file.lastModified() else null,
                    "sizeBytes" to if (exists) file.length() else null,
                ),
            )
        }
        return slots
    }

    fun release() {
        core.stop()
        detachSurface()
    }
}
