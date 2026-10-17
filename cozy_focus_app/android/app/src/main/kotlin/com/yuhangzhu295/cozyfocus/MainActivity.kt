package com.yuhangzhu295.cozyfocus

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

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
    /**
     * One request at a time. Two system pickers cannot be open at once, and a
     * second request while the first is pending would overwrite the result and
     * leave the first Dart future hanging forever.
     */
    private var pendingResult: MethodChannel.Result? = null
    private var pendingKind: Int = 0
    private var pendingSaveBytes: ByteArray? = null

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
                        if (pendingResult != null) {
                            result.error("busy", "a file dialog is already open", null)
                            return@setMethodCallHandler
                        }
                        pendingResult = result
                        pendingKind = REQUEST_SAVE
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
                        if (pendingResult != null) {
                            result.error("busy", "a file dialog is already open", null)
                            return@setMethodCallHandler
                        }
                        pendingResult = result
                        pendingKind = REQUEST_OPEN
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
        if (requestCode != pendingKind) return
        val result = pendingResult
        pendingResult = null
        pendingKind = 0

        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            // Cancelling is not an error: the UI says "已取消".
            result?.success(null)
            return
        }

        when (requestCode) {
            REQUEST_SAVE -> {
                val bytes = pendingSaveBytes
                pendingSaveBytes = null
                if (bytes == null) {
                    result?.error("bad_args", "no bytes to write", null)
                    return
                }
                try {
                    val stream = contentResolver.openOutputStream(uri)
                    if (stream == null) {
                        // A null stream is a failure, not a save. Reporting
                        // success here would tell the user their backup exists
                        // when it does not.
                        result?.error("write_failed", "could not open the file", null)
                        return
                    }
                    stream.use { it.write(bytes) }
                    result?.success(uri.toString())
                } catch (error: Exception) {
                    result?.error("write_failed", error.message, null)
                }
            }
            REQUEST_OPEN -> {
                try {
                    val size = sizeOf(uri)
                    if (size != null && size > MAX_BYTES) {
                        result?.error("too_large", "the file is too large", null)
                        return
                    }
                    val bytes = readBounded(uri)
                    if (bytes == null) {
                        result?.error("read_failed", "could not open the file", null)
                    } else {
                        result?.success(bytes)
                    }
                } catch (error: Exception) {
                    result?.error("read_failed", error.message, null)
                }
            }
        }
    }

    /**
     * A pending result cannot survive the activity being recreated. Completing
     * it with an error is the honest end: the alternative is a Dart future that
     * never settles and a button that stays disabled forever.
     */
    override fun onDestroy() {
        pendingResult?.error(
            "interrupted",
            "the activity was destroyed before the file dialog finished",
            null,
        )
        pendingResult = null
        pendingKind = 0
        pendingSaveBytes = null
        super.onDestroy()
    }

    /** The document's declared size, when the provider reports one. */
    private fun sizeOf(uri: Uri): Long? {
        return contentResolver.query(
            uri,
            arrayOf(OpenableColumns.SIZE),
            null,
            null,
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst() && !cursor.isNull(0)) cursor.getLong(0) else null
        }
    }

    /**
     * Reads the document, refusing to allocate past [MAX_BYTES].
     *
     * The Dart side checks the size too, but by then the bytes are already in
     * memory. A limit that only runs after the allocation does not limit
     * anything.
     */
    private fun readBounded(uri: Uri): ByteArray? {
        val input = contentResolver.openInputStream(uri) ?: return null
        input.use { stream ->
            val out = ByteArrayOutputStream()
            val chunk = ByteArray(64 * 1024)
            var total = 0
            while (true) {
                val read = stream.read(chunk)
                if (read < 0) break
                total += read
                if (total > MAX_BYTES) {
                    throw IllegalStateException("the file is larger than the backup limit")
                }
                out.write(chunk, 0, read)
            }
            return out.toByteArray()
        }
    }

    companion object {
        private const val CHANNEL = "cozyfocus/backup"
        private const val REQUEST_SAVE = 4711
        private const val REQUEST_OPEN = 4712

        /** Keep in step with `BackupFormat.maxBytes` (64 MB). */
        private const val MAX_BYTES = 64L * 1024L * 1024L
    }
}
