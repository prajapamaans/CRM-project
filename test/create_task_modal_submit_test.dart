import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crmproject/features/activities/presentation/widgets/create_task_modal.dart';

/// Pumps the modal on its own route so Navigator.pop() has somewhere to go.
Future<void> _pumpModal(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(body: CreateTaskModal()),
    ),
  );
  await tester.pump();
}

Finder _createButton() => find.widgetWithText(ElevatedButton, 'Create');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('rejects an empty task name without locking the button',
      (tester) async {
    await _pumpModal(tester);

    await tester.tap(_createButton());
    await tester.pump();

    expect(find.text('Please enter a task name'), findsWidgets);
    // Still tappable — nothing was submitted.
    expect(tester.widget<ElevatedButton>(_createButton()).onPressed, isNotNull);

    // Let the SnackBar time out so no timer outlives the test.
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('a failed create keeps the form open and releases the button',
      (tester) async {
    await _pumpModal(tester);

    await tester.enterText(find.byType(TextField).first, 'Follow up with Acme');
    await tester.pump();

    await tester.tap(_createButton());
    await tester.pump();

    // While in flight: spinner up, button disabled — no double submit.
    final submitting = tester.widget<ElevatedButton>(
      find.byType(ElevatedButton).first,
    );
    expect(submitting.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // The request fails in tests (no backend); the sheet must recover.
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.byType(CreateTaskModal), findsOneWidget);
    expect(_createButton(), findsOneWidget);
    expect(tester.widget<ElevatedButton>(_createButton()).onPressed, isNotNull);
    expect(find.textContaining('Failed to save task'), findsWidgets);
  });
}
