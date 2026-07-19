import 'package:flutter_test/flutter_test.dart';
import 'package:onenotify_web/main.dart';

void main() {
  testWidgets('Web App Smoke Test', (WidgetTester tester) async {
    // Just verify the app widget can be pumped/rendered without immediate crashes
    await tester.pumpWidget(const OneNotifyWebApp());
  });
}
