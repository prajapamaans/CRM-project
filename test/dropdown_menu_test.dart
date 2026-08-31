import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crmproject/core/widgets/searchable_dropdown_form_field.dart';

/// The owner list from the screenshot — long enough to need scrolling.
final _owners = <String>[
  'Abhishek Puranik',
  'Admin User',
  'Allison Allen',
  'Anita Fernandes',
  'Aum Patel',
  'Dolsi Makkad',
  'Hemanshu Patel',
  'Mansi Prajapati',
  'Mihir Pandya',
  'Pradeep Talreja',
  'Rachel Slowey',
  'Rishabh Thapiyal',
  'Ron Lippitt',
  'Sales Executive',
  'Sales Manager',
  'Saurav Singh',
  'Sujith Kurup',
];

Widget _host({
  required List<DropdownSearchItem<String>> items,
  String? initialValue,
  ValueChanged<String?>? onChanged,
  Alignment align = Alignment.center,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: align,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SearchableDropdownFormField<String>(
            hintText: 'Select owner',
            items: items,
            initialValue: initialValue,
            onChanged: onChanged,
          ),
        ),
      ),
    ),
  );
}

List<DropdownSearchItem<String>> _ownerItems({bool withEmail = false}) => _owners
    .map((o) => DropdownSearchItem<String>(
          value: o,
          label: o,
          subtext: withEmail ? '${o.split(' ').first.toLowerCase()}@apidel.com' : null,
        ))
    .toList();

void main() {
  group('the open menu', () {
    testWidgets('lists the options', (tester) async {
      await tester.pumpWidget(_host(items: _ownerItems()));

      await tester.tap(find.text('Select owner'));
      await tester.pumpAndSettle();

      expect(find.text('Abhishek Puranik'), findsOneWidget);
      expect(find.text('Admin User'), findsOneWidget);
    });

    testWidgets('offers a search box once the list is long', (tester) async {
      await tester.pumpWidget(_host(items: _ownerItems()));

      await tester.tap(find.text('Select owner'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'anita');
      await tester.pumpAndSettle();

      expect(find.text('Anita Fernandes'), findsOneWidget);
      expect(find.text('Abhishek Puranik'), findsNothing);
    });

    testWidgets('a short list needs no search box', (tester) async {
      final short = _owners
          .take(3)
          .map((o) => DropdownSearchItem<String>(value: o, label: o))
          .toList();
      await tester.pumpWidget(_host(items: short));

      await tester.tap(find.text('Select owner'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('rows are tall enough to tap comfortably', (tester) async {
      await tester.pumpWidget(_host(items: _ownerItems()));

      await tester.tap(find.text('Select owner'));
      await tester.pumpAndSettle();

      final row = tester.getSize(
        find.ancestor(
          of: find.text('Abhishek Puranik'),
          matching: find.byType(InkWell),
        ).first,
      );
      expect(row.height, greaterThanOrEqualTo(44.0));
    });

    testWidgets('picking an option reports it and closes the menu', (tester) async {
      String? picked;
      await tester.pumpWidget(_host(
        items: _ownerItems(),
        onChanged: (v) => picked = v,
      ));

      await tester.tap(find.text('Select owner'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anita Fernandes'));
      await tester.pumpAndSettle();

      expect(picked, 'Anita Fernandes');
      // The field now shows it, and the menu is gone.
      expect(find.text('Anita Fernandes'), findsOneWidget);
    });

    testWidgets('marks the current selection', (tester) async {
      final short = _owners
          .take(3)
          .map((o) => DropdownSearchItem<String>(value: o, label: o))
          .toList();
      await tester.pumpWidget(_host(items: short, initialValue: 'Admin User'));

      // The field shows the selection; tapping it opens the menu.
      await tester.tap(find.text('Admin User'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('shows a subtext line when the option carries one', (tester) async {
      await tester.pumpWidget(_host(items: _ownerItems(withEmail: true)));

      await tester.tap(find.text('Select owner'));
      await tester.pumpAndSettle();

      expect(find.text('abhishek@apidel.com'), findsOneWidget);
    });

    testWidgets('a search matching nothing says so instead of rendering blank', (tester) async {
      await tester.pumpWidget(_host(items: _ownerItems()));

      await tester.tap(find.text('Select owner'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'zzzzz');
      await tester.pumpAndSettle();

      expect(find.textContaining('No option'), findsOneWidget);
    });
  });

  group('stays on screen', () {
    // The menu this replaced ran off the right edge and was clipped at the top
    // and bottom, cutting off its own list.
    for (final entry in {
      'anchored at the top': Alignment.topLeft,
      'anchored in the middle': Alignment.center,
      'anchored at the bottom': Alignment.bottomRight,
    }.entries) {
      testWidgets('fits within the viewport when ${entry.key}', (tester) async {
        await tester.pumpWidget(_host(items: _ownerItems(), align: entry.value));

        await tester.tap(find.text('Select owner'));
        await tester.pumpAndSettle();

        final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
        final menu = find.byType(Material).last;
        final topLeft = tester.getTopLeft(menu);
        final bottomRight = tester.getBottomRight(menu);

        expect(topLeft.dx, greaterThanOrEqualTo(0), reason: 'off the left edge');
        expect(topLeft.dy, greaterThanOrEqualTo(0), reason: 'off the top edge');
        expect(bottomRight.dx, lessThanOrEqualTo(screen.width), reason: 'off the right edge');
        expect(bottomRight.dy, lessThanOrEqualTo(screen.height), reason: 'off the bottom edge');
      });
    }

    testWidgets('a long list scrolls rather than overflowing', (tester) async {
      await tester.pumpWidget(_host(items: _ownerItems()));

      await tester.tap(find.text('Select owner'));
      await tester.pumpAndSettle();

      // Seventeen 56px rows cannot fit the test viewport, so the last name is
      // only reachable by scrolling — it must not be silently clipped away.
      expect(find.text('Sujith Kurup'), findsNothing);

      await tester.scrollUntilVisible(
        find.text('Sujith Kurup'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();

      expect(find.text('Sujith Kurup'), findsOneWidget);
    });
  });
}
