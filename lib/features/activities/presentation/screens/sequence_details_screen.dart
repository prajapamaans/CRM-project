import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/repositories/master_data_repository.dart';

class SequenceDetailsScreen extends StatefulWidget {
  final String? sequenceId;
  final String? initialName;
  final String ownerName;

  const SequenceDetailsScreen({
    super.key,
    this.sequenceId,
    this.initialName,
    this.ownerName = 'Admin User',
  });

  @override
  State<SequenceDetailsScreen> createState() => _SequenceDetailsScreenState();
}

class _SequenceDetailsScreenState extends State<SequenceDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _endEnrollmentDaysController;
  late TextEditingController _startDateController;
  late TextEditingController _endDateController;

  String _selectedTimezone = 'India (IST)';
  bool _unenrollOnReply = true;
  bool _unenrollOnMeetingBooked = true;

  int _automatedStepsCount = 0;
  int _manualStepsCount = 0;
  int _daysToCompleteCount = 0;

  String _selectedCompanyFilter = 'Company';
  String _selectedStatusFilter = 'Status';
  String _selectedEnrolledByFilter = 'Enrolled by';
  String _selectedEnrollmentDateFilter = 'Enrollment date';
  String _stepPerformanceToggle = 'Rates'; // Rates or Counts

  bool _isLoadingSequenceDetails = false;
  Map<String, dynamic>? _sequenceDetailsData;

  bool _isLoadingPerformance = false;
  Map<String, dynamic>? _performanceData;

  bool _isLoadingEnrollments = false;
  List<Map<String, dynamic>> _enrollmentsList = [];

  @override
  void initState() {
    super.initState();
    final bool isExisting = widget.sequenceId != null && widget.sequenceId!.isNotEmpty;
    _tabController = TabController(length: isExisting ? 5 : 3, vsync: this);
    _titleController = TextEditingController(
      text: widget.initialName ?? (isExisting ? 'Test' : 'Untitled Sequence'),
    );
    _descriptionController = TextEditingController();
    _endEnrollmentDaysController = TextEditingController();
    _startDateController = TextEditingController();
    _endDateController = TextEditingController();

    if (widget.sequenceId != null && widget.sequenceId!.isNotEmpty) {
      _fetchSequenceDetails();
      _fetchPerformanceAndEnrollments();
    }
  }

  Future<void> _fetchPerformanceAndEnrollments() async {
    final seqId = widget.sequenceId;
    if (seqId == null || seqId.isEmpty) return;

    setState(() {
      _isLoadingPerformance = true;
      _isLoadingEnrollments = true;
    });

    final repo = MasterDataRepositoryImpl();

    // Call http://192.168.250.2:8050/api/sequences/{id}/performance
    try {
      final perf = await repo.getSequencePerformance(seqId);
      if (mounted) {
        setState(() {
          _performanceData = perf;
          _isLoadingPerformance = false;
        });
      }
    } catch (e) {
      debugPrint('[Fetch Sequence Performance Error]: $e');
      if (mounted) setState(() => _isLoadingPerformance = false);
    }

    // Call http://192.168.250.2:8050/api/sequences/{id}/enrollments
    try {
      final enrolls = await repo.getSequenceEnrollments(seqId);
      if (mounted) {
        setState(() {
          _enrollmentsList = enrolls;
          _isLoadingEnrollments = false;
        });
      }
    } catch (e) {
      debugPrint('[Fetch Sequence Enrollments Error]: $e');
      if (mounted) setState(() => _isLoadingEnrollments = false);
    }
  }

  Future<void> _fetchSequenceDetails() async {
    setState(() {
      _isLoadingSequenceDetails = true;
    });
    try {
      final repo = MasterDataRepositoryImpl();
      final res = await repo.getSequences(page: 1, limit: 50);
      final List rawList = res['data'] is List ? res['data'] as List : [];
      final match = rawList.firstWhere(
        (e) => e['id']?.toString() == widget.sequenceId,
        orElse: () => null,
      );
      if (mounted && match != null) {
        setState(() {
          _sequenceDetailsData = Map<String, dynamic>.from(match);
          if (_sequenceDetailsData!['name'] != null) {
            _titleController.text = _sequenceDetailsData!['name'];
          }
          if (_sequenceDetailsData!['description'] != null) {
            _descriptionController.text = _sequenceDetailsData!['description'];
          }
          _automatedStepsCount = (_sequenceDetailsData!['automatedStepCount'] as num?)?.toInt() ?? 0;
          _manualStepsCount = (_sequenceDetailsData!['manualStepCount'] as num?)?.toInt() ?? 0;
          _isLoadingSequenceDetails = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('[Fetch Sequence Details Error]: $e');
    }
    if (mounted) {
      setState(() {
        _isLoadingSequenceDetails = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _endEnrollmentDaysController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF00897B),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final formatted =
          "${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}";
      setState(() {
        controller.text = formatted;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isExisting = widget.sequenceId != null && widget.sequenceId!.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          isExisting
              ? (_titleController.text.isEmpty ? 'Test' : _titleController.text)
              : 'Sequence Details',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SizedBox(
              width: 36,
              height: 36,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_none, color: Color(0xFF475569), size: 22),
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF97316),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
                onPressed: () {},
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(isExisting ? 74 : 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isExisting)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  _titleController.text.isEmpty
                                      ? 'Untitled Sequence'
                                      : _titleController.text,
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: _showEditTitleDialog,
                                  borderRadius: BorderRadius.circular(4),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4.0),
                                    child: Icon(
                                      Icons.edit_outlined,
                                      size: 16,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text.rich(
                              TextSpan(
                                text: 'Owner: ',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  color: const Color(0xFF64748B),
                                ),
                                children: [
                                  TextSpan(
                                    text: widget.ownerName,
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sequence saved successfully'),
                              backgroundColor: Color(0xFF00897B),
                            ),
                          );
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF66B2A0),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        child: Text(
                          'Save',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            text: 'Owner: ',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: const Color(0xFF64748B),
                            ),
                            children: [
                              TextSpan(
                                text: widget.ownerName,
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          backgroundColor: const Color(0xFFF1F5F9),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Actions',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF00897B),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.keyboard_arrow_down,
                              size: 16,
                              color: Color(0xFF00897B),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00897B),
                          elevation: 0,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                        ),
                        child: Text(
                          'Enroll',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelPadding: const EdgeInsets.only(left: 16, right: 14),
                  labelColor: isExisting ? const Color(0xFF00897B) : const Color(0xFF1E293B),
                  unselectedLabelColor: const Color(0xFF64748B),
                  labelStyle: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  indicatorColor: isExisting ? const Color(0xFF00897B) : const Color(0xFF1E293B),
                  indicatorWeight: 3,
                  tabs: isExisting
                      ? const [
                          Tab(text: 'Performance'),
                          Tab(text: 'Enrollments'),
                          Tab(text: 'Steps'),
                          Tab(text: 'Settings'),
                          Tab(text: 'Automate'),
                        ]
                      : const [
                          Tab(text: 'Steps'),
                          Tab(text: 'Settings'),
                          Tab(text: 'Automate'),
                        ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: isExisting
            ? [
                _buildPerformanceTab(),
                _buildEnrollmentsTab(),
                _buildStepsTab(),
                _buildSettingsTab(),
                _buildAutomateTab(),
              ]
            : [
                _buildStepsTab(),
                _buildSettingsTab(),
                _buildAutomateTab(),
              ],
      ),
    );
  }

  void _showEditTitleDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final tempController =
            TextEditingController(text: _titleController.text);
        return AlertDialog(
          title: Text(
            'Edit Sequence Name',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: tempController,
            decoration: const InputDecoration(
              hintText: 'Enter sequence name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00897B),
              ),
              onPressed: () {
                setState(() {
                  _titleController.text = tempController.text;
                });
                Navigator.pop(ctx);
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // ----------------------------------------------------
  // TAB: PERFORMANCE (Images 1, 2, 3)
  // ----------------------------------------------------
  Widget _buildPerformanceTab() {
    if (_isLoadingSequenceDetails || _isLoadingPerformance) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF00897B),
        ),
      );
    }

    final p = _performanceData ?? {};

    final int enrolled = (p['enrolled'] as num?)?.toInt() ?? 0;
    final int opened = (p['opened'] as num?)?.toInt() ?? 0;
    final int clicked = (p['clicked'] as num?)?.toInt() ?? 0;
    final int replied = (p['replied'] as num?)?.toInt() ?? 0;
    final int meetings = (p['meetings'] as num?)?.toInt() ?? 0;

    final num engagedRate = p['engagedRate'] as num? ?? 0;
    final num noEngagement = p['noEngagement'] as num? ?? 0;
    final num noResponse = p['noResponse'] as num? ?? 0;
    final int engagedCount = (p['engagedCount'] as num?)?.toInt() ?? 0;
    final int notEngagedCount = (p['notEngagedCount'] as num?)?.toInt() ?? 0;
    final int noResponseCount = (p['noResponseCount'] as num?)?.toInt() ?? 0;

    final num bounceRate = p['bounceRate'] as num? ?? 0;
    final num unsubscribeRate = p['unsubscribeRate'] as num? ?? 0;
    final num leadsReached = p['leadsReached'] as num? ?? 0;
    final int bouncedCount = (p['bouncedCount'] as num?)?.toInt() ?? 0;
    final int unsubscribedCount = (p['unsubscribedCount'] as num?)?.toInt() ?? 0;
    final int reached = (p['reached'] as num?)?.toInt() ?? (p['contactsEmailed'] as num?)?.toInt() ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Row: Company | Status | Enrolled by | Enrollment date | Live Data
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterDropdownButton(_selectedCompanyFilter, (val) {
                  setState(() => _selectedCompanyFilter = val);
                }, ['Company', 'All Companies']),
                const SizedBox(width: 8),
                _buildFilterDropdownButton(_selectedStatusFilter, (val) {
                  setState(() => _selectedStatusFilter = val);
                }, ['Status', 'Active', 'Completed', 'Unenrolled']),
                const SizedBox(width: 8),
                _buildFilterDropdownButton(_selectedEnrolledByFilter, (val) {
                  setState(() => _selectedEnrolledByFilter = val);
                }, ['Enrolled by', 'All users', 'Me']),
                const SizedBox(width: 8),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterDropdownButton(_selectedEnrollmentDateFilter, (val) {
                  setState(() => _selectedEnrollmentDateFilter = val);
                }, ['Enrollment date', 'All time', 'Today', 'This week', 'This month']),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F4F1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFB2DFDB)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00897B),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Live Data',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF00897B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 1. Insights Card with horizontal swipeable metrics
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Insights',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildInsightMetricBox('ENROLLED', '$enrolled', const Color(0xFF0E5C4E)),
                      const SizedBox(width: 10),
                      _buildInsightMetricBox('OPENED', '$opened', const Color(0xFF7C3AED)),
                      const SizedBox(width: 10),
                      _buildInsightMetricBox('CLICKED', '$clicked', const Color(0xFF059669)),
                      const SizedBox(width: 10),
                      _buildInsightMetricBox('REPLIED', '$replied', const Color(0xFFD97706)),
                      const SizedBox(width: 10),
                      _buildInsightMetricBox('MEETINGS', '$meetings', const Color(0xFF0284C7)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Engagement Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Engagement',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildRateStatTile(
                        label: 'ENGAGED RATE',
                        percentage: '${engagedRate.toInt()}%',
                        subtitle: '$engagedCount Contacts',
                        percentageColor: const Color(0xFF00897B),
                      ),
                    ),
                    Expanded(
                      child: _buildRateStatTile(
                        label: 'NO ENGAGEMENT',
                        percentage: '${noEngagement.toInt()}%',
                        subtitle: '$notEngagedCount Contacts',
                        percentageColor: const Color(0xFF1E293B),
                      ),
                    ),
                    Expanded(
                      child: _buildRateStatTile(
                        label: 'NO RESPONSE',
                        percentage: '${noResponse.toInt()}%',
                        subtitle: '$noResponseCount No Response',
                        percentageColor: const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. Lead quality Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lead quality',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildRateStatTile(
                        label: 'BOUNCE RATE',
                        percentage: '${bounceRate.toInt()}%',
                        subtitle: '$bouncedCount Bounced',
                        percentageColor: const Color(0xFF1E293B),
                      ),
                    ),
                    Expanded(
                      child: _buildRateStatTile(
                        label: 'UNSUB RATE',
                        percentage: '${unsubscribeRate.toInt()}%',
                        subtitle: '$unsubscribedCount Unsubscribes',
                        percentageColor: const Color(0xFF1E293B),
                      ),
                    ),
                    Expanded(
                      child: _buildRateStatTile(
                        label: 'LEADS REACHED',
                        percentage: '${leadsReached.toInt()}%',
                        subtitle: '$reached Contacts',
                        percentageColor: const Color(0xFF00897B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 4. Step performance Card with Rates/Counts Toggle
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Step performance',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => setState(() => _stepPerformanceToggle = 'Rates'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _stepPerformanceToggle == 'Rates'
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: _stepPerformanceToggle == 'Rates'
                                      ? [
                                          const BoxShadow(
                                            color: Color(0x0A000000),
                                            blurRadius: 2,
                                          )
                                        ]
                                      : [],
                                ),
                                child: Text(
                                  'Rates',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _stepPerformanceToggle == 'Rates'
                                        ? const Color(0xFF00897B)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _stepPerformanceToggle = 'Counts'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _stepPerformanceToggle == 'Counts'
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: _stepPerformanceToggle == 'Counts'
                                      ? [
                                          const BoxShadow(
                                            color: Color(0x0A000000),
                                            blurRadius: 2,
                                          )
                                        ]
                                      : [],
                                ),
                                child: Text(
                                  'Counts',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _stepPerformanceToggle == 'Counts'
                                        ? const Color(0xFF00897B)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                
                // Section 1: Automated outreach accordion
                ExpansionTile(
                  initiallyExpanded: true,
                  title: Text(
                    'Automated outreach',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE6F4F1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.send_outlined,
                                    color: Color(0xFF00897B),
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Step 1 — Automated email',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            'test email',
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF00897B),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.open_in_new,
                                            size: 13,
                                            color: Color(0xFF00897B),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Metrics 3x2 grid (SENT, OPENED, CLICKED, REPLIED, MEETINGS, PERSONALIZED)
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: _buildStepGridItem('SENT', '3')),
                                      Expanded(child: _buildStepGridItem('OPENED', '0%')),
                                      Expanded(child: _buildStepGridItem('CLICKED', '0%')),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(child: _buildStepGridItem('REPLIED', '0%')),
                                      Expanded(child: _buildStepGridItem('MEETINGS', '100%')),
                                      Expanded(child: _buildStepGridItem('PERSONALIZED', 'No')),
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

                // Section 2: Rep-led outreach accordion
                ExpansionTile(
                  initiallyExpanded: true,
                  title: Text(
                    'Rep-led outreach',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE6F4F1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.phone_in_talk,
                                    color: Color(0xFF00897B),
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Step 2 — Phone Call',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                      Text(
                                        'Call contact to follow up',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF00897B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Metrics grid (CREATED, OPENED, CLICKED, REPLIED, MEETINGS, COMPLETED, PERSONALIZED)
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: _buildStepGridItem('CREATED', '0')),
                                      Expanded(child: _buildStepGridItem('OPENED', '—')),
                                      Expanded(child: _buildStepGridItem('CLICKED', '—')),
                                      Expanded(child: _buildStepGridItem('REPLIED', '—')),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(child: _buildStepGridItem('MEETINGS', '—')),
                                      Expanded(child: _buildStepGridItem('COMPLETED', '—')),
                                      Expanded(child: _buildStepGridItem('PERSONALIZED', 'No')),
                                      const Expanded(child: SizedBox()),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightMetricBox(String label, String value, Color borderAccentColor) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                color: borderAccentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF475569),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRateStatTile({
    required String label,
    required String percentage,
    required String subtitle,
    required Color percentageColor,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF475569),
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.info_outline,
              size: 12,
              color: Color(0xFF94A3B8),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          percentage,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: percentageColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildStepGridItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF64748B),
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterDropdownButton(
    String label,
    ValueChanged<String> onChanged,
    List<String> items,
  ) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(label) ? label : items.first,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 16,
            color: Color(0xFF64748B),
          ),
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF00897B),
          ),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // TAB: ENROLLMENTS
  // ----------------------------------------------------
  Widget _buildEnrollmentsTab() {
    if (_isLoadingEnrollments) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF00897B),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Enrollments (${_enrollmentsList.length})',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),
          if (_enrollmentsList.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    const Icon(
                      Icons.group_outlined,
                      size: 48,
                      color: Color(0xFFCBD5E1),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No enrollments yet',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Enroll contacts to see performance data here',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _enrollmentsList.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = _enrollmentsList[index];
                final String contactName = item['contactName'] ?? 'Unknown Contact';
                final String contactEmail = item['contactEmail'] ?? '';
                final String status = (item['status'] ?? 'active').toString().toUpperCase();
                final String enrolledBy = item['enrolledByName'] ?? 'Admin User';
                final String stepType = (item['currentStepType'] ?? item['latestStepType'] ?? 'automated_email')
                    .toString()
                    .replaceAll('_', ' ');

                final int opens = (item['opensCount'] as num?)?.toInt() ?? 0;
                final int clicks = (item['clicksCount'] as num?)?.toInt() ?? 0;
                final int replies = (item['repliesCount'] as num?)?.toInt() ?? 0;

                Color statusColor = const Color(0xFFD97706); // paused/orange
                if (status == 'ACTIVE') statusColor = const Color(0xFF059669);
                if (status == 'COMPLETED') statusColor = const Color(0xFF0284C7);

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  contactName,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                                if (contactEmail.isNotEmpty)
                                  Text(
                                    contactEmail,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Enrolled by: $enrolledBy • Step: $stepType',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Opens: $opens',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Clicks: $clicks',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Replies: $replies',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
  Widget _buildStepsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Stat Cards Grid
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'AUTOMATED STEPS',
                  '$_automatedStepsCount',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'DAYS TO COMPLETE',
                  '$_daysToCompleteCount',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'MANUAL STEPS',
                  '$_manualStepsCount',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'UNENROLL CRITERIA',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF475569),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'On Reply & Meeting',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF00897B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ACTIVE DATE RANGE card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: Color(0xFF00897B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ACTIVE DATE RANGE',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF475569),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _startDateController.text.isNotEmpty &&
                          _endDateController.text.isNotEmpty
                      ? '${_startDateController.text} to ${_endDateController.text}'
                      : 'Always Active',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // AUTOMATED OUTRACH Banner & Box (Image 1)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0E5C4E), // Dark Teal Banner
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(7),
                      topRight: Radius.circular(7),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AUTOMATED OUTREACH',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Leads will receive automated steps until they engage',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFFE2E8F0),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Configure your initial step',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'All contacts will receive this first step',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _automatedStepsCount++;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Automated email step configured'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE6F4F1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.send_outlined,
                                    color: Color(0xFF00897B),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Automated email',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF1E293B),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Automatically send an email for me',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: Color(0xFF94A3B8),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Divider pill: "On Email Reply"
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEBF5FF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.email_outlined,
                  size: 14,
                  color: Color(0xFF2563EB),
                ),
                const SizedBox(width: 6),
                Text(
                  'On Email Reply',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // REP-LED OUTREACH Banner & Box (Image 2)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF5350), // Red Banner
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(7),
                      topRight: Radius.circular(7),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'REP-LED OUTREACH',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'As soon as a lead engages, the sequence will start to queue up manual steps',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Create dynamic follow-up steps',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Configure a series of task steps that starts as soon as a contact engages with your automated outreach.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Call task
                        _buildTaskOptionTile(
                          icon: Icons.phone_in_talk,
                          iconBgColor: const Color(0xFFD97706),
                          title: 'Call task',
                          subtitle: 'Get a task reminder to make a call',
                          onTap: () {
                            setState(() {
                              _manualStepsCount++;
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        // General task
                        _buildTaskOptionTile(
                          icon: Icons.assignment_turned_in_outlined,
                          iconBgColor: const Color(0xFF059669),
                          title: 'General task',
                          subtitle: 'Set a general task reminder',
                          onTap: () {
                            setState(() {
                              _manualStepsCount++;
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        // LinkedIn Task
                        _buildTaskOptionTile(
                          icon: Icons.work_outline,
                          iconBgColor: const Color(0xFF0284C7),
                          title: 'LinkedIn Task',
                          subtitle: 'Get a LinkedIn task reminder',
                          onTap: () {
                            setState(() {
                              _manualStepsCount++;
                            });
                          },
                        ),
                      ],
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

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF475569),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskOptionTile({
    required IconData icon,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF00897B)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: const Color(0xFF64748B),
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

  // ----------------------------------------------------
  // TAB 2: SETTINGS (Images 4 & 5)
  // ----------------------------------------------------
  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // General Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'General',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Description',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Describe what this sequence does...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF94A3B8),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                  style: GoogleFonts.inter(fontSize: 13),
                ),
                const SizedBox(height: 16),
                Text(
                  'Timezone',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedTimezone,
                      isExpanded: true,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF1E293B),
                      ),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedTimezone = val;
                          });
                        }
                      },
                      items: [
                        'India (IST)',
                        'US Eastern (EST)',
                        'US Pacific (PST)',
                        'London (GMT)',
                        'Tokyo (JST)',
                      ].map((tz) {
                        return DropdownMenuItem(
                          value: tz,
                          child: Text(tz),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'End Enrollment Days',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _endEnrollmentDaysController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText:
                        'e.g. 5 (days automated emails will send, 0 = no limit)',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF94A3B8),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                  style: GoogleFonts.inter(fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  'Number of business days automated emails will loop (every exact 24 hours, Mon-Fri only) before completing. Set to 0 or leave empty for no limit.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Sequence Active Date Range Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 16,
                      color: Color(0xFF00897B),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Sequence Active Date Range',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Start Date',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () => _selectDate(_startDateController),
                            child: IgnorePointer(
                              child: TextField(
                                controller: _startDateController,
                                decoration: InputDecoration(
                                  hintText: 'dd-mm-yyyy',
                                  hintStyle: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                  suffixIcon: const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 16,
                                    color: Color(0xFF64748B),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        const BorderSide(color: Color(0xFFCBD5E1)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        const BorderSide(color: Color(0xFFCBD5E1)),
                                  ),
                                ),
                                style: GoogleFonts.inter(fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'End Date',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () => _selectDate(_endDateController),
                            child: IgnorePointer(
                              child: TextField(
                                controller: _endDateController,
                                decoration: InputDecoration(
                                  hintText: 'dd-mm-yyyy',
                                  hintStyle: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                  suffixIcon: const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 16,
                                    color: Color(0xFF64748B),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        const BorderSide(color: Color(0xFFCBD5E1)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        const BorderSide(color: Color(0xFFCBD5E1)),
                                  ),
                                ),
                                style: GoogleFonts.inter(fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'The sequence will only execute automated steps within this date range (inclusive). Automation will stop after the end date. Leave empty for no date restrictions.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Unenroll Criteria Card (Image 5)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unenroll Criteria',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Unenroll on email reply',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Transition to manual phase when contact replies',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _unenrollOnReply,
                      activeColor: const Color(0xFF00897B),
                      onChanged: (val) {
                        setState(() {
                          _unenrollOnReply = val;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Unenroll on meeting booked',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Stop sequence when contact books a meeting',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _unenrollOnMeetingBooked,
                      activeColor: const Color(0xFF00897B),
                      onChanged: (val) {
                        setState(() {
                          _unenrollOnMeetingBooked = val;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // TAB 3: AUTOMATE (Image 3)
  // ----------------------------------------------------
  Widget _buildAutomateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active Enrollments Header
          Text(
            'Active Enrollments',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                const Icon(
                  Icons.group_outlined,
                  size: 48,
                  color: Color(0xFFCBD5E1),
                ),
                const SizedBox(height: 12),
                Text(
                  'No enrollments yet',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enroll contacts to start the sequence',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // Sequence Activity Log Header
          Text(
            'Sequence Activity Log',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                const Icon(
                  Icons.show_chart_rounded,
                  size: 48,
                  color: Color(0xFFCBD5E1),
                ),
                const SizedBox(height: 12),
                Text(
                  'No activity yet',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sequence activity will appear here',
                  style: GoogleFonts.inter(
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
  }
}
