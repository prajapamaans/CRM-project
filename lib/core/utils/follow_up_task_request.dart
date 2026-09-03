/// Turns a task that was just completed into the body of the follow-up that
/// carries on from it.
///
/// Every field is read off the row `GET /api/activities` returned, and every
/// key is one `POST /api/activities` documents. Nothing is invented: a value
/// the original task does not carry is left out of the body entirely rather
/// than sent as a default the user never chose.
library;

/// Trimmed text, or null when the value is absent or one of the empty shapes a
/// JSON row uses.
String? readText(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty || text == 'null' ? null : text;
}

/// An id off a row that may spell the field either way, or nest the record.
String? readId(Map<String, dynamic> row, String camelCase, String snakeCase,
    String nested) {
  final direct = readText(row[camelCase]) ?? readText(row[snakeCase]);
  if (direct != null) return direct;

  final record = row[nested];
  if (record is Map) return readText(record['id']) ?? readText(record['_id']);
  return null;
}

/// The activity's own id.
String? activityId(Map<String, dynamic> row) =>
    readText(row['id']) ?? readText(row['_id']);

/// The task's title, as the popup and the follow-up both need to name it.
String? taskTitle(Map<String, dynamic> row) =>
    readText(row['title']) ?? readText(row['subject']);

/// The `associations` list for the follow-up: every record the original task
/// was linked to, primary links included, each named once.
List<Map<String, String>> followUpAssociations(Map<String, dynamic> original) {
  final list = <Map<String, String>>[];
  final seen = <String>{};

  void add(String? objectId, String? objectType) {
    final id = readText(objectId);
    final type = readText(objectType)?.toLowerCase();
    if (id == null || type == null) return;
    if (!const {'contact', 'company', 'deal'}.contains(type)) return;
    if (!seen.add('$type:$id')) return;
    list.add({'objectId': id, 'objectType': type});
  }

  add(readId(original, 'contactId', 'contact_id', 'contact'), 'contact');
  add(readId(original, 'companyId', 'company_id', 'company'), 'company');
  add(readId(original, 'dealId', 'deal_id', 'deal'), 'deal');

  final existing = original['associations'];
  if (existing is List) {
    for (final entry in existing) {
      if (entry is! Map) continue;
      add(
        readText(entry['objectId']) ?? readText(entry['object_id']),
        readText(entry['objectType']) ?? readText(entry['object_type']),
      );
    }
  }

  return list;
}

/// The body for `POST /api/activities` that creates [original]'s follow-up.
///
/// The follow-up keeps the original's name, description, owner, priority,
/// queue, reminder and every record it was linked to; only when it is due
/// changes. `status` is left out — the API only accepts it on an update, and a
/// new task starts pending.
Map<String, dynamic> buildFollowUpTaskPayload({
  required Map<String, dynamic> original,
  required DateTime scheduledAt,
}) {
  final associations = followUpAssociations(original);

  String? primary(String objectType) {
    for (final association in associations) {
      if (association['objectType'] == objectType) return association['objectId'];
    }
    return null;
  }

  final title = taskTitle(original);
  final description = readText(original['description']) ?? readText(original['notes']);
  final priority = readText(original['priority'])?.toLowerCase();
  final ownerId = readId(original, 'ownerId', 'owner_id', 'owner');
  final queue = readText(original['queue']);
  final reminderType = readText(original['reminderType']) ?? readText(original['reminder_type']);

  final contactId = primary('contact');
  final companyId = primary('company');
  final dealId = primary('deal');

  return <String, dynamic>{
    'type': 'task',
    'title': ?title,
    'description': ?description,
    'scheduledAt': scheduledAt.toUtc().toIso8601String(),
    if (priority != null && const {'none', 'low', 'medium', 'high'}.contains(priority))
      'priority': priority,
    'ownerId': ?ownerId,
    if (queue != null && queue != 'None') 'queue': queue,
    'reminderType': ?reminderType,
    'contactId': ?contactId,
    'companyId': ?companyId,
    'dealId': ?dealId,
    if (associations.isNotEmpty) 'associations': associations,
  };
}

/// The tag that marks a task as the follow-up to [originalTaskId].
///
/// The activities API has no parent field, but it does take arbitrary tags
/// (`POST /api/activities/:id/tags`), so this is the one way the link survives
/// on the server rather than only on the device that made it.
String followUpTag(String originalTaskId) => 'follow-up-of:$originalTaskId';

/// The task [row] follows up on, read back out of whatever tags the API
/// returned with it. Null when the row carries no such tag.
String? followUpParentIdFromTags(Map<String, dynamic> row) {
  final tags = row['tags'] ?? row['labels'];
  if (tags is! List) return null;

  for (final tag in tags) {
    final text = tag is Map
        ? readText(tag['tag']) ?? readText(tag['name']) ?? readText(tag['value'])
        : readText(tag);
    if (text == null) continue;
    if (text.startsWith('follow-up-of:')) {
      final id = text.substring('follow-up-of:'.length).trim();
      if (id.isNotEmpty) return id;
    }
  }
  return null;
}
