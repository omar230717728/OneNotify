package com.example.onenotify

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.service.notification.NotificationListenerService
import android.util.Log

class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return

        val action = intent.action
        Log.d("OneNotifyEngine", "BootReceiver received action: $action")

        if (Intent.ACTION_BOOT_COMPLETED == action ||
            Intent.ACTION_MY_PACKAGE_REPLACED == action ||
            "android.intent.action.QUICKBOOT_POWERON" == action) {
            
            tryReconnectService(context)
        }
    }

    private fun tryReconnectService(context: Context) {
        val componentName = ComponentName(context, OneNotifyListenerService::class.java)

        // API 24 (Android 7.0)+ provides requestRebind() to ask the system to reconnect
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            try {
                NotificationListenerService.requestRebind(componentName)
                Log.d("OneNotifyEngine", "Requested service rebind via requestRebind")
            } catch (e: Exception) {
                Log.e("OneNotifyEngine", "Failed requestRebind, falling back to toggle: ${e.message}", e)
                toggleServiceComponent(context, componentName)
            }
        } else {
            toggleServiceComponent(context, componentName)
        }
    }

    private fun toggleServiceComponent(context: Context, componentName: ComponentName) {
        try {
            val pm = context.packageManager
            pm.setComponentEnabledSetting(
                componentName,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            )
            pm.setComponentEnabledSetting(
                componentName,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )
            Log.d("OneNotifyEngine", "Toggled NotificationListenerService component state to force bind")
        } catch (e: Exception) {
            Log.e("OneNotifyEngine", "Failed to toggle service component: ${e.message}", e)
        }
    }
}
