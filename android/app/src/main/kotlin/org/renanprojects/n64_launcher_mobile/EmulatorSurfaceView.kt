package org.renanprojects.n64_launcher_mobile

import android.content.Context
import android.opengl.GLSurfaceView
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10

class EmulatorSurfaceView(context: Context) : GLSurfaceView(context) {

    init {
        setEGLContextClientVersion(3)
        setEGLConfigChooser(8, 8, 8, 8, 24, 8)
        setRenderer(Renderer())
        renderMode = RENDERMODE_CONTINUOUSLY
    }

    fun shutdown() {
        queueEvent {
            if (NativeLib.available) NativeLib.nativeOnSurfaceDestroyed()
        }
    }

    private inner class Renderer : GLSurfaceView.Renderer {
        override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
            if (NativeLib.available) NativeLib.nativeOnSurfaceCreated()
        }

        override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
            if (NativeLib.available) NativeLib.nativeOnSurfaceChanged(width, height)
        }

        override fun onDrawFrame(gl: GL10?) {
            if (NativeLib.available) NativeLib.nativeRunFrame()
        }
    }
}
