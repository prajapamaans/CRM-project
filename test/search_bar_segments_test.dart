import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crmproject/core/widgets/search_and_filter_bar.dart';

Widget _host(Widget child, {Size size = const Size(320, 640)}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp(
      home: Scaffold(
        body: SizedBox(width: size.width, child: child),
      ),
    ),
  );
}

void main() {
  testWidgets('the All / Mine pill is there by default', (tester) async {
    await tester.pumpWidget(_host(const SearchAndFilterBar(
      searchHint: 'Search contacts...',
      allLabel: 'All Contacts',
      mineLabel: 'Mine',
    )));

    expect(find.text('All Contacts'), findsOneWidget);
    expect(find.text('Mine'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a screen can turn the pill off and keep the rest of the bar', (tester) async {
    await tester.pumpWidget(_host(const SearchAndFilterBar(
      searchHint: 'Search tasks...',
      showSegments: false,
    )));

    expect(find.text('All'), findsNothing);
    expect(find.text('Mine'), findsNothing);
    // The search field and the filter button are untouched.
    expect(find.text('Search tasks...'), findsOneWidget);
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'the row must not overflow without the pill');
  });

  testWidgets('the bar still lays out on a narrow screen with filters active', (tester) async {
    await tester.pumpWidget(_host(
      const SearchAndFilterBar(
        searchHint: 'Search tasks...',
        showSegments: false,
        isFilterActive: true,
      ),
      size: const Size(280, 640),
    ));

    expect(find.text('Clear'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
