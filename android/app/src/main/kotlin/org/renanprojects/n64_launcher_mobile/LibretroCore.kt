package org.renanprojects.n64_launcher_mobile

import android.content.Context
import java.io.File

class LibretroCore {

    private var running = false
    private var paused = false
    private var buttons = 0
    private var stickX = 0f
    private var stickY = 0f
    private var surface: EmulatorSurfaceView? = null

    fun attachSurface(view: EmulatorSurfaceView) {
        surface = view
    }

    fun detachSurface() {
        surface = null
    }

    fun isAvailable(context: Context): Boolean = coreFile(context) != null

    fun start(context: Context, romPath: String): Boolean {
        val core = coreFile(context) ?: return false
        if (!File(romPath).exists()) return false
        running = nativeStart(core.absolutePath, romPath)
        paused = false
        surface?.startRenderLoop()
        return running
    }

    fun stop() {
        if (running) nativeStop()
        running = false
        surface?.stopRenderLoop()
    }

    fun pause() {
        if (!running) return
        paused = true
        nativePause(true)
    }

    fun resume() {
        if (!running) return
        paused = false
        nativePause(false)
    }

    fun reset() {
        if (running) nativeReset()
    }

    fun setInput(buttons: Int, stickX: Float, stickY: Float) {
        this.buttons = buttons
        this.stickX = stickX
        this.stickY = stickY
        if (running) nativeSetInput(buttons, stickX, stickY)
    }

    fun saveState(file: File?) {
        if (running && file != null) nativeSaveState(file.absolutePath)
    }

    fun loadState(file: File?): Boolean {
        if (!running || file == null || !file.exists()) return false
        return nativeLoadState(file.absolutePath)
    }

    private fun coreFile(context: Context): File? {
        val dir = File(context.filesDir, "cores")
        if (!dir.exists()) return null
        return dir.listFiles { f -> f.extension == "so" }?.firstOrNull()
    }

    private external fun nativeStart(corePath: String, romPath: String): Boolean
    private external fun nativeStop()
    private external fun nativePause(paused: Boolean)
    private external fun nativeReset()
    private external fun nativeSetInput(buttons: Int, stickX: Float, stickY: Float)
    private external fun nativeSaveState(path: String)
    private external fun nativeLoadState(path: String): Boolean

    companion object {
        private var loaded = false

        init {
            try {
                System.loadLibrary("n64host")
                loaded = true
            } catch (_: Throwable) {
                loaded = false
            }
        }
    }
}
