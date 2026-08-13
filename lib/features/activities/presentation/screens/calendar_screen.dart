import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/network/api_service.dart';
import '../widgets/create_task_modal.dart';
import '../widgets/log_meeting_modal.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDate = DateTime(2026, 8, 7);
  DateTime _selectedDate = DateTime(2026, 8, 7);
  bool _isLoadingApis = false;
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
      _fetchAllApis();
    });
  }

  /// Fetches all 18 APIs shown in Image 4 concurrently
  Future<void> _fetchAllApis() async {
    if (!mounted) return;
    setState(() {
      _isLoadingApis = true;
    });

    final api = ApiService();
    final startDateStr = DateTime(_focusedDate.year, _focusedDate.month, 1).toIso8601String();
    final endDateStr = DateTime(_focusedDate.year, _focusedDate.month + 1, 0, 23, 59, 59).toIso8601String();

    try {
      await Future.wait([
        api.get('/auth/me').catchError((e) => null),
        api.get('/activities/stream').catchError((e) => null),
        api.get('/activities/notifications').catchError((e) => null),
        api.get('/departments').catchError((e) => null),
        api.get('/lifecycle-stages?entityType=company').catchError((e) => null),
        api.get('/master-dropdowns/key/company_industry?includeInactive=false').catchError((e) => null),
        api.get('/master-dropdowns/key/company_type?includeInactive=false').catchError((e) => null),
        api.get('/contacts?page=1&limit=25').catchError((e) => null),
        api.get('/msp-options').catchError((e) => null),
        api.get('/lifecycle-stages?entityType=contact').catchError((e) => null),
        api.get('/companies?page=1&limit=25').catchError((e) => null),
        api.get('/master-dropdowns/key/contact_lead_status?includeInactive=false').catchError((e) => null),
        api.get('/deals/stages').catchError((e) => null),
        api.get('/deals?page=1&limit=25').catchError((e) => null),
        api.get('/activities/notifications?isRead=false&limit=10').catchError((e) => null),
        api.get('/activities?startDate=$startDateStr&endDate=$endDateStr').then((res) {
          if (res.data != null && mounted) {
            final raw = res.data;
            if (raw is List) {
              _activities = raw.whereType<Map<String, dynamic>>().toList();
            } else if (raw is Map<String, dynamic> && raw['data'] is List) {
              _activities = (raw['data'] as List).whereType<Map<String, dynamic>>().toList();
            }
          }
          return res;
        }).catchError((e) => null),
        api.get('/auth/team').catchError((e) => null),
        api.get('/activities?ownerId=me').catchError((e) => null),
      ]);
    } catch (e) {
      debugPrint('[CalendarScreen _fetchAllApis error]: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingApis = false;
        });
      }
    }
  }

  void _previousMonth() {
    setState(() {
      _focusedDate = DateTime(_focusedDate.year, _focusedDate.month - 1, 1);
    });
    _fetchAllApis();
  }

  void _nextMonth() {
    setState(() {
      _focusedDate = DateTime(_focusedDate.year, _focusedDate.month + 1, 1);
    });
    _fetchAllApis();
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _focusedDate = DateTime(now.year, now.month, now.day);
      _selectedDate = DateTime(now.year, now.month, now.day);
    });
    _fetchAllApis();
  }

  void _openTaskForm() async {
    final result = await CreateTaskModal.show(context);
    if (result != null) {
      _fetchAllApis();
    }
  }

  void _openMeetingForm() async {
    final result = await LogMeetingModal.show(context);
    if (result != null) {
      _fetchAllApis();
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
        final dateActivities = _activities.where((act) {
          final actDate = act['dueDate'] ?? act['activityDate'] ?? act['createdAt'];
          if (actDate == null) return false;
          try {
            final parsed = DateTime.parse(actDate.toString());
            return parsed.year == date.year && parsed.month == date.month && parsed.day == date.day;
          } catch (_) {
            return false;
          }
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
              // Header Title (5th Image)
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

              // Action Buttons Row (5th Image)
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

              // Content Area (5th Image)
              Expanded(
                child: dateActivities.isNotEmpty
                    ? ListView.separated(
                        itemCount: dateActivities.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = dateActivities[index];
                          final title = item['title'] ?? item['name'] ?? 'Activity';
                          final type = item['type'] ?? 'Task';
                          return Container(
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
                                    color: type == 'Meeting'
                                        ? const Color(0xFF3B82F6)
                                        : const Color(0xFF00A884),
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
                                        '$type • Scheduled',
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

    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = firstDayOfMonth.weekday % 7; // 0 for Sun

    final prevMonthDays = DateTime(year, month, 0).day;

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
      body: _isLoadingApis
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00A884)),
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // 1. Month Header & Navigation Row (Image 1)
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

                // 2. Meeting and Task Action Buttons Row (Image 1)
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

                // 3. Days of Week Header Row (Image 1)
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

                // 4. Monthly Calendar Grid View with Adjusted Spacing (Image 1)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 0.62,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  itemCount: 35, // 5 rows of 7 days
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

                    final isTodayBadge = isCurrentMonth && dayNumber == 7;

                    return InkWell(
                      onTap: () => _showDateScheduleModal(cellDate),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFF1F5F9)),
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

                            // Indicators matching image 1
                            if (isCurrentMonth && dayNumber == 5)
                              const Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircleAvatar(radius: 2.5, backgroundColor: Color(0xFF3B82F6)),
                                    SizedBox(width: 2),
                                    CircleAvatar(radius: 2.5, backgroundColor: Color(0xFF3B82F6)),
                                    SizedBox(width: 2),
                                    CircleAvatar(radius: 2.5, backgroundColor: Color(0xFF3B82F6)),
                                  ],
                                ),
                              )
                            else if (isCurrentMonth && dayNumber == 11)
                              const Center(
                                child: CircleAvatar(radius: 3, backgroundColor: Color(0xFFEAB308)),
                              )
                            else if (isCurrentMonth && dayNumber == 13)
                              const Center(
                                child: CircleAvatar(radius: 3, backgroundColor: Color(0xFF22C55E)),
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
    );
  }
}
