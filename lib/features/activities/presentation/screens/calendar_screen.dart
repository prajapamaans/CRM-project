import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/network/api_service.dart';
import '../widgets/create_task_modal.dart';
import '../widgets/log_call_modal.dart';
import '../widgets/log_meeting_modal.dart';
import '../../../companies/data/models/company_model.dart';
import '../../../companies/presentation/screens/company_details_screen.dart';
import '../../../contacts/data/models/contact_model.dart';
import '../../../contacts/presentation/screens/contact_details_screen.dart';
import '../../../deals/data/models/deal_model.dart';
import '../../../deals/presentation/screens/deal_details_screen.dart';
import 'call_details_screen.dart';
import 'email_details_screen.dart';
import 'meeting_details_screen.dart';
import 'task_details_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDate = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  bool _isLoadingApis = false;
  bool _isFetchingActivities = false;
  String? _lastFetchedRangeKey;
  List<Map<String, dynamic>> _activities = [];

  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];

  static const List<String> _shortMonthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchCalendarActivities();
    });
  }

  /// Calculates the exact start and end DateTime of the visible calendar grid.
  /// The grid displays 5 or 6 rows of 7 days (35 or 42 cells), including
  /// overflow days from the previous and next months.
  Map<String, DateTime> _calculateVisibleRange(DateTime focusedDate) {
    final year = focusedDate.year;
    final month = focusedDate.month;

    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = firstDayOfMonth.weekday % 7; // 0 for Sun

    final prevMonthDays = DateTime(year, month, 0).day;

    final totalDaysNeeded = firstWeekday + daysInMonth;
    final itemCount = totalDaysNeeded > 35 ? 42 : 35;

    late final DateTime visibleStartLocal;
    if (firstWeekday > 0) {
      final startDay = prevMonthDays - firstWeekday + 1;
      visibleStartLocal = DateTime(year, month - 1, startDay, 0, 0, 0, 0);
    } else {
      visibleStartLocal = DateTime(year, month, 1, 0, 0, 0, 0);
    }

    late final DateTime visibleEndLocal;
    final nextMonthDaysOverflow = itemCount - firstWeekday - daysInMonth;
    if (nextMonthDaysOverflow > 0) {
      visibleEndLocal = DateTime(year, month + 1, nextMonthDaysOverflow, 23, 59, 59, 999);
    } else {
      visibleEndLocal = DateTime(year, month, daysInMonth, 23, 59, 59, 999);
    }

    return {
      'start': visibleStartLocal,
      'end': visibleEndLocal,
    };
  }

  /// Helper to safely resolve and parse local DateTime from an activity map
  DateTime? _getActivityLocalDate(Map<String, dynamic> act) {
    final rawDate = act['scheduledAt'] ??
        act['scheduled_at'] ??
        act['dueDate'] ??
        act['due_date'] ??
        act['activityDate'] ??
        act['activity_date'] ??
        act['startAt'] ??
        act['startDate'] ??
        act['createdAt'] ??
        act['created_at'];

    if (rawDate == null) return null;
    try {
      return DateTime.parse(rawDate.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  /// Fetches calendar activities dynamically based on visible grid date range
  Future<void> _fetchCalendarActivities({bool forceRefresh = false}) async {
    if (!mounted) return;

    final range = _calculateVisibleRange(_focusedDate);
    final startDateUtcStr = range['start']!.toUtc().toIso8601String();
    final endDateUtcStr = range['end']!.toUtc().toIso8601String();
    final rangeKey = '$startDateUtcStr--$endDateUtcStr';

    // Requirement 6: Prevent duplicate API requests for the same range
    if (!forceRefresh && _lastFetchedRangeKey == rangeKey && !_isFetchingActivities) {
      return;
    }

    if (_isFetchingActivities) return;

    setState(() {
      _isLoadingApis = true;
      _isFetchingActivities = true;
    });

    _lastFetchedRangeKey = rangeKey;

    try {
      final api = ApiService();
      final List<Map<String, dynamic>> allFetched = [];
      int page = 1;
      const limit = 1000;
      bool hasMore = true;

      // Requirement 1, 3, 15: Fetch all activities with dynamic range & limit=1000 with pagination support
      while (hasMore) {
        final requestUrl =
            '/activities?startDate=$startDateUtcStr&endDate=$endDateUtcStr&limit=$limit&page=$page';

        final response = await api.get(
          '/activities',
          queryParameters: {
            'startDate': startDateUtcStr,
            'endDate': endDateUtcStr,
            'limit': limit,
            'page': page,
          },
        );

        final raw = response.data;
        List<dynamic> pageItems = [];
        int totalCount = 0;

        if (raw is List) {
          pageItems = raw;
          hasMore = false;
        } else if (raw is Map<String, dynamic>) {
          if (raw['data'] is List) {
            pageItems = raw['data'] as List;
          } else if (raw['items'] is List) {
            pageItems = raw['items'] as List;
          } else if (raw['activities'] is List) {
            pageItems = raw['activities'] as List;
          }

          totalCount = (raw['total'] ??
                  raw['meta']?['total'] ??
                  raw['meta']?['totalCount'] ??
                  pageItems.length) as int;

          if (pageItems.isEmpty ||
              allFetched.length + pageItems.length >= totalCount ||
              pageItems.length < limit) {
            hasMore = false;
          }
        } else {
          hasMore = false;
        }

        allFetched.addAll(pageItems.whereType<Map<String, dynamic>>());

        if (pageItems.length < limit || page >= 10) {
          hasMore = false;
        } else {
          page++;
        }

        // Requirement 19: Debugging logs
        debugPrint('=== CALENDAR FETCH DEBUG ===');
        debugPrint('Calendar visible range: ${range['start']} to ${range['end']}');
        debugPrint('startDate (UTC): $startDateUtcStr');
        debugPrint('endDate (UTC): $endDateUtcStr');
        debugPrint('API Request URL: $requestUrl');
        debugPrint('API response status: ${response.statusCode}');
        debugPrint('Number of activities received: ${pageItems.length}');
        debugPrint('============================');
      }

      // Requirement 14: Deduplicate activities by activity.id
      final Map<String, Map<String, dynamic>> uniqueActivitiesMap = {};
      for (final act in allFetched) {
        final id = (act['id'] ?? act['_id'] ?? act['uuid'])?.toString();
        if (id != null && id.isNotEmpty) {
          uniqueActivitiesMap[id] = act;
        } else {
          final fallbackKey =
              '${act['title'] ?? act['subject']}_${act['scheduledAt'] ?? act['dueDate'] ?? act['createdAt']}';
          uniqueActivitiesMap[fallbackKey] = act;
        }
      }

      final deduplicatedList = uniqueActivitiesMap.values.toList();

      if (mounted) {
        setState(() {
          _activities = deduplicatedList;
        });
      }

      debugPrint('=== TOTAL CALENDAR ACTIVITIES LOADED ===');
      debugPrint('Total Unique Activities: ${_activities.length}');
      debugPrint('Activity IDs: ${_activities.map((a) => a['id']).toList()}');
      debugPrint('Activity types: ${_activities.map((a) => a['type']).toList()}');
      debugPrint(
          'Activity scheduled dates: ${_activities.map((a) => _getActivityLocalDate(a)?.toIso8601String()).toList()}');
      debugPrint('=======================================');
    } catch (e) {
      debugPrint('[CalendarScreen _fetchCalendarActivities error]: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch calendar activities: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingApis = false;
          _isFetchingActivities = false;
        });
      }
    }
  }

  void _previousMonth() {
    setState(() {
      _focusedDate = DateTime(_focusedDate.year, _focusedDate.month - 1, 1);
    });
    _fetchCalendarActivities();
  }

  void _nextMonth() {
    setState(() {
      _focusedDate = DateTime(_focusedDate.year, _focusedDate.month + 1, 1);
    });
    _fetchCalendarActivities();
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _focusedDate = DateTime(now.year, now.month, now.day);
      _selectedDate = DateTime(now.year, now.month, now.day);
    });
    _fetchCalendarActivities();
  }

  void _openTaskForm() async {
    final result = await CreateTaskModal.show(context);
    if (result != null) {
      _fetchCalendarActivities(forceRefresh: true);
    }
  }

  void _openMeetingForm() async {
    final result = await LogMeetingModal.show(context);
    if (result != null) {
      _fetchCalendarActivities(forceRefresh: true);
    }
  }

  void _showDateScheduleModal(DateTime date) {
    setState(() {
      _selectedDate = date;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // Requirement 4, 8: Map activities using local date comparison
        final dateActivities = _activities.where((act) {
          final localDate = _getActivityLocalDate(act);
          if (localDate == null) return false;
          return localDate.year == date.year &&
              localDate.month == date.month &&
              localDate.day == date.day;
        }).toList();

        return Container(
          height: MediaQuery.of(context).size.height * 0.58,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 16),
          child: Column(
            children: [
              // Header Title
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE6F4F1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.calendar_today_outlined,
                      color: Color(0xFF00A884),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Schedule for ${_monthNames[date.month - 1]} ${date.day}, ${date.year}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Action Buttons Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _openMeetingForm();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.videocam_outlined, size: 18, color: Color(0xFF334155)),
                          const SizedBox(width: 6),
                          Text(
                            'ADD MEETING',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF334155),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _openTaskForm();
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: const Color(0xFF0D7C66),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.more_vert, size: 18, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            'ADD TASK',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 32, color: Color(0xFFF1F5F9)),

              // Content Area
              Expanded(
                child: dateActivities.isNotEmpty
                    ? ListView.separated(
                        itemCount: dateActivities.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = dateActivities[index];
                          final title = item['title'] ??
                              item['subject'] ??
                              item['name'] ??
                              item['description'] ??
                              'Activity';
                          final rawType = (item['type'] ?? 'Task').toString();
                          final typeDisplay = rawType.isNotEmpty
                              ? '${rawType[0].toUpperCase()}${rawType.substring(1)}'
                              : 'Activity';

                          final localDate = _getActivityLocalDate(item);
                          String timeFormatted = 'Scheduled';
                          if (localDate != null) {
                            final hour = localDate.hour == 0
                                ? 12
                                : (localDate.hour > 12 ? localDate.hour - 12 : localDate.hour);
                            final amPm = localDate.hour >= 12 ? 'PM' : 'AM';
                            final minute = localDate.minute.toString().padLeft(2, '0');
                            timeFormatted = '$hour:$minute $amPm';
                          }

                          Color barColor;
                          final lowerType = rawType.toLowerCase();
                          if (lowerType == 'meeting') {
                            barColor = const Color(0xFF3B82F6);
                          } else if (lowerType == 'task') {
                            barColor = const Color(0xFF00A884);
                          } else if (lowerType == 'call') {
                            barColor = const Color(0xFFF59E0B);
                          } else if (lowerType == 'email') {
                            barColor = const Color(0xFF8B5CF6);
                          } else {
                            barColor = const Color(0xFF64748B);
                          }

                          return InkWell(
                            onTap: () async {
                              Navigator.of(context).pop();
                              final act = item;

                              String? compId = (act['companyId'] ?? act['company_id'] ?? (act['company'] is Map ? act['company']['id'] : null))?.toString();
                              String? compName = (act['companyName'] ?? act['company_name'] ?? (act['company'] is Map ? act['company']['name'] : null))?.toString();

                              String? contactId = (act['contactId'] ?? act['contact_id'] ?? (act['contact'] is Map ? act['contact']['id'] : null))?.toString();
                              String? contactName = (act['contactName'] ?? act['contact_name'] ?? (act['contact'] is Map ? act['contact']['firstName'] ?? act['contact']['name'] : null))?.toString();

                              String? dealId = (act['dealId'] ?? act['deal_id'] ?? (act['deal'] is Map ? act['deal']['id'] : null))?.toString();
                              String? dealName = (act['dealName'] ?? act['deal_name'] ?? (act['deal'] is Map ? act['deal']['title'] : null))?.toString();

                              if (act['associations'] is Map) {
                                final assocMap = act['associations'] as Map;
                                if ((compId == null || compId.isEmpty) && assocMap['Companies'] is List && (assocMap['Companies'] as List).isNotEmpty) {
                                  final firstComp = (assocMap['Companies'] as List).first;
                                  if (firstComp is Map) {
                                    compId = (firstComp['id'] ?? firstComp['_id'] ?? firstComp['objectId'])?.toString();
                                    compName = (firstComp['name'] ?? firstComp['title'])?.toString();
                                  }
                                }
                                if ((contactId == null || contactId.isEmpty) && assocMap['Contacts'] is List && (assocMap['Contacts'] as List).isNotEmpty) {
                                  final firstContact = (assocMap['Contacts'] as List).first;
                                  if (firstContact is Map) {
                                    contactId = (firstContact['id'] ?? firstContact['_id'] ?? firstContact['objectId'])?.toString();
                                    contactName = (firstContact['name'] ?? firstContact['title'])?.toString();
                                  }
                                }
                                if ((dealId == null || dealId.isEmpty) && assocMap['Deals'] is List && (assocMap['Deals'] as List).isNotEmpty) {
                                  final firstDeal = (assocMap['Deals'] as List).first;
                                  if (firstDeal is Map) {
                                    dealId = (firstDeal['id'] ?? firstDeal['_id'] ?? firstDeal['objectId'])?.toString();
                                    dealName = (firstDeal['name'] ?? firstDeal['title'])?.toString();
                                  }
                                }
                              } else if (act['associations'] is List) {
                                for (final assoc in (act['associations'] as List)) {
                                  if (assoc is Map) {
                                    final id = (assoc['objectId'] ?? assoc['id'] ?? assoc['_id'])?.toString();
                                    final type = (assoc['objectType'] ?? assoc['type'])?.toString().toLowerCase();
                                    final name = (assoc['name'] ?? assoc['title'])?.toString();
                                    if (id != null && id.isNotEmpty) {
                                      if ((type == 'company' || type == 'companies') && (compId == null || compId.isEmpty)) {
                                        compId = id;
                                        compName = name;
                                      } else if ((type == 'contact' || type == 'contacts') && (contactId == null || contactId.isEmpty)) {
                                        contactId = id;
                                        contactName = name;
                                      } else if ((type == 'deal' || type == 'deals') && (dealId == null || dealId.isEmpty)) {
                                        dealId = id;
                                        dealName = name;
                                      }
                                    }
                                  }
                                }
                              }

                              if (compId != null && compId.isNotEmpty) {
                                final companyModel = CompanyModel(
                                  id: compId,
                                  name: compName ?? 'Company',
                                );
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CompanyDetailsScreen(company: companyModel, initialTabIndex: 1),
                                  ),
                                );
                                _fetchCalendarActivities(forceRefresh: true);
                              } else if (contactId != null && contactId.isNotEmpty) {
                                final contactModel = ContactModel(
                                  id: contactId,
                                  firstName: contactName ?? 'Contact',
                                  email: '',
                                );
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ContactDetailsScreen(contact: contactModel, initialTabIndex: 1),
                                  ),
                                );
                                _fetchCalendarActivities(forceRefresh: true);
                              } else if (dealId != null && dealId.isNotEmpty) {
                                final dealModel = DealModel(
                                  id: dealId,
                                  title: dealName ?? 'Deal',
                                  amount: 0.0,
                                  stage: '',
                                  probability: 0,
                                );
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => DealDetailsScreen(deal: dealModel, initialTabIndex: 1),
                                  ),
                                );
                                _fetchCalendarActivities(forceRefresh: true);
                              } else if (lowerType == 'meeting') {
                                final meetingModel = MeetingModel(
                                  id: (item['id'] ?? item['_id'])?.toString(),
                                  title: title.toString(),
                                  outcome: (item['outcome'] ?? item['status'] ?? 'Scheduled').toString(),
                                  duration: (item['duration'] ?? '30 Minutes').toString(),
                                  startTime: (item['scheduledAt'] ?? item['dueDate'] ?? item['createdAt'] ?? '').toString(),
                                  notes: (item['notes'] ?? item['description'] ?? '').toString(),
                                  contactId: (item['contactId'] ?? item['contact_id'])?.toString(),
                                  companyId: (item['companyId'] ?? item['company_id'])?.toString(),
                                  dealId: (item['dealId'] ?? item['deal_id'])?.toString(),
                                );
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => MeetingDetailsScreen(meeting: meetingModel),
                                  ),
                                );
                                _fetchCalendarActivities(forceRefresh: true);
                              } else if (lowerType == 'call') {
                                final callModel = CallModel(
                                  id: (item['id'] ?? item['_id'])?.toString(),
                                  title: title.toString(),
                                  outcome: (item['outcome'] ?? item['status'] ?? 'Connected').toString(),
                                  duration: (item['duration'] ?? '5 Minutes').toString(),
                                  startTime: (item['scheduledAt'] ?? item['dueDate'] ?? item['createdAt'] ?? '').toString(),
                                  notes: (item['notes'] ?? item['description'] ?? '').toString(),
                                  contactId: (item['contactId'] ?? item['contact_id'])?.toString(),
                                  companyId: (item['companyId'] ?? item['company_id'])?.toString(),
                                  dealId: (item['dealId'] ?? item['deal_id'])?.toString(),
                                );
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => CallDetailsScreen(call: callModel),
                                  ),
                                );
                                _fetchCalendarActivities(forceRefresh: true);
                              } else if (lowerType == 'email') {
                                final emailModel = EmailModel(
                                  id: (item['id'] ?? item['_id'])?.toString(),
                                  title: title.toString(),
                                  status: (item['status'] ?? 'Logged').toString(),
                                  startTime: (item['scheduledAt'] ?? item['createdAt'] ?? '').toString(),
                                  notes: (item['notes'] ?? item['description'] ?? item['body'] ?? '').toString(),
                                );
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => EmailDetailsScreen(email: emailModel),
                                  ),
                                );
                                _fetchCalendarActivities(forceRefresh: true);
                              } else {
                                final taskModel = TaskModel(
                                  id: (item['id'] ?? item['_id'])?.toString(),
                                  title: title.toString(),
                                  dueDate: (item['dueDate'] ?? item['due_date'] ?? item['scheduledAt'] ?? item['createdAt'] ?? '').toString(),
                                  priority: (item['priority'] ?? 'Medium').toString(),
                                  status: (item['status'] ?? 'Pending').toString(),
                                  assignedTo: (item['assignedTo'] ?? item['owner']?['name'] ?? 'Admin User').toString(),
                                  notes: (item['notes'] ?? item['description'] ?? '').toString(),
                                  rawMap: item,
                                );
                                final refreshed = await Navigator.of(context).push<bool>(
                                  MaterialPageRoute(
                                    builder: (context) => TaskDetailsScreen(task: taskModel),
                                  ),
                                );
                                if (refreshed == true) {
                                  _fetchCalendarActivities(forceRefresh: true);
                                }
                              }
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: barColor,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title.toString(),
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF1E293B),
                                          ),
                                        ),
                                        Text(
                                          '$typeDisplay • $timeFormatted',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF8FAFC),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.calendar_today_outlined,
                              size: 30,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No events for this day',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'There are no scheduled activities for ${_shortMonthNames[date.month - 1]} ${date.day}.',
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              color: const Color(0xFF64748B),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final year = _focusedDate.year;
    final month = _focusedDate.month;
    final now = DateTime.now();

    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = firstDayOfMonth.weekday % 7; // 0 for Sun

    final prevMonthDays = DateTime(year, month, 0).day;

    final totalDaysNeeded = firstWeekday + daysInMonth;
    final itemCount = totalDaysNeeded > 35 ? 42 : 35;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Calendar',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: const Color(0xFF1E293B),
          ),
        ),
      ),
      body: _isLoadingApis && _activities.isEmpty
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00A884)),
              ),
            )
          : RefreshIndicator(
              onRefresh: () => _fetchCalendarActivities(forceRefresh: true),
              color: const Color(0xFF00A884),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // 1. Month Header & Navigation Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${_monthNames[month - 1]} $year',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 18,
                            color: Color(0xFF1E293B),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            height: 34,
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                InkWell(
                                  onTap: _previousMonth,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8),
                                    child: Icon(Icons.chevron_left, size: 20, color: Color(0xFF64748B)),
                                  ),
                                ),
                                Container(width: 1, height: 34, color: const Color(0xFFE2E8F0)),
                                InkWell(
                                  onTap: _goToToday,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Text(
                                      'Today',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF334155),
                                      ),
                                    ),
                                  ),
                                ),
                                Container(width: 1, height: 34, color: const Color(0xFFE2E8F0)),
                                InkWell(
                                  onTap: _nextMonth,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8),
                                    child: Icon(Icons.chevron_right, size: 20, color: Color(0xFF64748B)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 2. Meeting and Task Action Buttons Row
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _openMeetingForm,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.videocam_outlined, size: 18, color: Color(0xFF334155)),
                              const SizedBox(width: 8),
                              Text(
                                'Meeting',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _openTaskForm,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: const Color(0xFF0D7C66),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.more_vert, size: 18, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                'Task',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 3. Days of Week Header Row
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT']
                          .map(
                            (dayStr) => Expanded(
                              child: Center(
                                child: Text(
                                  dayStr,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 4. Monthly Calendar Grid View
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 0.62,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                    ),
                    itemCount: itemCount,
                    itemBuilder: (context, index) {
                      int dayNumber;
                      bool isCurrentMonth = true;
                      DateTime cellDate;

                      if (index < firstWeekday) {
                        // Overflow previous month
                        dayNumber = prevMonthDays - firstWeekday + index + 1;
                        isCurrentMonth = false;
                        cellDate = DateTime(year, month - 1, dayNumber);
                      } else if (index - firstWeekday < daysInMonth) {
                        // Current month
                        dayNumber = index - firstWeekday + 1;
                        isCurrentMonth = true;
                        cellDate = DateTime(year, month, dayNumber);
                      } else {
                        // Overflow next month
                        dayNumber = index - firstWeekday - daysInMonth + 1;
                        isCurrentMonth = false;
                        cellDate = DateTime(year, month + 1, dayNumber);
                      }

                      final isSelected = cellDate.year == _selectedDate.year &&
                          cellDate.month == _selectedDate.month &&
                          cellDate.day == _selectedDate.day;

                      final isTodayBadge = cellDate.year == now.year &&
                          cellDate.month == now.month &&
                          cellDate.day == now.day;

                      // Requirement 9: Get all activities for cell date
                      final cellActivities = _activities.where((act) {
                        final localDate = _getActivityLocalDate(act);
                        if (localDate == null) return false;
                        return localDate.year == cellDate.year &&
                            localDate.month == cellDate.month &&
                            localDate.day == cellDate.day;
                      }).toList();

                      return InkWell(
                        onTap: () => _showDateScheduleModal(cellDate),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF00A884)
                                    : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Day Number Badge
                              if (isTodayBadge)
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF0D7C66),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$dayNumber',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Padding(
                                  padding: const EdgeInsets.only(left: 2, top: 2),
                                  child: Text(
                                    '$dayNumber',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isCurrentMonth
                                          ? const Color(0xFF1E293B)
                                          : const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                ),
                              const Spacer(),

                              // Requirement 9: Dynamic activity indicators matching activity type
                              if (cellActivities.isNotEmpty)
                                Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: cellActivities.take(3).map((act) {
                                      final type = (act['type'] ?? '').toString().toLowerCase();
                                      Color dotColor;
                                      if (type == 'meeting') {
                                        dotColor = const Color(0xFF3B82F6);
                                      } else if (type == 'task') {
                                        dotColor = const Color(0xFF00A884);
                                      } else if (type == 'call') {
                                        dotColor = const Color(0xFFF59E0B);
                                      } else if (type == 'email') {
                                        dotColor = const Color(0xFF8B5CF6);
                                      } else {
                                        dotColor = const Color(0xFF64748B);
                                      }
                                      return Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 1),
                                        width: 5,
                                        height: 5,
                                        decoration: BoxDecoration(
                                          color: dotColor,
                                          shape: BoxShape.circle,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              const SizedBox(height: 6),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
