import 'package:flutter/material.dart';

/// Representation of a navigable menu item in the CRM app.
class NavItem {
  final String key;
  final String title;
  final IconData icon;
  final IconData selectedIcon;
  final int screenIndex;

  const NavItem({
    required this.key,
    required this.title,
    required this.icon,
    required this.selectedIcon,
    required this.screenIndex,
  });
}

/// Provider that manages bottom navigation state, active tab,
/// and dynamic pinned fields in the custom bottom navigation bar.
class NavigationProvider extends ChangeNotifier {
  int _selectedIndex = 0;

  // Maximum allowed pinned items in bottom nav bar (excluding Home & More)
  static const int maxPinnedItems = 3;

  // Default pinned item keys
  final List<String> _pinnedKeys = ['contacts', 'companies', 'deals'];

  // Master list of all pinnable items mapped to screen indices in MainLayoutScreen
  final List<NavItem> _allNavItems = const [
    NavItem(
      key: 'contacts',
      title: 'Contacts',
      icon: Icons.people_outline_rounded,
      selectedIcon: Icons.people_rounded,
      screenIndex: 1,
    ),
    NavItem(
      key: 'companies',
      title: 'Companies',
      icon: Icons.business_outlined,
      selectedIcon: Icons.business_rounded,
      screenIndex: 2,
    ),
    NavItem(
      key: 'deals',
      title: 'Deals',
      icon: Icons.monetization_on_outlined,
      selectedIcon: Icons.monetization_on_rounded,
      screenIndex: 3,
    ),
    NavItem(
      key: 'meetings',
      title: 'Meetings',
      icon: Icons.videocam_outlined,
      selectedIcon: Icons.videocam_rounded,
      screenIndex: 7,
    ),
    NavItem(
      key: 'meeting_scheduler',
      title: 'Scheduler',
      icon: Icons.access_time_outlined,
      selectedIcon: Icons.access_time_filled_rounded,
      screenIndex: 8,
    ),
    NavItem(
      key: 'calls',
      title: 'Calls',
      icon: Icons.phone_outlined,
      selectedIcon: Icons.phone_rounded,
      screenIndex: 9,
    ),
    NavItem(
      key: 'emails',
      title: 'Emails',
      icon: Icons.mail_outline_rounded,
      selectedIcon: Icons.mail_rounded,
      screenIndex: 10,
    ),
    NavItem(
      key: 'tasks',
      title: 'Tasks',
      icon: Icons.check_box_outlined,
      selectedIcon: Icons.check_box_rounded,
      screenIndex: 12,
    ),
    NavItem(
      key: 'calendar',
      title: 'Calendar',
      icon: Icons.calendar_today_outlined,
      selectedIcon: Icons.calendar_month_rounded,
      screenIndex: 13,
    ),
    NavItem(
      key: 'quarter_view',
      title: 'Quarter View',
      icon: Icons.layers_outlined,
      selectedIcon: Icons.layers_rounded,
      screenIndex: 14,
    ),
    NavItem(
      key: 'documents',
      title: 'Documents',
      icon: Icons.folder_open_outlined,
      selectedIcon: Icons.folder_rounded,
      screenIndex: 15,
    ),
    NavItem(
      key: 'templates',
      title: 'Templates',
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view_rounded,
      screenIndex: 16,
    ),
    NavItem(
      key: 'notifications',
      title: 'Notifications',
      icon: Icons.notifications_none_rounded,
      selectedIcon: Icons.notifications_rounded,
      screenIndex: 6,
    ),
    NavItem(
      key: 'bingo_ai',
      title: 'Bingo AI',
      icon: Icons.auto_awesome_outlined,
      selectedIcon: Icons.auto_awesome_rounded,
      screenIndex: 5,
    ),
  ];

  /// Activity the next screen should scroll to and highlight, set when the user
  /// opens one specific activity from elsewhere in the app.
  String? _focusedActivityId;

  /// Screen index per activity type, for [openActivity].
  static const Map<String, int> _activityScreenIndexes = {
    'call': 9,
    'meeting': 7,
    'email': 10,
  };

  int get selectedIndex => _selectedIndex;
  String? get focusedActivityId => _focusedActivityId;
  List<String> get pinnedKeys => List.unmodifiable(_pinnedKeys);
  List<NavItem> get allNavItems => _allNavItems;

  /// Returns the list of NavItems currently pinned to the bottom nav bar.
  List<NavItem> get pinnedNavItems {
    return _allNavItems.where((item) => _pinnedKeys.contains(item.key)).toList();
  }

  /// Checks if a specific nav item key is pinned.
  bool isPinned(String key) {
    return _pinnedKeys.contains(key);
  }

  /// Selects active screen index.
  ///
  /// Pass [activityId] to tell the destination screen which activity to scroll
  /// to and highlight once its list has loaded.
  void selectScreen(int index, {String? activityId}) {
    _selectedIndex = index;
    _focusedActivityId = activityId;
    notifyListeners();
  }

  /// Opens the list screen for [activityType] (`call`, `meeting` or `email`)
  /// focused on [activityId].
  ///
  /// Returns false when the type has no list screen or the id is missing, so
  /// callers can fall back to their own handling.
  bool openActivity({String? activityType, String? activityId}) {
    final id = activityId?.trim();
    if (id == null || id.isEmpty) return false;

    final type = activityType?.trim().toLowerCase();
    if (type == null || type.isEmpty) return false;

    // Notification types arrive as 'call', 'activity_call', 'call_logged', …
    final match = _activityScreenIndexes.entries
        .where((entry) => type.contains(entry.key))
        .firstOrNull;
    if (match == null) return false;

    selectScreen(match.value, activityId: id);
    return true;
  }

  /// Toggles pin status for a given item key.
  /// Returns `true` if item was successfully pinned, `false` if unpinned,
  /// or null if pinning failed due to max limit.
  bool? togglePin(String key) {
    if (_pinnedKeys.contains(key)) {
      _pinnedKeys.remove(key);
      notifyListeners();
      return false; // Unpinned
    } else {
      if (_pinnedKeys.length >= maxPinnedItems) {
        return null; // Max limit reached
      }
      _pinnedKeys.add(key);
      notifyListeners();
      return true; // Pinned
    }
  }
}
