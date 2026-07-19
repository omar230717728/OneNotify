package com.example.onenotify

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import com.onenotify.app.SyncBus
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.onenotify/sync"
    private var methodChannel: MethodChannel? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        Log.d("OneNotifyEngine", "LOG 4: MethodChannel registered: $channelName")

        val authChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.onenotify/auth_bridge")
        authChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "cacheFirebaseUID" -> {
                    val uid = call.argument<String>("uid")
                    if (uid != null) {
                        val sharedPref = getSharedPreferences("OneNotifyPrefs", Context.MODE_PRIVATE)
                        with (sharedPref.edit()) {
                            putString("firebase_uid", uid)
                            apply()
                        }
                        Log.d("OneNotifyEngine", "Successfully cached Firebase UID natively: $uid")
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "UID is null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isListenerPermissionGranted" -> {
                    val enabledListeners = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
                    val myComponent = ComponentName(this, com.onenotify.app.service.OneNotifyListenerService::class.java).flattenToString()
                    val isGranted = enabledListeners != null && (enabledListeners.contains(myComponent) || enabledListeners.contains(packageName))
                    result.success(isGranted)
                }
                "requestListenerPermission" -> {
                    val serviceComponent = ComponentName(this, com.onenotify.app.service.OneNotifyListenerService::class.java)
                    var opened = false
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
                        try {
                            val intent = Intent("android.settings.NOTIFICATION_LISTENER_DETAIL_SETTINGS").apply {
                                putExtra("android.provider.extra.NOTIFICATION_LISTENER_COMPONENT_NAME", serviceComponent.flattenToString())
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            opened = true
                        } catch (e: Exception) {
                            Log.w("OneNotify", "Failed to open direct detail settings. Falling back.", e)
                        }
                    }
                    if (!opened) {
                        try {
                            val fallbackIntent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(fallbackIntent)
                            opened = true
                        } catch (e: Exception) {
                            Log.e("OneNotify", "Critical: Cannot open any notification settings panel", e)
                        }
                    }
                    if (opened) {
                        result.success(true)
                    } else {
                        result.error("OPEN_SETTINGS_FAILED", "Failed to open any settings panel", null)
                    }
                }
                "requestRebindService" -> {
                    try {
                        val componentName = ComponentName(this, com.onenotify.app.service.OneNotifyListenerService::class.java)
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                            android.service.notification.NotificationListenerService.requestRebind(componentName)
                            Log.d("OneNotifyEngine", "Requested NotificationListenerService rebind.")
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("OneNotifyEngine", "Failed to request rebind: ", e)
                        result.success(false)
                    }
                }
                "isIgnoringBatteryOptimizations" -> {
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                        val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
                        val isIgnoring = powerManager?.isIgnoringBatteryOptimizations(packageName) ?: true
                        result.success(isIgnoring)
                    } else {
                        result.success(true)
                    }
                }
                "requestIgnoreBatteryOptimizations" -> {
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                        try {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            Log.e("OneNotifyEngine", "Failed to request battery optimization exemption: ", e)
                            try {
                                val fallbackIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(fallbackIntent)
                                result.success(true)
                            } catch (e2: Exception) {
                                try {
                                    val appDetailsIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                        data = Uri.parse("package:$packageName")
                                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    }
                                    startActivity(appDetailsIntent)
                                    result.success(true)
                                } catch (e3: Exception) {
                                    result.error("BATTERY_EXEMPTION_FAILED", e3.message, null)
                                }
                            }
                        }
                    } else {
                        result.success(true)
                    }
                }
                "openBatteryOptimizationSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("OneNotifyEngine", "Failed to open battery optimization settings, attempting App Details fallback: ", e)
                        try {
                            val appDetailsIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(appDetailsIntent)
                            result.success(true)
                        } catch (e2: Exception) {
                            Log.e("OneNotifyEngine", "Failed to open application details settings: ", e2)
                            result.error("OPEN_BATTERY_SETTINGS_FAILED", e2.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d("OneNotifyEngine", "LOG 4: MainActivity.onCreate — registering SyncBus callback")

        // Register the SyncBus callback to forward database updates to Flutter
        SyncBus.onDatabaseUpdated = {
            Log.d("OneNotifyEngine", "LOG 5: SyncBus callback FIRED — posting to main thread")
            mainHandler.post {
                Log.d("OneNotifyEngine", "LOG 5: Main thread post EXECUTING — methodChannel is ${if (methodChannel != null) "NOT NULL" else "NULL"}")
                try {
                    methodChannel?.invokeMethod("refresh", null)
                    Log.d("OneNotifyEngine", "LOG 5: methodChannel.invokeMethod('refresh') called SUCCESSFULLY")
                } catch (e: Exception) {
                    Log.e("OneNotifyEngine", "LOG 5 ERROR: invokeMethod threw exception: ${e.message}", e)
                }
            }
        }
        Log.d("OneNotifyEngine", "LOG 4: SyncBus.onDatabaseUpdated is now ${if (SyncBus.onDatabaseUpdated != null) "REGISTERED" else "NULL"}")
    }

    override fun onResume() {
        super.onResume()
        try {
            com.onenotify.app.service.OneNotifyListenerService.resetInboxCounter(this)
            Log.d("OneNotifyEngine", "LOG 4: MainActivity.onResume — reset silent inbox counter and cleared tray notification")
        } catch (e: Exception) {
            Log.e("OneNotifyEngine", "Error resetting inbox counter onResume: ${e.message}")
        }
    }

    override fun onDestroy() {
        Log.d("OneNotifyEngine", "LOG 4: MainActivity.onDestroy — clearing SyncBus and MethodChannel")
        SyncBus.onDatabaseUpdated = null
        methodChannel = null
        super.onDestroy()
    }
}
