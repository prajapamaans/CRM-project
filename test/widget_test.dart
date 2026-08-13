import 'package:flutter_test/flutter_test.dart';
import 'package:crmproject/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CrmApp());
    await tester.pump(const Duration(seconds: 3));

    // Verify app renders without throwing exception
    expect(find.byType(CrmApp), findsOneWidget);
  });
}
