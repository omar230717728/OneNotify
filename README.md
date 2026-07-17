# OneNotify

OneNotify is a high-reliability Android notification tracking application. It features a native Kotlin background service for low-level system notification interception and a cross-platform Flutter presentation layer for rendering, filtering, and managing notification history.

This document serves as the official QA and automated testing playbook (optimized for test suites like **testsprite**). It specifies the under-the-hood architecture, data persistence layers, IPC contracts, and step-by-step execution scripts.

---

## 📋 Features & Capabilities

* **Onboarding Permission Gates:** Locks down features and prompts for Android system settings permissions if Notification Access is not granted.
* **Battery Optimization Survival:** Requests Android battery settings exclusions to guarantee background service continuity when screen is locked or idle.
* **System Noise Filter:** Blacklists core Android telemetry packages to prevent system notifications cluttering the timeline.
* **Prune on Write Policy:** Limits notification storage to a maximum of 20 entries per application package name to prevent database bloat.
* **Auto-Purge Housekeeping:** Automatically wipes database entries older than 14 days upon application boot.
* **Dynamic Localization:** Supports full English LTR, Turkish LTR, and Arabic RTL layout mirroring, including dynamic ICU plural count formats.

---

## ⚙️ Deep Technical Architecture Spec

```
      +-------------------------------------------------------+
      |                  Android OS Notification              |
      +---------------------------+---------------------------+
                                  | (System Interception)
                                  v
      +-------------------------------------------------------+
      |             OneNotifyListenerService                  |  <--- (Native Kotlin Engine)
      +---------------------------+---------------------------+
                                  |
                                  +--> deduplicates & applies blacklists
                                  |
                                  +--> database.insertOrThrow()
                                  |    (Journal Mode: DELETE, Timeout: 5000ms)
                                  |
                                  v
                     +--------------------------+
                     |  Shared onenotify.db     |
                     +------------+-------------+
                                  ^
                                  | (Reactive Queries / Streams)
                                  |
      +---------------------------+---------------------------+
      |                        SyncBus                        |  <--- (In-Memory Kotlin Singleton)
      +---------------------------+---------------------------+
                                  |
                                  v (MainActivity.onCreate / Handler)
      +-------------------------------------------------------+
      |                     MethodChannel                     |  <--- (com.example.onenotify/sync)
      +---------------------------+---------------------------+
                                  |
                                  v (refresh signal)
      +-------------------------------------------------------+
      |                 Flutter Presentation                  |  <--- (Dart / Drift Database UI)
      +-------------------------------------------------------+
```

### 1. The Shared Data Layer (SQLite + Drift)
The application utilizes a shared SQLite database file accessed concurrently by two separate runtime environments in the same process:
* **Write Path (Kotlin):** The background service (`OneNotifyListenerService.kt`) writes intercepted notifications directly using native Android `SQLiteDatabase` APIs.
* **Read/Delete Path (Dart):** The Flutter UI reads, streams, and deletes notifications using the `drift` reactive query builder.

#### ⚠️ POSIX Locking & Journal Configuration
To prevent same-PID shared memory (`.shm`) conflicts and POSIX file lock clashes between the native JVM library (`libsqlite.so`) and the Dart library (`libsqlite3.so`), the database is configured with:
* **Journal Mode:** Explicitly set to `DELETE` (PRAGMA `journal_mode = DELETE`). Write-Ahead Logging (WAL) is disabled to prevent background thread lockouts.
* **Busy Timeout:** Configured to `5000` milliseconds on both ends to queue concurrent operations cleanly.
* **Database File Path:** `/data/data/com.example.onenotify/files/onenotify.db` (Mapped to Kotlin's `context.filesDir` and Dart's resolved parent folder).

### 2. The Inter-Process Communication (IPC) & Real-Time Sync
Because both engines run in different execution bounds (the native background process container vs. the Dart VM isolate thread pool), real-time UI synchronization bypasses system broadcasts (which can be deferred by Android doze rules) in favor of a direct memory bridge:
1. **Database Update Signal:** After a successful SQLite database insert, the native background service calls `SyncBus.onDatabaseUpdated?.invoke()`.
2. **SyncBus Callback Registry:** `SyncBus` is a Kotlin singleton object that bridges callbacks to the `MainActivity` instance.
3. **UI Thread Dispatcher:** The `MainActivity` captures the event, wraps it in `Handler(Looper.getMainLooper()).post` to ensure thread safety, and forwards it to Flutter via a `MethodChannel` call.
4. **Dart Cache Invalidation:** The Flutter timeline screen receives the `'refresh'` call and triggers `notifyUpdates()` on the Drift database instance to re-emit fresh streams.

---

## 🛡️ Business Logic & Data Constraints

QA suites should validate system behavior against the following strict constraints:
1. **Deduplication Check:** Native Kotlin code checks the most recent notification for the package. If both the `title` and `message` match the incoming notification, the write is skipped.
2. **System Noise Blacklist:** Notifications originating from the following package names must be silently dropped:
   * `android`
   * `com.android.systemui`
   * `com.android.settings`
   * `com.google.android.inputmethod.latin`
   * `com.android.providers.downloads`
   * `com.google.android.apps.messaging`
3. **Prune on Write Policy:** Every successful insertion triggers a clean-up query keeping only the **20 most recent** records per app package name.
4. **Housekeeping Guard:** Upon booting the timeline screen, an auto-purge query deletes all database rows where `timestamp` is older than **14 days**.

---

## 🔌 MethodChannel API Matrix

The platform communications are handled via the channel identifier **`com.example.onenotify/sync`**. Below is the API matrix defining the expectations for mock engines and test suites:

| Method String | Arguments | Returns | Native Action |
| :--- | :--- | :--- | :--- |
| `isListenerPermissionGranted` | None | `Boolean` | Checks Android system settings (`enabled_notification_listeners`) for service approval. |
| `requestListenerPermission` | None | `Boolean` | Fires an Activity Intent to open Android's Special Access Notification settings screen. |
| `requestRebindService` | None | `Boolean` | Re-binds the `NotificationListenerService` handler dynamically to force background activation. |
| `isIgnoringBatteryOptimizations` | None | `Boolean` | Checks if the application is whitelisted under Android OS Power Manager restrictions. |
| `requestIgnoreBatteryOptimizations` | None | `Boolean` | Triggers a prompt to exempt the app from battery limits. Falls back to settings intents on OEMs. |
| `openBatteryOptimizationSettings` | None | `Boolean` | Opens the Android Power optimization list directly for manual whitelisting. |

*Note: App launching from timeline cards is handled on the Dart side using the `flutter_device_apps` library via `FlutterDeviceApps.openApp(packageName)`.*

---

## 🧪 E2E Testing & Simulation Playbook

### 1. Simulating Notifications via ADB
You can push mock notification events directly to the Android System notification queue using `adb shell cmd notification`. The background interception engine will capture it only if the package name is whitelisted in `monitored_apps`.

```bash
# Step 1: Ensure the app is whitelisted (run inside app UI or insert directly into database)
# Step 2: Fire simulated notification into the status bar queue:
adb shell cmd notification post -s "TestTag" "com.whatsapp" "John Doe" "Hey! This is a test message"
```

### 2. UI State Verification Matrix
* **Accordion States:** Check list components. When a package header card is tapped, list expansion is toggled (`_expandedPackages`). Verify that tapping exposes the child message list.
* **Notification Count Badge:** Verify that counts match the ICU plural syntax rules:
  * **English:** `=1{1 notification} other{{count} notifications}`
  * **Turkish:** `=1{1 bildirim} other{{count} bildirim}`
  * **Arabic:** `=1{إشعار واحد} =2{إشعاران} few{{count} إشعارات} other{{count} إشعار}`
* **Swiping Interactivity (Swipe-To-Dismiss):**
  * **Child Card Swipe:** Swiping a child message card deletes that specific row (`deleteNotificationById`). Verify that the item list animations trigger and database count decreases by 1.
  * **Parent Header Swipe:** Swiping the main package card runs a query removing all rows matching the package name. Verify that the whole accordion category disappears and all rows are removed.
* **Localization Check:** Set system language to Arabic. Verify:
  * Layout flow changes from LTR to RTL.
  * Icons (like arrow_forward/expand_more) point in RTL direction.
  * Spacers and margins match dynamic `EdgeInsetsDirectional` configurations.

---

## 📂 Directory Map & Setup

### Folder Tree
```
onenotify/
├── l10n.yaml                   # Localization compile config
├── pubspec.yaml                # App dependencies and setup
├── lib/
│   ├── main.dart               # Entry point
│   ├── database/
│   │   ├── database.dart       # Drift schema & PRAGMA configurations
│   │   └── database.g.dart     # Generated SQLite entities
│   ├── l10n/
│   │   ├── app_en.arb          # English translations
│   │   ├── app_tr.arb          # Turkish translations
│   │   ├── app_ar.arb          # Arabic translations
│   │   └── app_localizations.dart # Generated localization class
│   └── presentation/
│       ├── main_navigation_holder.dart    # App scaffolding, PopScope back gate
│       ├── notification_timeline_screen.dart # Main timeline interface, swipe dismissals
│       ├── onboarding_permission_screen.dart # Setup onboarding steps UI
│       └── tracked_apps_screen.dart       # App whitelist options
└── android/
    └── app/src/main/kotlin/
        ├── com/example/onenotify/
        │   └── MainActivity.kt            # Platform channels handler
        └── com/onenotify/app/
            ├── SyncBus.kt                 # Decoupled callback manager
            └── service/
                ├── BootReceiver.kt        # System boot startup
                └── OneNotifyListenerService.kt # Native interception engine
```

### Environment Execution
To trigger generation scripts and run the application:

```powershell
# 1. Resolve Dart dependencies
# (run inside directory /onenotify)
flutter pub get

# 2. Build localizations and database schemas
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs

# 3. Launch unit tests
flutter test

# 4. Build/run application
flutter run
```
