import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crmproject/core/providers/master_data_provider.dart';
import 'package:crmproject/features/activities/presentation/screens/meeting_scheduler_screen.dart';
import 'package:crmproject/features/contacts/data/models/contact_model.dart';
import 'package:crmproject/features/authentication/presentation/providers/auth_provider.dart';
import 'package:crmproject/features/companies/presentation/providers/company_provider.dart';
import 'package:crmproject/features/contacts/presentation/providers/contact_provider.dart';
import 'package:crmproject/features/deals/presentation/providers/deal_provider.dart';
import 'package:crmproject/features/departments/presentation/providers/department_provider.dart';

/// The phone the screenshots came from: 720x1600 at 2x.
const Size _phone = Size(360, 800);

/// Stands in for contacts already loaded from the API.
class _LoadedContactProvider extends ContactProvider {
  @override
  List<ContactModel> get contacts => const [
        ContactModel(id: 'c-1', firstName: 'Ada', lastName: 'Lovelace', email: 'ada@example.com'),
        ContactModel(id: 'c-2', firstName: 'Grace', lastName: 'Hopper', email: 'grace@example.com'),
      ];

  @override
  bool get isLoading => false;

  @override
  Future<void> fetchContacts({
    String? search,
    String? ownerId,
    String? departmentId,
    bool? ignorePermissions,
    bool refresh = true,
  }) async {}
}

Future<void> _pumpWizard(
  WidgetTester tester, {
  int step = 1,
  ContactProvider? contactProvider,
}) async {
  tester.view.physicalSize = _phone * tester.view.devicePixelRatio;
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = _phone;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ContactProvider>(
          create: (_) => contactProvider ?? ContactProvider(),
        ),
        ChangeNotifierProvider(create: (_) => CompanyProvider()),
        ChangeNotifierProvider(create: (_) => DealProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MasterDataProvider()),
        ChangeNotifierProvider(create: (_) => DepartmentProvider()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: CreateSchedulingPageWizardModal(initialStep: step),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle(const Duration(seconds: 1));
}

/// Font size actually rendered for [text].
double _renderedFontSize(WidgetTester tester, String text) {
  final widget = tester.widget<Text>(find.text(text).first);
  final style = widget.style;
  if (style?.fontSize != null) return style!.fontSize!;
  // Falls back to the inherited style, which is what the bug was about.
  final richText = tester.widget<RichText>(
    find
        .descendant(of: find.text(text).first, matching: find.byType(RichText))
        .first,
  );
  return richText.text.style?.fontSize ?? 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('no overflow on a phone-sized screen', () {
    for (final step in [1, 2, 3]) {
      testWidgets('step $step lays out without overflowing', (tester) async {
        await _pumpWizard(tester, step: step);
        // A RenderFlex overflow throws during paint in tests.
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('step 2 still fits at a larger text scale', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await _pumpWizard(tester, step: 2);
      expect(tester.takeException(), isNull);
    });
  });

  group('dropdown text matches the rest of the form', () {
    testWidgets('the timezone and time values are not oversized',
        (tester) async {
      await _pumpWizard(tester, step: 2);

      // Was Material's default titleMedium (16sp) beside 13.5sp fields.
      expect(_renderedFontSize(tester, 'UTC'), 13.5);
      expect(_renderedFontSize(tester, 'Monday'), 13.5);
      expect(_renderedFontSize(tester, '9:00 AM'), 13.5);
      expect(_renderedFontSize(tester, '5:00 PM'), 13.5);
    });

    testWidgets('the reminder unit is not oversized', (tester) async {
      await _pumpWizard(tester, step: 3);
      expect(_renderedFontSize(tester, 'day(s) before'), 13.5);
    });
  });

  group('organizer and contact options', () {
    testWidgets('no longer offer hardcoded placeholder people', (tester) async {
      await _pumpWizard(tester, step: 1);

      // The API is unreachable under test, so both lists come back empty —
      // the old build showed these regardless.
      expect(find.text('John Doe'), findsNothing);
      expect(find.text('Admin User'), findsNothing);
      expect(find.text('Contact 1'), findsNothing);
    });

    testWidgets('show their prompts while empty', (tester) async {
      await _pumpWizard(tester, step: 1);

      expect(find.text('Select organizer'), findsOneWidget);
      expect(find.text('Select a contact'), findsOneWidget);
    });

    testWidgets('the contact dropdown lists the fetched contacts',
        (tester) async {
      await _pumpWizard(
        tester,
        step: 1,
        contactProvider: _LoadedContactProvider(),
      );

      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();

      expect(find.text('Ada Lovelace'), findsWidgets);
      expect(find.text('Grace Hopper'), findsWidgets);
    });

    testWidgets('picking a contact keeps it selected', (tester) async {
      await _pumpWizard(
        tester,
        step: 1,
        contactProvider: _LoadedContactProvider(),
      );

      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Grace Hopper').last);
      await tester.pumpAndSettle();

      expect(find.text('Grace Hopper'), findsOneWidget);
      expect(find.text('Select a contact'), findsNothing);
    });
  });
}
