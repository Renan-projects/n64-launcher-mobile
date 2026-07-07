package org.renanprojects.n64_launcher_mobile

object NativeLib {

    var available = false
        private set

    external fun nativeSetPaths(
        corePath: String,
        romPath: String,
        systemDir: String,
        saveDir: String,
    )

    external fun nativeOnSurfaceCreated()
    external fun nativeOnSurfaceChanged(width: Int, height: Int)
    external fun nativeRunFrame()
    external fun nativeOnSurfaceDestroyed()
    external fun nativeStop()
    external fun nativePause(paused: Boolean)
    external fun nativeReset()
    external fun nativeSetInput(buttons: Int, stickX: Float, stickY: Float)
    external fun nativeSaveState(path: String)
    external fun nativeLoadState(path: String): Boolean

    init {
        try {
            System.loadLibrary("n64host")
            available = true
        } catch (_: Throwable) {
            available = false
        }
    }
}
