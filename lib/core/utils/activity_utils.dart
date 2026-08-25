import 'dart:convert';

/// Parses raw activity description or notes strings (including TipTap JSON,
/// Quill Delta JSON, or raw plain text) into clean, bracket-free text.
String parseActivityDescription(dynamic rawDescription) {
  if (rawDescription == null) return '';
  String str = rawDescription.toString().trim();
  if (str.isEmpty) return '';

  if (str.startsWith('{') && str.endsWith('}')) {
    try {
      final decoded = jsonDecode(str);
      if (decoded is Map<String, dynamic>) {
        // 1. TipTap / ProseMirror schema: {"type":"doc", "content":[...]}
        if (decoded.containsKey('content') && decoded['content'] is List) {
          final StringBuffer sb = StringBuffer();
          void extractText(dynamic node) {
            if (node is Map<String, dynamic>) {
              if (node.containsKey('text') && node['text'] != null) {
                sb.write(node['text']);
              }
              if (node.containsKey('content') && node['content'] is List) {
                for (var child in node['content']) {
                  extractText(child);
                }
              }
            }
          }
          for (var item in (decoded['content'] as List)) {
            extractText(item);
          }
          final result = sb.toString().trim();
          if (result.isNotEmpty) return result;
        }

        // 2. Quill Delta schema: {"ops":[{"insert":"..."}]}
        if (decoded.containsKey('ops') && decoded['ops'] is List) {
          final StringBuffer sb = StringBuffer();
          for (var op in (decoded['ops'] as List)) {
            if (op is Map && op.containsKey('insert')) {
              sb.write(op['insert']);
            }
          }
          final result = sb.toString().trim();
          if (result.isNotEmpty) return result;
        }

        if (decoded.containsKey('text') && decoded['text'] != null) {
          return decoded['text'].toString().trim();
        }
        if (decoded.containsKey('notes')) {
          return parseActivityDescription(decoded['notes']);
        }
        if (decoded.containsKey('description')) {
          return parseActivityDescription(decoded['description']);
        }
        if (decoded.containsKey('body')) {
          return parseActivityDescription(decoded['body']);
        }
      }
    } catch (_) {}
  }
  return str;
}

/// Parses raw activity date or map into DateTime for consistent sorting (most recent first).
DateTime parseActivityDateTime(dynamic act) {
  if (act == null) return DateTime.fromMillisecondsSinceEpoch(0);
  if (act is DateTime) return act;
  if (act is Map) {
    final rawDate = act['activityDate'] ??
        act['activity_date'] ??
        act['createdAt'] ??
        act['created_at'] ??
        act['scheduledAt'] ??
        act['scheduled_at'] ??
        act['date'] ??
        act['updatedAt'] ??
        act['updated_at'];
    if (rawDate != null) return parseActivityDateTime(rawDate);
  }
  final str = act.toString().trim();
  if (str.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
  return DateTime.tryParse(str) ?? DateTime.fromMillisecondsSinceEpoch(0);
}

/// Formats a DateTime object into a clean timestamp string (e.g. 08/24/2026 \n 6:10 PM \n GMT+5:30).
String formatActivityDateTime(DateTime dt, {bool multiLine = true}) {
  final month = dt.month.toString().padLeft(2, '0');
  final day = dt.day.toString().padLeft(2, '0');
  final year = dt.year;

  int hour = dt.hour;
  final period = hour >= 12 ? 'PM' : 'AM';
  hour = hour % 12;
  if (hour == 0) hour = 12;
  final minute = dt.minute.toString().padLeft(2, '0');

  final timeStr = '$hour:$minute $period';
  final offsetHours = dt.timeZoneOffset.inHours;
  final offsetMinutes = (dt.timeZoneOffset.inMinutes % 60).abs().toString().padLeft(2, '0');
  final offsetSign = dt.timeZoneOffset.isNegative ? '-' : '+';
  final tzStr = 'GMT$offsetSign${offsetHours.abs().toString().padLeft(2, '0')}:$offsetMinutes';

  if (multiLine) {
    return '$month/$day/$year\n$timeStr\n$tzStr';
  }
  return '$month/$day/$year $timeStr $tzStr';
}

/// Dynamic calculation of Last Activity Date from sorted activities list.
String formatLastActivityDateFromList(List<dynamic> activities, {String fallback = '--', bool multiLine = true}) {
  if (activities.isEmpty) return fallback;
  final top = activities.first;
  final dt = parseActivityDateTime(top);
  if (dt.millisecondsSinceEpoch == 0) return fallback;
  return formatActivityDateTime(dt.toLocal(), multiLine: multiLine);
}


