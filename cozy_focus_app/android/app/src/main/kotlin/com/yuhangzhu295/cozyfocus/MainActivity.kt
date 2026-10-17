package com.yuhangzhu295.cozyfocus

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Storage Access Framework calls the local backup needs.
 *
 * The app writes no backup to shared storage on its own and asks for no storage
 * permission. `ACTION_CREATE_DOCUMENT` lets the user choose a destination and
 * grants this process access to that one file; `ACTION_OPEN_DOCUMENT` does the
 * same for reading. That is the smallest permission surface that still lets a
 * backup leave the app.
 */
class MainActivity : FlutterActivity() {
    private var pendingSave: MethodChannel.Result? = null
    private var pendingSaveBytes: ByteArray? = null
    private var pendingOpen: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveBackup" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        if (bytes == null) {
                            result.error("bad_args", "no bytes to write", null)
                            return@setMethodCallHandler
                        }
                        // One dialog at a time. A second request while the first
                        // is open would overwrite the pending result and leave
                        // the first future hanging forever.
                        if (pendingSave != null) {
                            result.error("busy", "a save dialog is already open", null)
                            return@setMethodCallHandler
                        }
                        pendingSave = result
                        pendingSaveBytes = bytes
                        val name = call.argument<String>("name")
                            ?: "cozyfocus-backup.cozybackup"
                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "application/octet-stream"
                            putExtra(Intent.EXTRA_TITLE, name)
                        }
                        startActivityForResult(intent, REQUEST_SAVE)
                    }
                    "openBackup" -> {
                        if (pendingOpen != null) {
                            result.error("busy", "an open dialog is already open", null)
                            return@setMethodCallHandler
                        }
                        pendingOpen = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                        }
                        startActivityForResult(intent, REQUEST_OPEN)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            REQUEST_SAVE -> {
                val result = pendingSave
                val bytes = pendingSaveBytes
                pendingSave = null
                pendingSaveBytes = null
                if (resultCode != Activity.RESULT_OK || data?.data == null || bytes == null) {
                    // Cancelling is not an error: the UI says "已取消".
                    result?.success(null)
                    return
                }
                try {
                    contentResolver.openOutputStream(data.data!!)?.use { it.write(bytes) }
                    result?.success(data.data.toString())
                } catch (error: Exception) {
                    result?.error("write_failed", error.message, null)
                }
            }
            REQUEST_OPEN -> {
                val result = pendingOpen
                pendingOpen = null
                if (resultCode != Activity.RESULT_OK || data?.data == null) {
                    result?.success(null)
                    return
                }
                try {
                    val bytes = contentResolver.openInputStream(data.data!!)
                        ?.use { it.readBytes() }
                    result?.success(bytes)
                } catch (error: Exception) {
                    result?.error("read_failed", error.message, null)
                }
            }
        }
    }

    companion object {
        private const val CHANNEL = "cozyfocus/backup"
        private const val REQUEST_SAVE = 4711
        private const val REQUEST_OPEN = 4712
    }
}
