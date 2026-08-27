import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crmproject/features/activities/presentation/widgets/create_email_modal.dart';

Future<void> _pumpModal(WidgetTester tester, {Map<String, dynamic>? emailToEdit}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: CreateEmailModal(emailToEdit: emailToEdit)),
    ),
  );
  await tester.pump();
}

/// The editable field on the row labelled [label].
Finder _rowField(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byType(Row),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Cc and Bcc are separate links, and no rows show up front',
      (tester) async {
    await _pumpModal(tester);

    expect(find.text('Cc'), findsOneWidget);
    expect(find.text('Bcc'), findsOneWidget);
    // The old build had a single inert 'Cc  Bcc' label.
    expect(find.text('Cc  Bcc'), findsNothing);
    // Only the From/To rows exist until a link is tapped.
    expect(_rowField('Cc'), findsWidgets);
    expect(find.widgetWithText(TextField, ''), findsWidgets);
  });

  testWidgets('tapping Cc opens its own row below To', (tester) async {
    await _pumpModal(tester);

    final fieldsBefore = find.byType(TextField).evaluate().length;

    await tester.tap(find.text('Cc').first);
    await tester.pumpAndSettle();

    // A new input row appeared.
    expect(find.byType(TextField).evaluate().length, fieldsBefore + 1);

    await tester.enterText(
      find.byType(TextField).at(0),
      'someone@example.com',
    );
    await tester.pump();
    expect(find.text('someone@example.com'), findsOneWidget);
  });

  testWidgets('Cc and Bcc open independently', (tester) async {
    await _pumpModal(tester);
    final fieldsBefore = find.byType(TextField).evaluate().length;

    await tester.tap(find.text('Cc').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bcc').first);
    await tester.pumpAndSettle();

    expect(find.byType(TextField).evaluate().length, fieldsBefore + 2);
  });

  testWidgets('tapping Cc again closes its row', (tester) async {
    await _pumpModal(tester);
    final fieldsBefore = find.byType(TextField).evaluate().length;

    await tester.tap(find.text('Cc').first);
    await tester.pumpAndSettle();
    expect(find.byType(TextField).evaluate().length, fieldsBefore + 1);

    await tester.tap(find.text('Cc').first);
    await tester.pumpAndSettle();
    expect(find.byType(TextField).evaluate().length, fieldsBefore);
  });

  testWidgets('an email being edited opens with its Cc and Bcc filled in',
      (tester) async {
    await _pumpModal(tester, emailToEdit: const {
      'id': 'email-1',
      'subject': 'Quarterly check-in',
      'cc': 'cc-one@example.com, cc-two@example.com',
      // The API may hand back a list instead of a string.
      'bcc': ['bcc@example.com'],
    });
    await tester.pumpAndSettle();

    expect(find.text('cc-one@example.com, cc-two@example.com'), findsOneWidget);
    expect(find.text('bcc@example.com'), findsOneWidget);
  });
}
