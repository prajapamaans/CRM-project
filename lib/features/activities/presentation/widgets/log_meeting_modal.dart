import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../../../core/providers/master_data_provider.dart';
import '../../../../core/models/master_dropdown_model.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/storage/activity_association_storage.dart';
import '../../../../core/widgets/record_association_sheet.dart';
import '../../../../core/utils/activity_utils.dart';
import 'follow_up_task_section.dart';

class MeetingModel {
  final String? id;
  final String title;
  final String outcome;
  final String duration;
  final String startTime;
  final String notes;
  final String? assignedTo;
  final String? contactId;
  final String? companyId;
  final String? dealId;
  final Map<String, dynamic>? rawMap;

  MeetingModel({
    this.id,
    required this.title,
    required this.outcome,
    required this.duration,
    required this.startTime,
    required this.notes,
    this.assignedTo = 'Admin User',
    this.contactId,
    this.companyId,
    this.dealId,
    this.rawMap,
  });
}

class LogMeetingModal extends StatefulWidget {
  final String? contactId;
  final String? companyId;
  final String? dealId;
  final String associatedRecordName;
  final MeetingModel? existingMeeting;

  const LogMeetingModal({
    super.key,
    this.contactId,
    this.companyId,
    this.dealId,
    this.associatedRecordName = 'xyzzzz',
    this.existingMeeting,
  });

  static Future<MeetingModel?> show(
    BuildContext context, {
    String? contactId,
    String? companyId,
    String? dealId,
    String associatedRecordName = 'xyzzzz',
    MeetingModel? existingMeeting,
  }) {
    return showModalBottomSheet<MeetingModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LogMeetingModal(
        contactId: contactId,
        companyId: companyId,
        dealId: dealId,
        associatedRecordName: associatedRecordName,
        existingMeeting: existingMeeting,
      ),
    );
  }

  @override
  State<LogMeetingModal> createState() => _LogMeetingModalState();
}

class _LogMeetingModalState extends State<LogMeetingModal> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  late final TextEditingController _startTimeController;

  String _selectedOutcome = 'Scheduled';
  String _selectedDuration = '15 Minutes';
  bool _createFollowUpTask = false;
  bool _isSubmitting = false;

  // Associations state
  late Map<String, List<Map<String, String>>> _associations;

  int get _totalAssociations {
    return _associations['Companies']!.length +
        _associations['Contacts']!.length +
        _associations['Deals']!.length;
  }

  int get _contactCount {
    return _associations['Contacts']?.length ?? 0;
  }

  // Active formatting state toggles
  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderline = false;
  String _activeHeading = 'T';

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

  final List<String> _outcomes = const [
    'Scheduled',
    'Completed',
    'Rescheduled',
  ];

  final List<String> _durations = const [
    '15 Minutes',
    '30 Minutes',
    '45 Minutes',
    '1 Hour',
    '2 Hours',
  ];

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
    final em = widget.existingMeeting;
    if (em != null) {
      _titleController.text = parseActivityDescription(em.title);
      _notesController.text = parseActivityDescription(em.notes);
      if (em.outcome.trim().isNotEmpty) {
        _selectedOutcome = _canonicalOutcome(em.outcome);
      }
      // The value may arrive as '30', '30m' or '30 Minutes' depending on the
      // screen that opened this form — normalise it onto a picker option.
      final raw = em.rawMap;
      final minutes = parseDurationMinutes(em.duration) ??
          parseDurationMinutes(raw?['durationMinutes'] ?? raw?['duration_minutes']);
      if (minutes != null) {
        _selectedDuration = formatDurationLabel(minutes);
      }
    }

    final cId = widget.contactId ?? em?.contactId;
    final compId = widget.companyId ?? em?.companyId;
    final dId = widget.dealId ?? em?.dealId;

    _associations = {
      'Companies': compId != null && compId.isNotEmpty ? [{'id': compId, 'name': widget.associatedRecordName}] : [],
      'Contacts': cId != null && cId.isNotEmpty ? [{'id': cId, 'name': widget.associatedRecordName}] : [],
      'Deals': dId != null && dId.isNotEmpty ? [{'id': dId, 'name': widget.associatedRecordName}] : [],
    };
    final scheduledAt = em == null
        ? null
        : parseActivityDateTimeOrNull(em.startTime) ??
            parseActivityDateTimeOrNull(em.rawMap?['scheduledAt'] ?? em.rawMap?['scheduled_at']);
    _startTimeController = TextEditingController(
      text: formatActivityDateTimeInput(scheduledAt ?? DateTime.now()),
    );
  }

  /// Matches a stored outcome (often lowercase, e.g. `completed`) back onto the
  /// option label so the picker shows the value the meeting was saved with.
  String _canonicalOutcome(String raw) {
    final value = raw.trim();
    for (final option in _outcomes) {
      if (option.toLowerCase() == value.toLowerCase()) return option;
    }
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _startTimeController.dispose();
    super.dispose();
  }

  Future<void> _pickMeetingStartDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (mounted) {
        final month = pickedDate.month.toString().padLeft(2, '0');
        final day = pickedDate.day.toString().padLeft(2, '0');
        final year = pickedDate.year.toString();

        if (pickedTime != null) {
          final hour = pickedTime.hourOfPeriod == 0 ? 12 : pickedTime.hourOfPeriod;
          final period = pickedTime.period == DayPeriod.am ? 'AM' : 'PM';
          final minute = pickedTime.minute.toString().padLeft(2, '0');
          _startTimeController.text = '$month/$day/$year $hour:$minute $period';
        } else {
          _startTimeController.text = '$month/$day/$year';
        }
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canSubmit = _titleController.text.trim().isNotEmpty;
    final provider = context.watch<MasterDataProvider>();
    // Growable copy, and the meeting's own outcome is appended rather than
    // replaced — overwriting it here silently discarded the saved value.
    final outcomes = <String>[
      if (provider.meetingOutcomeOptions.isNotEmpty)
        ...provider.meetingOutcomeOptions.map((o) => o.label)
      else
        ..._outcomes,
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
          // 1. Dark Blue/Grey Top Header matching Image 4
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
                      widget.existingMeeting != null ? 'Edit Meeting' : 'Log Meeting',
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
                    const Icon(Icons.drag_indicator_rounded, color: Colors.white70, size: 18),
                    const SizedBox(width: 14),
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
                // "What is this meeting about?" Text Input Box matching Image 4
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
                      hintText: 'What is this meeting about?',
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
                const SizedBox(height: 8),

                // ATTENDEES, MEETING OUTCOME & DURATION 3-Column Row matching reference image
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ATTENDEES
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ATTENDEES',
                            style: GoogleFonts.poppins(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
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
                            child: Text(
                              '$_contactCount contact${_contactCount != 1 ? 's' : ''}',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF00A884),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // MEETING OUTCOME
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MEETING OUTCOME',
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
                                _selectedOutcome = val;
                              });
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
                            itemBuilder: (context) => outcomes
                                .map((o) => _buildPopupMenuItem(o, _selectedOutcome))
                                .toList(),
                          ),
                        ],
                      ),
                    ),

                    // DURATION
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DURATION',
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
                                _selectedDuration = val;
                              });
                            },
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _selectedDuration,
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
                            itemBuilder: (context) => _durations
                                .map((d) => _buildPopupMenuItem(d, _selectedDuration))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // MEETING START TIME Box matching reference image
                Text(
                  'MEETING START TIME',
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickMeetingStartDateTime,
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF94A3B8), width: 1.2),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _startTimeController.text.isNotEmpty
                                ? _startTimeController.text
                                : '${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().year}',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: const Color(0xFF1E293B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.calendar_today_outlined,
                            size: 18,
                            color: Color(0xFF64748B),
                          ),
                          onPressed: _pickMeetingStartDateTime,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Rich Text Editor Formatting Toolbar Row (same spacing as Note form)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
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
                          onTap: () => _applyFormatPrefix('• ', ''),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Icon(Icons.format_list_bulleted_rounded, size: 24, color: Color(0xFF64748B)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => _applyFormatPrefix('1. ', ''),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Icon(Icons.format_list_numbered_rounded, size: 24, color: Color(0xFF64748B)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Icon(Icons.attach_file_rounded, size: 24, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(width: 10),
                        const SizedBox(height: 24, child: VerticalDivider(color: Color(0xFFCBD5E1), width: 1)),
                        const SizedBox(width: 10),
                        InkWell(
                          onTap: () {
                            if (_notesController.text.isNotEmpty) _notesController.clear();
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Icon(Icons.undo_rounded, size: 24, color: Color(0xFF64748B)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Icon(Icons.redo_rounded, size: 24, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ),

                // Large Note Text Input Area
                Container(
                  height: 140,
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
                    border: Border(
                      left: BorderSide(color: Color(0xFFE2E8F0)),
                      right: BorderSide(color: Color(0xFFE2E8F0)),
                      bottom: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: TextField(
                    controller: _notesController,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    style: _getContentStyle(),
                    decoration: InputDecoration(
                      hintText: 'Start typing to log a meeting...',
                      hintStyle: GoogleFonts.poppins(
                        color: const Color(0xFF94A3B8),
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Associated with 0 records v
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
                        'Associated with $_totalAssociations record${_totalAssociations > 1 ? 's' : ''} ',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF00A884),
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF00A884),
                        size: 18,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Checkbox Row: Create a To-do task to follow up
                FollowUpTaskSection(
                  initialChecked: _createFollowUpTask,
                  onCheckedChanged: (val) {
                    setState(() {
                      _createFollowUpTask = val;
                    });
                  },
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                        onPressed: canSubmit
                        ? () async {
                            final title = _titleController.text.trim();
                            final notes = _notesController.text.trim();

                            if (title.isEmpty && notes.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter a meeting title or notes.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            setState(() {
                              _isSubmitting = true;
                            });

                            try {
                              final matchedOption = provider.meetingOutcomeOptions.firstWhere(
                                (o) => o.label == _selectedOutcome,
                                orElse: () => MasterDropdownOptionModel(
                                  id: '',
                                  value: _selectedOutcome.toLowerCase().replaceAll(' ', '_'),
                                  label: _selectedOutcome,
                                ),
                              );
                              final outcomeValue = matchedOption.value;

                              String? targetCompanyId = widget.companyId ?? widget.existingMeeting?.companyId;
                              if ((targetCompanyId == null || targetCompanyId.isEmpty) &&
                                  _associations['Companies'] != null &&
                                  _associations['Companies']!.isNotEmpty) {
                                targetCompanyId = _associations['Companies']!.first['id'];
                              }

                              String? targetContactId = widget.contactId ?? widget.existingMeeting?.contactId;
                              if ((targetContactId == null || targetContactId.isEmpty) &&
                                  _associations['Contacts'] != null &&
                                  _associations['Contacts']!.isNotEmpty) {
                                targetContactId = _associations['Contacts']!.first['id'];
                              }

                              String? targetDealId = widget.dealId ?? widget.existingMeeting?.dealId;
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

                              // The API stores these as durationMinutes (int)
                              // and scheduledAt (ISO); the display strings are
                              // kept for the endpoints that echo them back.
                              final durationMinutes = parseDurationMinutes(_selectedDuration);
                              final scheduledAt =
                                  parseActivityDateTimeOrNull(_startTimeController.text.trim());

                              final meetingData = {
                                'title': title.isNotEmpty ? title : 'Meeting Activity',
                                'type': 'meeting',
                                'outcome': outcomeValue,
                                'duration': _selectedDuration,
                                if (durationMinutes != null) 'durationMinutes': durationMinutes,
                                if (scheduledAt != null)
                                  'scheduledAt': scheduledAt.toUtc().toIso8601String(),
                                'startTime': _startTimeController.text.trim(),
                                'notes': notes,
                                'description': notes,
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

                              final existingId = widget.existingMeeting?.id;
                              bool meetingSuccess = false;
                              Response? res;
                              try {
                                if (existingId != null && existingId.isNotEmpty) {
                                  // PATCH /api/activities/:id is the documented
                                  // update route; PUT is not exposed.
                                  res = await ApiService().patch(
                                    '${ApiConstants.activities}/$existingId',
                                    data: meetingData,
                                  );
                                } else {
                                  res = await ApiService().post(ApiConstants.activities, data: meetingData);
                                }
                                meetingSuccess = true;
                              } catch (e) {
                                debugPrint('[SAVE MEETING ERROR]: $e');
                                if (context.mounted) {
                                  setState(() {
                                    _isSubmitting = false;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to save meeting: $e'),
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

                              final createdId = (dataMap['id'] ?? dataMap['_id'] ?? existingId)?.toString();
                              if (createdId != null && createdId.isNotEmpty) {
                                await ActivityAssociationStorage.saveAssociations(createdId, _associations);
                              }

                               if (meetingSuccess && _createFollowUpTask) {
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
                                     'title': 'Follow-up: ${title.isNotEmpty ? title : "Meeting"}',
                                     'subject': 'Follow-up: ${title.isNotEmpty ? title : "Meeting"}',
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

                              final meeting = MeetingModel(
                                id: createdId,
                                title: title,
                                outcome: _selectedOutcome,
                                duration: _selectedDuration,
                                startTime: _startTimeController.text.trim(),
                                notes: notes,
                                assignedTo: widget.existingMeeting?.assignedTo ?? 'Admin User',
                                contactId: targetContactId,
                                companyId: targetCompanyId,
                                dealId: targetDealId,
                                rawMap: dataMap.isNotEmpty ? dataMap : meetingData,
                              );
                              if (context.mounted) {
                                setState(() {
                                  _isSubmitting = false;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Meeting saved successfully!'),
                                    backgroundColor: Color(0xFF00A884),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                Navigator.of(context).pop(meeting);
                              }
                            } catch (e) {
                              if (context.mounted) {
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
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canSubmit ? const Color(0xFF00A884) : const Color(0xFFF1F5F9),
                      foregroundColor: canSubmit ? Colors.white : const Color(0xFF94A3B8),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      widget.existingMeeting != null ? 'Save' : 'Log meeting',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
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

  Widget _buildFormatIconButton(
    String label, {
    required bool isActive,
    bool isBold = false,
    bool isItalic = false,
    bool isUnderline = false,
    required VoidCallback onTap,
  }) {
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
}
