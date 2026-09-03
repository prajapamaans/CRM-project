import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crmproject/core/utils/department_aware_state.dart';
import 'package:crmproject/core/utils/task_query_builder.dart';
import 'package:crmproject/features/departments/presentation/providers/department_provider.dart';

/// The three departments the app ships with, read from its own constants.
/// Nothing below is written for any one of them in particular.
final apacId = DepartmentConstants.apacId;
final australiaId = DepartmentConstants.australiaId;
final talentAcquisitionId = DepartmentConstants.talentAcquisitionNightId;

/// A department picker that can be driven a step at a time, so a test can sit
/// in the gap between "the user picked a department" and "the access token for
/// it has been swapped" — the window the real provider spends on a network
/// round trip.
class _FakeDepartments extends DepartmentProvider {
  String _selected;
  bool _switching = false;

  _FakeDepartments(this._selected);

  @override
  String get selectedDepartmentId => _selected;

  @override
  bool get isSwitchingDepartment => _switching;

  /// The user picks a department: the id changes at once, the token has not
  /// been swapped yet.
  void beginSwitch(String departmentId) {
    _switching = true;
    _selected = departmentId;
    notifyListeners();
  }

  /// `/auth/switch-department` answered.
  void finishSwitch({String? revertTo}) {
    if (revertTo != null) _selected = revertTo;
    _switching = false;
    notifyListeners();
  }
}

/// Stands in for a department-scoped list screen: it records the department of
/// every reload it is asked for, and whether its rows were wiped.
class _ListScreen extends StatefulWidget {
  final List<String> reloads;
  final List<String> clears;

  const _ListScreen({required this.reloads, required this.clears});

  @override
  State<_ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<_ListScreen> with DepartmentAwareState {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    watchDepartmentChanges(
      (departmentId) => widget.reloads.add(departmentId),
      onSwitchStarted: () => widget.clears.add(currentDepartmentId()),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Future<_FakeDepartments> _pumpScreen(
  WidgetTester tester, {
  required String startOn,
  required List<String> reloads,
  required List<String> clears,
}) async {
  final departments = _FakeDepartments(startOn);
  await tester.pumpWidget(
    ChangeNotifierProvider<DepartmentProvider>.value(
      value: departments,
      child: MaterialApp(
        home: _ListScreen(reloads: reloads, clears: clears),
      ),
    ),
  );
  await tester.pump();
  return departments;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the task request', () {
    test('carries whichever department is selected', () {
      for (final departmentId in [apacId, australiaId, talentAcquisitionId]) {
        final query = buildTaskListQuery(
          page: 1,
          limit: 25,
          departmentId: departmentId,
        );

        expect(query['type'], 'task');
        expect(query['page'], 1);
        expect(query['limit'], 25);
        expect(query['sort'], 'createdAt');
        expect(query['order'], 'desc');
        // Both spellings, so whichever the backend reads finds it.
        expect(query['departmentId'], departmentId);
        expect(query['department_id'], departmentId);
      }
    });

    test('never carries a department other than the selected one', () {
      final talentAcquisition =
          buildTaskListQuery(page: 1, limit: 25, departmentId: talentAcquisitionId);

      expect(talentAcquisition.values.contains(apacId), isFalse);
      expect(talentAcquisition.values.contains(australiaId), isFalse);
    });

    test('works for a department the app has no constant for', () {
      const newDepartmentId = 'a1b2c3d4-0000-0000-0000-0000000000ff';
      final query =
          buildTaskListQuery(page: 1, limit: 25, departmentId: newDepartmentId);

      expect(query['departmentId'], newDepartmentId);
    });
  });

  group('switching to another department', () {
    testWidgets('does not fetch until the access token has been swapped',
        (tester) async {
      final reloads = <String>[];
      final clears = <String>[];
      final departments = await _pumpScreen(
        tester,
        startOn: apacId,
        reloads: reloads,
        clears: clears,
      );

      departments.beginSwitch(talentAcquisitionId);
      await tester.pump();
      await tester.pump();

      // The rows are already gone, but nothing has been fetched: the API reads
      // the department from the token, and that is still APAC's. A request now
      // would answer with APAC's tasks and look entirely valid.
      expect(clears, hasLength(1));
      expect(reloads, isEmpty);

      departments.finishSwitch();
      await tester.pump();
      await tester.pump();

      expect(reloads, [talentAcquisitionId]);
    });

    testWidgets('fetches exactly once per switch', (tester) async {
      final reloads = <String>[];
      final clears = <String>[];
      final departments = await _pumpScreen(
        tester,
        startOn: apacId,
        reloads: reloads,
        clears: clears,
      );

      departments.beginSwitch(talentAcquisitionId);
      await tester.pump();
      // Several rebuilds while the swap is in flight must not pile up requests.
      departments.notifyListeners();
      await tester.pump();
      departments.notifyListeners();
      await tester.pump();
      departments.finishSwitch();
      await tester.pump();
      await tester.pump();

      expect(reloads, [talentAcquisitionId]);
      expect(clears, hasLength(1));
    });

    testWidgets('reloads every time, in both directions', (tester) async {
      final reloads = <String>[];
      final clears = <String>[];
      final departments = await _pumpScreen(
        tester,
        startOn: apacId,
        reloads: reloads,
        clears: clears,
      );

      for (final departmentId in [talentAcquisitionId, australiaId, apacId]) {
        departments.beginSwitch(departmentId);
        await tester.pump();
        await tester.pump();
        departments.finishSwitch();
        await tester.pump();
        await tester.pump();
      }

      expect(reloads, [talentAcquisitionId, australiaId, apacId]);
      expect(clears, hasLength(3));
    });

    testWidgets('a refused switch fetches back what it wiped', (tester) async {
      final reloads = <String>[];
      final clears = <String>[];
      final departments = await _pumpScreen(
        tester,
        startOn: apacId,
        reloads: reloads,
        clears: clears,
      );

      departments.beginSwitch(talentAcquisitionId);
      await tester.pump();
      await tester.pump();

      // The backend refuses and the provider reverts.
      departments.finishSwitch(revertTo: apacId);
      await tester.pump();
      await tester.pump();

      // The screen stays on APAC — and is not left empty.
      expect(reloads, [apacId]);
    });

    testWidgets('does not fetch on first build — initState already did',
        (tester) async {
      final reloads = <String>[];
      final clears = <String>[];
      await _pumpScreen(
        tester,
        startOn: talentAcquisitionId,
        reloads: reloads,
        clears: clears,
      );

      await tester.pump();

      expect(reloads, isEmpty);
      expect(clears, isEmpty);
    });
  });
}
