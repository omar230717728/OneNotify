import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:onenotify/database/database.dart';
import 'package:onenotify/main.dart';

void main() {
  testWidgets('Timeline screen displays empty state smoke test', (WidgetTester tester) async {
    // Initialize in-memory database for testing
    final db = AppDatabase(NativeDatabase.memory());

    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(database: db));

    // Verify that the empty state is displayed
    expect(find.text('Silent Hub'), findsOneWidget);
    expect(find.text('No important notifications captured yet.'), findsOneWidget);

    // Clean up
    await db.close();
  });
}
