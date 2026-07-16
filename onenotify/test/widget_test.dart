import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:onenotify/database/database.dart';
import 'package:onenotify/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Timeline screen displays empty state smoke test', (WidgetTester tester) async {
    // Mock the MethodChannel for permissions and system sync
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.example.onenotify/sync'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'isListenerPermissionGranted') {
          return true;
        }
        return null;
      },
    );

    // Initialize in-memory database for testing
    final db = AppDatabase(NativeDatabase.memory());

    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(database: db));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify that the empty state is displayed
    expect(find.text('Silent Hub'), findsOneWidget);
    expect(find.textContaining('No important notifications captured yet.'), findsOneWidget);

    // Clean up
    await db.close();
  });
}
