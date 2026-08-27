import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crmproject/core/providers/master_data_provider.dart';
import 'package:crmproject/core/utils/activity_utils.dart';
import 'package:crmproject/features/activities/presentation/screens/call_details_screen.dart';
import 'package:crmproject/features/activities/presentation/screens/meeting_details_screen.dart';
import 'package:crmproject/features/activities/presentation/screens/task_details_screen.dart';
import 'package:crmproject/features/activities/presentation/widgets/create_task_modal.dart';
import 'package:crmproject/features/activities/presentation/widgets/log_call_modal.dart';
import 'package:crmproject/features/activities/presentation/widgets/log_meeting_modal.dart';

Widget _wrap(Widget child) => MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MasterDataProvider()),
      ],
      child: MaterialApp(home: child),
    );

/// A local wall-clock time, so the expectations hold in any timezone.
final _scheduled = DateTime(2026, 8, 20, 15, 30);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('duration and schedule parsing', () {
    test('reads every shape a duration arrives in', () {
      expect(parseDurationMinutes(30), 30);
      expect(parseDurationMinutes('30'), 30);
      expect(parseDurationMinutes('30m'), 30);
      expect(parseDurationMinutes('30 Minutes'), 30);
      expect(parseDurationMinutes('1 Hour'), 60);
      expect(parseDurationMinutes('2 Hours'), 120);
      expect(parseDurationMinutes('1h 30m'), 90);
      expect(parseDurationMinutes(''), isNull);
      expect(parseDurationMinutes(null), isNull);
      expect(parseDurationMinutes(0), isNull);
    });

    test('renders minutes with the picker wording', () {
      expect(formatDurationLabel(15), '15 Minutes');
      expect(formatDurationLabel(45), '45 Minutes');
      expect(formatDurationLabel(60), '1 Hour');
      expect(formatDurationLabel(120), '2 Hours');
    });

    test('round-trips a stored duration back onto an option', () {
      expect(formatDurationLabel(parseDurationMinutes('30')!), '30 Minutes');
      expect(formatDurationLabel(parseDurationMinutes('60')!), '1 Hour');
    });

    test('parses ISO and the form\'s own date/time text', () {
      final iso = parseActivityDateTimeOrNull(_scheduled.toUtc().toIso8601String());
      expect(iso, isNotNull);
      expect(iso!.toLocal(), _scheduled);

      expect(formatActivityDateTimeInput(_scheduled), '08/20/2026 3:30 PM');
      expect(parseActivityDateTimeOrNull('08/20/2026 3:30 PM'), _scheduled);
      expect(parseActivityDateTimeOrNull('08/20/2026'), DateTime(2026, 8, 20));
      expect(parseActivityDateTimeOrNull(''), isNull);
      expect(parseActivityDateTimeOrNull('not a date'), isNull);
    });
  });

  group('opening the edit form', () {
    testWidgets('a task opens with its stored values', (tester) async {
      final task = TaskModel(
        id: 'task-1',
        title: 'Follow up with Acme',
        dueDate: _scheduled.toUtc().toIso8601String(),
        // Lowercase, as the API returns it — absent from the fallback options.
        priority: 'medium',
        status: 'pending',
        assignedTo: 'Riley Owner',
        notes: 'Bring the renewal quote',
        rawMap: const {'id': 'task-1', 'type': 'task'},
      );

      await tester.pumpWidget(_wrap(TaskDetailsScreen(task: task)));
      await tester.pump();
      await tester.tap(find.byTooltip('Edit Task'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.byType(CreateTaskModal), findsOneWidget);
      expect(tester.takeException(), isNull);

      expect(find.text('Follow up with Acme'), findsWidgets);
      expect(find.text('Bring the renewal quote'), findsWidgets);
      // Date and time come from the stored dueDate, not from today.
      expect(find.text('Aug 20, 2026'), findsOneWidget);
      expect(find.text('3:30 PM'), findsOneWidget);
      // Values outside the fallback options are still shown.
      expect(find.text('medium'), findsOneWidget);
      expect(find.text('Riley Owner'), findsOneWidget);
      // The form is usable: Save, not Create.
      expect(find.widgetWithText(ElevatedButton, 'Save'), findsOneWidget);
    });

    testWidgets('a call opens with its stored values', (tester) async {
      final call = CallModel(
        id: 'call-1',
        title: 'Intro call',
        outcome: 'connected',
        duration: '30',
        startTime: _scheduled.toUtc().toIso8601String(),
        notes: 'Discussed pricing',
        rawMap: const {'id': 'call-1', 'type': 'call'},
      );

      await tester.pumpWidget(_wrap(CallDetailsScreen(call: call)));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.byType(LogCallModal), findsOneWidget);
      expect(tester.takeException(), isNull);

      expect(find.text('Discussed pricing'), findsWidgets);
      // '30' becomes the '30 Minutes' option, and the header date comes from
      // the stored schedule rather than defaulting to today.
      expect(find.text('30 Minutes'), findsWidgets);
      expect(find.text('Aug 20, 2026'), findsWidgets);
      // 'connected' is matched back onto the 'Connected' option.
      expect(find.text('Connected'), findsWidgets);
    });

    testWidgets('a meeting opens with its stored values', (tester) async {
      final meeting = MeetingModel(
        id: 'meeting-1',
        title: 'Quarterly sync',
        outcome: 'completed',
        duration: '45',
        startTime: _scheduled.toUtc().toIso8601String(),
        notes: 'Agenda attached',
        rawMap: const {'id': 'meeting-1', 'type': 'meeting'},
      );

      await tester.pumpWidget(_wrap(MeetingDetailsScreen(meeting: meeting)));
      await tester.pump();
      await tester.tap(find.byTooltip('Edit Meeting'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.byType(LogMeetingModal), findsOneWidget);
      expect(tester.takeException(), isNull);

      expect(find.text('Agenda attached'), findsWidgets);
      expect(find.text('45 Minutes'), findsWidgets);
      expect(find.text('08/20/2026 3:30 PM'), findsWidgets);
      // The saved outcome survives instead of being reset to the first option.
      expect(find.text('Completed'), findsWidgets);
    });
  });

  group('creating is unaffected', () {
    testWidgets('the call form still opens with its defaults', (tester) async {
      await tester.pumpWidget(_wrap(const Scaffold(body: LogCallModal())));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
      expect(find.text('5 minutes'), findsWidgets);
    });

    testWidgets('the meeting form still opens with its defaults', (tester) async {
      await tester.pumpWidget(_wrap(const Scaffold(body: LogMeetingModal())));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
      expect(find.text('Scheduled'), findsWidgets);
    });
  });
}
