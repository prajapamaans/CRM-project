import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../../../core/repositories/master_data_repository.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../companies/presentation/providers/company_provider.dart';
import '../../../contacts/presentation/providers/contact_provider.dart';
import '../../../deals/presentation/providers/deal_provider.dart';
import '../../../../core/providers/master_data_provider.dart';

class MeetingSchedulerModel {
  final String id;
  final String title;
  final String slug;
  final int durationMinutes;
  final String ownerInitials;

  MeetingSchedulerModel({
    required this.id,
    required this.title,
    required this.slug,
    required this.durationMinutes,
    required this.ownerInitials,
  });

  factory MeetingSchedulerModel.fromJson(Map<String, dynamic> json) {
    final title = json['title'] as String? ?? json['name'] as String? ?? 'test';
    final slug = json['slug'] as String? ?? json['url'] as String? ?? '/test';
    final duration = json['durationMinutes'] as int? ??
        json['duration'] as int? ??
        int.tryParse(json['duration']?.toString() ?? '') ??
        30;

    String initials = 'AD';
    if (json['owner'] != null && json['owner']['firstName'] != null) {
      final f = json['owner']['firstName'] as String;
      final l = json['owner']['lastName'] as String? ?? '';
      initials = '${f.isNotEmpty ? f[0] : ''}${l.isNotEmpty ? l[0] : ''}'.toUpperCase();
    } else if (json['ownerName'] != null) {
      final parts = (json['ownerName'] as String).split(' ');
      if (parts.length >= 2) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
        initials = parts[0][0].toUpperCase();
      }
    }

    return MeetingSchedulerModel(
      id: json['id']?.toString() ?? '',
      title: title,
      slug: slug.startsWith('/') ? slug : '/$slug',
      durationMinutes: duration,
      ownerInitials: initials.isEmpty ? 'AD' : initials,
    );
  }
}

class MeetingSchedulerScreen extends StatefulWidget {
  const MeetingSchedulerScreen({super.key});

  @override
  State<MeetingSchedulerScreen> createState() => _MeetingSchedulerScreenState();
}

class _MeetingSchedulerScreenState extends State<MeetingSchedulerScreen> {
  bool _isLoading = false;
  List<MeetingSchedulerModel> _schedulers = [
    MeetingSchedulerModel(
      id: '1',
      title: 'test',
      slug: '/test',
      durationMinutes: 30,
      ownerInitials: 'AD',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadScreenData();
    });
  }

  Future<void> _loadScreenData() async {
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    final currentUserId = auth.currentUser?.id ?? '311fee58-ba54-42b9-8795-f3ba19255b20';

    auth.fetchUserProfile().catchError((e, s) => false);
    auth.fetchTeamMembers().then((_) {}).catchError((e, s) {});
    context.read<MasterDataProvider>().fetchAllMasterData(currentUserId: currentUserId).catchError((e) {});
    context.read<CompanyProvider>().fetchCompanies(ignorePermissions: true).catchError((e) => []);
    context.read<ContactProvider>().fetchContacts(ignorePermissions: true).catchError((e) => []);
    context.read<DealProvider>().fetchDeals(ignorePermissions: true).catchError((e) => []);

    try {
      final repo = MasterDataRepositoryImpl();
      final data = await repo.getMeetingSchedulers().timeout(const Duration(seconds: 3));
      if (mounted) {
        final list = data.map((e) => MeetingSchedulerModel.fromJson(e)).toList();
        setState(() {
          _schedulers = list.isNotEmpty
              ? list
              : [
                  MeetingSchedulerModel(
                    id: '1',
                    title: 'test',
                    slug: '/test',
                    durationMinutes: 30,
                    ownerInitials: 'AD',
                  ),
                ];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[MeetingSchedulerScreen load error]: $e');
      if (mounted) {
        setState(() {
          _schedulers = [
            MeetingSchedulerModel(
              id: '1',
              title: 'test',
              slug: '/test',
              durationMinutes: 30,
              ownerInitials: 'AD',
            ),
          ];
          _isLoading = false;
        });
      }
    }
  }

  void _openCreateWizard({int initialStep = 1, bool isEditMode = false}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateSchedulingPageWizardModal(
          initialStep: initialStep,
          isEditMode: isEditMode,
        ),
      ),
    );
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

            // Scheduler Cards list area
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00897B)),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadScreenData,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        itemCount: _schedulers.length,
                        itemBuilder: (context, index) {
                          return _buildSchedulerCard(_schedulers[index]);
                        },
                      ),
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
                const Icon(
                  Icons.open_in_new,
                  size: 17,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: () => _openCreateWizard(initialStep: 2, isEditMode: true),
                  icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF64748B)),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 16),
                const Icon(
                  Icons.delete_outline,
                  size: 17,
                  color: Color(0xFF64748B),
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

  const CreateSchedulingPageWizardModal({
    super.key,
    this.initialStep = 1,
    this.isEditMode = false,
  });

  @override
  State<CreateSchedulingPageWizardModal> createState() =>
      _CreateSchedulingPageWizardModalState();
}

class _CreateSchedulingPageWizardModalState
    extends State<CreateSchedulingPageWizardModal> {
  late int _currentStep;
  bool _isLivePreviewTab = false; // false = Edit Details, true = Live Preview

  // Step 1 Form Controllers & State
  final _internalNameController = TextEditingController();
  final _eventTitleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedOrganizer;
  String? _selectedContact;
  bool _cancelAndReschedule = false;

  // Step 2 Form State (Schedule rules)
  String _timezone = 'UTC';
  List<String> _allDurationOptions = ['15 min', '30 min', '45 min', '1 hr'];
  List<String> _selectedDurations = ['15 min', '30 min', '45 min', '1 hr'];
  String _activeSelectedDuration = '30 min';
  List<Map<String, String>> _availabilityWindows = [
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
  int _reminderValue = 1;
  String _reminderUnit = 'day(s) before';

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;
  }

  @override
  void dispose() {
    _internalNameController.dispose();
    _eventTitleController.dispose();
    _descriptionController.dispose();
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
                              Text(
                                'Edit Details',
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
                              Text(
                                'Live Preview',
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
                  const Spacer(),
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
                  ElevatedButton(
                    onPressed: () {
                      if (_currentStep < 3) {
                        setState(() {
                          _currentStep++;
                        });
                      } else {
                        // Submit & Save changes
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(widget.isEditMode
                                ? 'Changes saved successfully!'
                                : 'Scheduling page created successfully!'),
                          ),
                        );
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentStep == 3
                              ? (widget.isEditMode ? 'Save changes' : 'Create scheduling page')
                              : 'Next',
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_currentStep < 3) const SizedBox(width: 4),
                        if (_currentStep < 3)
                          const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white),
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
        DropdownButtonFormField<String>(
          value: _selectedOrganizer,
          decoration: _inputDecoration('Select organizer'),
          items: const [
            DropdownMenuItem(value: 'Admin User', child: Text('Admin User')),
            DropdownMenuItem(value: 'John Doe', child: Text('John Doe')),
          ],
          onChanged: (val) => setState(() => _selectedOrganizer = val),
        ),

        const SizedBox(height: 18),
        _buildLabelWithInfo('Contact'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _selectedContact,
          decoration: _inputDecoration('Select a contact'),
          items: const [
            DropdownMenuItem(value: 'Contact 1', child: Text('Select a contact')),
          ],
          onChanged: (val) => setState(() => _selectedContact = val),
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
                child: TextButton.icon(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  label: Text(
                    'Personalize',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF00897B),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF00897B)),
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
              activeColor: const Color(0xFF00897B),
              onChanged: (val) => setState(() => _cancelAndReschedule = val),
            ),
          ],
        ),

        const SizedBox(height: 18),
        _buildLabelWithInfo('Description'),
        const SizedBox(height: 6),
        TextField(
          controller: _descriptionController,
          maxLines: 4,
          decoration: _inputDecoration('Invite text or agenda...'),
          style: GoogleFonts.inter(fontSize: 13.5),
        ),
      ],
    );
  }

  /// Step 2 Form (Schedule rules) matching Image 1 & 2
  Widget _buildStep2Form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sub Tabs: Schedule rules | Booking form | Confirmation
        Row(
          children: [
            _buildSubTabItem(0, 'Schedule rules'),
            const SizedBox(width: 16),
            _buildSubTabItem(1, 'Booking form'),
            const SizedBox(width: 16),
            _buildSubTabItem(2, 'Confirmation'),
          ],
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
          value: _timezone,
          decoration: _inputDecoration('UTC'),
          items: const [
            DropdownMenuItem(value: 'UTC', child: Text('UTC')),
            DropdownMenuItem(value: 'Asia/Calcutta', child: Text('Asia/Calcutta')),
            DropdownMenuItem(value: 'EST', child: Text('EST')),
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

        ..._availabilityWindows.map((win) => _buildAvailabilityCard(win)).toList(),

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
                  value: win['day'],
                  decoration: _inputDecoration('Select day'),
                  items: const [
                    DropdownMenuItem(value: 'Monday', child: Text('Monday')),
                    DropdownMenuItem(value: 'Tuesday', child: Text('Tuesday')),
                    DropdownMenuItem(value: 'Wednesday', child: Text('Wednesday')),
                    DropdownMenuItem(value: 'Thursday', child: Text('Thursday')),
                    DropdownMenuItem(value: 'Friday', child: Text('Friday')),
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
                  value: win['from'],
                  decoration: _inputDecoration('From'),
                  items: const [
                    DropdownMenuItem(value: '9:00 AM', child: Text('9:00 AM')),
                    DropdownMenuItem(value: '10:00 AM', child: Text('10:00 AM')),
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
                  value: win['to'],
                  decoration: _inputDecoration('To'),
                  items: const [
                    DropdownMenuItem(value: '5:00 PM', child: Text('5:00 PM')),
                    DropdownMenuItem(value: '6:00 PM', child: Text('6:00 PM')),
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
                activeColor: const Color(0xFF00897B),
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
            Text(
              'Pre-meeting reminders',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add, size: 16, color: Color(0xFF00897B)),
              label: Text(
                'Add reminder',
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
                  controller: TextEditingController(text: '$_reminderValue'),
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
                  value: _reminderUnit,
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
                        value: 'day(s) before', child: Text('day(s) before')),
                    DropdownMenuItem(
                        value: 'hour(s) before', child: Text('hour(s) before')),
                    DropdownMenuItem(
                        value: 'minute(s) before', child: Text('minute(s) before')),
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

  /// Custom Duration Dialog (Image 3 style)
  void _showAddCustomDurationDialog() {
    final customController = TextEditingController();
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
                'Duration (minutes)',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: customController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'e.g. 20',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                      ),
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Min',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF475569),
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
                final text = customController.text.trim();
                final val = int.tryParse(text);
                if (val != null && val > 0) {
                  final formatted = val >= 60 && val % 60 == 0
                      ? '${val ~/ 60} hr'
                      : '$val min';
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

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
      fillColor: Colors.white,
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
