import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';

import '../../../../core/models/master_dropdown_model.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/network/network_exception.dart';
import '../../../../core/repositories/master_data_repository.dart';
import '../../../../core/widgets/record_association_sheet.dart';
import '../../../../core/storage/activity_association_storage.dart';
import '../../../../core/utils/activity_utils.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import 'follow_up_task_section.dart';

class TaskModel {
  final String? id;
  final String title;
  final String dueDate;
  final String priority;
  final String status;
  final String assignedTo;
  final String notes;
  final String? taskType;
  final String? queue;
  final String? activityDateText;
  final String? reminderText;
  final Map<String, dynamic>? rawMap;

  TaskModel({
    this.id,
    required this.title,
    required this.dueDate,
    required this.priority,
    required this.status,
    required this.assignedTo,
    this.notes = '',
    this.taskType = 'To-do',
    this.queue = 'None',
    this.activityDateText = 'In 3 business days (Tuesday)',
    this.reminderText = 'No reminder',
    this.rawMap,
  });
}

/// An activity-date choice: the label shown in the menu and the date it means.
/// [date] is null for the "Custom Date" entry, which opens a picker instead.
class _TaskDateOption {
  final String label;
  final DateTime? date;

  const _TaskDateOption(this.label, this.date);
}

class CreateTaskModal extends StatefulWidget {
  final TaskModel? taskToEdit;
  final String? contactId;
  final String? companyId;
  final String? dealId;
  final String associatedRecordName;

  const CreateTaskModal({
    super.key,
    this.taskToEdit,
    this.contactId,
    this.companyId,
    this.dealId,
    this.associatedRecordName = 'xyzzzz',
  });

  static Future<TaskModel?> show(
    BuildContext context, {
    TaskModel? taskToEdit,
    String? contactId,
    String? companyId,
    String? dealId,
    String associatedRecordName = 'xyzzzz',
  }) {
    return showModalBottomSheet<TaskModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateTaskModal(
        taskToEdit: taskToEdit,
        contactId: contactId,
        companyId: companyId,
        dealId: dealId,
        associatedRecordName: associatedRecordName,
      ),
    );
  }

  @override
  State<CreateTaskModal> createState() => _CreateTaskModalState();
}

class _CreateTaskModalState extends State<CreateTaskModal> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;

  String _activityDateText = 'In 3 business days (Tuesday)';
  String _timeText = '8:00 AM';
  String _reminderText = 'No reminder';

  /// Resolved date behind [_activityDateText]. Kept in sync with every pick so
  /// the payload carries the date the user actually chose.
  DateTime _activityDate = _defaultActivityDate();

  /// Set when the reminder is a hand-picked date.
  DateTime? _customReminderAt;

  String _selectedTaskType = 'To-do';
  String _selectedPriority = 'None';
  String _selectedQueue = 'None';
  String _selectedAssignee = 'Select ...';

  bool _isSubmitting = false;

  /// Last save failure, shown inside the sheet — a SnackBar alone sits behind
  /// this full-height modal and is invisible to the user.
  String? _submitError;

  // Associations state
  late Map<String, List<Map<String, String>>> _associations;

  int get _totalAssociations {
    return _associations['Companies']!.length +
        _associations['Contacts']!.length +
        _associations['Deals']!.length;
  }

  // Active formatting state toggles
  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderline = false;
  String _activeHeading = 'T';
  bool _isBullet = false;
  bool _isNumbered = false;

  void _applyFormatPrefix(String prefix, String suffix) {
    final text = _notesController.text;
    final selection = _notesController.selection;
    if (selection.isValid && !selection.isCollapsed) {
      final selectedText = text.substring(selection.start, selection.end);
      final newText = text.replaceRange(selection.start, selection.end, '$prefix$selectedText$suffix');
      _notesController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + prefix.length + selectedText.length + suffix.length),
      );
    } else {
      final cursor = selection.start >= 0 ? selection.start : text.length;
      final newText = text.replaceRange(cursor, cursor, '$prefix$suffix');
      _notesController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: cursor + prefix.length),
      );
    }
  }

  TextStyle _getContentStyle() {
    double fontSize = 14.0;
    FontWeight fontWeight = _isBold ? FontWeight.bold : FontWeight.normal;
    FontStyle fontStyle = _isItalic ? FontStyle.italic : FontStyle.normal;
    TextDecoration decoration = _isUnderline ? TextDecoration.underline : TextDecoration.none;

    if (_activeHeading == 'H1') {
      fontSize = 20.0;
      fontWeight = FontWeight.bold;
    } else if (_activeHeading == 'H2') {
      fontSize = 17.0;
      fontWeight = FontWeight.bold;
    }

    return GoogleFonts.poppins(
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      decoration: decoration,
      color: const Color(0xFF334155),
    );
  }

  List<MasterDropdownOptionModel> _apiPriorities = [];
  List<Map<String, dynamic>> _apiUsers = [];

  final List<String> _taskTypes = const ['To-do', 'Call', 'Email'];
  final List<String> _queues = const [
    'None',
    'Day 7 reminder',
    'follow-up 1',
    'follow up 2',
    'New Outreach',
  ];
  final List<String> _reminders = const [
    'No reminder',
    'At task due time',
    '30 minutes before',
    '1 hour before',
    '1 day before',
    '1 week before',
    'Custom Date',
  ];

  static DateTime _addBusinessDays(DateTime start, int days) {
    DateTime current = start;
    int added = 0;
    while (added < days) {
      current = current.add(const Duration(days: 1));
      if (current.weekday != DateTime.saturday && current.weekday != DateTime.sunday) {
        added++;
      }
    }
    return current;
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime _defaultActivityDate() => _addBusinessDays(_today(), 3);

  static const List<String> _monthAbbrs = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _formatDateLabel(DateTime date) =>
      '${_monthAbbrs[date.month - 1]} ${date.day}, ${date.year}';

  static List<_TaskDateOption> _generateTaskActivityDateOptions() {
    final today = _today();

    final in2Biz = _addBusinessDays(today, 2);
    final in3Biz = _addBusinessDays(today, 3);
    final in1Week = today.add(const Duration(days: 7));
    final in2Weeks = today.add(const Duration(days: 14));

    DateTime addMonths(DateTime start, int months) {
      int year = start.year;
      int month = start.month + months;
      while (month > 12) {
        month -= 12;
        year += 1;
      }
      int day = start.day;
      int daysInTargetMonth = DateUtils.getDaysInMonth(year, month);
      if (day > daysInTargetMonth) day = daysInTargetMonth;
      return DateTime(year, month, day);
    }

    final in1Month = addMonths(today, 1);
    final in3Months = addMonths(today, 3);
    final in6Months = addMonths(today, 6);

    String weekdayName(int weekday) {
      const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return names[weekday - 1];
    }

    String monthAbbr(int month) => _monthAbbrs[month - 1];

    return [
      _TaskDateOption('Today', today),
      _TaskDateOption('Tomorrow', today.add(const Duration(days: 1))),
      _TaskDateOption('In 2 business days (${weekdayName(in2Biz.weekday)})', in2Biz),
      _TaskDateOption('In 3 business days (${weekdayName(in3Biz.weekday)})', in3Biz),
      _TaskDateOption('In 1 week (${monthAbbr(in1Week.month)} ${in1Week.day})', in1Week),
      _TaskDateOption('In 2 weeks (${monthAbbr(in2Weeks.month)} ${in2Weeks.day})', in2Weeks),
      _TaskDateOption('In 1 month (${monthAbbr(in1Month.month)} ${in1Month.day})', in1Month),
      _TaskDateOption('In 3 months (${monthAbbr(in3Months.month)} ${in3Months.day})', in3Months),
      _TaskDateOption('In 6 months (${monthAbbr(in6Months.month)} ${in6Months.day})', in6Months),
      const _TaskDateOption('Custom Date', null),
    ];
  }

  /// Parses a `h:mm AM/PM` label back into hours/minutes. Falls back to 08:00.
  static ({int hour, int minute}) _parseTimeLabel(String label) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false)
        .firstMatch(label.trim());
    if (match == null) return (hour: 8, minute: 0);

    var hour = int.parse(match.group(1)!) % 12;
    final minute = int.parse(match.group(2)!);
    if (match.group(3)!.toUpperCase() == 'PM') hour += 12;
    return (hour: hour, minute: minute);
  }

  static String _formatTimeLabel(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final period = date.hour < 12 ? 'AM' : 'PM';
    return '$hour:${date.minute.toString().padLeft(2, '0')} $period';
  }

  /// The selected date and time as a single instant, in UTC ISO-8601 —
  /// the format `scheduledAt` expects.
  String _resolveScheduledAtIso() {
    final time = _parseTimeLabel(_timeText);
    final scheduled = DateTime(
      _activityDate.year,
      _activityDate.month,
      _activityDate.day,
      time.hour,
      time.minute,
    );
    return scheduled.toUtc().toIso8601String();
  }

  static List<String> _generateTaskTimeOptions() {
    List<String> times = [];
    for (int hour = 0; hour < 24; hour++) {
      for (int minute = 0; minute < 60; minute += 15) {
        final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
        final period = hour < 12 ? 'AM' : 'PM';
        final m = minute.toString().padLeft(2, '0');
        times.add('$h:$m $period');
      }
    }
    return times;
  }

  PopupMenuItem<String> _buildPopupMenuItem(String value, String currentValue) {
    final isSelected = value == currentValue;
    return PopupMenuItem<String>(
      value: value,
      height: 40,
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isSelected ? const Color(0xFFF1F5F9) : Colors.transparent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: const Color(0xFF334155),
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check,
                color: Color(0xFF00A884),
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _associations = {
      'Companies': widget.companyId != null ? [{'id': widget.companyId!, 'name': widget.associatedRecordName}] : [],
      'Contacts': widget.contactId != null ? [{'id': widget.contactId!, 'name': widget.associatedRecordName}] : [],
      'Deals': widget.dealId != null ? [{'id': widget.dealId!, 'name': widget.associatedRecordName}] : [],
    };
    final editTask = widget.taskToEdit;
    _titleController = TextEditingController(text: parseActivityDescription(editTask?.title ?? ''));
    _notesController = TextEditingController(text: parseActivityDescription(editTask?.notes ?? ''));

    if (editTask != null) {
      if (editTask.priority.isNotEmpty) _selectedPriority = editTask.priority;
      if (editTask.assignedTo.isNotEmpty && editTask.assignedTo != 'Admin User') {
        _selectedAssignee = editTask.assignedTo;
      }
      if (editTask.taskType != null && editTask.taskType!.isNotEmpty) {
        _selectedTaskType = editTask.taskType!;
      }
      if (editTask.queue != null && editTask.queue!.isNotEmpty) {
        _selectedQueue = editTask.queue!;
      }
      // Prefer the stored due date — it is the only source that survives a
      // reload; activityDateText carries the model's default otherwise.
      final storedDue = DateTime.tryParse(editTask.dueDate)?.toLocal();
      if (storedDue != null) {
        _activityDate = DateTime(storedDue.year, storedDue.month, storedDue.day);
        _activityDateText = _formatDateLabel(_activityDate);
        _timeText = _formatTimeLabel(storedDue);
      } else if (editTask.activityDateText != null && editTask.activityDateText!.isNotEmpty) {
        _activityDateText = editTask.activityDateText!;
      }
      if (editTask.reminderText != null && editTask.reminderText!.isNotEmpty) {
        _reminderText = editTask.reminderText!;
      }
    }

    _loadMasterData();
  }

  Future<void> _loadMasterData() async {
    try {
      final repo = MasterDataRepositoryImpl();
      await repo.getMasterDropdownByKey('task_status', includeInactive: false);
      final priorities = await repo.getMasterDropdownByKey('task_priority', includeInactive: false);
      
      List<Map<String, dynamic>> usersList = [];
      try {
        final resp = await ApiService().get('/users');
        final raw = resp.data;
        if (raw is List) {
          usersList = raw.whereType<Map<String, dynamic>>().toList();
        } else if (raw is Map<String, dynamic> && raw['data'] is List) {
          usersList = (raw['data'] as List).whereType<Map<String, dynamic>>().toList();
        }
      } catch (e) {
        debugPrint('[FETCH /users IN TASK MODAL ERROR]: $e');
      }

      if (mounted) {
        setState(() {
          _apiPriorities = priorities;
          _apiUsers = usersList;

          if (widget.taskToEdit == null && priorities.isNotEmpty) {
            final defaultP = priorities.firstWhere((p) => p.isDefault, orElse: () => priorities.first);
            _selectedPriority = defaultP.label;
          }
        });
      }
    } catch (e) {
      debugPrint('[TaskModal _loadMasterData Error]: $e');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.taskToEdit != null;

    // Growable copies: an existing task's priority/assignee often isn't in the
    // fallback options, and appending to a const list throws while building.
    final prioritiesList = <String>[
      if (_apiPriorities.isNotEmpty)
        ..._apiPriorities.map((p) => p.label)
      else
        ...['None', 'Low', 'Medium', 'High'],
    ];

    if (_selectedPriority.isNotEmpty && !prioritiesList.contains(_selectedPriority)) {
      prioritiesList.add(_selectedPriority);
    }

    final usersDisplayList = <String>[
      if (_apiUsers.isNotEmpty)
        ..._apiUsers.map((u) {
          final first = u['firstName'] as String? ?? u['first_name'] as String? ?? '';
          final last = u['lastName'] as String? ?? u['last_name'] as String? ?? '';
          final name = '$first $last'.trim();
          return name.isNotEmpty ? name : u['email'] as String? ?? 'User';
        })
      else
        ...['Admin User', 'Abhishek Puranik', 'Select ...'],
    ];

    if (_selectedAssignee.isNotEmpty && !usersDisplayList.contains(_selectedAssignee)) {
      usersDisplayList.add(_selectedAssignee);
    }

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Column(
        children: [
          // 1. Dark Top Header matching 2nd Image
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF475569), // Dark steel grey as image 2
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isEditing ? 'Task' : 'Task',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _titleController.clear();
                          _notesController.clear();
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Task form data refreshed'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      tooltip: 'Refresh Form Data',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Form Body
          Expanded(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                // Enter task name... textfield container
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF5FB6AD), width: 1.5),
                  ),
                  child: TextField(
                    controller: _titleController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Enter task name...',
                      hintStyle: GoogleFonts.poppins(
                        color: const Color(0xFF94A3B8),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                    ),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                // Activity date label
                Text(
                  'Activity date',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),

                // Activity date & time pickers row
                Row(
                  children: [
                    PopupMenuButton<String>(
                      onSelected: (val) async {
                        if (val == 'Custom Date') {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _activityDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null && mounted) {
                            setState(() {
                              _activityDate = DateTime(picked.year, picked.month, picked.day);
                              _activityDateText = _formatDateLabel(_activityDate);
                            });
                          }
                        } else {
                          final option = _generateTaskActivityDateOptions()
                              .firstWhere((o) => o.label == val, orElse: () => const _TaskDateOption('', null));
                          setState(() {
                            _activityDateText = val;
                            if (option.date != null) _activityDate = option.date!;
                          });
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _activityDateText,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF00A884),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Color(0xFF00A884),
                            size: 18,
                          ),
                        ],
                      ),
                      itemBuilder: (context) {
                        final dates = _generateTaskActivityDateOptions();
                        return dates.map((d) => _buildPopupMenuItem(d.label, _activityDateText)).toList();
                      },
                    ),
                    const SizedBox(width: 12),
                    PopupMenuButton<String>(
                      onSelected: (val) async {
                        if (val == 'Custom Time...') {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (pickedTime != null && mounted) {
                            final hour = pickedTime.hourOfPeriod == 0 ? 12 : pickedTime.hourOfPeriod;
                            final period = pickedTime.period == DayPeriod.am ? 'AM' : 'PM';
                            final minute = pickedTime.minute.toString().padLeft(2, '0');
                            setState(() {
                              _timeText = '$hour:$minute $period';
                            });
                          }
                        } else {
                          setState(() {
                            _timeText = val;
                          });
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 16,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _timeText,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Color(0xFF94A3B8),
                            size: 18,
                          ),
                        ],
                      ),
                      itemBuilder: (context) {
                        final times = _generateTaskTimeOptions();
                        return [
                          ...times.map((t) => _buildPopupMenuItem(t, _timeText)),
                          _buildPopupMenuItem('Custom Time...', _timeText),
                        ];
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Send reminder label
                Text(
                  'Send reminder',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),

                // Send reminder dropdown
                PopupMenuButton<String>(
                  onSelected: (val) async {
                    if (val == 'Custom Date') {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                      );
                      if (picked != null && mounted) {
                        setState(() {
                          _customReminderAt = picked;
                          _reminderText = _formatDateLabel(picked);
                        });
                      }
                    } else {
                      setState(() {
                        _customReminderAt = null;
                        _reminderText = val;
                      });
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _reminderText,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF00A884),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF00A884),
                        size: 18,
                      ),
                    ],
                  ),
                  itemBuilder: (context) => _reminders
                      .map((r) => _buildPopupMenuItem(r, _reminderText))
                      .toList(),
                ),
                const SizedBox(height: 4),

                // 4 Columns: Task Type, Priority, Queue, Activity assigned to
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Task Type
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Task Type',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          PopupMenuButton<String>(
                            onSelected: (val) => setState(() => _selectedTaskType = val),
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _selectedTaskType,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF00A884),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Color(0xFF00A884),
                                  size: 16,
                                ),
                              ],
                            ),
                            itemBuilder: (context) => _taskTypes
                                .map((t) => PopupMenuItem(
                                      value: t,
                                      child: Text(t, style: GoogleFonts.poppins(fontSize: 12.5)),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),

                    // Priority
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Priority',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          PopupMenuButton<String>(
                            onSelected: (val) => setState(() => _selectedPriority = val),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF99ACC2),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _selectedPriority,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF00A884),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Color(0xFF00A884),
                                  size: 16,
                                ),
                              ],
                            ),
                            itemBuilder: (context) => prioritiesList
                                .map((p) => PopupMenuItem(
                                      value: p,
                                      child: Text(p, style: GoogleFonts.poppins(fontSize: 12.5)),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),

                    // Queue
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Queue',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          PopupMenuButton<String>(
                            onSelected: (val) => setState(() => _selectedQueue = val),
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _selectedQueue,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF00A884),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Color(0xFF00A884),
                                  size: 16,
                                ),
                              ],
                            ),
                            itemBuilder: (context) => _queues
                                .map((q) => PopupMenuItem(
                                      value: q,
                                      child: Text(q, style: GoogleFonts.poppins(fontSize: 12.5)),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),

                    // Activity assigned to
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Activity assigned to',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          PopupMenuButton<String>(
                            onSelected: (val) => setState(() => _selectedAssignee = val),
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _selectedAssignee,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF00A884),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Color(0xFF00A884),
                                  size: 16,
                                ),
                              ],
                            ),
                            itemBuilder: (context) => usersDisplayList
                                .map((u) => PopupMenuItem(
                                      value: u,
                                      child: Text(u, style: GoogleFonts.poppins(fontSize: 12.5)),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Rich Toolbar & Notes Card
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      // Toolbar Row (same spacing as Note form)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFormatIconButton('B', isActive: _isBold, isBold: true, onTap: () {
                                setState(() => _isBold = !_isBold);
                              }),
                              _buildFormatIconButton('I', isActive: _isItalic, isItalic: true, onTap: () {
                                setState(() => _isItalic = !_isItalic);
                              }),
                              _buildFormatIconButton('U', isActive: _isUnderline, isUnderline: true, onTap: () {
                                setState(() => _isUnderline = !_isUnderline);
                              }),
                              const SizedBox(width: 10),
                              const SizedBox(height: 24, child: VerticalDivider(color: Color(0xFFCBD5E1), width: 1)),
                              const SizedBox(width: 10),
                              _buildHeadingOption('H1'),
                              _buildHeadingOption('H2'),
                              _buildHeadingOption('T'),
                              const SizedBox(width: 10),
                              const SizedBox(height: 24, child: VerticalDivider(color: Color(0xFFCBD5E1), width: 1)),
                              const SizedBox(width: 10),
                              InkWell(
                                onTap: () {
                                  setState(() => _isBullet = !_isBullet);
                                  _applyFormatPrefix('• ', '');
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  child: Icon(Icons.format_list_bulleted, size: 24, color: _isBullet ? const Color(0xFF00A884) : const Color(0xFF64748B)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () {
                                  setState(() => _isNumbered = !_isNumbered);
                                  _applyFormatPrefix('1. ', '');
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  child: Icon(Icons.format_list_numbered, size: 24, color: _isNumbered ? const Color(0xFF00A884) : const Color(0xFF64748B)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('File attachment added', style: GoogleFonts.poppins(fontSize: 13)),
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  child: Icon(Icons.attach_file_rounded, size: 24, color: Color(0xFF64748B)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const SizedBox(height: 24, child: VerticalDivider(color: Color(0xFFCBD5E1), width: 1)),
                              const SizedBox(width: 10),
                              InkWell(
                                onTap: () {
                                  if (_notesController.text.isNotEmpty) {
                                    _notesController.clear();
                                  }
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  child: Icon(Icons.undo_rounded, size: 24, color: Color(0xFF64748B)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                child: Icon(Icons.redo_rounded, size: 24, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),

                      // Notes Input Field
                      Container(
                        constraints: const BoxConstraints(minHeight: 100),
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: _notesController,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          decoration: InputDecoration(
                            hintText: 'Notes...',
                            hintStyle: GoogleFonts.poppins(
                              color: const Color(0xFF94A3B8),
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                          ),
                          style: _getContentStyle(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FollowUpTaskSection(
                  initialChecked: false,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // Pinned Bottom Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Save failures are shown here: a SnackBar renders behind this
                // full-height sheet and would never be seen.
                if (_submitError != null) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _submitError!,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00A884),
                        disabledBackgroundColor: const Color(0xFF70D1C4),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              isEditing ? 'Save' : 'Create',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                    InkWell(
                      onTap: () async {
                        final result = await RecordAssociationSheet.show(
                          context,
                          initialAssociations: _associations,
                        );
                        if (result != null) {
                          setState(() {
                            _associations = result;
                          });
                        }
                      },
                      child: Row(
                        children: [
                          Text(
                            'Associated with $_totalAssociations record${_totalAssociations > 1 ? 's' : ''}',
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF00A884),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Color(0xFF00A884),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildFormatIconButton(String label, {required bool isActive, bool isBold = false, bool isItalic = false, bool isUnderline = false, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
            decoration: isUnderline ? TextDecoration.underline : TextDecoration.none,
            color: isActive ? const Color(0xFF00A884) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildHeadingOption(String type) {
    final isSelected = _activeHeading == type;
    if (type == 'T') {
      return InkWell(
        onTap: () => setState(() => _activeHeading = 'T'),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFCCFBF1) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'T',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isSelected ? const Color(0xFF0F766E) : const Color(0xFF64748B),
            ),
          ),
        ),
      );
    }

    return InkWell(
      onTap: () => setState(() => _activeHeading = type),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          type,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isSelected ? const Color(0xFF00A884) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }


  /// Priority values the activities API accepts.
  static const Set<String> _apiPriorityValues = {'none', 'low', 'medium', 'high'};

  /// Maps the selected priority label onto the API enum, preferring the value
  /// the master-dropdown API itself supplied. Returns null when the label maps
  /// to nothing valid, so the field is left out instead of failing validation.
  String? _resolvePriority() {
    for (final option in _apiPriorities) {
      if (option.label == _selectedPriority && option.value.isNotEmpty) {
        final value = option.value.trim().toLowerCase();
        if (_apiPriorityValues.contains(value)) return value;
      }
    }
    final fallback = _selectedPriority.trim().toLowerCase();
    return _apiPriorityValues.contains(fallback) ? fallback : null;
  }

  String _resolveReminderType() {
    if (_customReminderAt != null) return 'custom';
    if (_reminderText == 'No reminder') return 'none';
    return _reminderText.trim().toLowerCase().replaceAll(' ', '_');
  }

  /// Resolves the owner: the picked assignee if it matches a fetched user,
  /// otherwise the signed-in user.
  String? _resolveOwnerId() {
    for (final user in _apiUsers) {
      final first = user['firstName'] as String? ?? user['first_name'] as String? ?? '';
      final last = user['lastName'] as String? ?? user['last_name'] as String? ?? '';
      final name = '$first $last'.trim();
      final email = user['email'] as String? ?? '';
      if ((name.isNotEmpty && name == _selectedAssignee) ||
          (email.isNotEmpty && email == _selectedAssignee)) {
        final id = user['id']?.toString();
        if (id != null && id.isNotEmpty) return id;
      }
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      return authProvider.currentUser?.id ??
          authProvider.loginResponse?.user?['id']?.toString();
    } catch (_) {
      return null;
    }
  }

  static const Map<String, String> _associationObjectTypes = {
    'Companies': 'company',
    'Contacts': 'contact',
    'Deals': 'deal',
  };

  /// The `associations` field the API expects: a flat `[{objectId, objectType}]`
  /// list. The record this modal was opened from is always included.
  List<Map<String, String>> _buildAssociations() {
    final list = <Map<String, String>>[];
    final seen = <String>{};

    void add(String? id, String objectType) {
      final value = id?.trim();
      if (value == null || value.isEmpty) return;
      if (!seen.add('$objectType:$value')) return;
      list.add({'objectId': value, 'objectType': objectType});
    }

    _associations.forEach((group, records) {
      final objectType = _associationObjectTypes[group];
      if (objectType == null) return;
      for (final record in records) {
        add(record['id'], objectType);
      }
    });

    add(widget.companyId, 'company');
    add(widget.contactId, 'contact');
    add(widget.dealId, 'deal');

    return list;
  }

  /// First association of [objectType], used for the primary `contactId` /
  /// `companyId` / `dealId` links.
  String? _primaryId(List<Map<String, String>> associations, String objectType) {
    for (final association in associations) {
      if (association['objectType'] == objectType) return association['objectId'];
    }
    return null;
  }

  /// Pulls a readable message out of whatever the server sent back.
  static String? _serverMessage(dynamic data) {
    if (data is String && data.trim().isNotEmpty) return data.trim();
    if (data is Map) {
      final message = data['message'] ?? data['error'];
      if (message is String && message.trim().isNotEmpty) return message.trim();

      final errors = data['errors'];
      if (errors is List && errors.isNotEmpty) {
        final first = errors.first;
        if (first is String && first.trim().isNotEmpty) return first.trim();
        if (first is Map) {
          final detail = first['message'] ?? first['msg'] ?? first['error'];
          if (detail is String && detail.trim().isNotEmpty) return detail.trim();
        }
      }
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is String && first.trim().isNotEmpty) return first.trim();
        if (first is List && first.isNotEmpty) return first.first.toString();
      }
    }
    return null;
  }

  static String _describeError(Object error) {
    if (error is NetworkException) {
      return _serverMessage(error.data) ?? error.message;
    }
    if (error is DioException) {
      return _serverMessage(error.response?.data) ??
          (error.message?.isNotEmpty == true
              ? error.message!
              : 'Request failed. Please try again.');
    }
    return error.toString();
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _submitError = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    debugPrint('[CREATE TASK BUTTON CLICKED]');
    if (_isSubmitting) return;

    final titleText = _titleController.text.trim();
    if (titleText.isEmpty) {
      _showError('Please enter a task name');
      return;
    }
    if (titleText.length > 255) {
      _showError('Task name must be 255 characters or fewer');
      return;
    }

    final notesText = _notesController.text.trim();

    final taskId = widget.taskToEdit?.id;
    final isEditing = taskId != null && taskId.isNotEmpty;

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final scheduledAtIso = _resolveScheduledAtIso();
      final associations = _buildAssociations();

      final companyId = _primaryId(associations, 'company');
      final contactId = _primaryId(associations, 'contact');
      final dealId = _primaryId(associations, 'deal');

      final ownerId = _resolveOwnerId();
      final priority = _resolvePriority();
      final editedStatus = isEditing ? _normalizeStatus(widget.taskToEdit!.status) : null;

      // Body per POST/PATCH /api/activities.
      final payload = <String, dynamic>{
        'type': 'task',
        'title': titleText,
        'description': notesText,
        'scheduledAt': scheduledAtIso,
        'reminderType': _resolveReminderType(),
        if (_customReminderAt != null)
          'customReminderAt': _customReminderAt!.toUtc().toIso8601String(),
        if (priority != null) 'priority': priority,
        if (ownerId != null && ownerId.isNotEmpty) 'ownerId': ownerId,
        'queue': (_selectedQueue == 'None' || _selectedQueue.isEmpty) ? null : _selectedQueue,
        if (contactId != null) 'contactId': contactId,
        if (companyId != null) 'companyId': companyId,
        if (dealId != null) 'dealId': dealId,
        if (associations.isNotEmpty) 'associations': associations,
        // status is only accepted on update.
        if (isEditing && editedStatus != null) 'status': editedStatus,
      };

      debugPrint('[${isEditing ? 'PATCH' : 'POST'} ${ApiConstants.activities} PAYLOAD]: $payload');

      final Response res = isEditing
          ? await ApiService().patch(
              '${ApiConstants.activities}/$taskId',
              data: payload,
            )
          : await ApiService().post(
              ApiConstants.activities,
              data: payload,
            );

      debugPrint('[${isEditing ? 'PATCH' : 'POST'} ${ApiConstants.activities} SUCCESS]: ${res.statusCode} -> ${res.data}');

      // 201/200 answer with the raw activity object; tolerate wrapped shapes.
      Map<String, dynamic> dataMap = {};
      if (res.data is Map) {
        final rawMap = Map<String, dynamic>.from(res.data as Map);
        if (rawMap['data'] is Map) {
          dataMap = Map<String, dynamic>.from(rawMap['data'] as Map);
        } else if (rawMap['activity'] is Map) {
          dataMap = Map<String, dynamic>.from(rawMap['activity'] as Map);
        } else if (rawMap['task'] is Map) {
          dataMap = Map<String, dynamic>.from(rawMap['task'] as Map);
        } else {
          dataMap = rawMap;
        }
      }

      final createdId = (dataMap['id'] ??
                  dataMap['_id'] ??
                  dataMap['activityId'] ??
                  dataMap['activity_id'])
              ?.toString() ??
          taskId ??
          '';

      if (createdId.isNotEmpty) {
        await ActivityAssociationStorage.saveAssociations(createdId, _associations);
      }

      if (!mounted) return;

      final savedTask = TaskModel(
        id: createdId.isNotEmpty ? createdId : null,
        title: titleText,
        dueDate: (dataMap['scheduledAt'] ?? dataMap['dueDate'])?.toString() ?? scheduledAtIso,
        priority: _selectedPriority,
        status: dataMap['status']?.toString() ??
            (isEditing ? widget.taskToEdit!.status : 'pending'),
        assignedTo: _selectedAssignee != 'Select ...' ? _selectedAssignee : 'Admin User',
        notes: notesText,
        taskType: _selectedTaskType,
        queue: dataMap.containsKey('queue') ? (dataMap['queue']?.toString() ?? 'None') : _selectedQueue,
        activityDateText: _activityDateText,
        reminderText: _reminderText,
        rawMap: dataMap.isNotEmpty ? dataMap : payload,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing ? 'Task updated successfully!' : 'Task created successfully!',
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          backgroundColor: const Color(0xFF00A884),
          duration: const Duration(seconds: 2),
        ),
      );

      // Returning the task closes the sheet and tells the caller to refresh.
      Navigator.of(context).pop(savedTask);
    } catch (e, stack) {
      debugPrint('[SAVE TASK ERROR]: $e\n$stack');
      _showError('Failed to save task: ${_describeError(e)}');
    } finally {
      // Always release the button, whatever happened above.
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  /// The API status enum is lowercase (`pending` · `completed` · `cancelled` ·
  /// `reopened`); the UI carries mixed casing. Anything outside the enum
  /// returns null so the field is left untouched rather than overwritten.
  static String? _normalizeStatus(String status) {
    final normalized = status.trim().toLowerCase();
    const allowed = {'pending', 'completed', 'cancelled', 'reopened'};
    return allowed.contains(normalized) ? normalized : null;
  }
}
