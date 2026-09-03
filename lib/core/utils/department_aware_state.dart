import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/departments/presentation/providers/department_provider.dart';

/// Keeps a screen's own data in step with the selected department.
///
/// Screens that hold their list in local state (rather than in a provider that
/// [DepartmentProvider.changeDepartment] already reloads) have to notice the
/// switch themselves. Doing that by hand went wrong two ways: some screens
/// loaded once in `initState` and never reacted at all, and the ones that did
/// react left the previous department's rows on screen while the new request
/// was in flight.
///
/// Mix this in and call [watchDepartmentChanges] from `didChangeDependencies`.
mixin DepartmentAwareState<T extends StatefulWidget> on State<T> {
  String? _appliedDepartmentId;
  bool _switchInProgress = false;

  /// The department whose data this screen is currently showing.
  String? get appliedDepartmentId => _appliedDepartmentId;

  /// Runs [onChanged] when the selected department becomes something other
  /// than what this screen last loaded.
  ///
  /// It does not fire on the first resolve — the screen's own `initState` load
  /// already covers that, and firing here as well would double every request.
  /// It is safe to call on every `didChangeDependencies`.
  ///
  /// [onChanged] is deferred to after the current frame, so it may call
  /// `setState` to wipe the old rows before fetching the new ones.
  ///
  /// **It waits for the switch to finish before firing.** The selected id
  /// changes the moment the user picks a department, but the access token it
  /// depends on is swapped a network round trip later, and the API reads the
  /// department from that token rather than from the query — so a request sent
  /// in between comes back full of the department being *left*, and looks
  /// perfectly valid: the id it asked for and the id now selected agree, so
  /// nothing downstream can tell the rows are wrong.
  ///
  /// [onSwitchStarted] runs as soon as the switch begins, for wiping what is
  /// on screen so no rows from the old department are shown during the swap.
  /// If the switch is then refused, [onChanged] still runs for the department
  /// the screen stayed on, so what was wiped is fetched again.
  void watchDepartmentChanges(
    void Function(String departmentId) onChanged, {
    VoidCallback? onSwitchStarted,
  }) {
    final departments = context.watch<DepartmentProvider>();

    if (departments.isSwitchingDepartment) {
      if (!_switchInProgress) {
        _switchInProgress = true;
        debugPrint('[DEPARTMENT] ${widget.runtimeType} waiting for the token swap');
        if (onSwitchStarted != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) onSwitchStarted();
          });
        }
      }
      return;
    }

    final wasSwitching = _switchInProgress;
    _switchInProgress = false;

    final selected = departments.selectedDepartmentId;

    if (_appliedDepartmentId == selected) {
      // A switch that ended where it began — refused, or reverted. Anything
      // wiped when it started still has to be fetched back.
      if (wasSwitching && onSwitchStarted != null) {
        _scheduleReload(onChanged, selected, _appliedDepartmentId);
      }
      return;
    }

    final isFirstResolve = _appliedDepartmentId == null;
    final previous = _appliedDepartmentId;
    _appliedDepartmentId = selected;
    if (isFirstResolve) return;

    _scheduleReload(onChanged, selected, previous);
  }

  void _scheduleReload(
    void Function(String departmentId) onChanged,
    String selected,
    String? previous,
  ) {
    debugPrint(
      '[DEPARTMENT] ${widget.runtimeType} reloading: $previous → $selected',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) onChanged(selected);
    });
  }

  /// The selected department id, read without subscribing to changes. Use when
  /// building a request so the id is always the current one rather than
  /// whatever was captured in `initState`.
  String currentDepartmentId() =>
      context.read<DepartmentProvider>().selectedDepartmentId;
}
