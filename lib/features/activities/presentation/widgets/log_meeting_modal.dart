import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/master_data_provider.dart';
import '../../../../core/models/master_dropdown_model.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/widgets/record_association_sheet.dart';

class MeetingModel {
  final String title;
  final String outcome;
  final String duration;
  final String startTime;
  final String notes;
  final String? assignedTo;

  MeetingModel({
    required this.title,
    required this.outcome,
    required this.duration,
    required this.startTime,
    required this.notes,
    this.assignedTo = 'Admin User',
  });
}

class LogMeetingModal extends StatefulWidget {
  final String? contactId;
  final String? companyId;
  final String? dealId;
  final String associatedRecordName;

  const LogMeetingModal({
    super.key,
    this.contactId,
    this.companyId,
    this.dealId,
    this.associatedRecordName = 'xyzzzz',
  });

  static Future<MeetingModel?> show(
    BuildContext context, {
    String? contactId,
    String? companyId,
    String? dealId,
    String associatedRecordName = 'xyzzzz',
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
    '45 Minutes',
    '1 Hour',
    '2 Hours',
  ];

  @override
  void initState() {
    super.initState();
    _associations = {
      'Companies': widget.companyId != null ? [{'id': widget.companyId!, 'name': widget.associatedRecordName}] : [],
      'Contacts': widget.contactId != null ? [{'id': widget.contactId!, 'name': widget.associatedRecordName}] : widget.companyId == null && widget.dealId == null ? [{'id': '1', 'name': widget.associatedRecordName}] : [],
      'Deals': widget.dealId != null ? [{'id': widget.dealId!, 'name': widget.associatedRecordName}] : [],
    };
    final now = DateTime.now();
    final d = now.day.toString().padLeft(2, '0');
    final m = now.month.toString().padLeft(2, '0');
    final y = now.year.toString();
    _startTimeController = TextEditingController(
      text: '$d/$m/$y 6:13 PM GMT+5:30',
    );
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
    final bool canSubmit = _titleController.text.trim().isNotEmpty;
    final provider = context.watch<MasterDataProvider>();
    final outcomes = provider.meetingOutcomeOptions.isNotEmpty
        ? provider.meetingOutcomeOptions.map((o) => o.label).toList()
        : _outcomes;

    if (!outcomes.contains(_selectedOutcome) && outcomes.isNotEmpty) {
      _selectedOutcome = outcomes.first;
    }

    return Container(
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
                      'Log Meeting',
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
                    const Icon(Icons.open_in_full_rounded, color: Colors.white, size: 18),
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

                // ATTENDEES & MEETING OUTCOME Row
                Row(
                  children: [
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
                          Text(
                            '1 contact',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF00A884),
                            ),
                          ),
                        ],
                      ),
                    ),
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
                                Text(
                                  _selectedOutcome,
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
                            itemBuilder: (context) => outcomes
                                .map((o) => PopupMenuItem(
                                      value: o,
                                      child: Text(o, style: GoogleFonts.poppins(fontSize: 13)),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // DURATION Row
                Column(
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedDuration,
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
                      itemBuilder: (context) => _durations
                          .map((d) => PopupMenuItem(
                                value: d,
                                child: Text(d, style: GoogleFonts.poppins(fontSize: 13)),
                              ))
                          .toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // MEETING START TIME Box
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
                Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _startTimeController,
                          style: GoogleFonts.poppins(fontSize: 13),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                        color: Color(0xFF64748B),
                      ),
                    ],
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
                Row(
                  children: [
                    Checkbox(
                      value: _createFollowUpTask,
                      onChanged: (val) {
                        setState(() {
                          _createFollowUpTask = val ?? false;
                        });
                      },
                      activeColor: const Color(0xFF00A884),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Create a ',
                            style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF334155)),
                          ),
                          Text(
                            'To-do ∨ ',
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF00A884),
                            ),
                          ),
                          Text(
                            'task to follow up ',
                            style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF334155)),
                          ),
                          Text(
                            'In 3 business days (Friday) ∨',
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF00A884),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),

          // 3. Bottom Action Footer Button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: ElevatedButton(
              onPressed: canSubmit
                  ? () async {
                      final matchedOption = provider.meetingOutcomeOptions.firstWhere(
                        (o) => o.label == _selectedOutcome,
                        orElse: () => MasterDropdownOptionModel(
                          id: '',
                          value: _selectedOutcome.toLowerCase().replaceAll(' ', '_'),
                          label: _selectedOutcome,
                        ),
                      );
                      final outcomeValue = matchedOption.value;

                      final meetingData = {
                        'title': _titleController.text.trim(),
                        'type': 'meeting',
                        'outcome': outcomeValue,
                        'duration': _selectedDuration,
                        'startTime': _startTimeController.text.trim(),
                        'notes': _notesController.text.trim(),
                        'createFollowUpTask': _createFollowUpTask,
                        if (widget.contactId != null) 'contactId': widget.contactId,
                        if (widget.companyId != null) 'companyId': widget.companyId,
                        if (widget.dealId != null) 'dealId': widget.dealId,
                      };

                      try {
                        await ApiService().post(ApiConstants.activities, data: meetingData);
                      } catch (e) {
                        debugPrint('[POST ${ApiConstants.activities} ERROR]: $e');
                      }

                      final meeting = MeetingModel(
                        title: _titleController.text.trim(),
                        outcome: _selectedOutcome,
                        duration: _selectedDuration,
                        startTime: _startTimeController.text.trim(),
                        notes: _notesController.text.trim(),
                      );
                      if (context.mounted) {
                        Navigator.of(context).pop(meeting);
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
                'Log meeting',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ),
          ),
        ],
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
