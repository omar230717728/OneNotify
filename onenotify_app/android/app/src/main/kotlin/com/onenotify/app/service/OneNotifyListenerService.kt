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
import com.google.firebase.FirebaseApp
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.FieldValue
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.util.Base64
import java.io.ByteArrayOutputStream
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
        try {
            if (FirebaseApp.getApps(this).isEmpty()) {
                FirebaseApp.initializeApp(this)
                Log.d("OneNotifyEngine", "LOG 1: FirebaseApp initialized natively in onCreate")
            }
        } catch (e: Exception) {
            Log.e("OneNotifyEngine", "LOG 1 ERROR: Failed to initialize FirebaseApp natively in onCreate: ${e.message}", e)
        }
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

            // Trigger native background Firestore sync
            syncToFirestoreNatively(rowId, packageName, appName, title, text, timestamp)

            // Update persistent silent inbox counter
            unreadCount++
            updateInboxNotification()

            // 14-day automatic expiration cleanup
            try {
                val cutoff = System.currentTimeMillis() - (14L * 24 * 60 * 60 * 1000)
                val expiredIds = mutableListOf<Long>()
                val selectExpiredQuery = "SELECT id FROM notifications WHERE timestamp < ?"
                val cursor = db.rawQuery(selectExpiredQuery, arrayOf(cutoff.toString()))
                if (cursor != null) {
                    while (cursor.moveToNext()) {
                        expiredIds.add(cursor.getLong(0))
                    }
                    cursor.close()
                }

                if (expiredIds.isNotEmpty()) {
                    // Delete from local SQLite
                    val idPlaceholders = expiredIds.joinToString(",") { "?" }
                    val deleteQuery = "DELETE FROM notifications WHERE id IN ($idPlaceholders)"
                    val bindArgs = expiredIds.map { it.toString() }.toTypedArray()
                    db.execSQL(deleteQuery, bindArgs)
                    Log.d("OneNotifyEngine", "Kotlin Service: Expired ${expiredIds.size} records older than 14 days locally.")

                    // Delete from Firestore
                    val sharedPref = applicationContext.getSharedPreferences("OneNotifyPrefs", Context.MODE_PRIVATE)
                    val uid = sharedPref.getString("firebase_uid", null)
                    if (!uid.isNullOrEmpty()) {
                        val firestore = FirebaseFirestore.getInstance()
                        for (expiredId in expiredIds) {
                            firestore.collection("users")
                                .document(uid)
                                .collection("notifications")
                                .document(expiredId.toString())
                                .delete()
                                .addOnSuccessListener {
                                    Log.d("OneNotifyEngine", "NATIVE_CLOUDSYNC: Successfully deleted expired notification $expiredId from Firestore")
                                }
                                .addOnFailureListener { e ->
                                    Log.e("OneNotifyEngine", "NATIVE_CLOUDSYNC ERROR: Failed to delete expired notification $expiredId: ${e.message}")
                                }
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e("OneNotifyEngine", "Kotlin Service ERROR: Failed to auto-purge 14-day expired notifications: ${e.message}", e)
            }

            // Prune older notifications for this package to prevent database bloat (keep 20 newest)
            try {
                val idsToPrune = mutableListOf<Long>()
                val selectPruneQuery = """
                    SELECT id FROM notifications 
                    WHERE package_name = ? 
                    AND id NOT IN (
                        SELECT id FROM notifications 
                        WHERE package_name = ? 
                        ORDER BY timestamp DESC 
                        LIMIT 20
                    )
                """.trimIndent()
                val cursor = db.rawQuery(selectPruneQuery, arrayOf(packageName, packageName))
                if (cursor != null) {
                    while (cursor.moveToNext()) {
                        idsToPrune.add(cursor.getLong(0))
                    }
                    cursor.close()
                }

                if (idsToPrune.isNotEmpty()) {
                    // Delete from local SQLite
                    val idPlaceholders = idsToPrune.joinToString(",") { "?" }
                    val deleteQuery = "DELETE FROM notifications WHERE id IN ($idPlaceholders)"
                    val bindArgs = idsToPrune.map { it.toString() }.toTypedArray()
                    db.execSQL(deleteQuery, bindArgs)
                    Log.d("OneNotifyEngine", "Kotlin Service: Pruned ${idsToPrune.size} records locally for package $packageName.")

                    // Delete from Firestore
                    val sharedPref = applicationContext.getSharedPreferences("OneNotifyPrefs", Context.MODE_PRIVATE)
                    val uid = sharedPref.getString("firebase_uid", null)
                    if (!uid.isNullOrEmpty()) {
                        val firestore = FirebaseFirestore.getInstance()
                        for (purgedId in idsToPrune) {
                            firestore.collection("users")
                                .document(uid)
                                .collection("notifications")
                                .document(purgedId.toString())
                                .delete()
                                .addOnSuccessListener {
                                    Log.d("OneNotifyEngine", "NATIVE_CLOUDSYNC: Successfully deleted pruned notification $purgedId from Firestore")
                                }
                                .addOnFailureListener { e ->
                                    Log.e("OneNotifyEngine", "NATIVE_CLOUDSYNC ERROR: Failed to delete pruned notification $purgedId: ${e.message}")
                                }
                        }
                    }
                }
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

    private fun syncToFirestoreNatively(
        rowId: Long,
        packageName: String,
        appName: String?,
        title: String,
        text: String,
        timestamp: Long
    ) {
        try {
            // Initialize Firebase natively if not already initialized (e.g. after system boot)
            if (FirebaseApp.getApps(applicationContext).isEmpty()) {
                FirebaseApp.initializeApp(applicationContext)
                Log.d("OneNotifyEngine", "NATIVE_CLOUDSYNC: Initialized FirebaseApp natively")
            }

            val sharedPref = applicationContext.getSharedPreferences("OneNotifyPrefs", Context.MODE_PRIVATE)
            val uid = sharedPref.getString("firebase_uid", null)
            if (uid.isNullOrEmpty()) {
                Log.d("OneNotifyEngine", "NATIVE_CLOUDSYNC: No cached Firebase UID found in SharedPreferences. Skipping sync.")
                return
            }

            // Sync app config / icon if not already done
            val cachedIcons = sharedPref.getStringSet("uploaded_icons", setOf()) ?: setOf()
            if (!cachedIcons.contains(packageName)) {
                syncAppConfigNatively(uid, packageName)
            }

            val firestore = FirebaseFirestore.getInstance()
            val docId = rowId.toString()

            val notificationData = hashMapOf(
                "id" to rowId,
                "packageName" to packageName,
                "appName" to appName,
                "title" to title,
                "message" to text,
                "localTimestamp" to timestamp,
                "timestamp" to FieldValue.serverTimestamp()
            )

            Log.d("OneNotifyEngine", "NATIVE_CLOUDSYNC: Uploading notification $docId for user $uid")

            firestore.collection("users")
                .document(uid)
                .collection("notifications")
                .document(docId)
                .set(notificationData)
                .addOnSuccessListener {
                    try {
                        Log.d("OneNotifyEngine", "NATIVE_CLOUDSYNC: Successfully synced notification $docId to Firestore")
                        // Prune Firestore to match local cap (keep 20 newest per package)
                        pruneFirestoreCollection(uid, packageName)
                    } catch (e: Exception) {
                        Log.e("OneNotifyEngine", "NATIVE_CLOUDSYNC ERROR: Exception inside sync success callback: ${e.message}", e)
                    }
                }
                .addOnFailureListener { e ->
                    Log.e("OneNotifyEngine", "NATIVE_CLOUDSYNC ERROR: Failed to sync to Firestore: ${e.message}", e)
                }

        } catch (e: Exception) {
            Log.e("OneNotifyEngine", "NATIVE_CLOUDSYNC ERROR: Exception in native sync: ${e.message}", e)
        }
    }

    private fun pruneFirestoreCollection(uid: String, targetPackage: String) {
        try {
            val firestore = FirebaseFirestore.getInstance()
            firestore.collection("users")
                .document(uid)
                .collection("notifications")
                .get()
                .addOnSuccessListener { querySnapshot ->
                    try {
                        val docs = querySnapshot.documents
                        // Group by packageName
                        val groups = docs.groupBy { it.getString("packageName") ?: "" }
                        for ((pkg, groupDocs) in groups) {
                            if (pkg != targetPackage) continue
                            // Sort by localTimestamp DESC
                            val sortedDocs = groupDocs.sortedByDescending { it.getLong("localTimestamp") ?: 0L }
                            if (sortedDocs.size > 20) {
                                for (i in 20 until sortedDocs.size) {
                                    sortedDocs[i].reference.delete()
                                        .addOnSuccessListener {
                                            Log.d("OneNotifyEngine", "NATIVE_CLOUDSYNC: Pruned remote doc ${sortedDocs[i].id} for package $pkg")
                                        }
                                        .addOnFailureListener { e ->
                                            Log.e("OneNotifyEngine", "NATIVE_CLOUDSYNC ERROR: Failed to prune remote doc: ${e.message}")
                                        }
                                }
                            }
                        }
                    } catch (e: Exception) {
                        Log.e("OneNotifyEngine", "NATIVE_CLOUDSYNC ERROR: Exception inside prune success callback: ${e.message}", e)
                    }
                }
        } catch (e: Exception) {
            Log.e("OneNotifyEngine", "NATIVE_CLOUDSYNC ERROR: Exception in Firestore pruning: ${e.message}", e)
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

    private fun syncAppConfigNatively(uid: String, packageName: String) {
        try {
            val pm = applicationContext.packageManager
            val appIcon = pm.getApplicationIcon(packageName)
            val (base64Icon, dominantColor) = convertDrawableToBase64(appIcon)

            val configData = hashMapOf(
                "packageName" to packageName,
                "iconBase64" to base64Icon,
                "dominantColor" to dominantColor
            )

            val firestore = FirebaseFirestore.getInstance()
            firestore.collection("users")
                .document(uid)
                .collection("app_configs")
                .document(packageName)
                .set(configData)
                .addOnSuccessListener {
                    try {
                        val sharedPref = applicationContext.getSharedPreferences("OneNotifyPrefs", Context.MODE_PRIVATE)
                        val cachedIcons = sharedPref.getStringSet("uploaded_icons", setOf()) ?: setOf()
                        val newCachedIcons = cachedIcons.toMutableSet()
                        newCachedIcons.add(packageName)
                        sharedPref.edit().putStringSet("uploaded_icons", newCachedIcons).apply()
                        Log.d("OneNotifyEngine", "NATIVE_CLOUDSYNC: Uploaded app config/icon for $packageName")
                    } catch (e: Exception) {
                        Log.e("OneNotifyEngine", "NATIVE_CLOUDSYNC ERROR: Failed to save cached icon state: ${e.message}")
                    }
                }
                .addOnFailureListener { e ->
                    Log.e("OneNotifyEngine", "NATIVE_CLOUDSYNC ERROR: Failed to upload app config: ${e.message}")
                }
        } catch (e: Exception) {
            Log.e("OneNotifyEngine", "NATIVE_CLOUDSYNC ERROR: Exception syncAppConfigNatively for $packageName: ${e.message}", e)
        }
    }

    private fun convertDrawableToBase64(drawable: Drawable): Pair<String, String> {
        val bitmap = if (drawable is BitmapDrawable) {
            drawable.bitmap
        } else {
            val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 48
            val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 48
            val b = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(b)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            b
        }

        // Scale to exactly 48x48
        val scaledBitmap = Bitmap.createScaledBitmap(bitmap, 48, 48, true)
        
        // Extract dominant color
        val hexColor = getDominantColor(scaledBitmap)

        // Compress to PNG
        val outputStream = ByteArrayOutputStream()
        scaledBitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
        val bytes = outputStream.toByteArray()
        
        // Encode to Base64
        val base64String = Base64.encodeToString(bytes, Base64.NO_WRAP)
        
        return Pair(base64String, hexColor)
    }

    private fun getDominantColor(bitmap: Bitmap): String {
        val smallBitmap = Bitmap.createScaledBitmap(bitmap, 10, 10, false)
        var sumRed = 0
        var sumGreen = 0
        var sumBlue = 0
        var count = 0
        for (x in 0 until 10) {
            for (y in 0 until 10) {
                val color = smallBitmap.getPixel(x, y)
                val alpha = (color shr 24) and 0xff
                // Skip highly transparent pixels
                if (alpha > 100) {
                    sumRed += (color shr 16) and 0xff
                    sumGreen += (color shr 8) and 0xff
                    sumBlue += color and 0xff
                    count++
                }
            }
        }
        val avgRed = if (count > 0) sumRed / count else 128
        val avgGreen = if (count > 0) sumGreen / count else 128
        val avgBlue = if (count > 0) sumBlue / count else 128
        return String.format("#%02X%02X%02X", avgRed, avgGreen, avgBlue)
    }
}
