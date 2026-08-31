import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crmproject/core/utils/filter_query_utils.dart';

void main() {
  // A fixed "now" so the boundaries are checkable: Wednesday 2026-08-19.
  final now = DateTime(2026, 8, 19, 14, 30);

  group('FilterDateRange.isUnset', () {
    test('recognises every placeholder the pills use', () {
      for (final label in [
        null,
        '',
        '  ',
        'All time',
        'Create date',
        'all dates',
        'Any time',
      ]) {
        expect(FilterDateRange.isUnset(label), isTrue, reason: 'label: $label');
      }
    });

    test('a real range is not unset', () {
      expect(FilterDateRange.isUnset('Today'), isFalse);
      expect(FilterDateRange.isUnset('This month'), isFalse);
    });
  });

  group('FilterDateRange.resolve', () {
    test('today and yesterday are single inclusive days', () {
      final today = FilterDateRange.resolve('Today', now: now)!;
      expect(today.start, DateTime(2026, 8, 19));
      expect(today.end, DateTime(2026, 8, 19));

      final yesterday = FilterDateRange.resolve('Yesterday', now: now)!;
      expect(yesterday.start, DateTime(2026, 8, 18));
      expect(yesterday.end, DateTime(2026, 8, 18));
    });

    test('this week starts on Monday and ends today', () {
      final range = FilterDateRange.resolve('This week', now: now)!;
      expect(range.start, DateTime(2026, 8, 17)); // Monday
      expect(range.end, DateTime(2026, 8, 19));
    });

    test('last week is the seven days before this one', () {
      final range = FilterDateRange.resolve('Last week', now: now)!;
      expect(range.start, DateTime(2026, 8, 10));
      expect(range.end, DateTime(2026, 8, 16));
    });

    test('rolling windows include today and count back inclusively', () {
      expect(FilterDateRange.resolve('Last 7 days', now: now)!.start, DateTime(2026, 8, 13));
      expect(FilterDateRange.resolve('Last 30 days', now: now)!.start, DateTime(2026, 7, 21));
      expect(FilterDateRange.resolve('Last 90 days', now: now)!.start, DateTime(2026, 5, 22));
    });

    test('this month, last month, quarter and year', () {
      expect(FilterDateRange.resolve('This month', now: now)!.start, DateTime(2026, 8, 1));

      final lastMonth = FilterDateRange.resolve('Last month', now: now)!;
      expect(lastMonth.start, DateTime(2026, 7, 1));
      expect(lastMonth.end, DateTime(2026, 7, 31), reason: 'ends on the last day, not the 1st of this month');

      // August sits in Q3, which starts in July.
      expect(FilterDateRange.resolve('This quarter', now: now)!.start, DateTime(2026, 7, 1));
      expect(FilterDateRange.resolve('This year', now: now)!.start, DateTime(2026, 1, 1));
    });

    test('an unknown label resolves to no range rather than a wrong one', () {
      expect(FilterDateRange.resolve('Since the dawn of time', now: now), isNull);
    });
  });

  group('FilterDateRange.toQueryValue', () {
    test('formats as the documented yyyy-MM-dd,yyyy-MM-dd', () {
      final value = FilterDateRange.toQueryValue('Yesterday');
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final day = FilterDateRange.formatDay(yesterday);
      expect(value, '$day,$day');
    });

    test('zero-pads month and day', () {
      expect(FilterDateRange.formatDay(DateTime(2026, 1, 4)), '2026-01-04');
    });

    test('a cleared pill produces no parameter at all', () {
      expect(FilterDateRange.toQueryValue('All time'), isNull);
      expect(FilterDateRange.toQueryValue(null), isNull);
      expect(FilterDateRange.toQueryValue(''), isNull);
    });

    test('a custom range keeps its own dates, including the year', () {
      final range = DateTimeRange(
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 20),
      );
      expect(
        FilterDateRange.toQueryValue('8/1 - 8/20', customRange: range),
        '2026-08-01,2026-08-20',
      );
    });
  });

  group('FilterDateRange.matches', () {
    test('includes both boundary days', () {
      final range = DateTimeRange(start: DateTime(2026, 8, 1), end: DateTime(2026, 8, 20));
      expect(FilterDateRange.matches(null, '2026-08-01T00:00:00.000Z', customRange: range), isTrue);
      expect(FilterDateRange.matches(null, '2026-08-20T23:59:00', customRange: range), isTrue);
      expect(FilterDateRange.matches(null, '2026-07-31T23:59:00', customRange: range), isFalse);
      expect(FilterDateRange.matches(null, '2026-08-21T00:01:00', customRange: range), isFalse);
    });

    test('no filter lets everything through, including unparsable values', () {
      expect(FilterDateRange.matches('All time', 'not a date'), isTrue);
      expect(FilterDateRange.matches(null, null), isTrue);
    });

    test('an unparsable value is excluded when a filter is set', () {
      expect(FilterDateRange.matches('Today', 'not a date', now: now), isFalse);
      expect(FilterDateRange.matches('Today', null, now: now), isFalse);
    });
  });

  group('FilterValue.orNull', () {
    test('every pill placeholder counts as no selection', () {
      for (final label in [
        null,
        '',
        'all',
        'All owners',
        'All statuses',
        'All MSPs',
        'Select a stage',
        'Select a status',
        'Owner',
        'Status',
        'Priority',
        'Company',
        'Contact',
        'Deal',
      ]) {
        expect(FilterValue.orNull(label), isNull, reason: 'label: $label');
      }
    });

    test('a real selection is returned trimmed', () {
      expect(FilterValue.orNull('  Customer '), 'Customer');
    });
  });

  group('FilterValue.lifecycleStage', () {
    test('maps display names onto the documented enum values', () {
      expect(FilterValue.lifecycleStage('Lead'), 'lead');
      expect(FilterValue.lifecycleStage('Customer'), 'customer');
      expect(FilterValue.lifecycleStage('Evangelist'), 'evangelist');
      expect(FilterValue.lifecycleStage('Subscriber'), 'subscriber');
      expect(FilterValue.lifecycleStage('Opportunity'), 'opportunity');
      expect(FilterValue.lifecycleStage('Added'), 'added');
    });

    test('the two qualified stages drop the trailing Lead, as the API stores them', () {
      expect(FilterValue.lifecycleStage('Marketing Qualified Lead'), 'marketing_qualified');
      expect(FilterValue.lifecycleStage('Sales Qualified Lead'), 'sales_qualified');
    });

    test('a placeholder produces no parameter', () {
      expect(FilterValue.lifecycleStage('Select a stage'), isNull);
      expect(FilterValue.lifecycleStage(null), isNull);
    });

    test('matches a record whose stored stage is the slug', () {
      // The bug this replaced: comparing the label to the slug directly, which
      // never matched a stage with more than one word in its name.
      expect(FilterValue.matchesLifecycleStage('Marketing Qualified Lead', 'marketing_qualified'), isTrue);
      expect(FilterValue.matchesLifecycleStage('Customer', 'customer'), isTrue);
      expect(FilterValue.matchesLifecycleStage('Customer', 'lead'), isFalse);
      expect(FilterValue.matchesLifecycleStage('Customer', ''), isFalse);
      expect(FilterValue.matchesLifecycleStage('Select a stage', 'anything'), isTrue);
    });
  });

  group('FilterValue.matchesSlug', () {
    test('tolerates label/slug spelling differences', () {
      expect(FilterValue.matchesSlug('In progress', 'in_progress'), isTrue);
      expect(FilterValue.matchesSlug('No show', 'no_show'), isTrue);
    });

    test('folds the cancelled/canceled spellings onto each other', () {
      expect(FilterValue.matchesSlug('Cancelled', 'canceled'), isTrue);
      expect(FilterValue.matchesSlug('Canceled', 'cancelled'), isTrue);
    });

    test('does not match a different value', () {
      expect(FilterValue.matchesSlug('Completed', 'pending'), isFalse);
    });

    test('no selection matches everything', () {
      expect(FilterValue.matchesSlug('All statuses', 'anything'), isTrue);
    });
  });

  group('FilterValue.activityStatus', () {
    test('returns the four documented statuses', () {
      expect(FilterValue.activityStatus('Pending'), 'pending');
      expect(FilterValue.activityStatus('Completed'), 'completed');
      expect(FilterValue.activityStatus('Cancelled'), 'cancelled');
      expect(FilterValue.activityStatus('Reopened'), 'reopened');
    });

    test('an outcome the endpoint has no parameter for stays null', () {
      // These are matched in memory instead of being invented as query values.
      expect(FilterValue.activityStatus('Scheduled'), isNull);
      expect(FilterValue.activityStatus('Logged'), isNull);
      expect(FilterValue.activityStatus('No show'), isNull);
    });

    test('a placeholder produces no parameter', () {
      expect(FilterValue.activityStatus('All statuses'), isNull);
      expect(FilterValue.activityStatus(null), isNull);
    });
  });
}
