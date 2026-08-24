import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_service.dart';
import '../../../activities/presentation/widgets/create_email_modal.dart';
import '../../../activities/presentation/widgets/create_note_modal.dart';
import '../../../activities/presentation/widgets/create_task_modal.dart';
import '../../../activities/presentation/widgets/log_call_modal.dart';
import '../../../activities/presentation/widgets/log_meeting_modal.dart';
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Notifications',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: const Color(0xFF1E293B),
          ),
        ),
        actions: [
          if (notificationProvider.unreadCount > 0)
            TextButton(
              onPressed: () {
                context.read<NotificationProvider>().markAllAsRead();
              },
              child: Text(
                'Mark all read',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF00A884),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF00A884),
        onRefresh: () async {
          await context.read<NotificationProvider>().fetchNotifications();
        },
        child: Column(
          children: [
            _buildTypeTabs(),
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
  Widget _buildTypeTabs() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(4),
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
                  padding: const EdgeInsets.symmetric(vertical: 8),
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        tab.icon,
                        size: 15,
                        color: isSelected
                            ? const Color(0xFF00A884)
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          tab.label,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected
                                ? const Color(0xFF1E293B)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
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
              return InkWell(
                onTap: () {
                  if (!item.isRead) {
                    provider.markAsRead(item.id);
                  }
                },
                child: _buildNotificationItem(
                  item: item,
                ),
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

  Future<void> _handleDeleteNotificationActivity(NotificationModel item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Activity', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete this activity?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final actId = item.entityId ?? item.id;
      final actType = (item.activityType ?? item.type).toLowerCase();
      final api = ApiService();
      try {
        if (actType.contains('task')) {
          await api.delete('/tasks/$actId');
        } else {
          await api.delete('${ApiConstants.activities}/$actId');
        }
      } catch (_) {
        try {
          await api.delete('${ApiConstants.activities}/$actId');
        } catch (e) {
          debugPrint('[DELETE NOTIFICATION ACTIVITY ERROR]: $e');
        }
      }

      if (mounted) {
        context.read<NotificationProvider>().fetchNotifications();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activity deleted successfully'),
            backgroundColor: Color(0xFF00A884),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleEditNotificationActivity(NotificationModel item) async {
    final actId = item.entityId ?? item.id;
    final actType = (item.activityType ?? item.type).toLowerCase();

    if (actType.contains('task')) {
      await CreateTaskModal.show(
        context,
        taskToEdit: TaskModel(
          id: actId,
          title: item.message,
          dueDate: 'Today',
          priority: 'Medium',
          status: 'PENDING',
          assignedTo: 'Admin User',
          notes: item.message,
        ),
        companyId: item.companyId,
        contactId: item.contactId,
        dealId: item.dealId,
      );
    } else if (actType.contains('email')) {
      await CreateEmailModal.show(
        context,
        emailToEdit: {
          'id': actId,
          'title': item.message,
          'notes': item.message,
        },
        companyId: item.companyId,
        contactId: item.contactId,
        dealId: item.dealId,
      );
    } else if (actType.contains('note')) {
      await CreateNoteModal.show(
        context,
        noteToEdit: {
          'id': actId,
          'title': item.message,
          'notes': item.message,
        },
        companyId: item.companyId,
        contactId: item.contactId,
        dealId: item.dealId,
      );
    } else if (actType.contains('call')) {
      await LogCallModal.show(
        context,
        callToEdit: CallModel(
          id: actId,
          title: item.message,
          outcome: 'Connected',
          duration: '5m',
          startTime: '10:00 AM',
          notes: item.message,
          companyId: item.companyId,
          contactId: item.contactId,
          dealId: item.dealId,
        ),
        companyId: item.companyId,
        contactId: item.contactId,
        dealId: item.dealId,
      );
    } else if (actType.contains('meeting')) {
      await LogMeetingModal.show(
        context,
        existingMeeting: MeetingModel(
          id: actId,
          title: item.message,
          outcome: 'Completed',
          duration: '30m',
          startTime: '10:00 AM',
          notes: item.message,
          companyId: item.companyId,
          contactId: item.contactId,
          dealId: item.dealId,
        ),
        companyId: item.companyId,
        contactId: item.contactId,
        dealId: item.dealId,
      );
    }

    if (mounted) {
      context.read<NotificationProvider>().fetchNotifications();
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isNew ? const Color(0xFFE6F4F1).withValues(alpha: 0.3) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
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
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: Color(0xFF94A3B8),
              size: 20,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'edit',
                child: Row(
                  children: [
                    const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF00A884)),
                    const SizedBox(width: 8),
                    Text('Edit Activity', style: GoogleFonts.poppins(fontSize: 13)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                    const SizedBox(width: 8),
                    Text('Delete Activity', style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFFEF4444))),
                  ],
                ),
              ),
            ],
            onSelected: (action) {
              if (action == 'delete') {
                _handleDeleteNotificationActivity(item);
              } else if (action == 'edit') {
                _handleEditNotificationActivity(item);
              }
            },
          ),
        ],
      ),
    );
  }
}


