import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/network/network_exception.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../companies/presentation/providers/company_provider.dart';
import '../../../contacts/presentation/providers/contact_provider.dart';
import '../../../deals/presentation/providers/deal_provider.dart';
import '../../../departments/presentation/providers/department_provider.dart';
import '../../../../core/providers/master_data_provider.dart';
import '../../data/models/meeting_scheduler_model.dart';
import '../providers/meeting_scheduler_provider.dart';

class MeetingSchedulerScreen extends StatefulWidget {
  const MeetingSchedulerScreen({super.key});

  @override
  State<MeetingSchedulerScreen> createState() => _MeetingSchedulerScreenState();
}

class _MeetingSchedulerScreenState extends State<MeetingSchedulerScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MeetingSchedulerProvider>().fetchMeetingSchedulers();
      _loadOtherMasterData();
    });
  }

  void _loadOtherMasterData() {
    final auth = context.read<AuthProvider>();
    final currentUserId = auth.currentUser?.id ?? '311fee58-ba54-42b9-8795-f3ba19255b20';
    auth.fetchUserProfile().catchError((e, s) => false);
    auth.fetchTeamMembers().then((_) {}).catchError((e, s) {});
    context.read<MasterDataProvider>().fetchAllMasterData(currentUserId: currentUserId).catchError((e) {});
    context.read<CompanyProvider>().fetchCompanies(ignorePermissions: true).catchError((e) => []);
    context.read<ContactProvider>().fetchContacts(ignorePermissions: true).catchError((e) => []);
    context.read<DealProvider>().fetchDeals(ignorePermissions: true).catchError((e) => []);
  }

  Future<void> _openCreateWizard({
    int initialStep = 1,
    bool isEditMode = false,
    bool initialLivePreview = false,
    MeetingScheduler? existingItem,
  }) async {
    final result = await Navigator.of(context).push<MeetingScheduler>(
      MaterialPageRoute(
        builder: (_) => CreateSchedulingPageWizardModal(
          initialStep: initialStep,
          isEditMode: isEditMode,
          initialLivePreview: initialLivePreview,
          existingItem: existingItem,
        ),
      ),
    );

    if (result != null && mounted) {
      final provider = context.read<MeetingSchedulerProvider>();
      await provider.fetchMeetingSchedulers(isRefresh: true);
      if (provider.error != null) {
        provider.addOrUpdateScheduler(result);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F8),
      body: SafeArea(
        child: Column(
          children: [
            // Top Header Bar matching image design
            Container(
              color: const Color(0xFFEFF3F8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.access_time,
                    color: Color(0xFF00897B),
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Meeting Scheduler\nPages',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                        height: 1.15,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _openCreateWizard(initialStep: 1, isEditMode: false),
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00897B),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add, size: 16, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            'Create scheduling\npage',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Scheduler Cards list area driven by MeetingSchedulerProvider
            Expanded(
              child: Consumer<MeetingSchedulerProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading && provider.schedulers.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00897B)),
                      ),
                    );
                  }

                  if (provider.error != null && provider.schedulers.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Color(0xFFE53935)),
                            const SizedBox(height: 12),
                            Text(
                              'Failed to load meeting schedulers',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              provider.error!,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => provider.fetchMeetingSchedulers(),
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00897B),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (provider.schedulers.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 48, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 12),
                          Text(
                            'No meeting schedulers found.',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () => provider.fetchMeetingSchedulers(isRefresh: true),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      itemCount: provider.schedulers.length,
                      itemBuilder: (context, index) {
                        return _buildSchedulerCard(provider.schedulers[index]);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchedulerCard(MeetingSchedulerModel item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Upper Section
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        item.ownerInitials,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.slug,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 15,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${item.durationMinutes} mins',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Card Bottom Action Bar matching image
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(10),
                bottomRight: Radius.circular(10),
              ),
              border: Border(
                top: BorderSide(color: Color(0xFFEDF2F7)),
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: item.slug));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copied to clipboard!')),
                    );
                  },
                  child: Row(
                    children: [
                      const Icon(
                        Icons.copy_outlined,
                        size: 15,
                        color: Color(0xFF334155),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Copy link',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _openCreateWizard(
                    initialStep: 1,
                    isEditMode: false,
                    initialLivePreview: true,
                    existingItem: item,
                  ),
                  icon: const Icon(Icons.open_in_new, size: 17, color: Color(0xFF64748B)),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: () => _openCreateWizard(
                    initialStep: 1,
                    isEditMode: true,
                    existingItem: item,
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF64748B)),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Delete Scheduling Page',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                        content: Text('Are you sure you want to delete "${item.title}"?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: Text('Delete',
                                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      if (mounted) {
                        context.read<MeetingSchedulerProvider>().removeScheduler(item.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Scheduling page deleted.')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_outline, size: 17, color: Color(0xFF64748B)),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Multi-step Wizard for Creating / Editing a Scheduling Page
class CreateSchedulingPageWizardModal extends StatefulWidget {
  final int initialStep;
  final bool isEditMode;
  final bool initialLivePreview;
  final MeetingSchedulerModel? existingItem;

  /// Injectable for tests; defaults to the app's shared client.
  final ApiService? apiService;

  const CreateSchedulingPageWizardModal({
    super.key,
    this.initialStep = 1,
    this.isEditMode = false,
    this.initialLivePreview = false,
    this.existingItem,
    this.apiService,
  });

  @override
  State<CreateSchedulingPageWizardModal> createState() =>
      _CreateSchedulingPageWizardModalState();
}

class _CreateSchedulingPageWizardModalState
    extends State<CreateSchedulingPageWizardModal> {
  late int _currentStep;
  bool _isLivePreviewTab = false; // false = Edit Details, true = Live Preview
  bool _isSaving = false;

  ApiService get _api => widget.apiService ?? ApiService();

  // Step 1 Form Controllers & State
  final _internalNameController = TextEditingController();
  final _eventTitleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedOrganizer;
  String? _selectedContact;
  bool _cancelAndReschedule = false;

  // Step 2 Form State (Schedule rules)
  String _timezone = 'UTC';
  final List<String> _allDurationOptions = ['15 min', '30 min', '45 min', '1 hr'];
  final List<String> _selectedDurations = ['30 min'];
  String _activeSelectedDuration = '30 min';
  final List<Map<String, String>> _availabilityWindows = [
    {'day': 'Monday', 'from': '9:00 AM', 'to': '5:00 PM'},
    {'day': 'Tuesday', 'from': '9:00 AM', 'to': '5:00 PM'},
  ];
  int _step2SubTab = 0; // 0: Schedule rules, 1: Booking form, 2: Confirmation

  // Live preview interactive state
  DateTime _previewMonth = DateTime(2026, 8, 1);
  int _selectedDay = 6;
  String? _selectedTimeSlot;

  // Step 3 Form Controllers & State
  bool _confirmationEmail = true;
  final _reminderValueController = TextEditingController(text: '1');
  String _reminderUnit = 'day(s) before';

  /// How many days/hours/minutes before the meeting to remind. Falls back to 1
  /// when the field is empty or not a positive number.
  int get _reminderValue {
    final parsed = int.tryParse(_reminderValueController.text.trim());
    return (parsed != null && parsed > 0) ? parsed : 1;
  }

  // Organizer / contact options, loaded from the API.
  List<Map<String, dynamic>> _users = [];
  bool _isLoadingUsers = false;

  /// Dropdown values fall back to Material's titleMedium (16sp) when no style
  /// is given, which left them towering over the 13.5sp fields beside them and
  /// overflowing their boxes. Every dropdown on this wizard uses this instead.
  static final TextStyle _dropdownTextStyle = GoogleFonts.inter(
    fontSize: 13.5,
    fontWeight: FontWeight.w500,
    color: const Color(0xFF1E293B),
  );

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;
    _isLivePreviewTab = widget.initialLivePreview;

    if (widget.existingItem != null) {
      _internalNameController.text = widget.existingItem!.title;
      _eventTitleController.text = widget.existingItem!.title;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fetchUsers();
      // Contacts come from the shared provider, which caches them across screens.
      final contactProvider = context.read<ContactProvider>();
      if (contactProvider.contacts.isEmpty) {
        contactProvider.fetchContacts(ignorePermissions: true);
      }
    });
  }

  /// Minutes for a duration chip such as '15 min', '1 hr', or '1 hr 30 min'.
  static int? _durationChipToMinutes(String chip) {
    final lower = chip.toLowerCase().trim();
    if (lower.contains('hr') && lower.contains('min')) {
      final parts = lower.split(RegExp(r'\s+'));
      int total = 0;
      for (int i = 0; i < parts.length; i++) {
        if (parts[i].contains('hr') || parts[i].contains('hour')) {
          final h = int.tryParse(parts[i].replaceAll(RegExp(r'[^0-9]'), '')) ??
              (i > 0 ? int.tryParse(parts[i - 1].replaceAll(RegExp(r'[^0-9]'), '')) : null);
          if (h != null) total += h * 60;
        } else if (parts[i].contains('min')) {
          final m = int.tryParse(parts[i].replaceAll(RegExp(r'[^0-9]'), '')) ??
              (i > 0 ? int.tryParse(parts[i - 1].replaceAll(RegExp(r'[^0-9]'), '')) : null);
          if (m != null) total += m;
        }
      }
      if (total > 0) return total;
    }
    final digits = int.tryParse(chip.replaceAll(RegExp(r'[^0-9]'), ''));
    if (digits == null || digits <= 0) return null;
    final isHours = lower.contains('hr') || lower.contains('hour');
    return isHours ? digits * 60 : digits;
  }

  /// The selected duration chips as whole minutes, in the order shown.
  List<int> _durationOptionsInMinutes() {
    final minutes = <int>[];
    for (final chip in _selectedDurations) {
      final value = _durationChipToMinutes(chip);
      if (value != null && !minutes.contains(value)) minutes.add(value);
    }
    return minutes;
  }

  String _formatTimeTo24Hour(String time12) {
    final clean = time12.trim();
    if (clean.isEmpty) return '09:00';
    if (RegExp(r'^\d{1,2}:\d{2}$').hasMatch(clean)) {
      final parts = clean.split(':');
      final h = parts[0].padLeft(2, '0');
      final m = parts[1];
      return '$h:$m';
    }

    final isPM = clean.toUpperCase().contains('PM');
    final isAM = clean.toUpperCase().contains('AM');
    final digits = clean.replaceAll(RegExp(r'[^0-9:]'), '');
    final parts = digits.split(':');
    if (parts.length < 2) return '09:00';

    int hour = int.tryParse(parts[0]) ?? 9;
    int minute = int.tryParse(parts[1]) ?? 0;

    if (isPM && hour < 12) hour += 12;
    if (isAM && hour == 12) hour = 0;

    final hStr = hour.toString().padLeft(2, '0');
    final mStr = minute.toString().padLeft(2, '0');
    return '$hStr:$mStr';
  }

  /// The availability rows in the `[{day, slots:[{start, end}]}]` shape the
  /// API returns, merging repeated days into one entry.
  List<Map<String, dynamic>> _availabilityWindowPayload() {
    final byDay = <String, List<Map<String, String>>>{};

    for (final window in _availabilityWindows) {
      final day = (window['day'] ?? '').trim().toLowerCase();
      final startRaw = (window['from'] ?? '').trim();
      final endRaw = (window['to'] ?? '').trim();
      if (day.isEmpty || startRaw.isEmpty || endRaw.isEmpty) continue;

      final start = _formatTimeTo24Hour(startRaw);
      final end = _formatTimeTo24Hour(endRaw);

      byDay.putIfAbsent(day, () => []).add({'start': start, 'end': end});
    }

    return byDay.entries
        .map((entry) => {'day': entry.key, 'slots': entry.value})
        .toList();
  }

  /// 'day(s) before' → 'day', so the unit matches backend enum validation ("minute" | "hour" | "day").
  String _reminderUnitValue() {
    final unit = _reminderUnit.toLowerCase();
    if (unit.contains('hour')) return 'hour';
    if (unit.contains('minute')) return 'minute';
    return 'day';
  }

  Future<void> _submitForm() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final internalName = _internalNameController.text.trim();
    if (internalName.isEmpty) {
      setState(() {
        _currentStep = 1;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an internal name.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String ownerInitials = 'AD';
    if (_selectedOrganizer != null && _selectedOrganizer!.isNotEmpty) {
      final foundUser = _users.firstWhere(
        (u) => (u['id'] ?? u['_id'])?.toString() == _selectedOrganizer,
        orElse: () => {},
      );
      if (foundUser.isNotEmpty) {
        final first = (foundUser['firstName'] ?? foundUser['first_name'] ?? '').toString();
        final last = (foundUser['lastName'] ?? foundUser['last_name'] ?? '').toString();
        if (first.isNotEmpty || last.isNotEmpty) {
          ownerInitials = '${first.isNotEmpty ? first[0] : ''}${last.isNotEmpty ? last[0] : ''}'.toUpperCase();
        }
      }
    }

    final rawSlug = internalName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final slug = rawSlug.isEmpty ? 'meeting' : rawSlug;

    final eventTitleText = _eventTitleController.text.trim();

    final auth = context.read<AuthProvider>();
    final currentUserId = auth.currentUser?.id ?? '311fee58-ba54-42b9-8795-f3ba19255b20';
    final deptProvider = context.read<DepartmentProvider>();
    final currentDeptId = deptProvider.selectedDepartmentId;

    final desc = _descriptionController.text.trim();

    final payload = {
      'name': internalName,
      'slug': slug.startsWith('/') ? slug : '/$slug',
      'eventTitle': eventTitleText.isNotEmpty ? eventTitleText : internalName,
      if (desc.isNotEmpty) 'description': desc,
      'ownerId': (_selectedOrganizer != null && _selectedOrganizer!.isNotEmpty)
          ? _selectedOrganizer
          : currentUserId,
      if (currentDeptId.isNotEmpty && !currentDeptId.startsWith('a1b2c3d4-0000'))
        'departmentId': currentDeptId,
      'cancelReschedule': _cancelAndReschedule,
      'collectPayments': false,
      'durationOptions': _durationOptionsInMinutes(),
      'timeZone': _timezone.isEmpty ? 'UTC' : _timezone,
      'availabilityWindow': _availabilityWindowPayload(),
      'formFields': [
        {
          'name': 'firstName',
          'type': 'text',
          'label': 'First name',
          'required': true,
        },
        {
          'name': 'lastName',
          'type': 'text',
          'label': 'Last name',
          'required': true,
        },
        {
          'name': 'email',
          'type': 'text',
          'label': 'Email address',
          'required': true,
        },
      ],
      'confirmationType': 'message',
      'sendConfirmationEmail': _confirmationEmail,
      'reminderEmails': [
        {
          'value': _reminderValue,
          'unit': _reminderUnitValue(),
        },
      ],
      if (_selectedContact != null && _selectedContact!.isNotEmpty)
        'contactId': _selectedContact,
    };

    final existingId = widget.existingItem?.id;
    final isEditing =
        widget.isEditMode && existingId != null && existingId.isNotEmpty;

    MeetingSchedulerModel savedModel;

    try {
      final response = isEditing
          ? await _api
              .patch('${ApiConstants.meetingSchedulers}/$existingId', data: payload)
          : await _api
              .post(ApiConstants.meetingSchedulers, data: payload);

      debugPrint('[SAVE SCHEDULING PAGE SUCCESS]: ${response.statusCode} -> ${response.data}');

      final raw = response.data;
      final body = raw is Map && raw['data'] is Map ? raw['data'] : raw;

      if (body is Map) {
        savedModel = MeetingScheduler.fromJson(Map<String, dynamic>.from(body));
      } else {
        savedModel = MeetingScheduler(
          id: existingId ?? DateTime.now().millisecondsSinceEpoch.toString(),
          name: internalName,
          slug: slug,
          durationOptions: _durationOptionsInMinutes(),
          organizerName: ownerInitials,
          availabilityWindow: const [],
          formFields: const [],
          reminderEmails: const [],
        );
      }
    } catch (e) {
      debugPrint('[SAVE SCHEDULING PAGE ERROR]: $e');
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.isEditMode ? 'Could not save changes' : 'Could not create the scheduling page'}: ${_describeError(e)}',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    if (!mounted) return;

    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.isEditMode
            ? 'Scheduling page updated successfully!'
            : 'Scheduling page created successfully!'),
        backgroundColor: const Color(0xFF00897B),
      ),
    );

    Navigator.of(context).pop(savedModel);
  }

  /// Pulls a readable message out of whatever the server sent back.
  static String _describeError(Object error) {
    if (error is NetworkException) {
      final data = error.data;
      if (data is Map) {
        final errors = data['errors'] ?? data['details'];
        if (errors is List && errors.isNotEmpty) return errors.join(', ');
        final msg = data['message'] ?? data['error'];
        if (msg is List && msg.isNotEmpty) return msg.join(', ');
        if (msg is String && msg.trim().isNotEmpty && msg.trim() != 'Validation failed') return msg.trim();
        if (errors != null && errors.toString().isNotEmpty) return errors.toString();
      }
      return error.message;
    }
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final errors = data['errors'] ?? data['details'];
        if (errors is List && errors.isNotEmpty) return errors.join(', ');
        final msg = data['message'] ?? data['error'];
        if (msg is List && msg.isNotEmpty) return msg.join(', ');
        if (msg is String && msg.trim().isNotEmpty && msg.trim() != 'Validation failed') return msg.trim();
        if (errors != null && errors.toString().isNotEmpty) return errors.toString();
      }
      if (error.message != null && error.message!.isNotEmpty) return error.message!;
    }
    return error.toString();
  }

  /// Loads the organizer options from `GET /api/users`.
  Future<void> _fetchUsers() async {
    setState(() => _isLoadingUsers = true);
    try {
      final resp = await _api.get('/users');
      final raw = resp.data;
      List<Map<String, dynamic>> users = [];
      if (raw is List) {
        users = raw.whereType<Map<String, dynamic>>().toList();
      } else if (raw is Map && raw['data'] is List) {
        users = (raw['data'] as List).whereType<Map<String, dynamic>>().toList();
      } else if (raw is Map && raw['users'] is List) {
        users = (raw['users'] as List).whereType<Map<String, dynamic>>().toList();
      }
      if (!mounted) return;
      setState(() {
        _users = users;
        _isLoadingUsers = false;
      });
    } catch (e) {
      debugPrint('[SchedulingWizard _fetchUsers ERROR]: $e');
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }

  /// One entry per user, keyed by id so duplicates cannot break the dropdown.
  List<DropdownMenuItem<String>> _organizerItems() {
    final items = <DropdownMenuItem<String>>[];
    final seen = <String>{};

    for (final user in _users) {
      final id = (user['id'] ?? user['_id'])?.toString();
      if (id == null || id.isEmpty || !seen.add(id)) continue;
      items.add(
        DropdownMenuItem(
          value: id,
          child: Text(_userLabel(user), overflow: TextOverflow.ellipsis),
        ),
      );
    }
    return items;
  }

  /// Display name for a user record from `/api/users`.
  String _userLabel(Map<String, dynamic> user) {
    final first = (user['firstName'] ?? user['first_name'] ?? '').toString();
    final last = (user['lastName'] ?? user['last_name'] ?? '').toString();
    final name = '$first $last'.trim();
    if (name.isNotEmpty) return name;
    final email = (user['email'] ?? '').toString();
    return email.isNotEmpty ? email : 'User';
  }

  @override
  void dispose() {
    _internalNameController.dispose();
    _eventTitleController.dispose();
    _descriptionController.dispose();
    _reminderValueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF334155)),
          onPressed: () {
            if (_currentStep > 1) {
              setState(() {
                _currentStep--;
              });
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Text(
          widget.isEditMode ? 'Edit scheduling page' : 'Create one-on-one ...',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _submitForm,
            child: Text(
              widget.isEditMode ? 'Save' : 'Create',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: _isSaving ? const Color(0xFF94A3B8) : const Color(0xFF00897B),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                'Step $_currentStep of 3',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Tab Header: Edit Details | Live Preview (Increased white box size)
            Container(
              color: const Color(0xFFF1F5F9),
              padding: const EdgeInsets.all(12),
              child: Container(
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Edit Details Button
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isLivePreviewTab = false;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: !_isLivePreviewTab ? const Color(0xFFE6F4F1) : Colors.transparent,
                            borderRadius: BorderRadius.circular(7),
                            border: !_isLivePreviewTab
                                ? Border.all(color: const Color(0xFFB2DFDB))
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.edit_outlined,
                                size: 17,
                                color: !_isLivePreviewTab
                                    ? const Color(0xFF00897B)
                                    : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 8),
                              // Flexible so the label shortens instead of
                              // pushing the row past the half it is given.
                              Flexible(
                                child: Text(
                                  'Edit Details',
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    fontWeight: !_isLivePreviewTab
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: !_isLivePreviewTab
                                        ? const Color(0xFF00897B)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Live Preview Button
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isLivePreviewTab = true;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: _isLivePreviewTab ? const Color(0xFFE6F4F1) : Colors.transparent,
                            borderRadius: BorderRadius.circular(7),
                            border: _isLivePreviewTab
                                ? Border.all(color: const Color(0xFFB2DFDB))
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.visibility_outlined,
                                size: 17,
                                color: _isLivePreviewTab
                                    ? const Color(0xFF00897B)
                                    : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 8),
                              // Flexible so the label shortens instead of
                              // pushing the row past the half it is given.
                              Flexible(
                                child: Text(
                                  'Live Preview',
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    fontWeight: _isLivePreviewTab
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: _isLivePreviewTab
                                        ? const Color(0xFF00897B)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 1),

            // Step Content or Live Preview Calendar Content
            Expanded(
              child: _isLivePreviewTab
                  ? _buildLivePreviewCalendar()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: _currentStep == 1
                          ? _buildStep1Form()
                          : (_currentStep == 2 ? _buildStep2Form() : _buildStep3Form()),
                    ),
            ),

            // Bottom Navigation Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  // The actions share the space left of Cancel, so the primary
                  // button shrinks instead of pushing the bar off-screen.
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                  if (_currentStep > 1)
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _currentStep--;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_back_ios, size: 12, color: Color(0xFF334155)),
                      label: Text(
                        'Back',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ),
                  if (_currentStep > 1) const SizedBox(width: 10),
                  // Flexible so 'Create scheduling page' shortens on a narrow
                  // phone instead of pushing the bar past the screen.
                  Flexible(
                    child: ElevatedButton(
                      onPressed: _isSaving
                          ? null
                          : () {
                              if (_currentStep < 3) {
                                if (_currentStep == 1 &&
                                    _internalNameController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Please enter an internal name.'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }
                                setState(() {
                                  _currentStep++;
                                });
                              } else {
                                _submitForm();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00897B),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    _currentStep == 3
                                        ? (widget.isEditMode ? 'Save changes' : 'Create scheduling page')
                                        : 'Next',
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (_currentStep < 3) const SizedBox(width: 4),
                                if (_currentStep < 3)
                                  const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white),
                              ],
                            ),
                    ),
                  ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Step 1 Layout
  Widget _buildStep1Form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'One-on-one',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF334155),
            ),
          ),
        ),

        const SizedBox(height: 18),
        _buildLabelWithInfo('Internal name *'),
        const SizedBox(height: 6),
        TextField(
          controller: _internalNameController,
          decoration: _inputDecoration('e.g. 30min intro call'),
          style: GoogleFonts.inter(fontSize: 13.5),
        ),

        const SizedBox(height: 18),
        _buildLabelWithInfo('Organizer'),
        const SizedBox(height: 6),
        // Every user from GET /api/users.
        DropdownButtonFormField<String>(
          initialValue: _selectedOrganizer,
          isExpanded: true,
          style: _dropdownTextStyle,
          decoration: _inputDecoration(
            _isLoadingUsers ? 'Loading users...' : 'Select organizer',
          ),
          items: _organizerItems(),
          onChanged: (val) => setState(() => _selectedOrganizer = val),
        ),

        const SizedBox(height: 18),
        _buildLabelWithInfo('Contact'),
        const SizedBox(height: 6),
        // Contacts from the shared ContactProvider.
        Consumer<ContactProvider>(
          builder: (context, contactProvider, child) {
            final contacts = contactProvider.contacts;
            return DropdownButtonFormField<String>(
              initialValue: contacts.any((c) => c.id == _selectedContact)
                  ? _selectedContact
                  : null,
              isExpanded: true,
              style: _dropdownTextStyle,
              decoration: _inputDecoration(
                contactProvider.isLoading && contacts.isEmpty
                    ? 'Loading contacts...'
                    : 'Select a contact',
              ),
              items: contacts
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(c.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (val) => setState(() => _selectedContact = val),
            );
          },
        ),

        const SizedBox(height: 18),
        _buildLabelWithInfo('Event title'),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _eventTitleController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText:
                      'e.g. {{contact.first_name}} {{contact.last_name}} and {{organizer.first_name}}',
                  border: InputBorder.none,
                  isDense: true,
                ),
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: _buildPersonalizeDropdown(
                  onSelected: (tag) {
                    setState(() {
                      _insertTagIntoController(_eventTitleController, tag);
                    });
                  },
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cancel and reschedule',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Include cancel and reschedule links in the event description',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _cancelAndReschedule,
              activeThumbColor: const Color(0xFF00897B),
              onChanged: (val) => setState(() => _cancelAndReschedule = val),
            ),
          ],
        ),

        const SizedBox(height: 18),
        _buildLabelWithInfo('Description'),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Invite text or agenda...',
                  hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  border: InputBorder.none,
                  isDense: true,
                ),
                style: GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF0F172A)),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: _buildPersonalizeDropdown(
                  onSelected: (tag) {
                    setState(() {
                      _insertTagIntoController(_descriptionController, tag);
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _insertTagIntoController(TextEditingController controller, String tag) {
    final text = controller.text;
    final selection = controller.selection;

    if (selection.isValid && selection.start >= 0 && selection.end >= 0) {
      final start = selection.start;
      final end = selection.end;
      final newText = text.replaceRange(start, end, tag);
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + tag.length),
      );
    } else {
      final newText = text + tag;
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
  }

  Widget _buildPersonalizeDropdown({required ValueChanged<String> onSelected}) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      elevation: 3,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      onSelected: onSelected,
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: '{{organizer.last_name}}',
          height: 38,
          child: Text(
            'Organizer last name',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1E293B),
            ),
          ),
        ),
        PopupMenuItem<String>(
          value: '{{organizer.email}}',
          height: 38,
          child: Text(
            'Organizer email',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1E293B),
            ),
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Personalize',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF00897B),
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: Color(0xFF00897B),
            ),
          ],
        ),
      ),
    );
  }

  /// Step 2 Form (Schedule rules) matching Image 1 & 2
  Widget _buildStep2Form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sub Tabs: Schedule rules | Booking form | Confirmation
        // Scrolls sideways rather than overflowing on a narrow phone.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildSubTabItem(0, 'Schedule rules'),
              const SizedBox(width: 16),
              _buildSubTabItem(1, 'Booking form'),
              const SizedBox(width: 16),
              _buildSubTabItem(2, 'Confirmation'),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Organizer timezone
        Text(
          'Organizer timezone',
          style: GoogleFonts.inter(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _timezone,
          isExpanded: true,
          style: _dropdownTextStyle,
          decoration: _inputDecoration('UTC'),
          items: const [
            DropdownMenuItem(value: 'UTC', child: Text('UTC', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 'Asia/Calcutta', child: Text('Asia/Calcutta', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 'EST', child: Text('EST', overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _timezone = val);
          },
        ),

        const SizedBox(height: 18),

        // Duration options (Click to open Image 2 duration picker modal)
        Text(
          'Duration options',
          style: GoogleFonts.inter(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _showDurationPickerModal,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _selectedDurations.isEmpty
                      ? Text(
                          'Select duration options',
                          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: _selectedDurations.map((dur) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE6F4F1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFB2DFDB)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    dur,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF00897B),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedDurations.remove(dur);
                                      });
                                    },
                                    child: const Icon(Icons.close, size: 14, color: Color(0xFF00897B)),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ),
                const Icon(Icons.arrow_drop_down, color: Color(0xFF00897B)),
              ],
            ),
          ),
        ),

        const SizedBox(height: 18),

        // Availability window
        Text(
          'Availability window',
          style: GoogleFonts.inter(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),

        ..._availabilityWindows.map((win) => _buildAvailabilityCard(win)),

        const SizedBox(height: 8),

        TextButton.icon(
          onPressed: () {
            setState(() {
              _availabilityWindows.add({
                'day': 'Wednesday',
                'from': '9:00 AM',
                'to': '5:00 PM',
              });
            });
          },
          icon: const Icon(Icons.add, size: 16, color: Color(0xFF00897B)),
          label: Text(
            'Add hours',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF00897B),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubTabItem(int index, String title) {
    final bool isSelected = _step2SubTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _step2SubTab = index;
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? const Color(0xFF00897B) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 2,
            width: 75,
            color: isSelected ? const Color(0xFF00897B) : Colors.transparent,
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityCard(Map<String, String> win) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: win['day'],
                  isExpanded: true,
                  style: _dropdownTextStyle,
                  decoration: _inputDecoration('Select day'),
                  items: const [
                    DropdownMenuItem(value: 'Monday', child: Text('Monday', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'Tuesday', child: Text('Tuesday', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'Wednesday', child: Text('Wednesday', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'Thursday', child: Text('Thursday', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'Friday', child: Text('Friday', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => win['day'] = val);
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  setState(() {
                    _availabilityWindows.remove(win);
                  });
                },
                icon: const Icon(Icons.delete_outline, color: Color(0xFFE53935), size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('from', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
              const SizedBox(width: 6),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: win['from'],
                  isExpanded: true,
                  style: _dropdownTextStyle,
                  decoration: _inputDecoration('From', dense: true),
                  items: const [
                    DropdownMenuItem(value: '9:00 AM', child: Text('9:00 AM', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: '10:00 AM', child: Text('10:00 AM', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => win['from'] = val);
                  },
                ),
              ),
              const SizedBox(width: 6),
              Text('to', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
              const SizedBox(width: 6),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: win['to'],
                  isExpanded: true,
                  style: _dropdownTextStyle,
                  decoration: _inputDecoration('To', dense: true),
                  items: const [
                    DropdownMenuItem(value: '5:00 PM', child: Text('5:00 PM', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: '6:00 PM', child: Text('6:00 PM', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => win['to'] = val);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Interactive Dynamic Live Preview Calendar View
  Widget _buildLivePreviewCalendar() {
    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final monthTitle = '${monthNames[_previewMonth.month - 1]} ${_previewMonth.year}';

    // Build time slots dynamically based on active duration
    final List<String> availableTimeSlots = [
      '09:00 AM', '09:30 AM', '10:00 AM', '11:30 AM',
      '02:00 PM', '03:30 PM', '04:30 PM'
    ];

    return SingleChildScrollView(
      child: Column(
        children: [
          // Dynamic Teal Header Banner Area
          Container(
            width: double.infinity,
            color: const Color(0xFF0F5B53), // Teal dark green
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              children: [
                // Initials Circle
                Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    (_selectedOrganizer != null && _selectedOrganizer!.isNotEmpty)
                        ? _selectedOrganizer![0].toUpperCase()
                        : 'A',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F5B53),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _eventTitleController.text.trim().isNotEmpty
                      ? _eventTitleController.text
                      : 'Meet with ${_selectedOrganizer ?? "Organizer"}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),

                // Calendar Month Navigation View
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: Colors.white, size: 22),
                      onPressed: () {
                        setState(() {
                          _previewMonth = DateTime(_previewMonth.year, _previewMonth.month - 1, 1);
                        });
                      },
                    ),
                    Text(
                      monthTitle,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, color: Colors.white, size: 22),
                      onPressed: () {
                        setState(() {
                          _previewMonth = DateTime(_previewMonth.year, _previewMonth.month + 1, 1);
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Days Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'].map((day) {
                    return SizedBox(
                      width: 32,
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 10),

                // Calendar Grid Days
                Column(
                  children: [
                    _buildInteractiveCalendarRow(['', '', '1', '2', '3', '4', '5']),
                    const SizedBox(height: 8),
                    _buildInteractiveCalendarRow(['6', '7', '8', '9', '10', '11', '12']),
                    const SizedBox(height: 8),
                    _buildInteractiveCalendarRow(['13', '14', '15', '16', '17', '18', '19']),
                    const SizedBox(height: 8),
                    _buildInteractiveCalendarRow(['20', '21', '22', '23', '24', '25', '26']),
                    const SizedBox(height: 8),
                    _buildInteractiveCalendarRow(['27', '28', '29', '30', '31', '', '']),
                  ],
                ),

                const SizedBox(height: 20),
                Text(
                  'Powered by Apidel CRM',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),

          // Bottom White Area below Calendar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MEETING DURATION',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 8),
                
                // Dynamic Duration Selection Chips
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: _selectedDurations.map((dur) {
                    final bool isSelected = _activeSelectedDuration == dur;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _activeSelectedDuration = dur;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFE6F4F1) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: isSelected ? Border.all(color: const Color(0xFFB2DFDB)) : null,
                        ),
                        child: Text(
                          dur,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? const Color(0xFF00897B) : const Color(0xFF334155),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),
                Text(
                  'What time works best?',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'Showing times for $_selectedDay ${monthNames[_previewMonth.month - 1]} ${_previewMonth.year}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '$_timezone ▼',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF00897B),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Dynamic Time Slots or Empty state
                if (_selectedDay % 2 == 0) ...[
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 2.8,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: availableTimeSlots.length,
                    itemBuilder: (context, idx) {
                      final slot = availableTimeSlots[idx];
                      final isSelected = _selectedTimeSlot == slot;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedTimeSlot = slot;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF00897B) : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF00897B) : const Color(0xFFCBD5E1),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            slot,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : const Color(0xFF00897B),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'No availability configured for this day',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveCalendarRow(List<String> days) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: days.map((dayStr) {
        final dayInt = int.tryParse(dayStr);
        final bool isSelected = dayInt != null && dayInt == _selectedDay;

        return GestureDetector(
          onTap: dayInt == null
              ? null
              : () {
                  setState(() {
                    _selectedDay = dayInt;
                    _selectedTimeSlot = null;
                  });
                },
          child: SizedBox(
            width: 32,
            height: 32,
            child: Container(
              decoration: isSelected
                  ? const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    )
                  : null,
              alignment: Alignment.center,
              child: Text(
                dayStr,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFF0F5B53) : Colors.white,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }



  /// Step 3 Layout matching Image 3
  Widget _buildStep3Form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Automation',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Configure confirmation triggers and automated email reminders.',
          style: GoogleFonts.inter(
            fontSize: 12.5,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 20),

        // Confirmation email card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Confirmation email',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Send validation email immediately after calendar booking',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _confirmationEmail,
                activeThumbColor: const Color(0xFF00897B),
                onChanged: (val) => setState(() => _confirmationEmail = val),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Pre-meeting reminders
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // The heading gives way to the action rather than overflowing.
            Expanded(
              child: Text(
                'Pre-meeting reminders',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add, size: 16, color: Color(0xFF00897B)),
              label: Text(
                'Add reminder',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF00897B),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Reminder row box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              // Value field
              SizedBox(
                width: 60,
                child: TextField(
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  // A controller built inline was recreated every frame, so
                  // whatever was typed here never reached the payload.
                  controller: _reminderValueController,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              // Unit dropdown
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _reminderUnit,
                  isExpanded: true,
                  style: _dropdownTextStyle,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'day(s) before',
                      child: Text('day(s) before', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 'hour(s) before',
                      child: Text('hour(s) before', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 'minute(s) before',
                      child: Text('minute(s) before', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _reminderUnit = val);
                  },
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.delete_outline, color: Color(0xFF94A3B8), size: 20),
            ],
          ),
        ),
      ],
    );
  }

  /// Custom Duration Dialog with Hours & Minutes input boxes
  void _showAddCustomDurationDialog() {
    final hoursController = TextEditingController();
    final minsController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: Text(
            'Add custom duration',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter duration in Hours and Minutes:',
                style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // Hours Box
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hours',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: hoursController,
                          keyboardType: TextInputType.number,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: '0',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                          ),
                          style: GoogleFonts.inter(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Minutes Box
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Minutes',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: minsController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: '30',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                          ),
                          style: GoogleFonts.inter(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final hrs = int.tryParse(hoursController.text.trim()) ?? 0;
                final mins = int.tryParse(minsController.text.trim()) ?? 0;
                final totalMinutes = (hrs * 60) + mins;

                if (totalMinutes > 0) {
                  String formatted;
                  if (hrs > 0 && mins > 0) {
                    formatted = '$hrs hr $mins min';
                  } else if (hrs > 0) {
                    formatted = '$hrs hr';
                  } else {
                    formatted = '$mins min';
                  }

                  setState(() {
                    if (!_allDurationOptions.contains(formatted)) {
                      _allDurationOptions.add(formatted);
                    }
                    if (!_selectedDurations.contains(formatted)) {
                      _selectedDurations.add(formatted);
                    }
                    if (_activeSelectedDuration.isEmpty) {
                      _activeSelectedDuration = formatted;
                    }
                  });
                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00897B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: Text(
                'Add',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Duration Options Picker Overlay (Image 2 style)
  void _showDurationPickerModal() {
    String searchQuery = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredOptions = _allDurationOptions
                .where((opt) => opt.toLowerCase().contains(searchQuery.toLowerCase()))
                .toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.55,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search box (Image 2 top)
                    TextField(
                      onChanged: (val) {
                        setModalState(() {
                          searchQuery = val;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search',
                        prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: Color(0xFF00897B)),
                        ),
                      ),
                      style: GoogleFonts.inter(fontSize: 13),
                    ),
                    const SizedBox(height: 12),

                    // Options Checkbox List
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredOptions.length,
                        itemBuilder: (context, idx) {
                          final option = filteredOptions[idx];
                          final isChecked = _selectedDurations.contains(option);
                          return InkWell(
                            onTap: () {
                              setState(() {
                                if (isChecked) {
                                  _selectedDurations.remove(option);
                                } else {
                                  _selectedDurations.add(option);
                                }
                                if (_selectedDurations.isNotEmpty &&
                                    !_selectedDurations.contains(_activeSelectedDuration)) {
                                  _activeSelectedDuration = _selectedDurations.first;
                                }
                              });
                              setModalState(() {});
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Checkbox(
                                      value: isChecked,
                                      activeColor: const Color(0xFF00897B),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedDurations.add(option);
                                          } else {
                                            _selectedDurations.remove(option);
                                          }
                                        });
                                        setModalState(() {});
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    option,
                                    style: GoogleFonts.inter(
                                      fontSize: 13.5,
                                      fontWeight: isChecked ? FontWeight.w600 : FontWeight.w400,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const Divider(height: 16),

                    // Add Custom Duration button at bottom (Image 2 style)
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        _showAddCustomDurationDialog();
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Add custom duration',
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF00897B),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLabelWithInfo(String text) {
    return Row(
      children: [
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.info_outline, size: 14, color: Color(0xFF94A3B8)),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint, {bool dense = false}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
      fillColor: Colors.white,
      filled: true,
      contentPadding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 12,
        vertical: 12,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
    );
  }
}
