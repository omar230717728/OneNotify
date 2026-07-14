package com.onenotify.app

/**
 * SyncBus is a lightweight, in-memory event bus for same-process communication.
 *
 * Since OneNotifyListenerService and MainActivity run in the same JVM process
 * (no android:process attribute in the manifest), they share the same static
 * memory space. This allows us to bypass the unreliable Android BroadcastReceiver
 * system entirely and use a direct function callback for real-time signaling.
 *
 * Usage:
 *   - MainActivity registers a listener: SyncBus.onDatabaseUpdated = { ... }
 *   - OneNotifyListenerService fires it:  SyncBus.onDatabaseUpdated?.invoke()
 *   - MainActivity clears it on destroy:  SyncBus.onDatabaseUpdated = null
 */
object SyncBus {
    /**
     * Callback invoked by the NotificationListenerService after a successful
     * database write. MainActivity sets this to forward the event to Flutter
     * via MethodChannel. Null when no activity is attached.
     */
    var onDatabaseUpdated: (() -> Unit)? = null
}
