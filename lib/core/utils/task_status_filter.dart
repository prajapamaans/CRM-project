import '../models/master_dropdown_model.dart';

/// The three status choices on the Tasks screen.
///
/// The enum is only a label for the choice — the value sent to the API and
/// compared against a task comes from the backend's own `task_status` options,
/// with the status documented for `/api/activities` as the fallback when those
/// options have not loaded.
enum TaskStatusTab { all, pending, completed }

/// The status `/api/activities` documents for each tab, used only when the
/// backend's own `task_status` list has nothing matching.
const Map<TaskStatusTab, String> _documentedStatus = {
  TaskStatusTab.pending: 'pending',
  TaskStatusTab.completed: 'completed',
};

/// Puts a status into one shape for comparison. The API, the master dropdown
/// and the UI each spell the same status a little differently ("Completed",
/// "completed", "in progress", "in_progress").
String normalizeTaskStatus(String? raw) =>
    (raw ?? '').trim().toLowerCase().replaceAll(RegExp(r'[\s\-]+'), '_');

/// The value the backend uses for [tab].
///
/// [statusOptions] is the `task_status` master dropdown as the backend
/// publishes it; whichever option matches the tab supplies the value, so a
/// backend that spells its statuses differently is followed rather than
/// overruled. Returns null for [TaskStatusTab.all], which filters nothing.
String? taskStatusValueFor(
  TaskStatusTab tab, {
  List<MasterDropdownOptionModel> statusOptions = const [],
}) {
  final documented = _documentedStatus[tab];
  if (documented == null) return null;

  for (final option in statusOptions) {
    if (normalizeTaskStatus(option.value) == documented ||
        normalizeTaskStatus(option.label) == documented) {
      final value = option.value.trim().isNotEmpty ? option.value : option.label;
      if (value.trim().isNotEmpty) return value;
    }
  }
  return documented;
}

/// Whether a task whose API status is [status] belongs under [tab].
///
/// [TaskStatusTab.all] takes everything. The other two match the resolved
/// backend value exactly, so a status the tabs do not cover — `cancelled`,
/// `reopened` — shows up under All only.
bool taskStatusMatchesTab(
  String? status,
  TaskStatusTab tab, {
  List<MasterDropdownOptionModel> statusOptions = const [],
}) {
  if (tab == TaskStatusTab.all) return true;
  final wanted = taskStatusValueFor(tab, statusOptions: statusOptions);
  if (wanted == null) return true;
  return normalizeTaskStatus(status) == normalizeTaskStatus(wanted);
}
