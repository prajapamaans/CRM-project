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
import '../../../../core/utils/meeting_booking_source.dart';
import 'follow_up_task_section.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../contacts/presentation/providers/contact_provider.dart';

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
  final String? bookingSource;
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
    this.bookingSource,
    this.rawMap,
  });
}

class LogMeetingModal extends StatefulWidget {
  final String? contactId;
  final String? companyId;
  final String? dealId;
  final String associatedRecordName;
  final MeetingModel? existingMeeting;
  final bool isCreateMode;
  final String? titleOverride;

  const LogMeetingModal({
    super.key,
    this.contactId,
    this.companyId,
    this.dealId,
    this.associatedRecordName = 'xyzzzz',
    this.existingMeeting,
    this.isCreateMode = false,
    this.titleOverride,
  });

  static Future<MeetingModel?> show(
    BuildContext context, {
    String? contactId,
    String? companyId,
    String? dealId,
    String associatedRecordName = 'xyzzzz',
    MeetingModel? existingMeeting,
    bool isCreateMode = false,
    String? titleOverride,
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
        isCreateMode: isCreateMode,
        titleOverride: titleOverride,
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

  // Create Meeting specific state
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 15, minute: 0);
  String? _selectedOrganizerId;
  String? _selectedOrganizerName;
  List<Map<String, dynamic>> _users = [];
  bool _useEmailInstead = false;
  final _emailController = TextEditingController();
  String? _selectedContactId;
  String? _selectedContactName;
  bool _createTeamsLink = true;

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

    if (scheduledAt != null) {
      _selectedDate = scheduledAt;
      _selectedTime = TimeOfDay(hour: scheduledAt.hour, minute: scheduledAt.minute);
    }

    // Warmed up here so the booking source of the meeting being edited can be
    // read synchronously when the form is submitted.
    MeetingBookingSourceStore.ensureLoaded();

    _fetchUsers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ContactProvider>().fetchContacts(ignorePermissions: true);
      }
    });
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
          _users = usersList;
        });
      }
    } catch (e) {
      debugPrint('[LogMeetingModal _fetchUsers error]: $e');
    }
  }

  String _formatDateLabel(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    return '$d-$m-$y';
  }

  String _formatTimeLabel(TimeOfDay tod) {
    final h = tod.hour.toString().padLeft(2, '0');
    final m = tod.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickMeetingDateOnly() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickMeetingTimeOnly() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF1E293B),
      ),
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
    _emailController.dispose();
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

  Widget _buildCreateMeetingForm(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final contactProvider = context.watch<ContactProvider>();

    final allUsers = <Map<String, dynamic>>[];
    if (auth.currentUser != null) {
      allUsers.add({
        'id': auth.currentUser!.id,
        'name': auth.currentUser!.fullName,
      });
    }
    for (final member in auth.teamMembers) {
      final name = '${member.firstName ?? ''} ${member.lastName ?? ''}'.trim();
      if (name.isNotEmpty && !allUsers.any((u) => u['id'] == member.id)) {
        allUsers.add({'id': member.id, 'name': name});
      }
    }
    for (final u in _users) {
      final id = (u['id'] ?? u['_id'])?.toString();
      final fn = u['firstName'] ?? u['first_name'] ?? '';
      final ln = u['lastName'] ?? u['last_name'] ?? '';
      final name = '$fn $ln'.trim().isNotEmpty ? '$fn $ln'.trim() : (u['name']?.toString() ?? 'User');
      if (id != null && !allUsers.any((item) => item['id'] == id)) {
        allUsers.add({'id': id, 'name': name});
      }
    }

    final contactsList = contactProvider.contacts;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        children: [
          // Header: Icon + Title + Close Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.event_available_outlined,
                  color: Color(0xFF0F766E),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'Create Meeting',
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Form Body
          Expanded(
            child: Container(
              color: const Color(0xFFF8FAFC),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Informational Callout Box
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "This books the meeting immediately on the selected organizer's calendar — no link is shared, no slot picking. Use this when the time is already agreed with the client.",
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              color: const Color(0xFF64748B),
                              height: 1.45,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Title Field
                        _buildFieldLabel('Title'),
                        const SizedBox(height: 6),
                        Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: TextField(
                            controller: _titleController,
                            onChanged: (_) => setState(() {}),
                            style: GoogleFonts.poppins(fontSize: 13.5, color: const Color(0xFF1E293B)),
                            decoration: InputDecoration(
                              hintText: 'e.g. Kickoff call with Acme Corp',
                              hintStyle: GoogleFonts.poppins(fontSize: 13.5, color: const Color(0xFF94A3B8)),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 11),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Organizer Field
                        Row(
                          children: [
                            _buildFieldLabel('Organizer'),
                            const SizedBox(width: 4),
                            const Icon(Icons.info_outline, size: 14, color: Color(0xFF94A3B8)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        PopupMenuButton<Map<String, dynamic>>(
                          onSelected: (userMap) {
                            setState(() {
                              _selectedOrganizerId = userMap['id'];
                              _selectedOrganizerName = userMap['name'];
                            });
                          },
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _selectedOrganizerName ?? (allUsers.isNotEmpty ? allUsers.first['name'] : 'Select organizer'),
                                  style: GoogleFonts.poppins(
                                    fontSize: 13.5,
                                    color: _selectedOrganizerName != null ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                                  ),
                                ),
                                const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(0xFF64748B)),
                              ],
                            ),
                          ),
                          itemBuilder: (context) => allUsers.map((u) {
                            return PopupMenuItem<Map<String, dynamic>>(
                              value: u,
                              height: 40,
                              child: Text(
                                u['name'] ?? 'User',
                                style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF1E293B)),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // Contact Field & Toggle
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                _buildFieldLabel('Contact'),
                                const SizedBox(width: 4),
                                const Icon(Icons.info_outline, size: 14, color: Color(0xFF94A3B8)),
                              ],
                            ),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _useEmailInstead = !_useEmailInstead;
                                });
                              },
                              child: Row(
                                children: [
                                  Icon(
                                    _useEmailInstead ? Icons.people_outline : Icons.email_outlined,
                                    size: 14,
                                    color: const Color(0xFF0F766E),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _useEmailInstead ? 'Select contact instead' : 'Enter email instead',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF0F766E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (!_useEmailInstead)
                          PopupMenuButton<Map<String, dynamic>>(
                            onSelected: (contactMap) {
                              setState(() {
                                _selectedContactId = contactMap['id'];
                                _selectedContactName = contactMap['name'];
                              });
                            },
                            child: Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _selectedContactName ?? 'Select a contact',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13.5,
                                      color: _selectedContactName != null ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                  const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(0xFF64748B)),
                                ],
                              ),
                            ),
                            itemBuilder: (context) => contactsList.map((c) {
                              final name = '${c.firstName} ${c.lastName}'.trim();
                              return PopupMenuItem<Map<String, dynamic>>(
                                value: {'id': c.id, 'name': name.isNotEmpty ? name : 'Contact'},
                                height: 40,
                                child: Text(
                                  name.isNotEmpty ? name : 'Contact',
                                  style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF1E293B)),
                                ),
                              );
                            }).toList(),
                          )
                        else
                          Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: GoogleFonts.poppins(fontSize: 13.5, color: const Color(0xFF1E293B)),
                              decoration: InputDecoration(
                                hintText: 'Enter email address...',
                                hintStyle: GoogleFonts.poppins(fontSize: 13.5, color: const Color(0xFF94A3B8)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 11),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),

                        // Date & time
                        _buildFieldLabel('Date & time'),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: _pickMeetingDateOnly,
                                child: Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF94A3B8)),
                                          const SizedBox(width: 8),
                                          Text(
                                            _formatDateLabel(_selectedDate),
                                            style: GoogleFonts.poppins(fontSize: 13.5, color: const Color(0xFF1E293B)),
                                          ),
                                        ],
                                      ),
                                      const Icon(Icons.calendar_month_outlined, size: 16, color: Color(0xFF1E293B)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: _pickMeetingTimeOnly,
                                child: Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF94A3B8)),
                                          const SizedBox(width: 8),
                                          Text(
                                            _formatTimeLabel(_selectedTime),
                                            style: GoogleFonts.poppins(fontSize: 13.5, color: const Color(0xFF1E293B)),
                                          ),
                                        ],
                                      ),
                                      const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF1E293B)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Duration Dropdown (matching Image 3)
                        _buildFieldLabel('Duration'),
                        const SizedBox(height: 6),
                        PopupMenuButton<String>(
                          onSelected: (val) {
                            setState(() {
                              _selectedDuration = val;
                            });
                          },
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _selectedDuration,
                                  style: GoogleFonts.poppins(fontSize: 13.5, color: const Color(0xFF1E293B)),
                                ),
                                const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(0xFF64748B)),
                              ],
                            ),
                          ),
                          itemBuilder: (context) => _durations.map((d) {
                            final isSelected = d == _selectedDuration;
                            return PopupMenuItem<String>(
                              value: d,
                              height: 40,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    d,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(Icons.check_rounded, size: 18, color: Color(0xFF0F766E)),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // Description
                        _buildFieldLabel('Description'),
                        const SizedBox(height: 6),
                        Container(
                          height: 100,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: TextField(
                            controller: _notesController,
                            maxLines: null,
                            style: GoogleFonts.poppins(fontSize: 13.5, color: const Color(0xFF1E293B)),
                            decoration: InputDecoration(
                              hintText: 'Optional notes about this meeting...',
                              hintStyle: GoogleFonts.poppins(fontSize: 13.5, color: const Color(0xFF94A3B8)),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Checkbox
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _createTeamsLink,
                                activeColor: const Color(0xFF00A884),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                onChanged: (val) {
                                  setState(() {
                                    _createTeamsLink = val ?? true;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Create a Microsoft Teams meeting link and send the calendar invite via Outlook',
                                style: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  color: const Color(0xFF334155),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(null),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.poppins(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF334155),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: _isSubmitting ? null : _submitCreateMeeting,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF66B2A9),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : Text(
                                      'Book meeting',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
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
          ),
        ],
      ),
    );
  }

  Future<void> _submitCreateMeeting() async {
    final auth = context.read<AuthProvider>();
    final organizerId = _selectedOrganizerId ?? auth.currentUser?.id ?? '311fee58-ba54-42b9-8795-f3ba19255b20';
    final organizerName = _selectedOrganizerName ?? auth.currentUser?.fullName ?? 'Admin User';

    final title = _titleController.text.trim();
    final notes = _notesController.text.trim();

    // A booked meeting is a *future* slot — the list it lands in and the
    // pending status both assume that, so reject a time that has already gone.
    final scheduledAtDt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a meeting title.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!scheduledAtDt.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pick a future date and time for the meeting.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final durationMinutes = parseDurationMinutes(_selectedDuration);

    final List<Map<String, String>> assocList = [];
    String? targetContactId = _selectedContactId ?? widget.contactId;

    if (targetContactId != null && targetContactId.isNotEmpty) {
      assocList.add({'objectId': targetContactId, 'objectType': 'contact'});
    }

    String fullNotes = notes;
    if (_useEmailInstead && _emailController.text.trim().isNotEmpty) {
      final email = _emailController.text.trim();
      fullNotes = fullNotes.isNotEmpty ? '$fullNotes\nGuest Email: $email' : 'Guest Email: $email';
    }

    final isoScheduled = scheduledAtDt.toUtc().toIso8601String();

    final meetingData = {
      'title': title,
      'type': 'meeting',
      // A booked meeting is pending until it happens, so it carries no
      // outcome yet — `outcome` is left off the payload entirely rather than
      // sent as null.
      'bookingSource': BookingSource.directBooking,
      'booking_source': BookingSource.directBooking,
      'status': 'pending',
      'duration': _selectedDuration,
      if (durationMinutes != null) 'durationMinutes': durationMinutes,
      if (durationMinutes != null) 'duration_minutes': durationMinutes,
      'scheduledAt': isoScheduled,
      'scheduled_at': isoScheduled,
      'startTime': isoScheduled,
      'start_time': isoScheduled,
      'notes': fullNotes,
      'description': fullNotes,
      'activityDate': isoScheduled,
      'activity_date': isoScheduled,
      'ownerId': organizerId,
      'owner_id': organizerId,
      'ownerName': organizerName,
      'owner_name': organizerName,
      'assignedTo': organizerName,
      'assigned_to': organizerName,
      if (assocList.isNotEmpty) 'associations': assocList,
      if (targetContactId != null && targetContactId.isNotEmpty) ...{
        'contactId': targetContactId,
        'contact_id': targetContactId,
      },
      if (_useEmailInstead && _emailController.text.trim().isNotEmpty) ...{
        'guestEmail': _emailController.text.trim(),
        'guest_email': _emailController.text.trim(),
      },
      'createTeamsLink': _createTeamsLink,
    };

    debugPrint('[CREATE MEETING POST ${ApiConstants.activities}]: ${jsonEncode(meetingData)}');

    try {
      final res = await ApiService().post(ApiConstants.activities, data: meetingData);
      debugPrint('[CREATE MEETING RESPONSE ${res.statusCode}]: ${res.data}');

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

      final createdId = (dataMap['id'] ?? dataMap['_id'])?.toString();

      // What the server actually kept. When it drops `bookingSource` the local
      // registry is what keeps this meeting out of the Log Meeting list, so
      // say so in the log rather than failing silently.
      final savedBookingSource = dataMap['bookingSource'] ?? dataMap['booking_source'];
      final savedScheduledAt = dataMap['scheduledAt'] ?? dataMap['scheduled_at'];
      debugPrint(
        '[CREATE MEETING SAVED]: id=$createdId '
        'bookingSource=${savedBookingSource ?? '(not returned)'} '
        'status=${dataMap['status'] ?? '(not returned)'} '
        'scheduledAt=${savedScheduledAt ?? '(not returned)'}',
      );
      if (BookingSource.normalize(savedBookingSource) != BookingSource.directBooking) {
        debugPrint(
          '[CREATE MEETING WARNING]: server did not echo '
          'bookingSource=direct_booking — falling back to the local registry.',
        );
      }
      if (savedScheduledAt == null || DateTime.tryParse(savedScheduledAt.toString()) == null) {
        debugPrint(
          '[CREATE MEETING WARNING]: server did not return a parsable '
          'scheduledAt (sent $isoScheduled).',
        );
      }

      // Remembered before the list reloads, so the new meeting is classified
      // as a direct booking even on the very next fetch.
      await MeetingBookingSourceStore.remember(createdId, BookingSource.directBooking);

      final createdMeeting = MeetingModel(
        id: createdId,
        title: title,
        outcome: 'Pending',
        duration: _selectedDuration,
        // Same format the meetings list renders its rows in, so the optimistic
        // row does not reshuffle its date once the reload replaces it.
        startTime: formatActivityDateTimeInput(
          parseActivityDateTimeOrNull(savedScheduledAt) ?? scheduledAtDt,
        ),
        notes: fullNotes,
        assignedTo: organizerName,
        contactId: targetContactId,
        bookingSource: BookingSource.directBooking,
        rawMap: {
          ...dataMap,
          // The screen classifies straight off rawMap; keep the tag on the
          // optimistic copy even when the response omitted it.
          'bookingSource': BookingSource.directBooking,
          if (dataMap['status'] == null) 'status': 'pending',
          if (savedScheduledAt == null) 'scheduledAt': isoScheduled,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meeting scheduled successfully!'),
            backgroundColor: Color(0xFF00A884),
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop(createdMeeting);
      }
    } catch (e) {
      debugPrint('[CREATE MEETING ERROR]: $e');
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to book meeting: $e'),
            backgroundColor: Colors.red,
          ),
        );
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

    if (widget.isCreateMode) {
      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: _buildCreateMeetingForm(context),
        ),
      );
    }

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
                      widget.titleOverride ??
                          (widget.existingMeeting != null
                              ? 'Edit Meeting'
                              : (widget.isCreateMode ? 'Create Meeting' : 'Log Meeting')),
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

                              // Logging a meeting keeps it manual; editing one
                              // keeps whatever source it was saved with, so an
                              // edited booking does not slide into this list.
                              final bookingSource = BookingSource.normalize(
                                    widget.existingMeeting?.bookingSource ??
                                        widget.existingMeeting?.rawMap?['bookingSource'] ??
                                        widget.existingMeeting?.rawMap?['booking_source'],
                                  ) ??
                                  MeetingBookingSourceStore.remembered(widget.existingMeeting?.id) ??
                                  (widget.isCreateMode
                                      ? BookingSource.directBooking
                                      : BookingSource.manual);

                              final meetingData = {
                                'title': title.isNotEmpty ? title : 'Meeting Activity',
                                'type': 'meeting',
                                'bookingSource': bookingSource,
                                'booking_source': bookingSource,
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
                                await MeetingBookingSourceStore.remember(createdId, bookingSource);
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
                                bookingSource: bookingSource,
                                rawMap: {
                                  ...(dataMap.isNotEmpty ? dataMap : meetingData),
                                  'bookingSource': bookingSource,
                                },
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
                      widget.existingMeeting != null
                          ? 'Save'
                          : (widget.isCreateMode ? 'Create meeting' : 'Log meeting'),
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
