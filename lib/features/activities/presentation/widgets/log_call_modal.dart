import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/models/master_dropdown_model.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/repositories/master_data_repository.dart';
import '../../../../core/widgets/record_association_sheet.dart';

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
  String _selectedDate = 'Aug 5, 2026';
  bool _createFollowUpTask = false;
  bool _isSubmitting = false;
  List<MasterDropdownOptionModel> _apiOutcomes = [];

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

  final List<String> _durations = const [
    '5 minutes',
    '15 minutes',
    '30 minutes',
    '45 minutes',
    '1 hour',
    '2 hours',
  ];

  final List<String> _directions = const [
    'Outbound',
    'Inbound',
  ];

  final List<String> _owners = const [
    'Admin User',
    'Select owner',
  ];

  @override
  void initState() {
    super.initState();
    _associations = {
      'Companies': widget.companyId != null ? [{'id': widget.companyId!, 'name': widget.associatedRecordName}] : [],
      'Contacts': widget.contactId != null ? [{'id': widget.contactId!, 'name': widget.associatedRecordName}] : widget.companyId == null && widget.dealId == null ? [{'id': '1', 'name': widget.associatedRecordName}] : [],
      'Deals': widget.dealId != null ? [{'id': widget.dealId!, 'name': widget.associatedRecordName}] : [],
    };
    final editCall = widget.callToEdit;
    _titleController = TextEditingController(text: editCall?.title ?? '');
    _notesController = TextEditingController(text: editCall?.notes ?? '');

    if (editCall != null) {
      if (editCall.outcome.isNotEmpty) {
        _selectedOutcome = editCall.outcome;
      }
      if (editCall.duration.isNotEmpty) {
        _selectedDuration = editCall.duration;
      }
      if (editCall.direction != null && editCall.direction!.isNotEmpty) {
        _selectedDirection = editCall.direction!;
      }
      if (editCall.assignedTo != null && editCall.assignedTo!.isNotEmpty) {
        _selectedOwner = editCall.assignedTo!;
      }
      if (editCall.startTime.isNotEmpty) {
        _startTimeController = TextEditingController(text: editCall.startTime);
        _selectedDate = _formatDateHeader(editCall.startTime);
      } else {
        final now = DateTime.now();
        final d = now.day.toString().padLeft(2, '0');
        final m = now.month.toString().padLeft(2, '0');
        final y = now.year.toString();
        _startTimeController = TextEditingController(text: '$d/$m/$y 6:13 PM GMT+5:30');
      }
    } else {
      final now = DateTime.now();
      final d = now.day.toString().padLeft(2, '0');
      final m = now.month.toString().padLeft(2, '0');
      final y = now.year.toString();
      _startTimeController = TextEditingController(text: '$d/$m/$y 6:13 PM GMT+5:30');
    }

    _fetchCallOutcomes();
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

    final outcomes = _apiOutcomes.isNotEmpty
        ? _apiOutcomes.map((o) => o.label).toList()
        : _outcomes;

    if (!outcomes.contains(_selectedOutcome) && outcomes.isNotEmpty) {
      outcomes.add(_selectedOutcome);
    }

    return Container(
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
          ),

          // 2. Form Body
          Expanded(
            child: ListView(
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
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                                setState(() {
                                  _selectedDate = '${months[picked.month - 1]} ${picked.day}, ${picked.year}';
                                });
                              }
                            },
                            child: Row(
                              children: [
                                Text(
                                  _selectedDate,
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
                                .map((d) => PopupMenuItem(
                                      value: d,
                                      child: Text(d, style: GoogleFonts.poppins(fontSize: 13)),
                                    ))
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
                                .map((o) => PopupMenuItem(
                                      value: o,
                                      child: Text(o, style: GoogleFonts.poppins(fontSize: 13)),
                                    ))
                                .toList(),
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
                              setState(() {
                                _selectedDuration = val;
                              });
                            },
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.access_time_rounded,
                                  size: 15,
                                  color: Color(0xFF64748B),
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
                                  color: Color(0xFF94A3B8),
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
                      itemBuilder: (context) => _owners
                          .map((o) => PopupMenuItem(
                                value: o,
                                child: Text(o, style: GoogleFonts.poppins(fontSize: 13)),
                              ))
                          .toList(),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Checkbox(
                        value: _createFollowUpTask,
                        onChanged: (val) {
                          setState(() {
                            _createFollowUpTask = val ?? false;
                          });
                        },
                        activeColor: const Color(0xFF00A884),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Create a ',
                              style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF475569)),
                            ),
                            Text(
                              'To-do ⌄ ',
                              style: GoogleFonts.poppins(
                                  fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF00A884)),
                            ),
                            Text(
                              'task to follow up ',
                              style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF475569)),
                            ),
                            Text(
                              'In 3 business days (Monday) ⌄ ',
                              style: GoogleFonts.poppins(
                                  fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF00A884)),
                            ),
                            Text(
                              'at ',
                              style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF475569)),
                            ),
                            Text(
                              '8:00 AM ⌄',
                              style: GoogleFonts.poppins(
                                  fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF00A884)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),

          // 3. Footer Bar: "Associated with 0 records v" + Save Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
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
    setState(() {
      _isSubmitting = true;
    });

    String outcomeValue = _selectedOutcome;
    if (_apiOutcomes.isNotEmpty) {
      final matchedOption = _apiOutcomes.firstWhere(
        (o) => o.label == _selectedOutcome,
        orElse: () => _apiOutcomes.first,
      );
      outcomeValue = matchedOption.value;
    } else {
      outcomeValue = _selectedOutcome.toLowerCase();
    }

    final callData = {
      'title': _titleController.text.trim(),
      'type': widget.activityType.toLowerCase(),
      'outcome': outcomeValue,
      'duration': _selectedDuration,
      'startTime': _startTimeController.text.trim(),
      'notes': _notesController.text.trim(),
      'direction': _selectedDirection,
      'createFollowUpTask': _createFollowUpTask,
      if (widget.contactId != null) 'contactId': widget.contactId,
      if (widget.companyId != null) 'companyId': widget.companyId,
      if (widget.dealId != null) 'dealId': widget.dealId,
    };

    final isEditing = widget.callToEdit != null &&
        widget.callToEdit!.id != null &&
        widget.callToEdit!.id!.isNotEmpty;

    try {
      if (isEditing) {
        await ApiService().put(
          '${ApiConstants.activities}/${widget.callToEdit!.id}',
          data: callData,
        );
      } else {
        await ApiService().post(ApiConstants.activities, data: callData);
      }
    } catch (e) {
      debugPrint('[LOG/EDIT CALL ERROR]: $e');
    }

    final updatedCall = CallModel(
      id: widget.callToEdit?.id,
      title: _titleController.text.trim(),
      outcome: _selectedOutcome,
      duration: _selectedDuration,
      startTime: _startTimeController.text.trim(),
      notes: _notesController.text.trim(),
      assignedTo: _selectedOwner != 'Select owner' ? _selectedOwner : (widget.callToEdit?.assignedTo ?? 'Admin User'),
      direction: _selectedDirection,
      priority: widget.callToEdit?.priority ?? 'Medium',
      status: widget.callToEdit?.status ?? 'PENDING',
      type: widget.callToEdit?.type ?? 'call',
    );

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });
      Navigator.of(context).pop(updatedCall);
    }
  }
}
