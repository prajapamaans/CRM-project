/// The date and time arithmetic behind a follow-up.
///
/// The task form already worked out what "in 3 business days" means; this
/// library is the one copy of that arithmetic, so the follow-up popup and the
/// task form can never drift apart on the date they land on.
library;

const List<String> _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const List<String> _monthAbbrs = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// [moment] with the time of day dropped.
DateTime startOfDay(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);

/// The weekday [date] falls on, spelled out.
String weekdayName(DateTime date) => _weekdayNames[date.weekday - 1];

/// The month [date] falls in, abbreviated.
String monthAbbr(DateTime date) => _monthAbbrs[date.month - 1];

/// [days] working days after [start]. Saturdays and Sundays are stepped over
/// rather than counted, so a Wednesday plus three business days is the Monday
/// after — not the Saturday.
DateTime addBusinessDays(DateTime start, int days) {
  var current = startOfDay(start);
  var added = 0;
  while (added < days) {
    current = current.add(const Duration(days: 1));
    if (current.weekday != DateTime.saturday &&
        current.weekday != DateTime.sunday) {
      added++;
    }
  }
  return current;
}

/// [months] calendar months after [start], clamped to the last day of the
/// target month so 31 January plus one month is 28 February, not 3 March.
DateTime addMonths(DateTime start, int months) {
  var year = start.year;
  var month = start.month + months;
  while (month > 12) {
    month -= 12;
    year += 1;
  }
  final daysInMonth = DateTime(year, month + 1, 0).day;
  final day = start.day > daysInMonth ? daysInMonth : start.day;
  return DateTime(year, month, day);
}

/// One entry in the follow-up date menu. [date] is null for the "Custom Date"
/// entry, which opens a picker instead of standing for a date of its own.
class FollowUpDateOption {
  final String label;
  final DateTime? date;

  const FollowUpDateOption(this.label, this.date);

  bool get isCustom => date == null;
}

/// The dates the follow-up popup offers, all measured from [from] (defaults to
/// today), so the labels name the days they actually land on.
List<FollowUpDateOption> followUpDateOptions({DateTime? from}) {
  final today = startOfDay(from ?? DateTime.now());

  final in2Biz = addBusinessDays(today, 2);
  final in3Biz = addBusinessDays(today, 3);
  final in1Week = today.add(const Duration(days: 7));
  final in2Weeks = today.add(const Duration(days: 14));
  final in1Month = addMonths(today, 1);
  final in3Months = addMonths(today, 3);
  final in6Months = addMonths(today, 6);

  String dayAndMonth(DateTime date) => '${monthAbbr(date)} ${date.day}';

  return [
    FollowUpDateOption('Today', today),
    FollowUpDateOption('Tomorrow', today.add(const Duration(days: 1))),
    FollowUpDateOption('In 2 business days (${weekdayName(in2Biz)})', in2Biz),
    FollowUpDateOption('In 3 business days (${weekdayName(in3Biz)})', in3Biz),
    FollowUpDateOption('In 1 week (${dayAndMonth(in1Week)})', in1Week),
    FollowUpDateOption('In 2 weeks (${dayAndMonth(in2Weeks)})', in2Weeks),
    FollowUpDateOption('In 1 month (${dayAndMonth(in1Month)})', in1Month),
    FollowUpDateOption('In 3 months (${dayAndMonth(in3Months)})', in3Months),
    FollowUpDateOption('In 6 months (${dayAndMonth(in6Months)})', in6Months),
    const FollowUpDateOption('Custom Date', null),
  ];
}

/// Where the popup starts: three business days after the task was finished.
DateTime defaultFollowUpDate({DateTime? from}) =>
    addBusinessDays(from ?? DateTime.now(), 3);

/// How [date] reads on the popup's date button.
///
/// A date that is one of the offered options is named the way the menu names
/// it; any other date is spelled out with the weekday it genuinely falls on.
/// Either way the day shown is worked out from the date, never assumed.
String followUpDateLabel(DateTime date, {DateTime? from}) {
  final target = startOfDay(date);
  for (final option in followUpDateOptions(from: from)) {
    if (option.date == target) return option.label;
  }
  return '${monthAbbr(target)} ${target.day}, ${target.year} '
      '(${weekdayName(target)})';
}

/// A time of day as the pickers write it — `08:00 AM` when [padHour], else
/// `8:00 AM`, which is how the task form writes it.
String formatTimeLabel(int hour, int minute, {bool padHour = false}) {
  final hourOfPeriod = hour % 12 == 0 ? 12 : hour % 12;
  final shown =
      padHour ? hourOfPeriod.toString().padLeft(2, '0') : '$hourOfPeriod';
  return '$shown:${minute.toString().padLeft(2, '0')} ${hour < 12 ? 'AM' : 'PM'}';
}

/// [moment]'s time of day, in the same wording.
String formatTimeOfDay(DateTime moment, {bool padHour = false}) =>
    formatTimeLabel(moment.hour, moment.minute, padHour: padHour);

/// Every quarter hour of the day, for the time menu.
List<String> followUpTimeOptions({bool padHour = false}) {
  return [
    for (var hour = 0; hour < 24; hour++)
      for (var minute = 0; minute < 60; minute += 15)
        formatTimeLabel(hour, minute, padHour: padHour),
  ];
}

/// Reads a `h:mm AM` or `hh:mm AM` label back into a time of day. Null when the
/// text is not a time — the caller decides what to do rather than being handed
/// a silent 8am.
({int hour, int minute})? parseTimeLabel(String label) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false)
      .firstMatch(label.trim());
  if (match == null) return null;

  final rawHour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (rawHour < 1 || rawHour > 12 || minute > 59) return null;

  var hour = rawHour % 12;
  if (match.group(3)!.toUpperCase() == 'PM') hour += 12;
  return (hour: hour, minute: minute);
}

/// The chosen day and the chosen time as the single local instant the task is
/// due at. An unreadable [timeLabel] leaves the date's own time of day alone.
DateTime combineDateAndTime(DateTime date, String timeLabel) {
  final time = parseTimeLabel(timeLabel);
  if (time == null) return date;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
