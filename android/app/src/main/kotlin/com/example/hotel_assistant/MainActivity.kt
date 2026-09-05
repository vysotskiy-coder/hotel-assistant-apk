package com.example.hotel_assistant

import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.core.content.FileProvider
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "HotelAssistantUpdate"
        private const val CHANNEL = "hotel_assistant/apk_installer"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        Log.d(TAG, "Flutter engine configured.")

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            Log.d(TAG, "MethodChannel call: ${call.method}")

            when (call.method) {

                "canRequestPackageInstalls" -> {
                    try {
                        val allowed =
                            Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                                packageManager.canRequestPackageInstalls()

                        Log.d(
                            TAG,
                            "canRequestPackageInstalls = $allowed"
                        )

                        result.success(allowed)
                    } catch (e: Exception) {
                        Log.e(
                            TAG,
                            "Permission check failed",
                            e
                        )

                        result.error(
                            "PERMISSION_CHECK_ERROR",
                            e.message,
                            e.stackTraceToString()
                        )
                    }
                }

                "openInstallPermissionSettings" -> {
                    try {
                        Log.d(
                            TAG,
                            "Opening unknown-app-sources settings."
                        )

                        openInstallPermissionSettings()

                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(
                            TAG,
                            "Cannot open install permission settings.",
                            e
                        )

                        result.error(
                            "SETTINGS_ERROR",
                            e.message,
                            e.stackTraceToString()
                        )
                    }
                }

                "installApk" -> {
                    val path = call.argument<String>("path")

                    Log.d(
                        TAG,
                        "installApk called. path=$path"
                    )

                    if (path.isNullOrBlank()) {
                        Log.e(
                            TAG,
                            "APK path is empty."
                        )

                        result.error(
                            "INVALID_PATH",
                            "APK path is empty.",
                            null
                        )

                        return@setMethodCallHandler
                    }

                    try {
                        val file = File(path)

                        Log.d(
                            TAG,
                            "APK exists=${file.exists()}, " +
                                "length=${if (file.exists()) file.length() else 0}"
                        )

                        installApk(file)

                        Log.d(
                            TAG,
                            "Install intent started successfully."
                        )

                        result.success(true)

                    } catch (e: SecurityException) {
                        Log.e(
                            TAG,
                            "SecurityException while starting APK installer.",
                            e
                        )

                        result.error(
                            "INSTALL_SECURITY_ERROR",
                            e.message,
                            e.stackTraceToString()
                        )

                    } catch (e: Exception) {
                        Log.e(
                            TAG,
                            "Exception while starting APK installer.",
                            e
                        )

                        result.error(
                            "INSTALL_ERROR",
                            e.message,
                            e.stackTraceToString()
                        )
                    }
                }

                else -> {
                    Log.w(
                        TAG,
                        "Unknown method: ${call.method}"
                    )

                    result.notImplemented()
                }
            }
        }
    }

    private fun openInstallPermissionSettings() {

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            Log.d(
                TAG,
                "Android version is below O. Permission is not required."
            )
            return
        }

        if (packageManager.canRequestPackageInstalls()) {
            Log.d(
                TAG,
                "Install permission is already granted."
            )
            return
        }

        val settingsIntent = Intent(
            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
            Uri.parse("package:$packageName")
        )

        settingsIntent.addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK
        )

        Log.d(
            TAG,
            "Starting settings: $settingsIntent"
        )

        startActivity(settingsIntent)
    }

    private fun installApk(file: File) {

        Log.d(
            TAG,
            "installApk(): ${file.absolutePath}"
        )

        if (!file.exists()) {
            throw IllegalArgumentException(
                "APK file does not exist: ${file.absolutePath}"
            )
        }

        if (file.length() <= 0) {
            throw IllegalArgumentException(
                "APK file is empty."
            )
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {

            val allowed =
                packageManager.canRequestPackageInstalls()

            Log.d(
                TAG,
                "Unknown sources permission = $allowed"
            )

            if (!allowed) {
                openInstallPermissionSettings()

                throw IllegalStateException(
                    "Allow installation from this source, " +
                        "then tap Update again."
                )
            }
        }

        val authority =
            "${applicationContext.packageName}.fileprovider"

        Log.d(
            TAG,
            "FileProvider authority=$authority"
        )

        val uri: Uri = FileProvider.getUriForFile(
            this,
            authority,
            file
        )

        Log.d(
            TAG,
            "APK content URI=$uri"
        )

        val intent = Intent(
            Intent.ACTION_VIEW
        ).apply {

            setDataAndType(
                uri,
                "application/vnd.android.package-archive"
            )

            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION
            )

            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK
            )

            clipData = ClipData.newRawUri(
                "APK",
                uri
            )
        }

        Log.d(
            TAG,
            "Starting APK installer intent."
        )

        Log.d(
            TAG,
            "Intent action=${intent.action}"
        )

        Log.d(
            TAG,
            "Intent type=${intent.type}"
        )

        Log.d(
            TAG,
            "Intent data=${intent.data}"
        )

        try {
            startActivity(intent)

            Log.d(
                TAG,
                "startActivity() completed."
            )

        } catch (e: Exception) {

            Log.e(
                TAG,
                "startActivity() failed.",
                e
            )

            throw e
        }
    }
}