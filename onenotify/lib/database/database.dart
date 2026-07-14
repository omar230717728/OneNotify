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

@DriftDatabase(tables: [Notifications])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
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
