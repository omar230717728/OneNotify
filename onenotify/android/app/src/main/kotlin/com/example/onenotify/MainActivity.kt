package com.example.onenotify

import android.os.Bundle
import android.os.Handler
import android.os.Looper
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
