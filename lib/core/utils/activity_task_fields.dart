import 'activity_utils.dart';

/// Reads the display fields off an activity row exactly as `/api/activities`
/// returns it. Every helper answers null when the row does not carry the
/// value, so the screen can leave the line out instead of inventing one.

String? _text(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty || text == 'null' ? null : text;
}

/// A person's name out of whatever shape the row holds them in.
String? _personName(dynamic person) {
  if (person == null) return null;
  if (person is String) return _text(person);
  if (person is Map) {
    final map = Map<String, dynamic>.from(person);
    final direct = _text(map['name']) ?? _text(map['fullName']) ?? _text(map['displayName']);
    if (direct != null) return direct;

    final first = _text(map['firstName']) ?? _text(map['first_name']) ?? '';
    final last = _text(map['lastName']) ?? _text(map['last_name']) ?? '';
    final joined = '$first $last'.trim();
    if (joined.isNotEmpty) return joined;

    // Some rows nest the person under `user`.
    final nested = _personName(map['user']);
    if (nested != null) return nested;

    return _text(map['email']);
  }
  return null;
}

/// Who the task is assigned to: its `assignees` if it has any, otherwise its
/// owner, otherwise whoever created it. Null when the row names nobody —
/// which must not be dressed up as a real person.
String? activityAssigneeLabel(Map<String, dynamic> row) {
  final assignees = row['assignees'];
  if (assignees is List && assignees.isNotEmpty) {
    final names = assignees.map(_personName).whereType<String>().toList();
    if (names.length == 1) return names.single;
    if (names.length > 1) return '${names.first} +${names.length - 1}';
  }

  return _personName(row['owner']) ??
      _text(row['ownerName']) ??
      _text(row['assignedTo']) ??
      _personName(row['creator']) ??
      _text(row['creatorName']);
}

/// The record the task hangs off — its contact, company or deal.
String? activityRelatedRecordLabel(Map<String, dynamic> row) {
  // `recipientName` is what the list response calls the contact on the other
  // side of the activity; rows carry it instead of `contactName`.
  final contact = _text(row['contactName']) ??
      _text(row['recipientName']) ??
      _personName(row['contact']);
  if (contact != null) return contact;

  final company = _text(row['companyName']) ??
      _text(row['company'] is Map ? (row['company'] as Map)['name'] : null);
  if (company != null) return company;

  final deal = _text(row['dealName']) ??
      _text(row['deal'] is Map
          ? ((row['deal'] as Map)['title'] ?? (row['deal'] as Map)['name'])
          : null);
  return deal;
}

/// When the task is scheduled, as `MM/dd/yyyy h:mm AM`. Null when the row
/// carries no date — no placeholder date is made up for it.
String? activityDueLabel(Map<String, dynamic> row) {
  final raw = row['scheduledAt'] ??
      row['dueDate'] ??
      row['due_date'] ??
      row['scheduled_at'] ??
      row['completedAt'];
  final parsed = parseActivityDateTimeOrNull(raw);
  if (parsed == null) return null;
  return formatActivityDateTimeInput(parsed.toLocal());
}
