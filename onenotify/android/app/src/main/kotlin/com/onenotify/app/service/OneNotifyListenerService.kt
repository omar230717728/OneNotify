package com.onenotify.app.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import com.onenotify.app.SyncBus
import java.io.File

class OneNotifyListenerService : NotificationListenerService() {

    private val SYSTEM_BLACKLIST = setOf(
        "android",
        "com.android.systemui",
        "com.android.settings",
        "com.google.android.inputmethod.latin",
        "com.android.providers.downloads",
        "com.google.android.apps.messaging"
    )

    companion object {
        const val INBOX_CHANNEL_ID = "silent_inbox_channel"
        const val INBOX_NOTIFICATION_ID = 1001
        var unreadCount: Int = 0

        fun resetInboxCounter(context: Context) {
            unreadCount = 0
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            notificationManager?.cancel(INBOX_NOTIFICATION_ID)
            Log.d("OneNotifyEngine", "LOG 1: Reset silent inbox counter and cancelled persistent notification 1001")
        }
    }

    override fun onCreate() {
        super.onCreate()
        createInboxNotificationChannel()
    }

    private fun createInboxNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Silent Inbox Tracker"
            val descriptionText = "Persistent unread notification summary for OneNotify"
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(INBOX_CHANNEL_ID, name, importance).apply {
                description = descriptionText
                setShowBadge(true)
            }
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager?.createNotificationChannel(channel)
            Log.d("OneNotifyEngine", "LOG 1: Created silent inbox channel ($INBOX_CHANNEL_ID)")
        }
    }

    private fun updateInboxNotification() {
        try {
            val intent = Intent(this, com.example.onenotify.MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            }
            val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val pendingIntent = PendingIntent.getActivity(this, 0, intent, pendingIntentFlags)

            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, INBOX_CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(this)
            }

            val notification = builder
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle("OneNotify Active")
                .setContentText("📥 $unreadCount Unread Messages")
                .setOnlyAlertOnce(true)
                .setOngoing(false)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .build()

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            notificationManager?.notify(INBOX_NOTIFICATION_ID, notification)
            Log.d("OneNotifyEngine", "LOG 1: Updated silent inbox notification — unreadCount = $unreadCount")
        } catch (e: Exception) {
            Log.e("OneNotifyEngine", "Error posting inbox notification: ${e.message}")
        }
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d("OneNotifyEngine", "LOG 0: OneNotifyListenerService connected and active")
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.d("OneNotifyEngine", "LOG 0: OneNotifyListenerService disconnected")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)

        if (sbn == null) return

        val packageName = sbn.packageName

        // Filter: Silently drop system notifications from blacklist
        if (SYSTEM_BLACKLIST.contains(packageName)) {
            Log.d("OneNotifyFilter", "Silently dropping system notification from: $packageName")
            return
        }

        // Log 1: Notification captured
        Log.d("OneNotifyEngine", "LOG 1: Intercepted notification from package: $packageName")
        
        // Filter: Discard anything not in the monitored_apps table early
        val status = getMonitoredStatus(packageName)
        if (!status.isMonitored) {
            Log.d("OneNotifyEngine", "LOG 1: SKIPPED — package not in monitored_apps table: $packageName")
            return
        }

        val extras = sbn.notification?.extras
        val title = extras?.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        
        // Extract the most detailed text (supporting InboxStyle EXTRA_TEXT_LINES and BigTextStyle)
        var text = extras?.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        val textLines = extras?.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
        if (!textLines.isNullOrEmpty()) {
            val linesString = textLines.joinToString("\n") { it.toString() }
            if (linesString.isNotBlank()) {
                text = linesString
            }
        } else {
            val bigText = extras?.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
            if (!bigText.isNullOrBlank() && bigText != text) {
                text = bigText
            }
        }
        val timestamp = sbn.postTime

        Log.d("OneNotifyEngine", "LOG 1: Allowed notification — title='$title', text='$text', timestamp=$timestamp")

        // Push to shared SQLite database
        insertNotificationToDb(packageName, title, text, timestamp)

        // If Auto-Dismiss (Mute) is enabled for this tracked app, instantly cancel the notification from the Android status bar
        if (status.isMuted) {
            try {
                cancelNotification(sbn.key)
                Log.d("OneNotifyEngine", "LOG 1: AUTO-DISMISSED — wiped notification from status bar for muted package: $packageName")
            } catch (e: Exception) {
                Log.e("OneNotifyEngine", "Error cancelling notification for $packageName: ${e.message}")
            }
        }
    }

    private fun insertNotificationToDb(packageName: String, title: String, text: String, timestamp: Long) {
        var db: SQLiteDatabase? = null
        try {
            val dbFile = File(applicationContext.filesDir, "onenotify.db")
            
            // Ensure the directory exists
            if (!dbFile.parentFile.exists()) {
                dbFile.parentFile.mkdirs()
            }

            Log.d("OneNotifyEngine", "LOG 2: KOTLIN_DB_PATH: " + dbFile.absolutePath)

            // Open or create database
            db = SQLiteDatabase.openOrCreateDatabase(dbFile, null)
            
            // Disable Write-Ahead Logging (WAL) to prevent same-PID POSIX shm/lock conflicts across libsqlite.so and libsqlite3.so.
            // Instead, set busy timeout and DELETE journal mode so both engines coordinate via the file change counter.
            db.rawQuery("PRAGMA busy_timeout = 5000;", null).close()
            db.rawQuery("PRAGMA journal_mode = DELETE;", null).close()

            // Self-healing schema definition: Ensure notifications table matches Drift's definition
            db.execSQL("""
                CREATE TABLE IF NOT EXISTS notifications (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    package_name TEXT NOT NULL,
                    app_name TEXT,
                    title TEXT,
                    message TEXT,
                    timestamp INTEGER NOT NULL
                );
            """.trimIndent())

            // Resolve app user-facing name using PackageManager
            val appName = try {
                val pm = packageManager
                val ai = pm.getApplicationInfo(packageName, 0)
                pm.getApplicationLabel(ai).toString()
            } catch (e: Exception) {
                null
            }

            val values = ContentValues().apply {
                put("package_name", packageName)
                put("app_name", appName)
                put("title", title)
                put("message", text)
                put("timestamp", timestamp)
            }

            // Deduplication check: skip if the most recent record for this package has identical title and message
            try {
                val checkCursor = db.rawQuery(
                    "SELECT title, message FROM notifications WHERE package_name = ? ORDER BY timestamp DESC LIMIT 1",
                    arrayOf(packageName)
                )
                if (checkCursor.moveToFirst()) {
                    val lastTitle = checkCursor.getString(0) ?: ""
                    val lastMessage = checkCursor.getString(1) ?: ""
                    if (lastTitle == title && lastMessage == text) {
                        checkCursor.close()
                        Log.d("OneNotifyEngine", "LOG 2: SKIPPED duplicate notification insertion for $packageName (title='$title')")
                        return
                    }
                }
                checkCursor.close()
            } catch (e: Exception) {
                // Safe fallthrough if table is empty or check fails
            }

            // Using insertOrThrow to catch detailed constraint/syntax errors in our try-catch block
            val rowId = db.insertOrThrow("notifications", null, values)
            Log.d("OneNotifyEngine", "LOG 2: Successfully wrote notification to SQLite. Row ID: $rowId")

            // Update persistent silent inbox counter
            unreadCount++
            updateInboxNotification()

            // Prune older notifications for this package to prevent database bloat (keep 20 newest)
            try {
                val pruneQuery = """
                    DELETE FROM notifications 
                    WHERE package_name = ? 
                    AND id NOT IN (
                        SELECT id FROM notifications 
                        WHERE package_name = ? 
                        ORDER BY timestamp DESC 
                        LIMIT 20
                    )
                """.trimIndent()
                db.execSQL(pruneQuery, arrayOf(packageName, packageName))
                Log.d("OneNotifyEngine", "Kotlin Service: Pruned database for package $packageName to keep only the 20 newest records.")
            } catch (e: Exception) {
                Log.e("OneNotifyEngine", "Kotlin Service ERROR: Failed to prune notifications for package $packageName: ${e.message}", e)
            }

            // Log 3: SyncBus dispatch
            Log.d("OneNotifyEngine", "LOG 3: Attempting to invoke SyncBus.onDatabaseUpdated callback...")
            val callback = SyncBus.onDatabaseUpdated
            if (callback != null) {
                callback.invoke()
                Log.d("OneNotifyEngine", "LOG 3: SyncBus.onDatabaseUpdated invoked SUCCESSFULLY")
            } else {
                Log.d("OneNotifyEngine", "LOG 3 ERROR: SyncBus.onDatabaseUpdated is NULL! Flutter activity may not be running.")
            }
        } catch (e: android.database.sqlite.SQLiteException) {
            Log.e("OneNotifyEngine", "LOG 2 ERROR: SQLite Error: ", e)
        } catch (e: Exception) {
            Log.e("OneNotifyEngine", "LOG 2 ERROR: Exception in background writer: ${e.message}", e)
        } finally {
            db?.close()
        }
    }

    data class MonitoredStatus(val isMonitored: Boolean, val isMuted: Boolean)

    private fun getMonitoredStatus(packageName: String): MonitoredStatus {
        var db: SQLiteDatabase? = null
        var cursor: android.database.Cursor? = null
        try {
            val dbFile = File(applicationContext.filesDir, "onenotify.db")
            if (!dbFile.exists()) return MonitoredStatus(false, false)
            db = SQLiteDatabase.openDatabase(dbFile.absolutePath, null, SQLiteDatabase.OPEN_READONLY)
            cursor = db.rawQuery("SELECT is_muted FROM monitored_apps WHERE package_name = ? LIMIT 1", arrayOf(packageName))
            if (cursor != null && cursor.moveToFirst()) {
                val isMutedIndex = cursor.getColumnIndex("is_muted")
                val isMuted = if (isMutedIndex != -1) cursor.getInt(isMutedIndex) == 1 else false
                return MonitoredStatus(true, isMuted)
            }
            return MonitoredStatus(false, false)
        } catch (e: Exception) {
            Log.e("OneNotifyEngine", "Error checking monitored_apps for $packageName: ${e.message}")
            return MonitoredStatus(false, false)
        } finally {
            cursor?.close()
            db?.close()
        }
    }

    private fun isPackageMonitored(packageName: String): Boolean {
        return getMonitoredStatus(packageName).isMonitored
    }
}
