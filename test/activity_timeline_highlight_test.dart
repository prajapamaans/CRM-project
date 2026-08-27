import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crmproject/core/providers/master_data_provider.dart';
import 'package:crmproject/features/contacts/data/models/contact_model.dart';
import 'package:crmproject/features/contacts/presentation/providers/contact_provider.dart';
import 'package:crmproject/features/contacts/presentation/screens/contact_details_screen.dart';
import 'package:crmproject/features/navigation/presentation/providers/navigation_provider.dart';

const _highlightBackground = Color(0xFFE6F4F1);
const _highlightBorder = Color(0xFF00A884);

Widget _wrap(Widget child) => MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MasterDataProvider()),
        ChangeNotifierProvider(create: (_) => ContactProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
      ],
      child: MaterialApp(home: child),
    );

/// The activity rows in the All-activities list.
Iterable<BoxDecoration> _rowDecorations(WidgetTester tester) => tester
    .widgetList<Container>(find.byType(Container))
    .map((c) => c.decoration)
    .whereType<BoxDecoration>()
    .where((d) => d.borderRadius == BorderRadius.circular(10));

int _highlightedRowCount(WidgetTester tester) =>
    _rowDecorations(tester).where((d) => d.color == _highlightBackground).length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('opens on the All-activities tab when an activity is requested',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ContactDetailsScreen(
          contact: ContactModel(id: 'c-1', firstName: 'Ada', email: 'a@b.c'),
          initialTabIndex: 1,
          highlightActivityId: 'act-42',
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(find.text('All activities'), findsOneWidget);
  });

  testWidgets('an activity that is not in the timeline highlights nothing',
      (tester) async {
    // The API is unreachable under test, so the timeline loads empty.
    await tester.pumpWidget(
      _wrap(
        const ContactDetailsScreen(
          contact: ContactModel(id: 'c-1', firstName: 'Ada', email: 'a@b.c'),
          initialTabIndex: 1,
          highlightActivityId: 'act-missing',
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(_highlightedRowCount(tester), 0);
  });

  testWidgets('no highlight is shown when no activity was requested',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ContactDetailsScreen(
          contact: ContactModel(id: 'c-1', firstName: 'Ada', email: 'a@b.c'),
          initialTabIndex: 1,
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(_highlightedRowCount(tester), 0);
    expect(
      _rowDecorations(tester).any((d) => d.border == Border.all(color: _highlightBorder, width: 1.5)),
      isFalse,
    );
  });
}
