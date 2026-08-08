package org.renanprojects.n64_launcher_mobile

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class EmulatorBridge(private val context: Context) : MethodChannel.MethodCallHandler {

    private var surface: EmulatorSurfaceView? = null
    private var currentRom: String? = null

    /** Where saves, save states and the system folder live. See [resolveRoot]. */
    private var storageRoot: File = context.filesDir

    init {
        syncStorage()
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
            "savesInfo" -> {
                syncStorage()
                result.success(
                    mapOf(
                        "savesDir" to saveDir().absolutePath,
                        "statesDir" to statesDir().absolutePath,
                        "isShared" to isShared(),
                        "canOpenFolder" to true,
                    ),
                )
            }
            "openSavesFolder" -> {
                syncStorage()
                result.success(if (openFolder(saveDir())) "opened" else "noFileManager")
            }
            "requestSavesAccess" -> result.success(requestStorageAccess())
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

    // The core is dlopen'd, so it stays in internal storage whatever happens.
    private fun coresDir(): File {
        val dir = File(context.filesDir, "cores")
        if (!dir.exists()) dir.mkdirs()
        return dir
    }

    private fun statesDir(): File = dir("states")

    private fun systemDir(): File = dir("system")

    private fun saveDir(): File = dir("saves")

    private fun dir(name: String): File {
        val dir = File(storageRoot, name)
        if (!dir.exists()) dir.mkdirs()
        return dir
    }

    /** True when saves sit somewhere the user can reach with a file manager. */
    private fun isShared(): Boolean =
        storageRoot.absolutePath.startsWith(publicRoot().absolutePath)

    private fun publicRoot(): File =
        File(Environment.getExternalStorageDirectory(), PUBLIC_FOLDER)

    /**
     * Best folder we can actually write to, most reachable first:
     * /sdcard/N64Launcher (any file manager), Android/data/<pkg>/files (USB),
     * then internal storage as a last resort.
     */
    private fun resolveRoot(): File {
        val candidates = listOfNotNull(
            publicRoot(),
            context.getExternalFilesDir(null),
            context.filesDir,
        )
        return candidates.firstOrNull { writable(it) } ?: context.filesDir
    }

    private fun writable(dir: File): Boolean = try {
        if (!dir.exists()) dir.mkdirs()
        val probe = File(dir, ".write-probe")
        probe.writeText("ok")
        probe.delete()
        true
    } catch (_: Throwable) {
        false
    }

    /**
     * Pick the storage root and move anything left behind by an older install
     * (or by a run without storage permission) into it.
     */
    private fun syncStorage() {
        val target = resolveRoot()
        val previous = listOfNotNull(context.filesDir, context.getExternalFilesDir(null))
            .filter { it.absolutePath != target.absolutePath }
        for (old in previous) {
            for (name in MOVABLE_DIRS) {
                moveContents(File(old, name), File(target, name))
            }
        }
        storageRoot = target
    }

    private fun moveContents(from: File, to: File) {
        if (!from.isDirectory) return
        val files = from.listFiles() ?: return
        if (files.isEmpty()) return
        if (!to.exists() && !to.mkdirs()) return
        for (file in files) {
            if (!file.isFile) continue
            val target = File(to, file.name)
            // Never clobber a save that already exists in the new location.
            if (target.exists()) continue
            try {
                file.copyTo(target)
                file.delete()
            } catch (_: Throwable) {
            }
        }
    }

    /** Ask for whatever access would let us use the public folder. */
    private fun requestStorageAccess(): String {
        val activity = context as? Activity ?: return "unsupported"

        // From Android 11 the runtime permission no longer grants writes
        // outside the app folders: all-files access is the only way in.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (Environment.isExternalStorageManager()) return "granted"
            val settings = Intent(
                Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                Uri.parse("package:${context.packageName}"),
            )
            if (launch(settings)) return "settings"
            // Some builds only expose the whole-list screen.
            return if (launch(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION))) {
                "settings"
            } else {
                "unsupported"
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            activity.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            activity.requestPermissions(
                arrayOf(
                    Manifest.permission.READ_EXTERNAL_STORAGE,
                    Manifest.permission.WRITE_EXTERNAL_STORAGE,
                ),
                STORAGE_REQUEST_CODE,
            )
            return "requested"
        }
        return "granted"
    }

    /**
     * Open a folder in whatever browses files on this device. Falls back to the
     * system document picker, which every Android since 8 has.
     */
    private fun openFolder(dir: File): Boolean {
        val relative = relativeToPrimary(dir)
        if (relative != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val documentId = "primary:$relative"
            val document = DocumentsContract.buildDocumentUri(EXTERNAL_STORAGE_PROVIDER, documentId)
            val view = Intent(Intent.ACTION_VIEW)
                .setDataAndType(document, DOCUMENT_DIR_MIME)
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            if (launch(view)) return true

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val tree = DocumentsContract.buildTreeDocumentUri(EXTERNAL_STORAGE_PROVIDER, documentId)
                val picker = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
                    .putExtra(DocumentsContract.EXTRA_INITIAL_URI, tree)
                if (launch(picker)) return true
            }
        }
        return false
    }

    /** "N64Launcher/saves" for a path under /sdcard, null for anything else. */
    private fun relativeToPrimary(dir: File): String? {
        val root = Environment.getExternalStorageDirectory().absolutePath
        val path = dir.absolutePath
        if (!path.startsWith("$root/")) return null
        return path.removePrefix("$root/")
    }

    private fun launch(intent: Intent): Boolean = try {
        val activity = context as? Activity
        if (activity != null) {
            activity.startActivity(intent)
        } else {
            context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
        true
    } catch (_: Throwable) {
        false
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

    /** Called after the storage permission dialog so the folder is re-picked. */
    fun onStoragePermissionResult() {
        syncStorage()
    }

    companion object {
        const val STORAGE_REQUEST_CODE = 8064
        private const val PUBLIC_FOLDER = "N64Launcher"
        private const val EXTERNAL_STORAGE_PROVIDER = "com.android.externalstorage.documents"
        private const val DOCUMENT_DIR_MIME = "vnd.android.document/directory"
        private val MOVABLE_DIRS = listOf("saves", "states", "system")
    }
}
