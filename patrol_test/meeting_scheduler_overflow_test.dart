// ============================================================================
// On-device overflow check for the "Create one-on-one meeting" wizard.
// ============================================================================
// `test/meeting_scheduler_overflow_test.dart` covers the same ground far faster
// on the host, but it renders with the fallback font: google_fonts resolves
// Inter/Poppins only on a real device, and different glyph metrics mean
// different text widths. This suite therefore re-checks the layout with the
// fonts the user actually sees.
//
//   patrol test --target patrol_test/meeting_scheduler_overflow_test.dart
// ============================================================================

import 'package:crmproject/features/activities/presentation/screens/meeting_scheduler_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'common.dart';

/// null means "use the device's own width".
const _widths = <double?>[null, 320];
const _scales = <double>[1.0, 1.3];

void main() {
  // The first test in the process pays for google_fonts: `AppTheme` pulls
  // Inter/Poppins over HTTPS on first use and the rejection lands in whichever
  // test renders text first, killing it before it can report. Give that cost to
  // a throwaway case so it cannot be mistaken for a layout failure.
  // Bundling the TTFs under `assets/fonts/` removes the need for this.
  crmTest('warm up google_fonts', ($) async {
    await $.pumpWidget(const MaterialApp(home: Scaffold(body: Text('warmup'))));
    await $.pump();
  });

  for (final width in _widths) {
    for (final scale in _scales) {
      final label = width == null ? 'device width' : '${width.toInt()}px';

      crmTest('wizard has no overflow at $label @ ${scale}x', ($) async {
        final overflows = <String>{};
        final previousOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          final message = details.exceptionAsString();
          if (message.contains('overflowed by')) {
            overflows.add(message.split('\n').first.trim());
          } else {
            previousOnError?.call(details);
          }
        };

        for (final step in const [1, 2, 3]) {
          Widget wizard = CreateSchedulingPageWizardModal(initialStep: step);
          if (width != null) {
            // Constraining the subtree reproduces a narrow handset without
            // needing one: layout follows constraints, not MediaQuery.size.
            wizard = Center(child: SizedBox(width: width, child: wizard));
          }

          await $.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: wizard,
            ),
          );
          await $.pump();

          // Add a second and third row so the repeating layouts are covered.
          if (step == 3) {
            await _tap($, find.widgetWithText(TextButton, 'Add reminder'));
            await _tap($, find.widgetWithText(TextButton, 'Add reminder'));
          }
          if (step == 2) {
            await _tap($, find.widgetWithText(TextButton, 'Add hours'));
            await _tap($, find.widgetWithText(TextButton, 'Add hours'));
          }

          // Paint the part of the form below the fold — an overflowing Row that
          // never paints never reports.
          final scrollable = find.byType(Scrollable);
          if (scrollable.evaluate().isNotEmpty) {
            await $.tester.drag(scrollable.first, const Offset(0, -1500));
            await $.pump();
            await $.tester.drag(scrollable.first, const Offset(0, -1500));
            await $.pump();
          }
        }

        FlutterError.onError = previousOnError;

        expect(
          overflows,
          isEmpty,
          reason: 'Expected no RenderFlex overflow at $label @ ${scale}x, found:\n'
              '${overflows.map((o) => '  - $o').join('\n')}',
        );
      });
    }
  }
}

/// Scrolls [finder] into view before tapping, so a tap can never land on a
/// neighbouring control (such as the submit button, which posts to the API).
Future<void> _tap(PatrolIntegrationTester $, Finder finder) async {
  if (finder.evaluate().isEmpty) return;
  await $.tester.ensureVisible(finder.first);
  await $.pump();
  await $.tester.tap(finder.first);
  await $.pump();
}
