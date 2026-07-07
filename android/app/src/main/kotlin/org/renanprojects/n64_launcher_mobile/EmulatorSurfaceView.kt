package org.renanprojects.n64_launcher_mobile

import android.content.Context
import android.opengl.GLSurfaceView
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10
import android.opengl.GLES20

class EmulatorSurfaceView(context: Context) : GLSurfaceView(context) {

    private var looping = false

    init {
        setEGLContextClientVersion(2)
        setRenderer(Renderer())
        renderMode = RENDERMODE_CONTINUOUSLY
    }

    fun startRenderLoop() {
        looping = true
        onResume()
    }

    fun stopRenderLoop() {
        looping = false
        onPause()
    }

    private inner class Renderer : GLSurfaceView.Renderer {
        override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
            GLES20.glClearColor(0f, 0f, 0f, 1f)
        }

        override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
            GLES20.glViewport(0, 0, width, height)
        }

        override fun onDrawFrame(gl: GL10?) {
            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
        }
    }
}
