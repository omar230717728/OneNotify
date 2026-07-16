package com.example.onenotify

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.onenotify.app.SyncBus
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.onenotify/sync"
    private var methodChannel: MethodChannel? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        Log.d("OneNotifyEngine", "LOG 4: MethodChannel registered: $channelName")
        
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isListenerPermissionGranted" -> {
                    val enabledListeners = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
                    val myComponent = ComponentName(this, com.onenotify.app.service.OneNotifyListenerService::class.java).flattenToString()
                    val isGranted = enabledListeners != null && (enabledListeners.contains(myComponent) || enabledListeners.contains(packageName))
                    result.success(isGranted)
                }
                "requestListenerPermission" -> {
                    try {
                        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("OneNotifyEngine", "Failed to open Notification Listener settings: ", e)
                        result.error("OPEN_SETTINGS_FAILED", e.message, null)
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

    override fun onDestroy() {
        Log.d("OneNotifyEngine", "LOG 4: MainActivity.onDestroy — clearing SyncBus and MethodChannel")
        SyncBus.onDatabaseUpdated = null
        methodChannel = null
        super.onDestroy()
    }
}
