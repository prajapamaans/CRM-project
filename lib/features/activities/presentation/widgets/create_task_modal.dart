import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';

import '../../../../core/models/master_dropdown_model.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/repositories/master_data_repository.dart';
import '../../../../core/widgets/record_association_sheet.dart';
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

  String _selectedTaskType = 'To-do';
  String _selectedPriority = 'None';
  String _selectedQueue = 'None';
  String _selectedAssignee = 'Select ...';

  bool _isSubmitting = false;

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

  static List<String> _generateTaskActivityDateOptions() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime addBusinessDays(DateTime start, int days) {
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

    final in2Biz = addBusinessDays(today, 2);
    final in3Biz = addBusinessDays(today, 3);
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

    String monthAbbr(int month) {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return months[month - 1];
    }

    return [
      'Today',
      'Tomorrow',
      'In 2 business days (${weekdayName(in2Biz.weekday)})',
      'In 3 business days (${weekdayName(in3Biz.weekday)})',
      'In 1 week (${monthAbbr(in1Week.month)} ${in1Week.day})',
      'In 2 weeks (${monthAbbr(in2Weeks.month)} ${in2Weeks.day})',
      'In 1 month (${monthAbbr(in1Month.month)} ${in1Month.day})',
      'In 3 months (${monthAbbr(in3Months.month)} ${in3Months.day})',
      'In 6 months (${monthAbbr(in6Months.month)} ${in6Months.day})',
      'Custom Date',
    ];
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
      'Contacts': widget.contactId != null ? [{'id': widget.contactId!, 'name': widget.associatedRecordName}] : widget.companyId == null && widget.dealId == null ? [{'id': '1', 'name': widget.associatedRecordName}] : [],
      'Deals': widget.dealId != null ? [{'id': widget.dealId!, 'name': widget.associatedRecordName}] : [],
    };
    final editTask = widget.taskToEdit;
    _titleController = TextEditingController(text: editTask?.title ?? '');
    _notesController = TextEditingController(text: editTask?.notes ?? '');

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
      if (editTask.activityDateText != null && editTask.activityDateText!.isNotEmpty) {
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
    final prioritiesList = _apiPriorities.isNotEmpty
        ? _apiPriorities.map((p) => p.label).toList()
        : const ['None', 'Low', 'Medium', 'High'];

    if (!prioritiesList.contains(_selectedPriority) && prioritiesList.isNotEmpty) {
      prioritiesList.add(_selectedPriority);
    }

    final usersDisplayList = _apiUsers.isNotEmpty
        ? _apiUsers.map((u) {
            final first = u['firstName'] as String? ?? u['first_name'] as String? ?? '';
            final last = u['lastName'] as String? ?? u['last_name'] as String? ?? '';
            final name = '$first $last'.trim();
            return name.isNotEmpty ? name : u['email'] as String? ?? 'User';
          }).toList()
        : const ['Admin User', 'Abhishek Puranik', 'Select ...'];

    if (!usersDisplayList.contains(_selectedAssignee)) {
      usersDisplayList.add(_selectedAssignee);
    }

    return Container(
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
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null && mounted) {
                            final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                            setState(() {
                              _activityDateText = '${months[picked.month - 1]} ${picked.day}, ${picked.year}';
                            });
                          }
                        } else {
                          setState(() {
                            _activityDateText = val;
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
                        return dates.map((d) => _buildPopupMenuItem(d, _activityDateText)).toList();
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
                        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                        setState(() {
                          _reminderText = '${months[picked.month - 1]} ${picked.day}, ${picked.year}';
                        });
                      }
                    } else {
                      setState(() {
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
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: !_isSubmitting ? _handleSubmit : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF70D1C4),
                          disabledBackgroundColor: const Color(0xFFA5E3DB),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
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
                ),
                const SizedBox(height: 160),
              ],
            ),
          ),
        ],
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

  Future<void> _handleSubmit() async {
    final finalTitle = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : 'New Task';
    final notesText = _notesController.text.trim();

    setState(() {
      _isSubmitting = true;
    });

    // 1. Serialized JSON document for description field as expected by backend API
    final String descriptionJson = jsonEncode({
      'type': 'doc',
      'content': [
        {
          'type': 'paragraph',
          if (notesText.isNotEmpty)
            'content': [
              {
                'type': 'text',
                'text': notesText,
              }
            ]
        }
      ]
    });

    // 2. Dynamic Associations array
    final List<Map<String, String>> associations = [];
    if (widget.contactId != null && widget.contactId!.isNotEmpty) {
      associations.add({
        'objectId': widget.contactId!,
        'objectType': 'contact',
      });
    }
    if (widget.companyId != null && widget.companyId!.isNotEmpty) {
      associations.add({
        'objectId': widget.companyId!,
        'objectType': 'company',
      });
    }
    if (widget.dealId != null && widget.dealId!.isNotEmpty) {
      associations.add({
        'objectId': widget.dealId!,
        'objectType': 'deal',
      });
    }

    // 3. Owner ID resolution
    String? ownerId;
    for (final user in _apiUsers) {
      final first = user['firstName'] as String? ?? user['first_name'] as String? ?? '';
      final last = user['lastName'] as String? ?? user['last_name'] as String? ?? '';
      final name = '$first $last'.trim();
      final email = user['email'] as String? ?? '';
      if ((name.isNotEmpty && name == _selectedAssignee) || (email.isNotEmpty && email == _selectedAssignee)) {
        ownerId = user['id']?.toString();
        break;
      }
    }
    if (ownerId == null || ownerId.isEmpty) {
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        ownerId = authProvider.currentUser?.id ?? authProvider.loginResponse?.user?['id']?.toString();
      } catch (_) {}
    }

    // 4. ISO 8601 UTC date string
    final scheduledDateTime = DateTime.now().add(const Duration(days: 3));
    final scheduledAtIso = scheduledDateTime.toUtc().toIso8601String();

    String? targetCompanyId = widget.companyId;
    if ((targetCompanyId == null || targetCompanyId.isEmpty) &&
        _associations['Companies'] != null &&
        _associations['Companies']!.isNotEmpty) {
      targetCompanyId = _associations['Companies']!.first['id'];
    }

    String? targetContactId = widget.contactId;
    if ((targetContactId == null || targetContactId.isEmpty) &&
        _associations['Contacts'] != null &&
        _associations['Contacts']!.isNotEmpty) {
      targetContactId = _associations['Contacts']!.first['id'];
    }

    String? targetDealId = widget.dealId;
    if ((targetDealId == null || targetDealId.isEmpty) &&
        _associations['Deals'] != null &&
        _associations['Deals']!.isNotEmpty) {
      targetDealId = _associations['Deals']!.first['id'];
    }

    // 5. Confirmed API payload structure
    final taskPayload = {
      'type': 'task',
      'title': finalTitle,
      'associations': associations,
      if (targetCompanyId != null && targetCompanyId.isNotEmpty) ...{
        'companyId': targetCompanyId,
        'company_id': targetCompanyId,
      },
      if (targetContactId != null && targetContactId.isNotEmpty) ...{
        'contactId': targetContactId,
        'contact_id': targetContactId,
      },
      if (targetDealId != null && targetDealId.isNotEmpty) ...{
        'dealId': targetDealId,
        'deal_id': targetDealId,
      },
      'description': descriptionJson,
      if (ownerId != null && ownerId.isNotEmpty) 'ownerId': ownerId,
      'priority': _selectedPriority.toLowerCase(),
      'queue': _selectedQueue != 'None' ? _selectedQueue : null,
      'reminderType': _reminderText != 'No reminder' ? _reminderText.toLowerCase() : 'none',
      'scheduledAt': scheduledAtIso,
    };

    final isEditing = widget.taskToEdit != null &&
        widget.taskToEdit!.id != null &&
        widget.taskToEdit!.id!.isNotEmpty;

    try {
      Response res;
      if (isEditing) {
        res = await ApiService().put(
          '${ApiConstants.activities}/${widget.taskToEdit!.id}',
          data: taskPayload,
        );
      } else {
        res = await ApiService().post(
          ApiConstants.activities,
          data: taskPayload,
        );
      }

      debugPrint('[POST /api/activities SUCCESS]: ${res.statusCode} -> ${res.data}');

      try {
        await ApiService().post('/tasks', data: taskPayload);
      } catch (e) {
        debugPrint('[POST /api/tasks ERROR]: $e');
      }

      if (mounted) {
        final Map<String, dynamic> dataMap = res.data is Map<String, dynamic>
            ? Map<String, dynamic>.from(res.data as Map)
            : (res.data?['data'] is Map ? Map<String, dynamic>.from(res.data['data'] as Map) : {});

        final createdId = dataMap['id']?.toString() ?? widget.taskToEdit?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

        final createdTask = TaskModel(
          id: createdId,
          title: finalTitle,
          dueDate: scheduledAtIso,
          priority: _selectedPriority,
          status: dataMap['status']?.toString() ?? 'pending',
          assignedTo: _selectedAssignee != 'Select ...' ? _selectedAssignee : 'Admin User',
          notes: notesText,
          taskType: _selectedTaskType,
          queue: _selectedQueue,
          activityDateText: _activityDateText,
          reminderText: _reminderText,
          rawMap: dataMap,
        );

        Navigator.of(context).pop(createdTask);
      }
    } catch (e) {
      debugPrint('[CREATE TASK API ERROR]: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create task: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
