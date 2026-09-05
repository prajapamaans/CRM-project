import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../storage/secure_storage_service.dart';

/// The two ways a meeting comes into being.
///
/// [manual] is a meeting written down after the fact — the Log Meeting flow.
/// [directBooking] is a slot booked for a future date/time — the Create
/// Meeting flow. The meetings screen keeps the two lists apart by this value.
class BookingSource {
  BookingSource._();

  static const String manual = 'manual';
  static const String directBooking = 'direct_booking';

  /// A slot someone booked through a shared scheduler link. It reaches the
  /// same list as [directBooking] — from the user's side both are "a meeting
  /// that was booked", and only the way it was booked differs.
  static const String schedulerLink = 'scheduler_link';

  /// The `bookingSource` value the Create Meeting list asks for: both of the
  /// booked sources, comma separated, exactly as the endpoint accepts them.
  /// Asking for [directBooking] alone is what hid every meeting booked through
  /// a scheduler link.
  static const String createMeetingSources = '$directBooking,$schedulerLink';

  /// Maps the spellings the API (or an older build) may use onto the canonical
  /// values. Returns null when [raw] carries no usable value.
  static String? normalize(dynamic raw) {
    if (raw == null) return null;
    final value = raw.toString().trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
    if (value.isEmpty) return null;
    if (value == 'direct_booking' || value == 'directbooking' || value == 'direct') {
      return directBooking;
    }
    if (value == 'scheduler_link' ||
        value == 'schedulerlink' ||
        value == 'scheduler' ||
        value == 'meeting_scheduler') {
      return schedulerLink;
    }
    if (value == 'manual' || value == 'log' || value == 'logged' || value == 'manual_log') {
      return manual;
    }
    return null;
  }

  /// Whether [raw] is one of the sources the Create Meeting list shows.
  static bool isBooked(dynamic raw) {
    final value = normalize(raw);
    return value == directBooking || value == schedulerLink;
  }
}

/// Remembers which meetings were booked (Create) rather than logged (Log).
///
/// The activity POST carries `bookingSource`, but not every deployment echoes
/// it back on `GET /api/activities`. Without a fallback an untagged record has
/// to be guessed at, and guessing "whichever list is open" puts every meeting
/// in both lists. This registry keeps the answer for anything created from
/// this app; anything else falls back to [BookingSource.manual], so the Log
/// Meeting list keeps showing exactly what it showed before.
class MeetingBookingSourceStore {
  MeetingBookingSourceStore._();

  static const String _storageKey = 'meeting_booking_sources';

  static final SecureStorageService _storage = SecureStorageService();
  static final Map<String, String> _cache = {};
  static Future<void>? _loading;
  static bool _loaded = false;

  /// Reads the registry off disk once. Safe to call on every list load.
  static Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    return _loading ??= _load();
  }

  static Future<void> _load() async {
    try {
      final jsonStr = await _storage.getString(_storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            final id = key.toString();
            final source = BookingSource.normalize(value);
            if (id.isNotEmpty && source != null) _cache[id] = source;
          });
        }
      }
    } catch (e) {
      debugPrint('[MeetingBookingSourceStore load error]: $e');
    } finally {
      _loaded = true;
      _loading = null;
    }
  }

  /// Records the booking source of a meeting the app just saved.
  static Future<void> remember(String? activityId, String? bookingSource) async {
    final id = activityId?.trim();
    final source = BookingSource.normalize(bookingSource);
    if (id == null || id.isEmpty || source == null) return;

    await ensureLoaded();
    if (_cache[id] == source) return;
    _cache[id] = source;

    try {
      await _storage.saveString(_storageKey, jsonEncode(_cache));
    } catch (e) {
      debugPrint('[MeetingBookingSourceStore save error]: $e');
    }
  }

  /// The remembered booking source for [activityId], or null if unknown.
  /// Synchronous — call [ensureLoaded] before relying on it.
  static String? remembered(String? activityId) {
    final id = activityId?.trim();
    if (id == null || id.isEmpty) return null;
    return _cache[id];
  }
}

/// True when this meeting carries no outcome.
///
/// The Log Meeting form always writes one — the picker cannot be left blank —
/// while a booked meeting has none until it has happened. So on a record the
/// API did not tag, an absent outcome is the one signal that says "booked".
bool _hasNoOutcome(Map<String, dynamic> activity) =>
    (activity['outcome'] ?? '').toString().trim().isEmpty;

/// Whether [activities] can be classified by [_hasNoOutcome].
///
/// The inference only means anything if the endpoint actually returns
/// `outcome`. If the field is absent from every record in the page it is being
/// left out of the response rather than genuinely empty, and inferring would
/// sweep every logged meeting into the booked list.
///
/// This asks whether the *key* is there, not whether it holds a value: a page
/// of nothing but booked meetings has `outcome: null` throughout, and that is
/// a page the inference must still work on.
bool canInferBookingSourceFromOutcome(List<Map<String, dynamic>> activities) =>
    activities.any((a) => a.containsKey('outcome'));

/// The booking source of an activity payload: the value the API returned when
/// it returned one, otherwise what this device remembers saving, otherwise —
/// with [inferFromOutcome] set — a guess from the missing outcome, otherwise
/// [BookingSource.manual], the source every meeting had before Create Meeting
/// existed.
///
/// Pass [inferFromOutcome] only when [canInferBookingSourceFromOutcome] says
/// the page supports it. It is what puts meetings booked before the app
/// started tagging them back in the Create Meeting list.
String resolveBookingSource(
  Map<String, dynamic>? activity, {
  bool inferFromOutcome = false,
}) {
  if (activity == null) return BookingSource.manual;

  // What the API says wins: `GET /api/activities?bookingSource=direct_booking`
  // tags every row it returns, so a stale local guess can never override it.
  final fromApi = BookingSource.normalize(
    activity['bookingSource'] ?? activity['booking_source'],
  );
  if (fromApi != null) return fromApi;

  final id = (activity['id'] ?? activity['_id'])?.toString();
  final remembered = MeetingBookingSourceStore.remembered(id);
  if (remembered != null) return remembered;

  if (inferFromOutcome && _hasNoOutcome(activity)) {
    return BookingSource.directBooking;
  }

  return BookingSource.manual;
}
