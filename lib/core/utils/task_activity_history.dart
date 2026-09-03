/// The history of a single task, read out of the task itself.
///
/// The activities API keeps no audit log, so every entry here is anchored to a
/// timestamp the row genuinely carries — `createdAt`, `updatedAt`,
/// `completedAt`, and the same three on the follow-ups that came out of it. An
/// event with no timestamp behind it is not listed at all: a history that
/// invents when something happened is worse than a short one.
library;

import 'activity_task_fields.dart';
import 'follow_up_task_request.dart';

enum TaskHistoryKind {
  created,
  updated,
  completed,
  reopened,
  cancelled,
  followUpCreated,
  followUpCompleted,
}

class TaskHistoryEntry {
  /// What happened.
  final TaskHistoryKind kind;

  /// The heading, e.g. `Task completed`.
  final String title;

  /// The line under it — who, what or when — or null when the row named none.
  final String? detail;

  /// When it happened, in local time.
  final DateTime at;

  const TaskHistoryEntry({
    required this.kind,
    required this.title,
    required this.at,
    this.detail,
  });
}

DateTime? _localDate(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw.isUtc ? raw.toLocal() : raw;

  final text = raw.toString().trim();
  if (text.isEmpty || text == 'null') return null;
  final parsed = DateTime.tryParse(text);
  return parsed == null ? null : (parsed.isUtc ? parsed.toLocal() : parsed);
}

DateTime? _createdAt(Map<String, dynamic> row) =>
    _localDate(row['createdAt'] ?? row['created_at']);

DateTime? _updatedAt(Map<String, dynamic> row) =>
    _localDate(row['updatedAt'] ?? row['updated_at']);

String _status(Map<String, dynamic> row) =>
    (row['status'] ?? '').toString().trim().toLowerCase();

/// When the task was finished. Prefers the API's own `completedAt`; falls back
/// to `updatedAt` — the instant the row was last written, which for a task
/// that reads as completed is the write that completed it. Null unless the
/// task really is completed, so nothing dates a completion that never happened.
DateTime? taskCompletedAt(Map<String, dynamic> row) {
  final stamped = _localDate(row['completedAt'] ?? row['completed_at']);
  if (stamped != null) return stamped;
  return _status(row) == 'completed' ? _updatedAt(row) : null;
}

/// Two timestamps within a second of each other are the same write.
bool _sameInstant(DateTime a, DateTime b) =>
    a.difference(b).inSeconds.abs() < 1;

/// The history of [task], oldest first.
///
/// [followUps] are the tasks created as follow-ups to it, in whatever order;
/// each contributes the moment it was created and, if it has since been
/// finished, the moment it was completed.
List<TaskHistoryEntry> buildTaskActivityHistory(
  Map<String, dynamic> task, {
  List<Map<String, dynamic>> followUps = const [],
}) {
  final entries = <TaskHistoryEntry>[];

  final createdAt = _createdAt(task);
  final updatedAt = _updatedAt(task);
  final completedAt = taskCompletedAt(task);
  final status = _status(task);

  if (createdAt != null) {
    final assignee = activityAssigneeLabel(task);
    entries.add(TaskHistoryEntry(
      kind: TaskHistoryKind.created,
      title: 'Task created',
      // The row records who holds the task but not when it was handed to
      // them, so the assignment rides along with the creation rather than
      // becoming an event with a made-up time of its own.
      detail: assignee == null ? null : 'Assigned to $assignee',
      at: createdAt,
    ));
  }

  // An edit only counts when the row was written again after it was created,
  // and when that write was not itself the completion or the reopening below.
  final isCompletionWrite =
      completedAt != null && updatedAt != null && _sameInstant(updatedAt, completedAt);
  final isStatusWrite = isCompletionWrite ||
      status == 'reopened' ||
      status == 'cancelled';

  if (updatedAt != null &&
      createdAt != null &&
      !_sameInstant(updatedAt, createdAt) &&
      updatedAt.isAfter(createdAt) &&
      !isStatusWrite) {
    entries.add(TaskHistoryEntry(
      kind: TaskHistoryKind.updated,
      title: 'Task updated',
      at: updatedAt,
    ));
  }

  if (completedAt != null) {
    entries.add(TaskHistoryEntry(
      kind: TaskHistoryKind.completed,
      title: 'Task completed',
      at: completedAt,
    ));
  } else if (status == 'reopened' && updatedAt != null) {
    entries.add(TaskHistoryEntry(
      kind: TaskHistoryKind.reopened,
      title: 'Task reopened',
      at: updatedAt,
    ));
  } else if (status == 'cancelled' && updatedAt != null) {
    entries.add(TaskHistoryEntry(
      kind: TaskHistoryKind.cancelled,
      title: 'Task cancelled',
      at: updatedAt,
    ));
  }

  for (final followUp in followUps) {
    final followUpCreatedAt = _createdAt(followUp);
    final due = activityDueLabel(followUp);
    if (followUpCreatedAt != null) {
      entries.add(TaskHistoryEntry(
        kind: TaskHistoryKind.followUpCreated,
        title: 'Follow-up task created',
        detail: due == null ? taskTitle(followUp) : 'Due $due',
        at: followUpCreatedAt,
      ));
    }

    final followUpCompletedAt = taskCompletedAt(followUp);
    if (followUpCompletedAt != null) {
      entries.add(TaskHistoryEntry(
        kind: TaskHistoryKind.followUpCompleted,
        title: 'Follow-up task completed',
        detail: taskTitle(followUp),
        at: followUpCompletedAt,
      ));
    }
  }

  entries.sort((a, b) => a.at.compareTo(b.at));
  return entries;
}
