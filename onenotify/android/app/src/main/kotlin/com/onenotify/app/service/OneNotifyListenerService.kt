package com.onenotify.app.service

import android.app.Notification
import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import com.onenotify.app.SyncBus
import java.io.File

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

        // Log 1: Notification captured
        Log.d("OneNotifyEngine", "LOG 1: Intercepted notification from package: $packageName")
        
        // Filter: Discard anything not in the whitelist early
        if (!allowedPackages.contains(packageName)) {
            Log.d("OneNotifyEngine", "LOG 1: SKIPPED — package not in whitelist: $packageName")
            return
        }

        val extras = sbn.notification?.extras
        val title = extras?.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = extras?.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        val timestamp = sbn.postTime

        Log.d("OneNotifyEngine", "LOG 1: Allowed notification — title='$title', text='$text', timestamp=$timestamp")

        // Push to shared SQLite database
        insertNotificationToDb(packageName, title, text, timestamp)
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

            // Using insertOrThrow to catch detailed constraint/syntax errors in our try-catch block
            val rowId = db.insertOrThrow("notifications", null, values)
            Log.d("OneNotifyEngine", "LOG 2: Successfully wrote notification to SQLite. Row ID: $rowId")

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
}
