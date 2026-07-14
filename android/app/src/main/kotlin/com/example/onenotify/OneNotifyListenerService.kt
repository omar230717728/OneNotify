package com.example.onenotify

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class OneNotifyListenerService : NotificationListenerService() {

    // Whitelist of packages allowed to be intercepted
    private val allowedPackages = setOf(
        "com.whatsapp",
        "org.telegram.messenger",
        "com.google.android.gm",
        "com.microsoft.office.outlook"
    )

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d("OneNotifyEngine", "OneNotifyListenerService connected and active")
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.d("OneNotifyEngine", "OneNotifyListenerService disconnected")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)

        if (sbn == null) return

        val packageName = sbn.packageName
        
        // Filter: Discard anything not in the whitelist early
        if (!allowedPackages.contains(packageName)) {
            return
        }

        val extras = sbn.notification?.extras
        val title = extras?.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = extras?.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        val timestamp = sbn.postTime

        Log.d("OneNotifyEngine", buildLogMessage(packageName, title, text, timestamp))
    }

    private fun buildLogMessage(packageName: String, title: String, text: String, timestamp: Long): String {
        return """
            [Notification Captured]
            Package Name: $packageName
            Title: $title
            Text Content: $text
            Timestamp: $timestamp
        """.trimIndent()
    }
}
