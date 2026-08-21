// ============================================================================
// Shared scaffolding for every Patrol E2E test in this project.
// ============================================================================
// Patrol tests run on a real device/emulator against the real `CrmApp` widget
// tree and the real CRM API — there is no mocking layer here. That means two
// things every test in `patrol_test/` has to cope with:
//
//   1. `SplashScreen` holds for a minimum of 5 seconds while it restores the
//      saved session, so the login form is not on screen at pump time.
//   2. Screens fetch from the backend on open, so widgets appear late.
//
// `crmTest` bakes generous finder timeouts in, and `launchToLogin` hides the
// splash hand-off, so individual tests can stay about behaviour.
// ============================================================================

import 'package:crmproject/app/app.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:patrol/patrol.dart';

/// Finder timeouts tuned for a real backend on a real device.
const crmTesterConfig = PatrolTesterConfig(
  existsTimeout: Duration(seconds: 30),
  visibleTimeout: Duration(seconds: 30),
  settleTimeout: Duration(seconds: 30),
  printLogs: true,
);

/// Declares a Patrol test with this project's shared configuration.
///
/// Use this instead of calling [patrolTest] directly so timeouts stay
/// consistent across the suite.
void crmTest(
  String description,
  PatrolTesterCallback callback, {
  bool? skip,
}) {
  patrolTest(
    description,
    ($) async {
      // `AppTheme` styles everything with `GoogleFonts.poppins`, which downloads
      // Poppins over HTTPS on first use and rethrows into an unawaited future if
      // that fails — so a blocked network shows up as a failure in whichever
      // test happens to run first, unrelated to what it asserts.
      //
      // The device therefore needs network access to fonts.gstatic.com. To take
      // the suite (and app startup) off the network for good, vendor the Poppins
      // TTFs under `assets/fonts/`, declare them in pubspec.yaml, and flip this
      // to `false` — google_fonts then loads them straight from the bundle.
      GoogleFonts.config.allowRuntimeFetching = true;
      await callback($);
    },
    config: crmTesterConfig,
    skip: skip,
  );
}

/// Boots the real application and waits until [SplashScreen] has handed off to
/// the login form.
///
/// Note this uses `pumpWidget`, not `pumpWidgetAndSettle`: the splash screen's
/// 5 second delay is a plain timer that schedules no frames, so settling would
/// return while the splash is still up. Waiting on a widget that only the login
/// screen renders is the reliable signal.
Future<void> launchToLogin(PatrolIntegrationTester $) async {
  await $.pumpWidget(const CrmApp());
  await $('EMAIL ADDRESS').waitUntilVisible();
}
