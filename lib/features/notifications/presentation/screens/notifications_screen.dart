import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/navigation/route_names.dart';
import '../../../../core/navigation/route_paths.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../navigation/presentation/providers/navigation_provider.dart';
import '../../data/models/notification_model.dart';
import '../providers/notification_provider.dart';
import '../utils/notification_utils.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  NotificationTypeTab _selectedTab = NotificationTypeTab.all;
  NotificationTimeFilter _selectedTimeFilter = NotificationTimeFilter.all;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _deletingNotificationIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().fetchNotifications();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notificationProvider = context.watch<NotificationProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        color: const Color(0xFF00A884),
        onRefresh: () async {
          await context.read<NotificationProvider>().fetchNotifications();
        },
        child: Column(
          children: [
            _buildTypeTabs(notificationProvider),
            _buildSearchBar(),
            _buildTimeFilterChips(),
            Expanded(
              child: _buildContent(notificationProvider),
            ),
          ],
        ),
      ),
    );
  }

  /// Top Entity Type Tabs: All, Companies, Contacts, Deals
  Widget _buildTypeTabs(NotificationProvider provider) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: NotificationTypeTab.values.map((tab) {
                  final isSelected = _selectedTab == tab;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedTab = tab;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                tab.icon,
                                size: 14,
                                color: isSelected
                                    ? const Color(0xFF00A884)
                                    : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                tab.label,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight:
                                      isSelected ? FontWeight.w600 : FontWeight.w500,
                                  color: isSelected
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          if (provider.unreadCount > 0) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: () => context.read<NotificationProvider>().markAllAsRead(),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F4F1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Mark read',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF00A884),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Search Bar compatible with existing/filtered notifications
  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF1E293B)),
        decoration: InputDecoration(
          hintText: 'Search notifications...',
          hintStyle: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF94A3B8)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF00A884)),
          ),
        ),
      ),
    );
  }

  /// Time Range Filter Chips: All, Today, Yesterday, This Week
  Widget _buildTimeFilterChips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: NotificationTimeFilter.values.map((filter) {
            final isSelected = _selectedTimeFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(filter.label),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedTimeFilter = filter;
                    });
                  }
                },
                selectedColor: const Color(0xFFE6F4F1),
                backgroundColor: const Color(0xFFF1F5F9),
                labelStyle: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? const Color(0xFF00A884) : const Color(0xFF64748B),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF00A884) : Colors.transparent,
                  ),
                ),
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildContent(NotificationProvider provider) {
    if (provider.isLoading && provider.notifications.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00A884)),
      );
    }

    if (provider.error != null && provider.notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                provider.error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => provider.fetchNotifications(),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A884)),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    // Apply filtering, sorting, and date-wise grouping dynamically
    final filteredList = NotificationUtils.filterNotifications(
      notifications: provider.notifications,
      typeTab: _selectedTab,
      timeFilter: _selectedTimeFilter,
      searchQuery: _searchQuery,
    );

    final sortedList = NotificationUtils.sortDescending(filteredList);
    final groupedNotifications = NotificationUtils.groupNotificationsByDate(sortedList);

    if (groupedNotifications.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        children: [
          const SizedBox(height: 120),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.notifications_none_rounded, size: 54, color: Color(0xFFCBD5E1)),
                const SizedBox(height: 12),
                Text(
                  'No notifications found',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                if (_selectedTab != NotificationTypeTab.all ||
                    _selectedTimeFilter != NotificationTimeFilter.all ||
                    _searchQuery.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Try adjusting your selected tab or filter criteria',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    final dateKeys = groupedNotifications.keys.toList();

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: dateKeys.length,
      itemBuilder: (context, dateIndex) {
        final dateHeader = dateKeys[dateIndex];
        final itemsForDate = groupedNotifications[dateHeader]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateHeader(dateHeader, itemsForDate.length),
            const SizedBox(height: 8),
            ...itemsForDate.map((item) {
              return _buildNotificationItem(
                item: item,
              );
            }),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  /// Date Header with count badge on the right
  Widget _buildDateHeader(String headerText, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              headerText,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteNotification(NotificationModel item) async {
    if (_deletingNotificationIds.contains(item.id)) return;

    final provider = context.read<NotificationProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Notification', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Are you sure you want to delete this notification?', style: GoogleFonts.poppins(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _deletingNotificationIds.add(item.id);
    });

    try {
      await provider.deleteNotification(item.id);
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Notification deleted successfully'),
            backgroundColor: Color(0xFF00A884),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[DELETE NOTIFICATION ERROR]: $e');
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to delete notification: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _deletingNotificationIds.remove(item.id);
        });
      }
    }
  }

  /// Opens the Call, Meeting or Email screen on the activity this notification
  /// refers to, so it lands scrolled to that row and highlighted.
  ///
  /// Notifications for other activity types (or without an activity id) are
  /// left alone — the tap just marks them read as before.
  /// Handles tapping a notification item:
  /// - For Activity notifications (Task, Call, Meeting, Note, Email):
  ///   - If linked to Deal, Contact, or Company: opens entity screen on Activities tab (initialTabIndex: 1) with highlight.
  ///   - Otherwise: navigates to the global Activity screen (Calls, Meetings, Emails, Tasks) with highlight.
  /// - For Entity notifications (Deal, Contact, Company updates):
  ///   - Opens entity screen on Overview tab (initialTabIndex: 0).
  void _onNotificationTap(NotificationModel item) {
    if (!item.isRead) {
      context.read<NotificationProvider>().markAsRead(item.id);
    }

    final entityType = (item.entityType ?? '').toLowerCase();
    final type = item.type.toLowerCase();
    final actType = (item.activityType ?? '').toLowerCase();

    final isActivityNotification = type.contains('call') ||
        type.contains('meeting') ||
        type.contains('email') ||
        type.contains('task') ||
        type.contains('note') ||
        type.contains('activity') ||
        actType.isNotEmpty;

    final targetActivityId = item.entityId ?? item.id;

    // 1. Redirect to Deal screen
    final dealId = item.dealId ??
        (entityType == 'deal' || (type.contains('deal') && !isActivityNotification) ? item.entityId : null);
    if (dealId != null && dealId.isNotEmpty) {
      context.pushNamed(
        RouteNames.dealDetails,
        pathParameters: {RoutePaths.idParam: dealId},
        queryParameters: {
          'tab': isActivityNotification ? '1' : '0',
          if (isActivityNotification && targetActivityId != null)
            'activityId': targetActivityId,
        },
      );
      return;
    }

    // 2. Redirect to Contact screen
    final contactId = item.contactId ??
        (entityType == 'contact' || (type.contains('contact') && !isActivityNotification) ? item.entityId : null);
    if (contactId != null && contactId.isNotEmpty) {
      context.pushNamed(
        RouteNames.contactDetails,
        pathParameters: {RoutePaths.idParam: contactId},
        queryParameters: {
          'tab': isActivityNotification ? '1' : '0',
          if (isActivityNotification && targetActivityId != null)
            'activityId': targetActivityId,
        },
      );
      return;
    }

    // 3. Redirect to Company screen
    final companyId = item.companyId ??
        (entityType == 'company' || (type.contains('company') && !isActivityNotification) ? item.entityId : null);
    if (companyId != null && companyId.isNotEmpty) {
      context.pushNamed(
        RouteNames.companyDetails,
        pathParameters: {RoutePaths.idParam: companyId},
        queryParameters: {
          'tab': isActivityNotification ? '1' : '0',
          if (isActivityNotification && targetActivityId != null)
            'activityId': targetActivityId,
        },
      );
      return;
    }

    // 4. Global Activity screen navigation via NavigationProvider (Calls, Meetings, Emails, Tasks)
    final activityTypeToOpen = item.activityType ?? item.entityType ?? item.type;
    final lowerType = activityTypeToOpen.toLowerCase();
    if (lowerType.contains('task') || lowerType.contains('note')) {
      context.read<NavigationProvider>().selectScreen(11, activityId: targetActivityId);
    } else {
      context.read<NavigationProvider>().openActivity(
            activityType: activityTypeToOpen,
            activityId: targetActivityId,
          );
    }
  }

  Widget _buildNotificationItem({
    required NotificationModel item,
  }) {
    final title = item.type.isNotEmpty ? item.type.replaceAll('_', ' ') : 'NOTIFICATION';
    final isNew = !item.isRead;
    final timeStr = item.createdAt.isNotEmpty
        ? item.createdAt.split('T').first
        : 'Just now';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isNew ? const Color(0xFFE6F4F1).withValues(alpha: 0.3) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _onNotificationTap(item),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isNew ? const Color(0xFF00A884) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.dynamicIcon, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title.toUpperCase(),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1E293B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            timeStr,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.message,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: _deletingNotificationIds.contains(item.id)
                      ? const Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        )
                      : IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Color(0xFF94A3B8),
                            size: 20,
                          ),
                          hoverColor: const Color(0xFFFEE2E2),
                          splashRadius: 18,
                          onPressed: () => _handleDeleteNotification(item),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


