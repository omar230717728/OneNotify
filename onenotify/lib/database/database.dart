import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

@DataClassName('DbNotification')
class Notifications extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get packageName => text()();
  TextColumn get appName => text().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get message => text().nullable()();
  Int64Column get timestamp => int64()();
}

@DataClassName('DbMonitoredApp')
class MonitoredApps extends Table {
  TextColumn get packageName => text()();
  @override
  Set<Column> get primaryKey => {packageName};
}

@DriftDatabase(tables: [Notifications, MonitoredApps])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          // Pre-seed default popular apps into monitored_apps so new installations immediately track top apps if installed
          for (final pkg in [
            'com.whatsapp',
            'org.telegram.messenger',
            'com.google.android.gm',
            'com.microsoft.office.outlook',
            'com.google.android.youtube',
            'com.google.android.googlequicksearchbox'
          ]) {
            await customInsert(
                'INSERT OR IGNORE INTO monitored_apps (package_name) VALUES (?)',
                variables: [Variable.withString(pkg)]);
          }
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await m.createTable(monitoredApps);
            // Pre-seed existing whitelisted packages during upgrade from v1 -> v2
            for (final pkg in [
              'com.whatsapp',
              'org.telegram.messenger',
              'com.google.android.gm',
              'com.microsoft.office.outlook',
              'com.google.android.youtube',
              'com.google.android.googlequicksearchbox'
            ]) {
              await customInsert(
                  'INSERT OR IGNORE INTO monitored_apps (package_name) VALUES (?)',
                  variables: [Variable.withString(pkg)]);
            }
          }
        },
        beforeOpen: (details) async {
          // Enable foreign key constraints
          await customStatement('PRAGMA foreign_keys = ON;');
          
          // Disable WAL mode and set busy_timeout so both native Kotlin (libsqlite.so) and Dart (libsqlite3.so)
          // read/write directly to the main file header change counter without same-PID POSIX lock/shm conflicts.
          await customStatement('PRAGMA busy_timeout = 5000;');
          await customStatement('PRAGMA journal_mode = DELETE;');
        },
      );

  // Expose a reactive stream of all notifications sorted by timestamp DESC
  Stream<List<DbNotification>> watchAllNotifications() {
    return (select(notifications)
          ..orderBy([
            (t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)
          ]))
        .watch();
  }

  // Delete a specific notification by ID from the Drift database
  Future<int> deleteNotificationById(int id) {
    print("PURGE_PIPELINE: Executing DELETE for notification id=$id");
    return (delete(notifications)..where((t) => t.id.equals(id))).go();
  }

  // Expose a reactive stream of all monitored package names as a Set
  Stream<Set<String>> watchAllMonitoredPackages() {
    return select(monitoredApps).watch().map((list) => list.map((e) => e.packageName).toSet());
  }

  // Get current count of monitored apps (to check onboarding completion)
  Future<int> getMonitoredAppsCount() async {
    final list = await select(monitoredApps).get();
    return list.length;
  }

  // Add a package to monitored_apps
  Future<int> addMonitoredPackage(String packageName) {
    return into(monitoredApps).insert(
      MonitoredAppsCompanion.insert(packageName: packageName),
      mode: InsertMode.insertOrIgnore,
    );
  }

  // Remove a package from monitored_apps
  Future<int> removeMonitoredPackage(String packageName) {
    return (delete(monitoredApps)..where((t) => t.packageName.equals(packageName))).go();
  }
}

QueryExecutor _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationSupportDirectory();
    // Resolve to the parent and target 'files' directly to align with Android filesDir
    final filesDirPath = p.join(dbFolder.parent.path, 'files');
    final file = File(p.join(filesDirPath, 'onenotify.db'));
    
    // Ensure parent directory exists in case it's a fresh run
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    
    print("FLUTTER_DB_PATH: ${file.path}");
    return NativeDatabase.createInBackground(file);
  });
}
