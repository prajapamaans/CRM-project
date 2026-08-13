import 'package:flutter/material.dart';
import '../../data/models/notification_model.dart';

enum NotificationTypeTab {
  all,
  companies,
  contacts,
  deals;

  String get label {
    switch (this) {
      case NotificationTypeTab.all:
        return 'All';
      case NotificationTypeTab.companies:
        return 'Companies';
      case NotificationTypeTab.contacts:
        return 'Contacts';
      case NotificationTypeTab.deals:
        return 'Deals';
    }
  }

  IconData get icon {
    switch (this) {
      case NotificationTypeTab.all:
        return Icons.notifications_none_rounded;
      case NotificationTypeTab.companies:
        return Icons.business_rounded;
      case NotificationTypeTab.contacts:
        return Icons.person_outline_rounded;
      case NotificationTypeTab.deals:
        return Icons.monetization_on_outlined;
    }
  }
}

enum NotificationTimeFilter {
  all,
  today,
  yesterday,
  thisWeek;

  String get label {
    switch (this) {
      case NotificationTimeFilter.all:
        return 'All';
      case NotificationTimeFilter.today:
        return 'Today';
      case NotificationTimeFilter.yesterday:
        return 'Yesterday';
      case NotificationTimeFilter.thisWeek:
        return 'This Week';
    }
  }
}

/// Helper extension on NotificationModel to safely classify and parse notification attributes
extension NotificationModelX on NotificationModel {
  DateTime? get parsedDate {
    if (createdAt.isEmpty) return null;
    return DateTime.tryParse(createdAt)?.toLocal();
  }

  bool get isCompany {
    final eType = (entityType ?? '').toLowerCase();
    final t = type.toLowerCase();
    final act = (activityType ?? '').toLowerCase();
    final msg = message.toLowerCase();

    if (eType == 'company' || eType == 'companies') return true;
    if (companyId != null && companyId!.isNotEmpty) return true;
    if (companyName != null && companyName!.isNotEmpty) return true;
    if (t.contains('company')) return true;
    if (act.contains('company')) return true;
    if (msg.contains('company')) return true;
    return false;
  }

  bool get isContact {
    final eType = (entityType ?? '').toLowerCase();
    final t = type.toLowerCase();
    final act = (activityType ?? '').toLowerCase();
    final msg = message.toLowerCase();

    if (eType == 'contact' || eType == 'contacts') return true;
    if (contactId != null && contactId!.isNotEmpty) return true;
    if (contactName != null && contactName!.isNotEmpty) return true;
    if (t.contains('contact') || t.contains('user') || t.contains('lead')) return true;
    if (act.contains('contact') || act.contains('user')) return true;
    if (msg.contains('contact')) return true;
    return false;
  }

  bool get isDeal {
    final eType = (entityType ?? '').toLowerCase();
    final t = type.toLowerCase();
    final act = (activityType ?? '').toLowerCase();
    final msg = message.toLowerCase();

    if (eType == 'deal' || eType == 'deals' || eType == 'opportunity') return true;
    if (dealId != null && dealId!.isNotEmpty) return true;
    if (dealName != null && dealName!.isNotEmpty) return true;
    if (t.contains('deal') || t.contains('opportunity') || t.contains('pipeline')) return true;
    if (act.contains('deal')) return true;
    if (msg.contains('deal') || msg.contains('\$')) return true;
    return false;
  }

  IconData get dynamicIcon {
    if (isCompany) return Icons.business_rounded;
    if (isContact) return Icons.person_outline_rounded;
    if (isDeal) return Icons.monetization_on_outlined;
    return Icons.notifications_active_rounded;
  }
}

class NotificationUtils {
  /// Filter notifications by Type Tab and Time Range Filter and Search Query
  static List<NotificationModel> filterNotifications({
    required List<NotificationModel> notifications,
    required NotificationTypeTab typeTab,
    required NotificationTimeFilter timeFilter,
    String searchQuery = '',
  }) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final yesterdayEnd = todayStart.subtract(const Duration(microseconds: 1));

    // Calculate start of current week (Monday as start of week)
    final mondayOffset = now.weekday - 1;
    final weekStart = DateTime(now.year, now.month, now.day - mondayOffset);

    return notifications.where((item) {
      // 1. Entity Type Filter
      switch (typeTab) {
        case NotificationTypeTab.all:
          break;
        case NotificationTypeTab.companies:
          if (!item.isCompany) return false;
          break;
        case NotificationTypeTab.contacts:
          if (!item.isContact) return false;
          break;
        case NotificationTypeTab.deals:
          if (!item.isDeal) return false;
          break;
      }

      // 2. Time Range Filter
      final itemDate = item.parsedDate;
      if (itemDate != null) {
        switch (timeFilter) {
          case NotificationTimeFilter.all:
            break;
          case NotificationTimeFilter.today:
            if (itemDate.isBefore(todayStart)) return false;
            break;
          case NotificationTimeFilter.yesterday:
            if (itemDate.isBefore(yesterdayStart) || itemDate.isAfter(yesterdayEnd)) return false;
            break;
          case NotificationTimeFilter.thisWeek:
            if (itemDate.isBefore(weekStart)) return false;
            break;
        }
      }

      // 3. Search Query Filter
      if (searchQuery.trim().isNotEmpty) {
        final query = searchQuery.toLowerCase().trim();
        final msg = item.message.toLowerCase();
        final type = item.type.toLowerCase();
        final company = (item.companyName ?? '').toLowerCase();
        final contact = (item.contactName ?? '').toLowerCase();
        final deal = (item.dealName ?? '').toLowerCase();

        final matches = msg.contains(query) ||
            type.contains(query) ||
            company.contains(query) ||
            contact.contains(query) ||
            deal.contains(query);

        if (!matches) return false;
      }

      return true;
    }).toList();
  }

  /// Sort notifications in descending order (newest first)
  static List<NotificationModel> sortDescending(List<NotificationModel> notifications) {
    final list = List<NotificationModel>.from(notifications);
    list.sort((a, b) {
      final dateA = a.parsedDate;
      final dateB = b.parsedDate;
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA);
    });
    return list;
  }

  /// Format header date string dynamically (e.g. THURSDAY, AUGUST 6TH, 2026)
  static String formatDateHeader(DateTime date) {
    const monthNames = [
      'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
      'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'
    ];
    const weekdayNames = [
      'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'
    ];

    final weekday = weekdayNames[date.weekday - 1];
    final month = monthNames[date.month - 1];
    final day = date.day;
    final daySuffix = _getDaySuffix(day);
    final year = date.year;

    return '$weekday, $month $day$daySuffix, $year';
  }

  static String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) return 'TH';
    switch (day % 10) {
      case 1: return 'ST';
      case 2: return 'ND';
      case 3: return 'RD';
      default: return 'TH';
    }
  }

  /// Group sorted notifications date-wise (Key is formatted header string)
  static Map<String, List<NotificationModel>> groupNotificationsByDate(List<NotificationModel> sortedNotifications) {
    final Map<String, List<NotificationModel>> groups = {};

    for (final item in sortedNotifications) {
      final date = item.parsedDate;
      final headerKey = date != null ? formatDateHeader(date) : 'OTHER NOTIFICATIONS';
      if (!groups.containsKey(headerKey)) {
        groups[headerKey] = [];
      }
      groups[headerKey]!.add(item);
    }

    return groups;
  }
}
