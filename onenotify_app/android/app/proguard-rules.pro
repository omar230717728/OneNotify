# 1. Preserve Flutter Core & Plugin Engine
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.plugins.** { *; }

# 2. Protect OneNotify Native Background Service & SyncBus (CRITICAL)
-keep class com.example.onenotify.** { *; }
-keep class com.onenotify.app.** { *; }
-keepclassmembers class * extends android.app.Service { *; }
-keepclassmembers class * extends android.content.BroadcastReceiver { *; }

# 3. Preserve Firebase Android SDK & Google Play Services
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod

# 4. Protect Native Methods & Drift SQLite Database Bindings
-keepclasseswithmembernames class * {
    native <methods>;
}
-keep class * extends androidx.room.RoomDatabase { *; }
-dontwarn net.sqlcipher.**
-dontwarn com.google.android.play.core.**

