package org.renanprojects.n64_launcher_mobile

import android.content.Context
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class EmulatorBridge(private val context: Context) : MethodChannel.MethodCallHandler {

    private var surface: EmulatorSurfaceView? = null
    private var currentRom: String? = null

    init {
        installBundledCore()
    }

    fun attachSurface(view: EmulatorSurfaceView) {
        surface = view
    }

    fun detachSurface() {
        surface = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isCoreAvailable" -> result.success(coreFile() != null)
            "controllerCount" -> result.success(0)
            "start" -> start(call.argument<String>("rom"), result)
            "stop" -> {
                if (NativeLib.available) NativeLib.nativeStop()
                currentRom = null
                result.success(null)
            }
            "pause" -> {
                if (NativeLib.available) NativeLib.nativePause(true)
                result.success(null)
            }
            "resume" -> {
                if (NativeLib.available) NativeLib.nativePause(false)
                result.success(null)
            }
            "reset" -> {
                if (NativeLib.available) NativeLib.nativeReset()
                result.success(null)
            }
            "input" -> {
                if (NativeLib.available) {
                    NativeLib.nativeSetInput(
                        call.argument<Int>("buttons") ?: 0,
                        (call.argument<Double>("stickX") ?: 0.0).toFloat(),
                        (call.argument<Double>("stickY") ?: 0.0).toFloat(),
                    )
                }
                result.success(null)
            }
            "saveState" -> {
                val slot = call.argument<Int>("slot") ?: 0
                slotFile(currentRom, slot)?.let {
                    if (NativeLib.available) NativeLib.nativeSaveState(it.absolutePath)
                }
                result.success(null)
            }
            "loadState" -> {
                val slot = call.argument<Int>("slot") ?: 0
                val file = slotFile(currentRom, slot)
                val ok = file != null && file.exists() && NativeLib.available &&
                    NativeLib.nativeLoadState(file.absolutePath)
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
        val core = coreFile()
        if (rom == null) {
            result.success("error")
            return
        }
        if (core == null || !NativeLib.available) {
            result.success("missingCore")
            return
        }
        currentRom = rom
        NativeLib.nativeSetPaths(
            core.absolutePath,
            rom,
            systemDir().absolutePath,
            saveDir().absolutePath,
        )
        result.success("running")
    }

    private fun coresDir(): File = dir("cores")

    private fun statesDir(): File = dir("states")

    private fun systemDir(): File = dir("system")

    private fun saveDir(): File = dir("saves")

    private fun dir(name: String): File {
        val dir = File(context.filesDir, name)
        if (!dir.exists()) dir.mkdirs()
        return dir
    }

    private fun coreFile(): File? =
        coresDir().listFiles { f -> f.extension == "so" }?.firstOrNull()

    private fun installBundledCore(): Unit {
        if (coreFile() != null) return
        val abi = Build.SUPPORTED_ABIS.firstOrNull() ?: return
        val assetPath = "cores/$abi"
        val assets = context.assets
        val names = try {
            assets.list(assetPath) ?: return
        } catch (_: Exception) {
            return
        }
        for (name in names) {
            if (!name.endsWith(".so")) continue
            val target = File(coresDir(), name)
            try {
                assets.open("$assetPath/$name").use { input ->
                    target.outputStream().use { output -> input.copyTo(output) }
                }
            } catch (_: Exception) {
                target.delete()
            }
        }
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
        if (NativeLib.available) NativeLib.nativeStop()
        detachSurface()
    }
}
