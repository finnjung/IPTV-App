package com.streameee.app

import android.app.DownloadManager
import android.app.UiModeManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val TV_DETECTION_CHANNEL = "com.streameee.app/tv_detection"
    private val APP_UPDATE_CHANNEL = "com.streameee.app/app_update"

    private var downloadManager: DownloadManager? = null
    private var currentDownloadId: Long = -1
    private var updateChannel: MethodChannel? = null
    private var progressHandler: Handler? = null
    private var progressRunnable: Runnable? = null

    private val downloadReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val id = intent?.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1) ?: -1
            if (id == currentDownloadId) {
                stopProgressTracking()
                checkDownloadStatus()
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        downloadManager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager

        // TV Detection Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TV_DETECTION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isTvDevice" -> result.success(isTvDevice())
                "hasLeanbackFeature" -> result.success(hasLeanbackFeature())
                else -> result.notImplemented()
            }
        }

        // App Update Channel
        updateChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_UPDATE_CHANNEL)
        updateChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getVersionCode" -> {
                    result.success(getVersionCode())
                }
                "getVersionName" -> {
                    result.success(getVersionName())
                }
                "downloadApk" -> {
                    val url = call.argument<String>("url")
                    val fileName = call.argument<String>("fileName")
                    if (url != null && fileName != null) {
                        downloadApk(url, fileName, result)
                    } else {
                        result.error("INVALID_ARGS", "URL and fileName are required", null)
                    }
                }
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        installApk(filePath, result)
                    } else {
                        result.error("INVALID_ARGS", "filePath is required", null)
                    }
                }
                "cancelDownload" -> {
                    cancelDownload(result)
                }
                else -> result.notImplemented()
            }
        }

        // Register download complete receiver
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(
                downloadReceiver,
                IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE),
                Context.RECEIVER_EXPORTED
            )
        } else {
            registerReceiver(
                downloadReceiver,
                IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE)
            )
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(downloadReceiver)
        } catch (e: Exception) {
            // Receiver might not be registered
        }
        stopProgressTracking()
    }

    private fun isTvDevice(): Boolean {
        val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
        return uiModeManager.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION
    }

    private fun hasLeanbackFeature(): Boolean {
        return packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
    }

    private fun getVersionCode(): Int {
        return try {
            val packageInfo = packageManager.getPackageInfo(packageName, 0)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageInfo.longVersionCode.toInt()
            } else {
                @Suppress("DEPRECATION")
                packageInfo.versionCode
            }
        } catch (e: Exception) {
            0
        }
    }

    private fun getVersionName(): String {
        return try {
            val packageInfo = packageManager.getPackageInfo(packageName, 0)
            packageInfo.versionName ?: "1.0.0"
        } catch (e: Exception) {
            "1.0.0"
        }
    }

    private fun downloadApk(url: String, fileName: String, result: MethodChannel.Result) {
        try {
            // Cancel any existing download
            if (currentDownloadId != -1L) {
                downloadManager?.remove(currentDownloadId)
            }

            // Delete existing file if present
            val downloadDir = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
            val file = File(downloadDir, fileName)
            if (file.exists()) {
                file.delete()
            }

            val request = DownloadManager.Request(Uri.parse(url))
                .setTitle("streameee Update")
                .setDescription("Downloading update...")
                .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE)
                .setDestinationInExternalFilesDir(this, Environment.DIRECTORY_DOWNLOADS, fileName)
                .setAllowedOverMetered(true)
                .setAllowedOverRoaming(true)

            currentDownloadId = downloadManager?.enqueue(request) ?: -1

            if (currentDownloadId != -1L) {
                startProgressTracking()
                result.success(mapOf("downloadId" to currentDownloadId))
            } else {
                result.error("DOWNLOAD_FAILED", "Failed to start download", null)
            }
        } catch (e: Exception) {
            result.error("DOWNLOAD_ERROR", e.message, null)
        }
    }

    private fun startProgressTracking() {
        stopProgressTracking()

        progressHandler = Handler(Looper.getMainLooper())
        progressRunnable = object : Runnable {
            override fun run() {
                if (currentDownloadId == -1L) return

                val query = DownloadManager.Query().setFilterById(currentDownloadId)
                val cursor: Cursor? = downloadManager?.query(query)

                cursor?.use {
                    if (it.moveToFirst()) {
                        val bytesDownloadedIndex = it.getColumnIndex(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR)
                        val bytesTotalIndex = it.getColumnIndex(DownloadManager.COLUMN_TOTAL_SIZE_BYTES)
                        val statusIndex = it.getColumnIndex(DownloadManager.COLUMN_STATUS)

                        if (bytesDownloadedIndex >= 0 && bytesTotalIndex >= 0 && statusIndex >= 0) {
                            val bytesDownloaded = it.getLong(bytesDownloadedIndex)
                            val bytesTotal = it.getLong(bytesTotalIndex)
                            val status = it.getInt(statusIndex)

                            if (status == DownloadManager.STATUS_RUNNING && bytesTotal > 0) {
                                val progress = bytesDownloaded.toDouble() / bytesTotal.toDouble()
                                updateChannel?.invokeMethod("onDownloadProgress", progress)
                            }
                        }
                    }
                }

                progressHandler?.postDelayed(this, 500) // Update every 500ms
            }
        }
        progressHandler?.post(progressRunnable!!)
    }

    private fun stopProgressTracking() {
        progressRunnable?.let { progressHandler?.removeCallbacks(it) }
        progressHandler = null
        progressRunnable = null
    }

    private fun checkDownloadStatus() {
        if (currentDownloadId == -1L) return

        val query = DownloadManager.Query().setFilterById(currentDownloadId)
        val cursor: Cursor? = downloadManager?.query(query)

        cursor?.use {
            if (it.moveToFirst()) {
                val statusIndex = it.getColumnIndex(DownloadManager.COLUMN_STATUS)
                val localUriIndex = it.getColumnIndex(DownloadManager.COLUMN_LOCAL_URI)
                val reasonIndex = it.getColumnIndex(DownloadManager.COLUMN_REASON)

                if (statusIndex >= 0) {
                    when (it.getInt(statusIndex)) {
                        DownloadManager.STATUS_SUCCESSFUL -> {
                            if (localUriIndex >= 0) {
                                val localUri = it.getString(localUriIndex)
                                val filePath = Uri.parse(localUri).path
                                updateChannel?.invokeMethod("onDownloadComplete", filePath)
                            }
                        }
                        DownloadManager.STATUS_FAILED -> {
                            val reason = if (reasonIndex >= 0) it.getInt(reasonIndex) else -1
                            updateChannel?.invokeMethod("onDownloadFailed", "Download failed with reason: $reason")
                        }
                    }
                }
            }
        }
    }

    private fun installApk(filePath: String, result: MethodChannel.Result) {
        try {
            val file = File(filePath)
            if (!file.exists()) {
                result.error("FILE_NOT_FOUND", "APK file not found at $filePath", null)
                return
            }

            val uri: Uri = FileProvider.getUriForFile(
                this,
                "${packageName}.fileprovider",
                file
            )

            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
            }

            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("INSTALL_ERROR", e.message, null)
        }
    }

    private fun cancelDownload(result: MethodChannel.Result) {
        try {
            if (currentDownloadId != -1L) {
                downloadManager?.remove(currentDownloadId)
                currentDownloadId = -1
                stopProgressTracking()
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("CANCEL_ERROR", e.message, null)
        }
    }
}
