// ============================================================================
// Overflow harness for the "Create one-on-one meeting" wizard.
// ============================================================================
// RenderFlex overflow is a *paint-time* error: `flutter analyze` cannot see it,
// only a laid-out and painted frame can. This suite drives every step of
// `CreateSchedulingPageWizardModal` across the narrow-to-wide phone range and
// across the text scales the app supports, collects every
// "A RenderFlex overflowed by N pixels" report, and fails with the full list.
//
// Collecting rather than failing on the first report matters: one bad Row would
// otherwise mask the other twelve.
//
//   flutter test test/meeting_scheduler_overflow_test.dart
// ============================================================================

import 'package:crmproject/features/activities/presentation/screens/meeting_scheduler_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Physical widths this CRM is expected to survive, in logical pixels.
/// 320 is the narrowest Android phone still in the wild (e.g. Galaxy J-series
/// in landscape-locked launchers); 411 is a Pixel.
const _widths = <double>[300, 320, 360, 411];

/// Text scales the layout must survive. `FontSizeProvider` caps the in-app
/// preference at 19/16 = 1.19x, and `CrmApp` clamps the combined device +
/// in-app scale to [kMaxTextScale]; 2.0 is tested as headroom beyond the cap.
const _scales = <double>[1.0, 1.3, 1.6, 2.0];

void main() {
  // Keep the suite off the network — google_fonts otherwise tries to download
  // Inter/Poppins and the failure noise drowns out the overflow reports.
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final width in _widths) {
    for (final scale in _scales) {
      group('${width.toInt()}px @ ${scale}x', () {
        testWidgets('step 1 does not overflow', (tester) async {
          final o = await _drive(tester, width: width, scale: scale, step: 1);
          expect(o, isEmpty, reason: _report(o));
        });

        testWidgets('step 2 does not overflow', (tester) async {
          final o = await _drive(tester, width: width, scale: scale, step: 2);
          expect(o, isEmpty, reason: _report(o));
        });

        testWidgets('step 3 does not overflow', (tester) async {
          final o = await _drive(tester, width: width, scale: scale, step: 3);
          expect(o, isEmpty, reason: _report(o));
        });

        testWidgets('step 2 with extra availability days does not overflow',
            (tester) async {
          final o = await _drive(
            tester,
            width: width,
            scale: scale,
            step: 2,
            extraAvailabilityDays: 3,
          );
          expect(o, isEmpty, reason: _report(o));
        });

        testWidgets('step 3 with extra reminders does not overflow',
            (tester) async {
          final o = await _drive(
            tester,
            width: width,
            scale: scale,
            step: 3,
            extraReminders: 3,
          );
          expect(o, isEmpty, reason: _report(o));
        });

        testWidgets('live preview tab does not overflow', (tester) async {
          final o = await _drive(
            tester,
            width: width,
            scale: scale,
            step: 2,
            livePreview: true,
          );
          expect(o, isEmpty, reason: _report(o));
        });

        testWidgets('step 1 with the keyboard open does not overflow',
            (tester) async {
          final o = await _drive(
            tester,
            width: width,
            scale: scale,
            step: 1,
            keyboardInset: 320,
          );
          expect(o, isEmpty, reason: _report(o));
        });

        testWidgets('duration picker sheet does not overflow', (tester) async {
          final o = await _drive(
            tester,
            width: width,
            scale: scale,
            step: 2,
            openDurationPicker: true,
          );
          expect(o, isEmpty, reason: _report(o));
        });
      });
    }
  }
}

/// Renders the wizard at [width]/[scale], optionally exercises the "add row"
/// affordances, and returns every distinct overflow message produced.
Future<List<String>> _drive(
  WidgetTester tester, {
  required double width,
  required double scale,
  required int step,
  int extraReminders = 0,
  int extraAvailabilityDays = 0,
  bool livePreview = false,
  bool openDurationPicker = false,
  double keyboardInset = 0,
}) async {
  final overflows = <String>{};
  final previousOnError = FlutterError.onError;

  // Intercept only overflow reports. Everything else must still reach the test
  // binding's handler, otherwise its `_pendingExceptionDetails` bookkeeping
  // trips an assertion the moment an unrelated async error arrives.
  FlutterError.onError = (details) {
    final message = details.exceptionAsString();
    if (message.contains('overflowed by')) {
      // First line carries the direction and pixel count; the creator stack in
      // the full report carries the file:line of the offending Row.
      final creator = RegExp(r'meeting_scheduler_screen\.dart:\d+:\d+')
          .firstMatch(details.toString())
          ?.group(0);
      overflows.add('${message.split('\n').first.trim()}  <- ${creator ?? '?'}');
    } else {
      previousOnError?.call(details);
    }
  };

  tester.view.physicalSize = Size(width * 3, 900 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      // The app applies its scaler this way in `CrmApp`, so mirror it here.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          viewInsets: EdgeInsets.only(bottom: keyboardInset),
        ),
        child: child!,
      ),
      home: CreateSchedulingPageWizardModal(initialStep: step),
    ),
  );
  await tester.pump();

  for (var i = 0; i < extraReminders; i++) {
    await _tap(tester, find.widgetWithText(TextButton, 'Add reminder'));
  }

  for (var i = 0; i < extraAvailabilityDays; i++) {
    await _tap(tester, find.widgetWithText(TextButton, 'Add hours'));
  }

  if (livePreview) {
    await _tap(tester, find.text('Live Preview'));
  }

  if (openDurationPicker) {
    // The chip row is the tap target that opens the picker sheet.
    await _tap(tester, find.text('15 min'));
    await tester.pump(const Duration(milliseconds: 400)); // sheet animation
  }

  // Scroll the form so widgets below the fold get laid out and painted; an
  // overflowing Row that never paints never reports.
  final scrollable = find.byType(Scrollable);
  if (scrollable.evaluate().isNotEmpty) {
    await tester.drag(scrollable.first, const Offset(0, -2000));
    await tester.pump();
    await tester.drag(scrollable.first, const Offset(0, -2000));
    await tester.pump();
  }

  // Restore before any expect() runs — flutter_test asserts on a test that
  // leaves FlutterError.onError swapped out.
  FlutterError.onError = previousOnError;

  // Drain non-overflow errors (google_fonts cannot fetch Inter/Poppins in a
  // host test) so they don't fail the run.
  while (tester.takeException() != null) {}

  return overflows.toList()..sort();
}

/// Scrolls [finder] into view before tapping it.
///
/// Tapping blind is dangerous here: at a large text scale an off-screen "Add
/// reminder" tap once landed on "Create scheduling page" instead and fired a
/// real API request from a unit test.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) return;
  await tester.ensureVisible(finder.first);
  await tester.pump();
  await tester.tap(finder.first);
  await tester.pump();
}

String _report(List<String> overflows) =>
    'Expected no RenderFlex overflow, found ${overflows.length}:\n'
    '${overflows.map((o) => '  • $o').join('\n')}';
