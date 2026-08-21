// ============================================================================
// E2E tests for the login flow (`LoginScreen`).
// ============================================================================
// Run with:
//   patrol test --target patrol_test/login_test.dart
//
// These tests exercise the client-side behaviour of the sign-in form, so they
// pass without valid CRM credentials. The credentialed happy path lives at the
// bottom and is skipped until you supply real credentials via --dart-define.
// ============================================================================

import 'package:crmproject/core/widgets/bottom_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'common.dart';

/// Credentials for the happy-path test, supplied at run time:
///   patrol test --dart-define=CRM_EMAIL=you@apidel.com --dart-define=CRM_PASSWORD=...
const _email = String.fromEnvironment('CRM_EMAIL');
const _password = String.fromEnvironment('CRM_PASSWORD');

void main() {
  crmTest('splash screen hands off to the login form', ($) async {
    await launchToLogin($);

    expect($('EMAIL ADDRESS'), findsOneWidget);
    expect($('PASSWORD'), findsOneWidget);
    expect($('Sign In'), findsOneWidget);
  });

  crmTest('submitting an empty form shows both required-field errors', ($) async {
    await launchToLogin($);

    await $('Sign In').tap();

    expect($('Email is required'), findsOneWidget);
    expect($('Password is required'), findsOneWidget);
  });

  crmTest('a malformed email and a short password are both rejected', ($) async {
    await launchToLogin($);

    // `_validateEmail` rejects anything that misses the regex; `autovalidateMode`
    // is `onUserInteraction`, so the error surfaces while typing.
    await $(TextFormField).at(0).enterText('not-an-email');
    await $(TextFormField).at(1).enterText('short');
    await $('Sign In').tap();

    expect($('Enter a valid email address'), findsOneWidget);
    expect($('Password must be at least 8 characters'), findsOneWidget);
  });

  crmTest('the eye icon toggles password visibility', ($) async {
    await launchToLogin($);

    await $(TextFormField).at(1).enterText('supersecret');

    // Starts obscured, so the "show" icon is the one on screen.
    expect($(Icons.visibility_off_outlined), findsOneWidget);

    await $(Icons.visibility_off_outlined).tap();
    expect($(Icons.visibility_outlined), findsOneWidget);

    await $(Icons.visibility_outlined).tap();
    expect($(Icons.visibility_off_outlined), findsOneWidget);
  });

  // This is the case plain `integration_test` cannot cover: it leaves the
  // Flutter widget tree entirely and drives the operating system.
  crmTest('typed input survives backgrounding the app', ($) async {
    await launchToLogin($);

    await $(TextFormField).at(0).enterText('draft@apidel.com');

    await $.platform.mobile.pressHome();
    await $.platform.mobile.openApp();

    await $('EMAIL ADDRESS').waitUntilVisible();
    expect($('draft@apidel.com'), findsOneWidget);
  });

  crmTest('bad credentials surface the backend error in a snackbar', ($) async {
    await launchToLogin($);

    await $(TextFormField).at(0).enterText('nobody@apidel.com');
    await $(TextFormField).at(1).enterText('wrongpassword');
    await $('Sign In').tap();

    // `_showError` renders whatever `AuthProvider.error` holds, so assert on the
    // snackbar itself rather than on a specific backend message.
    await $(SnackBar).waitUntilVisible();
    expect($('EMAIL ADDRESS'), findsOneWidget, reason: 'should stay on login');
  });

  crmTest(
    'valid credentials land on the main layout',
    ($) async {
      await launchToLogin($);

      await $(TextFormField).at(0).enterText(_email);
      // Typing a valid email fires POST /auth/email-details in the background;
      // the Sign In button is disabled until that lookup finishes.
      await $.pumpAndSettle();

      await $(TextFormField).at(1).enterText(_password);
      await $('Sign In').tap();

      // InitialDataLoaderScreen pre-fetches dashboard/contacts/companies/deals
      // before MainLayoutScreen appears, so this wait covers several API calls.
      await $(CustomBottomNavBar).waitUntilVisible();
    },
    skip: _email.isEmpty || _password.isEmpty,
  );
}
