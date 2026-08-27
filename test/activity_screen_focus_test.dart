import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crmproject/features/activities/presentation/screens/calls_screen.dart';
import 'package:crmproject/features/activities/presentation/screens/emails_screen.dart';
import 'package:crmproject/features/authentication/presentation/providers/auth_provider.dart';
import 'package:crmproject/features/departments/presentation/providers/department_provider.dart';
import 'package:crmproject/features/navigation/presentation/providers/navigation_provider.dart';

/// The screens live under these providers in the real app.
Widget _wrap(Widget child, NavigationProvider navigation) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: navigation),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DepartmentProvider()),
      ],
      child: MaterialApp(home: child),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  // The API is unreachable under test, so these lists load empty — which is
  // exactly the "requested activity is not in this list" path.
  group('a focus request for an activity that is not in the list', () {
    testWidgets('leaves the Calls screen usable', (tester) async {
      final navigation = NavigationProvider()
        ..openActivity(activityType: 'call', activityId: 'missing-call');

      await tester.pumpWidget(_wrap(const CallsScreen(), navigation));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
      expect(find.byType(CallsScreen), findsOneWidget);
    });

    testWidgets('leaves the Emails screen usable', (tester) async {
      final navigation = NavigationProvider()
        ..openActivity(activityType: 'email', activityId: 'missing-email');

      await tester.pumpWidget(_wrap(const EmailsScreen(), navigation));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
      expect(find.byType(EmailsScreen), findsOneWidget);
    });
  });

  group('a focus request arriving while the screen is already open', () {
    testWidgets('does not break the Calls screen', (tester) async {
      final navigation = NavigationProvider();

      await tester.pumpWidget(_wrap(const CallsScreen(), navigation));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Applying a focus calls setState, so it must not run during build.
      navigation.openActivity(activityType: 'call', activityId: 'late-call');
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
      expect(find.byType(CallsScreen), findsOneWidget);
    });

    testWidgets('does not break the Emails screen', (tester) async {
      final navigation = NavigationProvider();

      await tester.pumpWidget(_wrap(const EmailsScreen(), navigation));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      navigation.openActivity(activityType: 'email', activityId: 'late-email');
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
      expect(find.byType(EmailsScreen), findsOneWidget);
    });
  });
}
