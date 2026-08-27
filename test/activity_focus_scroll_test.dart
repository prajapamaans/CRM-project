import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crmproject/core/utils/list_scroll_utils.dart';
import 'package:crmproject/features/navigation/presentation/providers/navigation_provider.dart';

const _rowHeight = 60.0;
const _rowCount = 200;

/// Drives frames until [future] settles — `ensureListItemVisible` waits on
/// end-of-frame between hops, which only happens when the test pumps.
Future<T> _pumpUntilDone<T>(WidgetTester tester, Future<T> future) async {
  var done = false;
  final tracked = future.whenComplete(() => done = true);
  for (var i = 0; i < 400 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  return tracked;
}

Future<void> _pumpList(
  WidgetTester tester, {
  required ScrollController controller,
  required GlobalKey itemKey,
  required int keyedIndex,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListView.builder(
          controller: controller,
          itemCount: _rowCount,
          itemBuilder: (context, index) => SizedBox(
            key: index == keyedIndex ? itemKey : null,
            height: _rowHeight,
            child: Text('Row $index'),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('ensureListItemVisible', () {
    testWidgets('brings a row that was never built into view', (tester) async {
      final controller = ScrollController();
      final key = GlobalKey();
      addTearDown(controller.dispose);

      await _pumpList(tester, controller: controller, itemKey: key, keyedIndex: 120);

      // Far outside the viewport, so ListView.builder has not built it.
      expect(find.text('Row 120'), findsNothing);
      expect(controller.offset, 0);

      final found = await _pumpUntilDone(
        tester,
        ensureListItemVisible(controller: controller, itemKey: key),
      );
      await tester.pumpAndSettle();

      expect(found, isTrue);
      expect(find.text('Row 120'), findsOneWidget);
      // Positioned by the item's real geometry, not a guessed offset.
      final box = tester.getRect(find.text('Row 120'));
      expect(box.top, greaterThanOrEqualTo(0));
      expect(box.bottom, lessThanOrEqualTo(tester.view.physicalSize.height));
    });

    testWidgets('finds a row above the current position', (tester) async {
      final controller = ScrollController();
      final key = GlobalKey();
      addTearDown(controller.dispose);

      await _pumpList(tester, controller: controller, itemKey: key, keyedIndex: 3);

      controller.jumpTo(_rowHeight * 150);
      await tester.pump();
      expect(find.text('Row 3'), findsNothing);

      final found = await _pumpUntilDone(
        tester,
        ensureListItemVisible(controller: controller, itemKey: key),
      );
      await tester.pumpAndSettle();

      expect(found, isTrue);
      expect(find.text('Row 3'), findsOneWidget);
    });

    testWidgets('leaves an already-visible row alone', (tester) async {
      final controller = ScrollController();
      final key = GlobalKey();
      addTearDown(controller.dispose);

      await _pumpList(tester, controller: controller, itemKey: key, keyedIndex: 0);

      final found = await _pumpUntilDone(
        tester,
        ensureListItemVisible(controller: controller, itemKey: key),
      );
      await tester.pumpAndSettle();

      expect(found, isTrue);
      expect(controller.offset, 0);
    });

    testWidgets('restores the offset when the row is not in the list',
        (tester) async {
      final controller = ScrollController();
      final orphanKey = GlobalKey();
      addTearDown(controller.dispose);

      // keyedIndex is out of range, so nothing ever carries the key.
      await _pumpList(tester, controller: controller, itemKey: orphanKey, keyedIndex: -1);

      controller.jumpTo(_rowHeight * 20);
      await tester.pump();
      final startOffset = controller.offset;

      final found = await _pumpUntilDone(
        tester,
        ensureListItemVisible(controller: controller, itemKey: orphanKey),
      );
      await tester.pumpAndSettle();

      expect(found, isFalse);
      expect(controller.offset, startOffset);
    });

    testWidgets('does nothing when the list has no viewport', (tester) async {
      final controller = ScrollController();
      final key = GlobalKey();
      addTearDown(controller.dispose);

      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));

      final found = await _pumpUntilDone(
        tester,
        ensureListItemVisible(controller: controller, itemKey: key),
      );

      expect(found, isFalse);
    });
  });

  group('NavigationProvider.openActivity', () {
    test('routes each activity type to its screen, carrying the id', () {
      final provider = NavigationProvider();

      expect(provider.openActivity(activityType: 'call', activityId: 'a-1'), isTrue);
      expect(provider.selectedIndex, 9);
      expect(provider.focusedActivityId, 'a-1');

      expect(provider.openActivity(activityType: 'meeting', activityId: 'a-2'), isTrue);
      expect(provider.selectedIndex, 7);
      expect(provider.focusedActivityId, 'a-2');

      expect(provider.openActivity(activityType: 'email', activityId: 'a-3'), isTrue);
      expect(provider.selectedIndex, 10);
      expect(provider.focusedActivityId, 'a-3');
    });

    test('reads the type out of a decorated notification type', () {
      final provider = NavigationProvider();

      expect(
        provider.openActivity(activityType: 'activity_email_sent', activityId: 'a-9'),
        isTrue,
      );
      expect(provider.selectedIndex, 10);
      expect(provider.focusedActivityId, 'a-9');
    });

    test('declines types without a list screen and missing ids', () {
      final provider = NavigationProvider();
      provider.selectScreen(3);

      expect(provider.openActivity(activityType: 'task', activityId: 'a-4'), isFalse);
      expect(provider.openActivity(activityType: 'note', activityId: 'a-5'), isFalse);
      expect(provider.openActivity(activityType: 'call', activityId: null), isFalse);
      expect(provider.openActivity(activityType: 'call', activityId: '  '), isFalse);
      expect(provider.openActivity(activityType: null, activityId: 'a-6'), isFalse);

      // Nothing moved.
      expect(provider.selectedIndex, 3);
      expect(provider.focusedActivityId, isNull);
    });

    test('a plain screen switch clears a stale focus', () {
      final provider = NavigationProvider();

      provider.openActivity(activityType: 'call', activityId: 'a-1');
      expect(provider.focusedActivityId, 'a-1');

      provider.selectScreen(1);
      expect(provider.focusedActivityId, isNull);
    });

    test('notifies listeners so the destination screen can react', () {
      final provider = NavigationProvider();
      var notifications = 0;
      provider.addListener(() => notifications++);

      provider.openActivity(activityType: 'meeting', activityId: 'a-7');

      expect(notifications, 1);
    });
  });
}
