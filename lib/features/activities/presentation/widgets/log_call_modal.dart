import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../../../../core/models/master_dropdown_model.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/repositories/master_data_repository.dart';
import '../../../../core/storage/activity_association_storage.dart';
import '../../../../core/widgets/record_association_sheet.dart';
import '../../../../core/utils/activity_utils.dart';
import 'follow_up_task_section.dart';

class CallModel {
  final String? id;
  final String title;
  final String outcome;
  final String duration;
  final String startTime;
  final String notes;
  final String? assignedTo;
  final String? priority;
  final String? status;
  final String? type;
  final String? direction;
  final String? contactId;
  final String? companyId;
  final String? dealId;
  final Map<String, dynamic>? rawMap;

  CallModel({
    this.id,
    required this.title,
    required this.outcome,
    required this.duration,
    required this.startTime,
    required this.notes,
    this.assignedTo = 'Admin User',
    this.priority = 'Medium',
    this.status = 'PENDING',
    this.type = 'call',
    this.direction = 'Outbound',
    this.contactId,
    this.companyId,
    this.dealId,
    this.rawMap,
  });
}

class LogCallModal extends StatefulWidget {
  final CallModel? callToEdit;
  final String? contactId;
  final String? companyId;
  final String? dealId;
  final String associatedRecordName;
  final String activityType;

  const LogCallModal({
    super.key,
    this.callToEdit,
    this.contactId,
    this.companyId,
    this.dealId,
    this.associatedRecordName = 'xyzzzz',
    this.activityType = 'Call',
  });

  static Future<CallModel?> show(
    BuildContext context, {
    CallModel? callToEdit,
    String? contactId,
    String? companyId,
    String? dealId,
    String associatedRecordName = 'xyzzzz',
    String activityType = 'Call',
  }) {
    return showModalBottomSheet<CallModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LogCallModal(
        callToEdit: callToEdit,
        contactId: contactId,
        companyId: companyId,
        dealId: dealId,
        associatedRecordName: associatedRecordName,
        activityType: activityType,
      ),
    );
  }

  @override
  State<LogCallModal> createState() => _LogCallModalState();
}

class _LogCallModalState extends State<LogCallModal> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late final TextEditingController _startTimeController;

  String _selectedOutcome = 'Connected';
  String _selectedDuration = '5 minutes';
  String _selectedDirection = 'Outbound';
  String _selectedOwner = 'Select owner';
  String _selectedDate = 'Today';
  bool _createFollowUpTask = false;
  bool _isSubmitting = false;
  List<MasterDropdownOptionModel> _apiOutcomes = [];
  List<Map<String, dynamic>> _apiUsers = [];
  final List<String> _customOutcomes = [];
  final List<String> _durationsList = [
    '1 minute',
    '2 minutes',
    '5 minutes',
    '10 minutes',
    '15 minutes',
    '30 minutes',
    '1 hour',
  ];

  // Rich Text Formatting State
  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderline = false;
  String _activeHeading = 'T'; // 'T', 'H1', 'H2'
  bool _isBullet = false;
  bool _isNumbered = false;

  // Associations state
  late Map<String, List<Map<String, String>>> _associations;

  int get _totalAssociations {
    return _associations['Companies']!.length +
        _associations['Contacts']!.length +
        _associations['Deals']!.length;
  }

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
    double fontSize = 13.5;
    FontWeight fontWeight = _isBold ? FontWeight.bold : FontWeight.normal;
    FontStyle fontStyle = _isItalic ? FontStyle.italic : FontStyle.normal;
    TextDecoration decoration = _isUnderline ? TextDecoration.underline : TextDecoration.none;

    if (_activeHeading == 'H1') {
      fontSize = 19.0;
      fontWeight = FontWeight.bold;
    } else if (_activeHeading == 'H2') {
      fontSize = 16.0;
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

  final List<String> _outcomes = const [
    'Connected',
    'Busy',
    'Left Message',
    'No Answer',
    'Wrong Number',
    'Scheduled',
    'Completed',
  ];

  final List<String> _directions = const [
    'Outbound',
    'Inbound',
  ];

  @override
  void initState() {
    super.initState();
    _associations = {
      'Companies': widget.companyId != null ? [{'id': widget.companyId!, 'name': widget.associatedRecordName}] : [],
      'Contacts': widget.contactId != null ? [{'id': widget.contactId!, 'name': widget.associatedRecordName}] : [],
      'Deals': widget.dealId != null ? [{'id': widget.dealId!, 'name': widget.associatedRecordName}] : [],
    };
    final editCall = widget.callToEdit;
    _titleController = TextEditingController(text: parseActivityDescription(editCall?.title ?? ''));
    _notesController = TextEditingController(text: parseActivityDescription(editCall?.notes ?? ''));

    if (editCall != null) {
      if (editCall.outcome.trim().isNotEmpty) {
        _selectedOutcome = _canonicalOutcome(editCall.outcome);
      }
      // The value may arrive as '15', '15m' or '15 Minutes' depending on the
      // screen that opened this form — normalise it onto a picker option.
      final raw = editCall.rawMap;
      final minutes = parseDurationMinutes(editCall.duration) ??
          parseDurationMinutes(raw?['durationMinutes'] ?? raw?['duration_minutes']);
      if (minutes != null) {
        _selectedDuration = formatDurationLabel(minutes);
      }
      if (editCall.direction != null && editCall.direction!.isNotEmpty) {
        _selectedDirection = editCall.direction!;
      }
      if (editCall.assignedTo != null && editCall.assignedTo!.isNotEmpty) {
        _selectedOwner = editCall.assignedTo!;
      }
      final scheduledAt = parseActivityDateTimeOrNull(editCall.startTime) ??
          parseActivityDateTimeOrNull(raw?['scheduledAt'] ?? raw?['scheduled_at']);
      if (scheduledAt != null) {
        _startTimeController = TextEditingController(text: formatActivityDateTimeInput(scheduledAt));
        _selectedDate = _formatDateHeader(scheduledAt.toIso8601String());
      } else {
        _startTimeController = TextEditingController(
          text: formatActivityDateTimeInput(DateTime.now()),
        );
      }
    } else {
      final now = DateTime.now();
      final d = now.day.toString().padLeft(2, '0');
      final m = now.month.toString().padLeft(2, '0');
      final y = now.year.toString();
      _startTimeController = TextEditingController(text: '$d/$m/$y 6:13 PM GMT+5:30');
    }

    _fetchCallOutcomes();
    _fetchUsers();
  }

  /// Matches a stored outcome (often lowercase, e.g. `connected`) back onto the
  /// option label so the picker shows the value the call was saved with.
  String _canonicalOutcome(String raw) {
    final value = raw.trim();
    for (final option in _outcomes) {
      if (option.toLowerCase() == value.toLowerCase()) return option;
    }
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  String _formatDateHeader(String raw) {
    if (raw.isEmpty) return 'Aug 5, 2026';
    try {
      final dt = DateTime.tryParse(raw);
      if (dt != null) {
        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
      }
    } catch (_) {}
    return 'Aug 5, 2026';
  }

  Future<void> _fetchUsers() async {
    try {
      final resp = await ApiService().get('/users');
      final raw = resp.data;
      List<Map<String, dynamic>> usersList = [];
      if (raw is List) {
        usersList = raw.whereType<Map<String, dynamic>>().toList();
      } else if (raw is Map<String, dynamic> && raw['data'] is List) {
        usersList = (raw['data'] as List).whereType<Map<String, dynamic>>().toList();
      } else if (raw is Map<String, dynamic> && raw['users'] is List) {
        usersList = (raw['users'] as List).whereType<Map<String, dynamic>>().toList();
      }
      if (mounted && usersList.isNotEmpty) {
        setState(() {
          _apiUsers = usersList;
        });
      }
    } catch (e) {
      debugPrint('[LogCallModal fetch /users error]: $e');
    }
  }

  Future<void> _showCustomOutcomeDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Custom Outcome', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter call outcome...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.poppins(color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                Navigator.pop(ctx, val);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A884),
              foregroundColor: Colors.white,
            ),
            child: Text('Add', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        if (!_customOutcomes.contains(result)) {
          _customOutcomes.add(result);
        }
        _selectedOutcome = result;
      });
    }
  }

  Future<void> _showCustomDurationDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Custom Duration', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Enter duration in minutes (e.g. 45 minutes)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.poppins(color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                final formatted = val.contains('minute') || val.contains('hour') ? val : '$val minutes';
                Navigator.pop(ctx, formatted);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A884),
              foregroundColor: Colors.white,
            ),
            child: Text('Set', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        if (!_durationsList.contains(result)) {
          _durationsList.add(result);
        }
        _selectedDuration = result;
      });
    }
  }

  static List<String> _generateActivityDateOptions() {
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

  Future<void> _fetchCallOutcomes() async {
    try {
      final repo = MasterDataRepositoryImpl();
      final list = await repo.getMasterDropdownByKey('call_outcome', includeInactive: false);
      if (list.isNotEmpty) {
        setState(() {
          _apiOutcomes = list;
          if (widget.callToEdit == null) {
            _selectedOutcome = list.first.label;
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _startTimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool canSubmit = _titleController.text.trim().isNotEmpty && !_isSubmitting;

    // Growable copy: the outcome stored on an existing call is often absent
    // from the fallback list, and appending to a const list throws.
    final outcomes = <String>[
      if (_apiOutcomes.isNotEmpty) ..._apiOutcomes.map((o) => o.label) else ..._outcomes,
    ];

    if (_selectedOutcome.isNotEmpty && !outcomes.contains(_selectedOutcome)) {
      outcomes.add(_selectedOutcome);
    }

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Column(
        children: [
          // 1. Header (Dark Navy Bar with Chevron, Title, and Close Icon matching Image 3)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF475569),
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
                    const SizedBox(width: 8),
                    Text(
                      'Log Call',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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
                          _createFollowUpTask = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Call form data refreshed'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                        size: 20,
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
                        size: 20,
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
                // "What was this call about?" Title Input Field matching Image 3
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF00A884), width: 1.5),
                  ),
                  child: TextField(
                    controller: _titleController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'What was this call about?',
                      hintStyle: GoogleFonts.poppins(
                        color: const Color(0xFF94A3B8),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                      ),
                      border: InputBorder.none,
                    ),
                    style: GoogleFonts.poppins(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Grid Row 1: ACTIVITY DATE & CALL DIRECTION
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ACTIVITY DATE
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ACTIVITY DATE',
                            style: GoogleFonts.poppins(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
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
                                    _selectedDate = '${months[picked.month - 1]} ${picked.day}, ${picked.year}';
                                  });
                                }
                              } else {
                                setState(() {
                                  _selectedDate = val;
                                });
                              }
                            },
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _selectedDate,
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
                              final options = _generateActivityDateOptions();
                              return options.map((d) => _buildPopupMenuItem(d, _selectedDate)).toList();
                            },
                          ),
                        ],
                      ),
                    ),

                    // CALL DIRECTION
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CALL DIRECTION',
                            style: GoogleFonts.poppins(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          PopupMenuButton<String>(
                            onSelected: (val) {
                              setState(() {
                                _selectedDirection = val;
                              });
                            },
                            child: Row(
                              children: [
                                Text(
                                  _selectedDirection,
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
                            itemBuilder: (context) => _directions
                                .map((d) => _buildPopupMenuItem(d, _selectedDirection))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Grid Row 2: CALL OUTCOME & CALL DURATION
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // CALL OUTCOME
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CALL OUTCOME',
                            style: GoogleFonts.poppins(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          PopupMenuButton<String>(
                            onSelected: (val) {
                              if (val == 'Custom Outcome...') {
                                _showCustomOutcomeDialog();
                              } else {
                                setState(() {
                                  _selectedOutcome = val;
                                });
                              }
                            },
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _selectedOutcome,
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
                              final outcomesList = [
                                ...outcomes,
                                ..._customOutcomes,
                                if (!outcomes.contains(_selectedOutcome) && !_customOutcomes.contains(_selectedOutcome))
                                  _selectedOutcome,
                              ].toSet().toList();

                              return [
                                ...outcomesList.map((o) => _buildPopupMenuItem(o, _selectedOutcome)),
                                _buildPopupMenuItem('Custom Outcome...', _selectedOutcome),
                              ];
                            },
                          ),
                        ],
                      ),
                    ),

                    // CALL DURATION
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CALL DURATION',
                            style: GoogleFonts.poppins(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          PopupMenuButton<String>(
                            onSelected: (val) {
                              if (val == 'Custom Duration...') {
                                _showCustomDurationDialog();
                              } else {
                                setState(() {
                                  _selectedDuration = val;
                                });
                              }
                            },
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.access_time_rounded,
                                  size: 15,
                                  color: Color(0xFF334155),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _selectedDuration,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF334155),
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
                              final durationsList = [
                                ..._durationsList,
                                if (!_durationsList.contains(_selectedDuration)) _selectedDuration,
                              ].toSet().toList();

                              return [
                                ...durationsList.map((d) => _buildPopupMenuItem(d, _selectedDuration)),
                                _buildPopupMenuItem('Custom Duration...', _selectedDuration),
                              ];
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ACTIVITY ASSIGNED TO
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACTIVITY ASSIGNED TO',
                      style: GoogleFonts.poppins(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    PopupMenuButton<String>(
                      onSelected: (val) {
                        setState(() {
                          _selectedOwner = val;
                        });
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedOwner,
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
                      itemBuilder: (context) {
                        // Growable copy: the owner of an existing call is often
                        // absent from the fallback list, and appending to a
                        // const list throws.
                        final usersDisplayList = <String>[
                          if (_apiUsers.isNotEmpty)
                            ..._apiUsers.map((u) {
                              final first = u['firstName'] as String? ?? u['first_name'] as String? ?? '';
                              final last = u['lastName'] as String? ?? u['last_name'] as String? ?? '';
                              final name = '$first $last'.trim();
                              return name.isNotEmpty ? name : (u['email'] as String? ?? 'User');
                            })
                          else
                            ...['Admin User', 'Select owner'],
                        ];

                        if (_selectedOwner.isNotEmpty && !usersDisplayList.contains(_selectedOwner)) {
                          usersDisplayList.add(_selectedOwner);
                        }

                        return usersDisplayList.map((o) => _buildPopupMenuItem(o, _selectedOwner)).toList();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Rich Text Formatting Toolbar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  color: const Color(0xFFF8FAFC),
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

                // NOTES Area
                Container(
                  constraints: const BoxConstraints(minHeight: 140),
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xFFF8FAFC),
                  child: TextField(
                    controller: _notesController,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    style: _getContentStyle(),
                    decoration: InputDecoration(
                      hintText: 'Call notes...',
                      hintStyle: GoogleFonts.poppins(
                        color: const Color(0xFF94A3B8),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Create To-do Follow-up Row
                FollowUpTaskSection(
                  initialChecked: _createFollowUpTask,
                  onCheckedChanged: (val) {
                    setState(() {
                      _createFollowUpTask = val;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
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
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF00A884),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Color(0xFF00A884),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: canSubmit ? _handleSubmit : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canSubmit ? const Color(0xFF00A884) : const Color(0xFFCBD5E1),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
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
                                'Log call',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
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
    final title = _titleController.text.trim();
    final notes = _notesController.text.trim();

    if (title.isEmpty && notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a call title or notes.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Falling back to the first option here used to silently replace the
      // outcome of the call being edited — keep the selected value instead.
      String outcomeValue = _selectedOutcome.toLowerCase().replaceAll(' ', '_');
      for (final option in _apiOutcomes) {
        if (option.label.toLowerCase() == _selectedOutcome.toLowerCase() && option.value.isNotEmpty) {
          outcomeValue = option.value;
          break;
        }
      }

      final contactId = widget.contactId ?? widget.callToEdit?.contactId;
      final companyId = widget.companyId ?? widget.callToEdit?.companyId;
      final dealId = widget.dealId ?? widget.callToEdit?.dealId;

      String? targetCompanyId = companyId ?? widget.callToEdit?.companyId;
      if ((targetCompanyId == null || targetCompanyId.isEmpty) &&
          _associations['Companies'] != null &&
          _associations['Companies']!.isNotEmpty) {
        targetCompanyId = _associations['Companies']!.first['id'];
      }

      String? targetContactId = contactId ?? widget.callToEdit?.contactId;
      if ((targetContactId == null || targetContactId.isEmpty) &&
          _associations['Contacts'] != null &&
          _associations['Contacts']!.isNotEmpty) {
        targetContactId = _associations['Contacts']!.first['id'];
      }

      String? targetDealId = dealId ?? widget.callToEdit?.dealId;
      if ((targetDealId == null || targetDealId.isEmpty) &&
          _associations['Deals'] != null &&
          _associations['Deals']!.isNotEmpty) {
        targetDealId = _associations['Deals']!.first['id'];
      }

      if (targetContactId == '1') targetContactId = null;
      if (targetCompanyId == '1') targetCompanyId = null;
      if (targetDealId == '1') targetDealId = null;

      final companyIds = _associations['Companies']?.map((e) => e['id']).whereType<String>().where((id) => id != '1').toList() ?? [];
      if (targetCompanyId != null && targetCompanyId.isNotEmpty && !companyIds.contains(targetCompanyId)) {
        companyIds.add(targetCompanyId);
      }

      final contactIds = _associations['Contacts']?.map((e) => e['id']).whereType<String>().where((id) => id != '1').toList() ?? [];
      if (targetContactId != null && targetContactId.isNotEmpty && !contactIds.contains(targetContactId)) {
        contactIds.add(targetContactId);
      }

      final dealIds = _associations['Deals']?.map((e) => e['id']).whereType<String>().where((id) => id != '1').toList() ?? [];
      if (targetDealId != null && targetDealId.isNotEmpty && !dealIds.contains(targetDealId)) {
        dealIds.add(targetDealId);
      }

      final List<Map<String, String>> assocList = [];
      for (final id in companyIds) {
        assocList.add({'objectId': id, 'objectType': 'company'});
      }
      for (final id in contactIds) {
        assocList.add({'objectId': id, 'objectType': 'contact'});
      }
      for (final id in dealIds) {
        assocList.add({'objectId': id, 'objectType': 'deal'});
      }

      // The API stores these as durationMinutes (int) and scheduledAt (ISO);
      // the display strings are kept for the endpoints that echo them back.
      final durationMinutes = parseDurationMinutes(_selectedDuration);
      final scheduledAt = parseActivityDateTimeOrNull(_startTimeController.text.trim());

      final callData = {
        'title': title.isNotEmpty ? title : 'Call Activity',
        'type': 'call',
        'outcome': outcomeValue,
        'duration': _selectedDuration,
        if (durationMinutes != null) 'durationMinutes': durationMinutes,
        if (scheduledAt != null) 'scheduledAt': scheduledAt.toUtc().toIso8601String(),
        'startTime': _startTimeController.text.trim(),
        'start_time': _startTimeController.text.trim(),
        'notes': notes,
        'description': notes,
        'direction': _selectedDirection,
        'createFollowUpTask': _createFollowUpTask,
        'activityDate': (scheduledAt ?? DateTime.now()).toIso8601String(),
        if (assocList.isNotEmpty) 'associations': assocList,
        'associationsList': assocList,
        'associations_list': assocList,
        'companyIds': companyIds,
        'company_ids': companyIds,
        'contactIds': contactIds,
        'contact_ids': contactIds,
        'dealIds': dealIds,
        'deal_ids': dealIds,
        if (_selectedOwner != 'Select owner') 'ownerName': _selectedOwner,
        if (targetContactId != null && targetContactId.isNotEmpty) ...{
          'contactId': targetContactId,
          'contact_id': targetContactId,
        },
        if (targetCompanyId != null && targetCompanyId.isNotEmpty) ...{
          'companyId': targetCompanyId,
          'company_id': targetCompanyId,
        },
        if (targetDealId != null && targetDealId.isNotEmpty) ...{
          'dealId': targetDealId,
          'deal_id': targetDealId,
        },
      };

      final isEditing = widget.callToEdit != null &&
          widget.callToEdit!.id != null &&
          widget.callToEdit!.id!.isNotEmpty;

      bool callSuccess = false;
      Response? res;
      try {
        if (isEditing) {
          // PATCH /api/activities/:id is the documented update route.
          final callId = widget.callToEdit!.id!;
          res = await ApiService().patch(
            '${ApiConstants.activities}/$callId',
            data: callData,
          );
        } else {
          res = await ApiService().post(ApiConstants.activities, data: callData);
        }
        callSuccess = true;
      } catch (e) {
        debugPrint('[LOG/EDIT CALL ERROR]: $e');
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save call: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      Map<String, dynamic> dataMap = {};
      if (res.data is Map) {
        final rawMap = Map<String, dynamic>.from(res.data as Map);
        if (rawMap['data'] is Map) {
          dataMap = Map<String, dynamic>.from(rawMap['data'] as Map);
        } else if (rawMap['activity'] is Map) {
          dataMap = Map<String, dynamic>.from(rawMap['activity'] as Map);
        } else {
          dataMap = rawMap;
        }
      }

      final createdId = (dataMap['id'] ?? dataMap['_id'] ?? widget.callToEdit?.id)?.toString();
      if (createdId != null && createdId.isNotEmpty) {
        await ActivityAssociationStorage.saveAssociations(createdId, _associations);
      }

      if (callSuccess && _createFollowUpTask) {
        try {
          final String taskDescJson = jsonEncode({
            'type': 'doc',
            'content': [
              {
                'type': 'paragraph',
                if (notes.isNotEmpty)
                  'content': [{'type': 'text', 'text': notes}]
              }
            ]
          });

          final taskPayload = {
            'type': 'task',
            'title': 'Follow-up: ${title.isNotEmpty ? title : "Call"}',
            'subject': 'Follow-up: ${title.isNotEmpty ? title : "Call"}',
            'priority': 'medium',
            'notes': notes,
            'description': taskDescJson,
            'scheduledAt': DateTime.now().toIso8601String(),
            if (targetContactId != null && targetContactId.isNotEmpty) ...{
              'contactId': targetContactId,
              'contact_id': targetContactId,
            },
            if (targetCompanyId != null && targetCompanyId.isNotEmpty) ...{
              'companyId': targetCompanyId,
              'company_id': targetCompanyId,
            },
            if (targetDealId != null && targetDealId.isNotEmpty) ...{
              'dealId': targetDealId,
              'deal_id': targetDealId,
            },
          };
          await ApiService().post(ApiConstants.activities, data: taskPayload);
        } catch (e) {
          debugPrint('[Create Follow-up Task Warning]: $e');
        }
      }

      final updatedCall = CallModel(
        id: createdId,
        title: title,
        outcome: _selectedOutcome,
        duration: _selectedDuration,
        startTime: _startTimeController.text.trim(),
        notes: notes,
        assignedTo: _selectedOwner != 'Select owner' ? _selectedOwner : (widget.callToEdit?.assignedTo ?? 'Admin User'),
        direction: _selectedDirection,
        priority: widget.callToEdit?.priority ?? 'Medium',
        status: widget.callToEdit?.status ?? 'PENDING',
        type: widget.callToEdit?.type ?? 'call',
        contactId: targetContactId,
        companyId: targetCompanyId,
        dealId: targetDealId,
        rawMap: dataMap.isNotEmpty ? dataMap : callData,
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Call logged successfully!'),
            backgroundColor: Color(0xFF00A884),
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop(updatedCall);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
