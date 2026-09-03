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
          if (result.isNotEmpty) return _cleanBrackets(result);
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
          if (result.isNotEmpty) return _cleanBrackets(result);
        }

        if (decoded.containsKey('text') && decoded['text'] != null) {
          return _cleanBrackets(decoded['text'].toString().trim());
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

  if (str.startsWith('[') && str.endsWith(']')) {
    try {
      final decoded = jsonDecode(str);
      if (decoded is List) {
        final List<String> parts = [];
        for (var item in decoded) {
          if (item is String) {
            parts.add(item);
          } else if (item is Map && item.containsKey('text')) {
            parts.add(item['text'].toString());
          } else {
            final parsed = parseActivityDescription(item);
            if (parsed.isNotEmpty) parts.add(parsed);
          }
        }
        if (parts.isNotEmpty) {
          return _cleanBrackets(parts.join(' ').trim());
        }
      }
    } catch (_) {}
  }

  return _cleanBrackets(str);
}

String _cleanBrackets(String input) {
  var s = input.trim();
  if (s.startsWith('[') && s.endsWith(']')) {
    s = s.substring(1, s.length - 1).trim();
  }
  return s.replaceAll('[', '').replaceAll(']', '').trim();
}

/// Parses raw activity date or map into DateTime for consistent sorting (most recent first).
DateTime parseActivityDateTime(dynamic act) {
  if (act == null) return DateTime.fromMillisecondsSinceEpoch(0);
  if (act is DateTime) return act;
  if (act is Map) {
    final rawDate = act['updatedAt'] ??
        act['updated_at'] ??
        act['activityDate'] ??
        act['activity_date'] ??
        act['createdAt'] ??
        act['created_at'] ??
        act['scheduledAt'] ??
        act['scheduled_at'] ??
        act['date'];
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

/// Parses whatever an activity carries as a duration into whole minutes:
/// `30`, `'30'`, `'30m'`, `'30 Minutes'`, `'1 Hour'`, `'1h 30m'`.
/// Returns null when nothing sensible can be read.
int? parseDurationMinutes(dynamic raw) {
  if (raw == null) return null;
  if (raw is num) {
    final minutes = raw.round();
    return minutes > 0 ? minutes : null;
  }

  final text = raw.toString().trim().toLowerCase();
  if (text.isEmpty) return null;

  final plain = int.tryParse(text);
  if (plain != null) return plain > 0 ? plain : null;

  int total = 0;
  final hourMatch = RegExp(r'(\d+)\s*(h|hr|hrs|hour|hours)\b').firstMatch(text);
  if (hourMatch != null) total += int.parse(hourMatch.group(1)!) * 60;

  final minuteMatch = RegExp(r'(\d+)\s*(m|min|mins|minute|minutes)\b').firstMatch(text);
  if (minuteMatch != null) total += int.parse(minuteMatch.group(1)!);

  if (total == 0) {
    // A bare leading number, e.g. "45 (custom)".
    final leading = RegExp(r'^(\d+)').firstMatch(text);
    if (leading != null) total = int.parse(leading.group(1)!);
  }

  return total > 0 ? total : null;
}

/// Renders minutes with the same wording the duration pickers use, so a stored
/// value lines up with an existing option instead of showing as a stray entry.
String formatDurationLabel(int minutes) {
  if (minutes <= 0) return '15 Minutes';
  if (minutes % 60 == 0) {
    final hours = minutes ~/ 60;
    return hours == 1 ? '1 Hour' : '$hours Hours';
  }
  return '$minutes Minutes';
}

/// Parses an activity's scheduled date/time. Accepts ISO-8601 as well as the
/// `MM/dd/yyyy h:mm AM` text the call/meeting forms display.
DateTime? parseActivityDateTimeOrNull(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;

  final text = raw.toString().trim();
  if (text.isEmpty) return null;

  final iso = DateTime.tryParse(text);
  if (iso != null) return iso.isUtc ? iso.toLocal() : iso;

  final match = RegExp(
    r'^(\d{1,2})/(\d{1,2})/(\d{4})(?:\s+(\d{1,2}):(\d{2})\s*(AM|PM))?$',
    caseSensitive: false,
  ).firstMatch(text);
  if (match == null) return null;

  var hour = int.tryParse(match.group(4) ?? '0') ?? 0;
  final minute = int.tryParse(match.group(5) ?? '0') ?? 0;
  final period = match.group(6)?.toUpperCase();
  if (period != null) {
    hour = hour % 12;
    if (period == 'PM') hour += 12;
  }

  return DateTime(
    int.parse(match.group(3)!),
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    hour,
    minute,
  );
}

/// `MM/dd/yyyy h:mm AM` — the format the call and meeting start-time fields use.
String formatActivityDateTimeInput(DateTime dt) {
  final month = dt.month.toString().padLeft(2, '0');
  final day = dt.day.toString().padLeft(2, '0');
  var hour = dt.hour % 12;
  if (hour == 0) hour = 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  return '$month/$day/${dt.year} $hour:$minute $period';
}

/// Dynamic calculation of Last Activity Date from sorted activities list.
String formatLastActivityDateFromList(List<dynamic> activities, {String fallback = '--', bool multiLine = true}) {
  if (activities.isEmpty) return fallback;
  final top = activities.first;
  final dt = parseActivityDateTime(top);
  if (dt.millisecondsSinceEpoch == 0) return fallback;
  return formatActivityDateTime(dt.toLocal(), multiLine: multiLine);
}


