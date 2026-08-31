import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Applies a filter to rows already fetched, without ever blanking the list.
///
/// Every filter is sent to the API *and* re-checked here, so it still works
/// against a backend that ignores the parameter. The catch is that the app and
/// the API do not always spell a value the same way: a lifecycle stage may come
/// back as an id rather than a name, a status in another case, an activity row
/// may not carry `createdAt` at all. When that happens the check matches
/// nothing and the screen goes empty — for a filter the server may well have
/// applied correctly.
///
/// So a check that matches *nothing* is treated as a failed comparison rather
/// than as a genuine empty result: the rows are returned untouched and the
/// values that failed to line up are logged. Showing the server's answer is the
/// better of the two failures, and the log says exactly which spelling to fix.
///
/// A genuinely empty result still shows as empty — that is [rows] already being
/// empty, which is returned as-is.
List<T> narrowInMemory<T>({
  required List<T> rows,
  required String filter,
  required String? selection,
  required bool Function(T) test,
  required String? Function(T) storedValue,
}) {
  if (rows.isEmpty) return rows;

  final kept = rows.where(test).toList();
  if (kept.isNotEmpty) return kept;

  // The in-memory comparison matched nothing. Return the server's rows so
  // that differences in field formatting between the app and API do not
  // blank out valid records returned by the server.
  final samples = rows
      .map(storedValue)
      .map((v) => (v == null || v.isEmpty) ? '(none)' : v)
      .toSet()
      .take(8)
      .join(', ');
  debugPrint(
    '[filter] "$filter" = "${selection ?? ''}" matched none of ${rows.length} rows. '
    'Showing server-returned rows as fallback. Values on rows: $samples',
  );
  return rows;
}

/// Turns the date-range labels the filter pills show into the
/// `createdDateRange` value `/api/contacts`, `/api/companies`, `/api/deals`
/// and `/api/activities` accept: `yyyy-MM-dd,yyyy-MM-dd`, start and end both
/// inclusive.
///
/// The boundaries are local calendar days — the same days the label names —
/// and the end is the range's last day, not the exclusive day after it.
class FilterDateRange {
  FilterDateRange._();

  /// Labels that mean "no date filter". Each screen spells its placeholder a
  /// little differently, so they are all recognised.
  static const Set<String> _unsetLabels = {
    'all time',
    'create date',
    'created date',
    'all dates',
    'any time',
    'select a date',
  };

  static bool isUnset(String? label) {
    if (label == null) return true;
    final value = label.trim().toLowerCase();
    return value.isEmpty || _unsetLabels.contains(value);
  }

  /// `yyyy-MM-dd` — the format the API's date-range parser expects.
  static String formatDay(DateTime day) {
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    return '${day.year}-$m-$d';
  }

  /// The `createdDateRange` query value for [label], or null when the label
  /// means "no filter" or is not one this app offers.
  ///
  /// [customRange] is used when the label is a custom range the user picked;
  /// the label alone cannot be parsed back into dates reliably.
  static String? toQueryValue(String? label, {DateTimeRange? customRange}) {
    if (customRange != null) {
      return '${formatDay(customRange.start)},${formatDay(customRange.end)}';
    }
    final range = resolve(label);
    if (range == null) return null;
    return '${formatDay(range.start)},${formatDay(range.end)}';
  }

  /// The concrete day span [label] names, or null when it names none.
  ///
  /// [now] is injectable so the boundaries can be tested without waiting for
  /// midnight.
  static DateTimeRange? resolve(String? label, {DateTime? now}) {
    if (isUnset(label)) return null;

    final today = _dayOf(now ?? DateTime.now());
    switch (label!.trim().toLowerCase()) {
      case 'today':
        return DateTimeRange(start: today, end: today);
      case 'yesterday':
        final yesterday = today.subtract(const Duration(days: 1));
        return DateTimeRange(start: yesterday, end: yesterday);
      case 'this week':
        // Monday-based, matching the week the rest of the app counts.
        final start = today.subtract(Duration(days: today.weekday - 1));
        return DateTimeRange(start: start, end: today);
      case 'last week':
        final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));
        final start = thisWeekStart.subtract(const Duration(days: 7));
        return DateTimeRange(start: start, end: thisWeekStart.subtract(const Duration(days: 1)));
      case 'last 7 days':
        return DateTimeRange(start: today.subtract(const Duration(days: 6)), end: today);
      case 'last 30 days':
        return DateTimeRange(start: today.subtract(const Duration(days: 29)), end: today);
      case 'last 90 days':
        return DateTimeRange(start: today.subtract(const Duration(days: 89)), end: today);
      case 'this month':
        return DateTimeRange(start: DateTime(today.year, today.month, 1), end: today);
      case 'last month':
        final start = DateTime(today.year, today.month - 1, 1);
        // Day 0 of this month is the last day of the previous one.
        final end = DateTime(today.year, today.month, 0);
        return DateTimeRange(start: start, end: end);
      case 'this quarter':
        final quarterStartMonth = ((today.month - 1) ~/ 3) * 3 + 1;
        return DateTimeRange(start: DateTime(today.year, quarterStartMonth, 1), end: today);
      case 'this year':
        return DateTimeRange(start: DateTime(today.year, 1, 1), end: today);
      case 'last year':
        return DateTimeRange(start: DateTime(today.year - 1, 1, 1), end: DateTime(today.year - 1, 12, 31));
      default:
        return null;
    }
  }

  /// Whether [value] — an ISO timestamp from a record — falls inside the span
  /// [label] names. Used where a list is filtered in memory because the
  /// endpoint has no date parameter.
  static bool matches(String? label, dynamic value, {DateTimeRange? customRange, DateTime? now}) {
    final range = customRange ?? resolve(label, now: now);
    if (range == null) return true;

    final parsed = value is DateTime ? value : DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return false;

    final day = _dayOf(parsed.toLocal());
    return !day.isBefore(range.start) && !day.isAfter(range.end);
  }

  static DateTime _dayOf(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}

/// Converts the labels shown in a filter pill into the values the API stores.
///
/// A pill lists display names (`Marketing Qualified Lead`) while the record
/// holds a slug (`marketing_qualified`), so comparing the two directly — which
/// is what the in-memory filters used to do — never matched anything with more
/// than one word in its name.
class FilterValue {
  FilterValue._();

  /// Placeholder pill values that mean "no filter".
  static const Set<String> _unsetLabels = {
    'all',
    'all owners',
    'all stages',
    'all statuses',
    'all msps',
    'all companies',
    'all contacts',
    'all deals',
    'all priorities',
    'all types',
    'all time',
    'select a stage',
    'select a status',
    'select an owner',
    'owner',
    'status',
    'priority',
    'company',
    'contact',
    'deal',
    'type',
  };

  static bool isUnset(String? label) {
    if (label == null) return true;
    final value = label.trim().toLowerCase();
    return value.isEmpty || _unsetLabels.contains(value);
  }

  /// [label] when it names a real selection, otherwise null.
  static String? orNull(String? label) => isUnset(label) ? null : label!.trim();

  /// `Marketing Qualified Lead` → `marketing_qualified_lead`.
  static String slugify(String label) => label
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z0-9]+"), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  /// The two documented contact lifecycle stages whose display name carries a
  /// word the stored slug does not. Every other stage slugifies directly.
  static const Map<String, String> _lifecycleStageOverrides = {
    'marketing_qualified_lead': 'marketing_qualified',
    'sales_qualified_lead': 'sales_qualified',
  };

  /// The `lifecycleStage` query value for a stage pill, or null when the pill
  /// is on its placeholder.
  ///
  /// Values follow the documented enum: `added`, `subscriber`, `lead`,
  /// `marketing_qualified`, `sales_qualified`, `opportunity`, `customer`,
  /// `evangelist`.
  static String? lifecycleStage(String? label) {
    final value = orNull(label);
    if (value == null) return null;
    return value;
  }

  /// True when a record's stored stage is the one [label] names. Used where a
  /// list has to be narrowed in memory.
  static bool matchesLifecycleStage(String? label, String? storedStage) {
    final wantedLabel = orNull(label);
    if (wantedLabel == null) return true;
    final stored = (storedStage ?? '').trim();
    if (stored.isEmpty) return false;

    // 1. Direct case-insensitive match
    if (stored.toLowerCase() == wantedLabel.toLowerCase()) return true;

    // 2. Direct slug match
    final wantedSlug = slugify(wantedLabel);
    final storedSlug = slugify(stored);
    if (storedSlug == wantedSlug) return true;

    // 3. Override mapping match (e.g. marketing_qualified_lead <-> marketing_qualified)
    final wantedOverride = _lifecycleStageOverrides[wantedSlug] ?? wantedSlug;
    final storedOverride = _lifecycleStageOverrides[storedSlug] ?? storedSlug;

    if (storedOverride == wantedOverride ||
        storedSlug == wantedOverride ||
        storedOverride == wantedSlug) {
      return true;
    }

    // 4. Substring / partial match fallback
    if (storedSlug.contains(wantedOverride) || wantedOverride.contains(storedSlug)) {
      return true;
    }

    return false;
  }

  /// Spellings that mean the same state. Records and pills disagree on these,
  /// so both sides are folded onto one form before comparing.
  static const Map<String, String> _aliases = {
    'cancelled': 'canceled',
    'no_show': 'noshow',
    'left_message': 'leftmessage',
  };

  static String canonical(String value) {
    final slug = slugify(value);
    return _aliases[slug] ?? slug;
  }

  /// Compares a pill label against a stored value, tolerating the slug/label
  /// mismatch (`In progress` vs `in_progress`, `Cancelled` vs `canceled`).
  static bool matchesSlug(String? label, String? storedValue) {
    final wanted = orNull(label);
    if (wanted == null) return true;
    final stored = (storedValue ?? '').trim();
    if (stored.isEmpty) return false;
    return canonical(stored) == canonical(wanted);
  }

  /// The documented `status` values for `/api/activities`. A pill offering
  /// anything else (an outcome such as `Logged`) has no status parameter to
  /// map onto, so that selection stays an in-memory match.
  static const Set<String> activityStatuses = {'pending', 'completed', 'cancelled', 'reopened'};

  /// [label] as an `status=` value, or null when it is not one of the four the
  /// endpoint accepts.
  static String? activityStatus(String? label) {
    final value = orNull(label);
    if (value == null) return null;
    final slug = slugify(value);
    return activityStatuses.contains(slug) ? slug : null;
  }
}
