import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crmproject/core/utils/follow_up_schedule.dart';
import 'package:crmproject/features/dashboard/presentation/widgets/follow_up_task_dialog.dart';

/// Opens the popup the way completing a task from the Dashboard opens it, and
/// hands back whatever it answered with.
Future<FollowUpTaskChoice?> _openDialog(
  WidgetTester tester, {
  required String taskTitle,
  required DateTime completedAt,
}) async {
  FollowUpTaskChoice? choice;
  var closed = false;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              choice = await FollowUpTaskDialog.show(
                context,
                taskTitle: taskTitle,
                completedAt: completedAt,
              );
              closed = true;
            },
            child: const Text('complete'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('complete'));
  await tester.pumpAndSettle();

  addTearDown(() => expect(closed || choice == null, isTrue));
  return choice;
}

void main() {
  // A Tuesday, so three business days later is the Friday.
  final completedAt = DateTime(2026, 9, 1, 16, 20);

  testWidgets('names the task the user actually completed', (tester) async {
    await _openDialog(
      tester,
      taskTitle: 'testtt taskkk',
      completedAt: completedAt,
    );

    expect(find.text('Create a follow up task?'), findsOneWidget);
    expect(
      find.text('We\'ll create a task for you to follow up on "testtt taskkk"'),
      findsOneWidget,
    );
  });

  testWidgets('opens on a date worked out from the completion', (tester) async {
    await _openDialog(tester, taskTitle: 'Call Mastercard', completedAt: completedAt);

    // Not a fixed string: the same label the schedule computes for that day.
    expect(
      find.text(followUpDateLabel(DateTime(2026, 9, 4), from: completedAt)),
      findsOneWidget,
    );
    expect(find.text('In 3 business days (Friday)'), findsOneWidget);
    expect(find.text('08:00 AM'), findsOneWidget);
  });

  testWidgets('a task completed on another day offers another day',
      (tester) async {
    // A Friday: three business days on is the Wednesday.
    final friday = DateTime(2026, 9, 4, 9);
    await _openDialog(tester, taskTitle: 'Call Mastercard', completedAt: friday);

    expect(find.text('In 3 business days (Wednesday)'), findsOneWidget);
    expect(find.text('In 3 business days (Friday)'), findsNothing);
  });

  testWidgets('"Not now" asks for nothing to be created', (tester) async {
    final choice = await _openDialog(
      tester,
      taskTitle: 'Call Mastercard',
      completedAt: completedAt,
    );
    expect(choice, isNull);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(find.byType(FollowUpTaskDialog), findsNothing);
  });

  testWidgets('"Create task" hands back the chosen date and time',
      (tester) async {
    FollowUpTaskChoice? captured;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                captured = await FollowUpTaskDialog.show(
                  context,
                  taskTitle: 'Call Mastercard',
                  completedAt: completedAt,
                );
              },
              child: const Text('complete'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('complete'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create task'));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.scheduledAt, DateTime(2026, 9, 4, 8));
  });

  testWidgets('picking another date moves the date the follow-up is due',
      (tester) async {
    FollowUpTaskChoice? captured;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                captured = await FollowUpTaskDialog.show(
                  context,
                  taskTitle: 'Call Mastercard',
                  completedAt: completedAt,
                );
              },
              child: const Text('complete'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('complete'));
    await tester.pumpAndSettle();

    // Open the date menu and take "Tomorrow" instead.
    await tester.tap(find.text('In 3 business days (Friday)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tomorrow').last);
    await tester.pumpAndSettle();

    expect(find.text('Tomorrow'), findsOneWidget);

    // And take a different time. The menu holds every quarter hour, so the
    // wanted one has to be scrolled to before it can be tapped.
    await tester.tap(find.text('08:00 AM'));
    await tester.pumpAndSettle();
    final time = find.text('09:30 AM').last;
    await tester.ensureVisible(time);
    await tester.pumpAndSettle();
    await tester.tap(time);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create task'));
    await tester.pumpAndSettle();

    expect(captured!.scheduledAt, DateTime(2026, 9, 2, 9, 30));
  });
}
