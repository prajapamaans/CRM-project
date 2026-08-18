import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:crmproject/core/widgets/app_refresh_indicator.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/models/bingo_summary_model.dart';
import '../../../../core/repositories/master_data_repository.dart';
import '../../../../core/widgets/add_association_modal.dart';
import '../../../../core/widgets/bottom_nav_bar.dart';
import '../../../activities/presentation/widgets/create_task_modal.dart';
import '../../../activities/presentation/widgets/create_note_modal.dart';
import '../../../activities/presentation/widgets/create_email_modal.dart';
import '../../../activities/presentation/widgets/log_call_modal.dart';
import '../../../activities/presentation/widgets/log_meeting_modal.dart';
import '../../data/models/deal_model.dart';
import '../../data/repositories/deal_repository.dart';
import '../providers/deal_provider.dart';
import '../../../navigation/presentation/providers/navigation_provider.dart';
import 'package:crmproject/features/contacts/presentation/screens/contact_details_screen.dart';
import 'package:crmproject/features/contacts/data/models/contact_model.dart';
import 'package:crmproject/features/companies/presentation/screens/company_details_screen.dart';
import 'package:crmproject/features/companies/data/models/company_model.dart';

class DealDetailsScreen extends StatefulWidget {
  final DealModel? deal;

  const DealDetailsScreen({
    super.key,
    this.deal,
  });

  @override
  State<DealDetailsScreen> createState() => _DealDetailsScreenState();
}

class _DealDetailsScreenState extends State<DealDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  late TextEditingController _nameController;
  late TextEditingController _pipelineController;
  late TextEditingController _amountController;
  late TextEditingController _closeDateController;
  late TextEditingController _probabilityController;
  late TextEditingController _companyController;
  late TextEditingController _ownerController;
  late TextEditingController _searchActivitiesController;
  late TextEditingController _startDateController;
  late TextEditingController _endDateController;

  String _dealStage = 'Prospect';
  String? _editingFieldKey;

  // Associated records lists
  final List<Map<String, dynamic>> _associatedCompanies = [];
  final List<Map<String, dynamic>> _associatedContacts = [];
  final List<Map<String, dynamic>> _associatedDeals = [];
  final List<Map<String, dynamic>> _associatedTasks = [];

  // Activities Tab State
  int _selectedActivitySubTab = 0;
  String _selectedDateFilter = 'All time';
  String _selectedAssigneeFilter = 'Activity assigned to';
  bool _isActivitiesCollapsed = false;
  List<Map<String, dynamic>> _activities = [];
  bool _isLoadingActivities = false;

  // AI Summary State
  BingoSummaryResponse? _bingoSummaryResponse;
  String? _aiSummary;
  bool _isLoadingAiSummary = false;

  Future<void> _fetchAiSummary(String recordType, String recordId) async {
    setState(() {
      _isLoadingAiSummary = true;
    });

    try {
      final apiService = ApiService();
      final bingoResponse = await apiService.getBingoSummary(
        recordType: recordType,
        recordId: recordId,
      );

      if (mounted) {
        setState(() {
          _bingoSummaryResponse = bingoResponse;
          if (bingoResponse.data.blocked) {
            _aiSummary = 'AI summary is blocked for this record.';
          } else if (bingoResponse.data.summary.isNotEmpty) {
            _aiSummary = bingoResponse.data.summary;
          } else {
            _aiSummary = 'No summary available for this record.';
          }
        });
      }
    } catch (e) {
      debugPrint('[DealDetailsScreen _fetchAiSummary ERROR]: $e');
      if (mounted) {
        setState(() {
          _aiSummary = 'Failed to generate AI summary. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAiSummary = false;
        });
      }
    }
  }

  final List<String> _activitySubTabs = const [
    'All activities',
    'Notes',
    'Emails',
    'Calls',
    'Tasks',
    'Meetings',
  ];

  final List<String> _dateFilterOptions = const [
    'Today',
    'Yesterday',
    'This week',
    'Last week',
    'This month',
    'Last month',
    'This year',
    'All time',
  ];

  final List<String> _dealStages = const [
    'Prospect',
    'Appointment Scheduled',
    'Qualified to Buy',
    'Presentation Scheduled',
    'Decision Maker Bought-In',
    'Contract Sent',
    'Closed Won',
    'Closed Lost',
  ];

  List<Map<String, dynamic>> _userList = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    final d = widget.deal;
    _nameController = TextEditingController(text: d?.title ?? '');
    _pipelineController = TextEditingController(text: 'default');
    _amountController = TextEditingController(
      text: d != null && d.amount > 0 ? d.amount.toStringAsFixed(0) : '',
    );
    _closeDateController = TextEditingController(
      text: d?.date ?? '',
    );
    _probabilityController = TextEditingController(
      text: d != null ? '${d.probability}%' : '',
    );
    _companyController = TextEditingController(text: d?.company ?? '');
    _ownerController = TextEditingController(text: d?.owner ?? 'Admin User');

    _searchActivitiesController = TextEditingController();
    _startDateController = TextEditingController();
    _endDateController = TextEditingController();

    _dealStage = d?.stage.isNotEmpty == true ? d!.stage : 'Prospect';

    _fetchActivities();
    _fetchUsers();
    _fetchDealDetails();
  }

  bool _isLoadingDetails = false;

  Future<void> _fetchDealDetails() async {
    final dealId = widget.deal?.id;
    if (dealId == null || dealId.isEmpty) return;

    setState(() {
      _isLoadingDetails = true;
    });

    try {
      final repo = DealRepositoryImpl();
      final dealModel = await repo.getDealById(dealId);

      if (mounted) {
        setState(() {
          if (dealModel.title.isNotEmpty) _nameController.text = dealModel.title;
          if (dealModel.amount > 0) _amountController.text = dealModel.amount.toStringAsFixed(0);
          if (dealModel.stage.isNotEmpty) _dealStage = dealModel.stage;
          if (dealModel.companyName != null) _companyController.text = dealModel.companyName!;
          if (dealModel.ownerName != null) _ownerController.text = dealModel.ownerName!;

          // Populate associations returned from GET /api/deals/:id
          _associatedCompanies.clear();
          if (dealModel.associatedCompanies != null) {
            for (final comp in dealModel.associatedCompanies!) {
              _associatedCompanies.add({
                'id': comp.id,
                'name': comp.name,
                'subtext': comp.domain ?? '',
                'domain': comp.domain ?? '',
                'isPrimary': comp.isPrimary,
              });
            }
          }

          _associatedContacts.clear();
          if (dealModel.associatedContacts != null) {
            for (final cont in dealModel.associatedContacts!) {
              _associatedContacts.add({
                'id': cont.id,
                'name': cont.name,
                'subtext': cont.email.isNotEmpty ? cont.email : '-',
                'email': cont.email,
                'msp': cont.msp,
                'isPrimary': cont.isPrimary,
              });
            }
          }

          if (dealModel.associatedDeals != null && dealModel.associatedDeals!.isNotEmpty) {
            _associatedDeals.clear();
            _associatedDeals.addAll(dealModel.associatedDeals!);
          }
        });
      }
    } catch (e) {
      debugPrint('[DealDetailsScreen _fetchDealDetails ERROR]: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDetails = false;
        });
      }
    }
  }

  Future<void> _fetchUsers() async {
    try {
      final repo = MasterDataRepositoryImpl();
      final users = await repo.getReportsUsers(limit: 200);
      if (mounted) {
        setState(() {
          _userList = users;
        });
      }
    } catch (e) {
      debugPrint('[DealDetailsScreen _fetchUsers ERROR]: $e');
    }
  }

  List<Map<String, dynamic>> get _filteredActivities {
    final search = _searchActivitiesController.text.trim().toLowerCase();

    return _activities.where((act) {
      final type = (act['type'] ?? act['activityType'] ?? '').toString().toUpperCase();
      final fieldKey = (act['fieldKey'] ?? act['field_key'] ?? '').toString().toLowerCase();

      // 1. Sub-tab filter
      if (_selectedActivitySubTab == 1) {
        // Notes
        if (!type.contains('NOTE') && !fieldKey.contains('note')) return false;
      } else if (_selectedActivitySubTab == 2) {
        // Emails
        if (!type.contains('EMAIL') && !fieldKey.contains('email')) return false;
      } else if (_selectedActivitySubTab == 3) {
        // Calls
        if (!type.contains('CALL') && !fieldKey.contains('call')) return false;
      } else if (_selectedActivitySubTab == 4) {
        // Tasks
        if (!type.contains('TASK') && !fieldKey.contains('task')) return false;
      } else if (_selectedActivitySubTab == 5) {
        // Meetings
        if (!type.contains('MEETING') && !fieldKey.contains('meeting')) return false;
      }

      // 2. Search query filter
      if (search.isNotEmpty) {
        final title = (act['title'] ?? act['notes'] ?? act['type'] ?? '').toString().toLowerCase();
        final notes = (act['notes'] ?? '').toString().toLowerCase();
        final ownerName = (act['creatorName'] ?? act['ownerName'] ?? act['assignedTo'] ?? '').toString().toLowerCase();
        if (!title.contains(search) && !notes.contains(search) && !ownerName.contains(search) && !type.toLowerCase().contains(search)) {
          return false;
        }
      }

      // 3. Assignee Filter
      if (_selectedAssigneeFilter != 'Activity assigned to') {
        final ownerName = (act['creatorName'] ?? act['ownerName'] ?? act['assignedTo'] ?? '').toString();
        if (_selectedAssigneeFilter == 'Unassigned') {
          if (ownerName.isNotEmpty && ownerName != 'Unassigned') return false;
        } else {
          if (!ownerName.toLowerCase().contains(_selectedAssigneeFilter.toLowerCase())) {
            return false;
          }
        }
      }

      // 4. Date Filter
      final rawDateStr = act['createdAt'] ?? act['scheduledAt'] ?? act['date'] ?? '';
      if (rawDateStr.toString().isNotEmpty) {
        DateTime? dt;
        try {
          dt = DateTime.parse(rawDateStr.toString()).toLocal();
        } catch (_) {}

        if (dt != null) {
          final now = DateTime.now();
          final todayStart = DateTime(now.year, now.month, now.day);
          final yesterdayStart = todayStart.subtract(const Duration(days: 1));

          if (_selectedDateFilter == 'Today') {
            if (dt.isBefore(todayStart)) return false;
          } else if (_selectedDateFilter == 'Yesterday') {
            if (dt.isBefore(yesterdayStart) || dt.isAfter(todayStart)) return false;
          } else if (_selectedDateFilter == 'This week') {
            final startOfWeek = todayStart.subtract(Duration(days: now.weekday - 1));
            if (dt.isBefore(startOfWeek)) return false;
          } else if (_selectedDateFilter == 'Last week') {
            final startOfThisWeek = todayStart.subtract(Duration(days: now.weekday - 1));
            final startOfLastWeek = startOfThisWeek.subtract(const Duration(days: 7));
            if (dt.isBefore(startOfLastWeek) || dt.isAfter(startOfThisWeek)) return false;
          } else if (_selectedDateFilter == 'This month') {
            final startOfMonth = DateTime(now.year, now.month, 1);
            if (dt.isBefore(startOfMonth)) return false;
          } else if (_selectedDateFilter == 'Last month') {
            final startOfThisMonth = DateTime(now.year, now.month, 1);
            final startOfLastMonth = DateTime(now.year, now.month - 1, 1);
            if (dt.isBefore(startOfLastMonth) || dt.isAfter(startOfThisMonth)) return false;
          } else if (_selectedDateFilter == 'This year') {
            final startOfYear = DateTime(now.year, 1, 1);
            if (dt.isBefore(startOfYear)) return false;
          }
        }
      }

      return true;
    }).toList();
  }

  Future<void> _fetchActivities() async {
    final dealId = widget.deal?.id;
    if (dealId == null || dealId.isEmpty) return;

    setState(() {
      _isLoadingActivities = true;
    });

    try {
      final repo = MasterDataRepositoryImpl();
      final results = await Future.wait([
        repo.getActivities(dealId: dealId, limit: 100),
        repo.getUnifiedTimeline(dealId: dealId, limit: 100),
      ]);
      final activitiesList = results[0];
      final timelineList = results[1];

      final combined = <Map<String, dynamic>>[...activitiesList, ...timelineList];
      final seenIds = <String>{};
      final uniqueList = <Map<String, dynamic>>[];
      for (final item in combined) {
        final id = item['id']?.toString();
        if (id != null && id.isNotEmpty) {
          if (!seenIds.contains(id)) {
            seenIds.add(id);
            uniqueList.add(item);
          }
        } else {
          uniqueList.add(item);
        }
      }

      uniqueList.sort((a, b) {
        final dateStrA = a['activityDate'] ?? a['createdAt'] ?? a['scheduledAt'] ?? a['date'] ?? '';
        final dateStrB = b['activityDate'] ?? b['createdAt'] ?? b['scheduledAt'] ?? b['date'] ?? '';
        final dtA = DateTime.tryParse(dateStrA.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dtB = DateTime.tryParse(dateStrB.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dtB.compareTo(dtA);
      });

      if (mounted) {
        setState(() {
          _activities = uniqueList;
        });
      }
    } catch (e) {
      debugPrint('[DealDetailsScreen _fetchActivities ERROR]: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingActivities = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _pipelineController.dispose();
    _amountController.dispose();
    _closeDateController.dispose();
    _probabilityController.dispose();
    _companyController.dispose();
    _ownerController.dispose();
    _searchActivitiesController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  String get _displayName {
    final title = _nameController.text.trim();
    return title.isNotEmpty ? title : 'Deal Details';
  }

  String get _initialLetter {
    final title = _displayName;
    if (title.isNotEmpty) {
      return title[0].toUpperCase();
    }
    return 'D';
  }

  String get _formattedCreateDate {
    return '08/04/2026\n2:12 PM\nGMT...';
  }

  String get _formattedLastActivityDate {
    return '08/04/2026\n2:12 PM\nGMT...';
  }

  Future<void> _saveDealChanges() async {
    final dealId = widget.deal?.id ?? context.read<DealProvider>().selectedDeal?.id;
    final amountNum = double.tryParse(_amountController.text.trim());
    final titleStr = _nameController.text.trim();
    final pipelineStr = _pipelineController.text.trim();
    final closeDateStr = _closeDateController.text.trim();
    final companyStr = _companyController.text.trim();
    final ownerStr = _ownerController.text.trim();

    final payload = <String, dynamic>{
      'title': titleStr.isNotEmpty ? titleStr : 'Deal',
      'name': titleStr.isNotEmpty ? titleStr : 'Deal',
      'dealName': titleStr,
      'deal_name': titleStr,
      'pipeline': pipelineStr,
      'stage': _dealStage,
      'stage_name': _dealStage,
      'status': _dealStage,
      if (amountNum != null) ...{
        'amount': amountNum,
        'value': amountNum,
      },
      if (closeDateStr.isNotEmpty) ...{
        'closeDate': closeDateStr,
        'close_date': closeDateStr,
        'expectedCloseDate': closeDateStr,
        'expected_close_date': closeDateStr,
      },
      if (companyStr.isNotEmpty) ...{
        'company': companyStr,
        'companyName': companyStr,
      },
      if (ownerStr.isNotEmpty) ...{
        'owner': ownerStr,
        'ownerName': ownerStr,
      },
    };

    bool success = true;
    if (dealId != null && dealId.isNotEmpty) {
      success = await context.read<DealProvider>().updateDeal(dealId, payload);
    }

    if (mounted) {
      final updatedDeal = context.read<DealProvider>().selectedDeal;
      if (updatedDeal != null) {
        if (updatedDeal.title.isNotEmpty) _nameController.text = updatedDeal.title;
        if (updatedDeal.amount > 0) _amountController.text = updatedDeal.amount.toStringAsFixed(0);
        if (updatedDeal.stage.isNotEmpty) _dealStage = updatedDeal.stage;
        if (updatedDeal.date.isNotEmpty) _closeDateController.text = updatedDeal.date;
        if (updatedDeal.company.isNotEmpty) _companyController.text = updatedDeal.company;
        if (updatedDeal.owner.isNotEmpty) _ownerController.text = updatedDeal.owner;
      }
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Deal updated successfully' : 'Failed to update deal',
          ),
          backgroundColor: success ? const Color(0xFF00A884) : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: Color(0xFF334155),
                  size: 20,
                ),
              ),
            ),
          ),
        ),
        title: Text(
          _displayName,
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications_none_rounded,
                  color: Color(0xFF1E293B),
                  size: 24,
                ),
                Positioned(
                  right: -1,
                  top: -1,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF5252),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Top 2 Action Cards Row (Task & Note)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _openActivityModal('Task'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE6F4F1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.task_alt_outlined,
                              color: Color(0xFF00A884),
                              size: 20,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Task',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _openActivityModal('Note'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE6F4F1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.more_horiz_rounded,
                              color: Color(0xFF00A884),
                              size: 20,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Note',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
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

          // Tab Bar Navigation
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF00A884),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF00A884),
              indicatorWeight: 2.5,
              labelStyle: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
              tabs: [
                const Tab(text: 'Overview'),
                const Tab(text: 'Activities'),
                Tab(
                  text:
                      'Associations (${_associatedCompanies.length + _associatedContacts.length})',
                ),
              ],
            ),
          ),

          // Tab Bar Views
          Expanded(
            child: AppRefreshIndicator(
              onRefresh: () async {
                await _fetchDealDetails();
                await _fetchActivities();
              },
              child: Stack(
                children: [
                  TabBarView(
                    controller: _tabController,
                    children: [
                      // 1. Overview Tab
                      _buildOverviewTab(),

                      // 2. Activities Tab
                      _buildActivitiesTab(),

                      // 3. Associations Tab
                      _buildAssociationsTab(),
                    ],
                  ),
                  if (_isLoadingDetails)
                    Container(
                      color: Colors.white.withValues(alpha: 0.6),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF00A884),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: 3, // Deals Tab
        onTap: (index) {
          context.read<NavigationProvider>().selectScreen(index);
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
      ),
    );
  }

  // ==========================================
  // TAB 1: OVERVIEW TAB
  // ==========================================
  Widget _buildOverviewTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        // 1. Profile Summary Card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F4F1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFF64D2B7), width: 1),
                        ),
                        child: Center(
                          child: Text(
                            _initialLetter,
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF00A884),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -3,
                        bottom: -3,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _editingFieldKey = 'title';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFF00A884),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit_rounded,
                              size: 11,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayName,
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '\$${_amountController.text.trim()}',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF00A884),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE6F4F1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _dealStage,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0F766E),
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
              const SizedBox(height: 18),

              // Action Icons Bar (Note, Email, Call, Task, Meeting)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildActionButton(Icons.description_outlined, 'Note'),
                  _buildActionButton(Icons.mail_outline_rounded, 'Email'),
                  _buildActionButton(Icons.phone_outlined, 'Call'),
                  _buildActionButton(Icons.task_alt_rounded, 'Task'),
                  _buildActionButton(Icons.videocam_outlined, 'Meeting'),
                ],
              ),
            ],
          ),
        ),

        // 2. Deal Stage Tracker Card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Deal stage tracker',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    'Deal stage: ',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (val) {
                      setState(() {
                        _dealStage = val;
                      });
                      _saveDealChanges();
                    },
                    offset: const Offset(0, 30),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    itemBuilder: (context) => _dealStages
                        .map((s) => PopupMenuItem(
                              value: s,
                              child: Text(
                                s,
                                style: GoogleFonts.poppins(fontSize: 13),
                              ),
                            ))
                        .toList(),
                    child: Row(
                      children: [
                        Text(
                          _dealStage,
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
              const SizedBox(height: 12),

              // Progress Bar (8 Boxes Row)
              Row(
                children: List.generate(8, (index) {
                  final int currentStageIndex = _dealStages.indexWhere(
                    (s) => s.trim().toLowerCase() == _dealStage.trim().toLowerCase(),
                  );
                  final int activeIndex = currentStageIndex >= 0 ? currentStageIndex : 0;
                  final bool isCompleted = index <= activeIndex;
                  return Expanded(
                    child: InkWell(
                      onTap: () {
                        if (index < _dealStages.length) {
                          setState(() {
                            _dealStage = _dealStages[index];
                          });
                          _saveDealChanges();
                        }
                      },
                      child: Container(
                        height: 24,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? const Color(0xFF00A884)
                              : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: isCompleted
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 16,
                              )
                            : null,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              Text(
                'Probability',
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _probabilityController.text.trim().isNotEmpty
                    ? _probabilityController.text.trim()
                    : '20%',
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),

        // 3. Data Highlights Card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Data highlights',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CREATE DATE',
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF64748B),
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formattedCreateDate,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            height: 1.3,
                            color: const Color(0xFF334155),
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
                          'DEAL STAGE',
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF64748B),
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _dealStage,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(0xFF334155),
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
                          'LAST ACTIVITY DATE',
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF64748B),
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formattedLastActivityDate,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            height: 1.3,
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 4. About this deal Section
        Container(
          margin: const EdgeInsets.fromLTRB(16, 6, 16, 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'About this deal',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 16),
              _buildAboutField('DEAL OWNER', 'owner', _ownerController),
              _buildAboutField('LAST CONTACTED', 'lastContacted', TextEditingController(text: '--')),
              _buildAboutField('DEAL TYPE', 'dealType', TextEditingController(text: '--')),
              _buildAboutField('PRIORITY', 'priority', TextEditingController(text: 'Medium')),
              _buildAboutField('RECORD SOURCE', 'recordSource', TextEditingController(text: '--')),
              _buildAboutField('FORECAST PROBABILITY', 'probability', _probabilityController),
              _buildAboutField('COMMENTS', 'comments', TextEditingController(text: '--')),
              _buildAboutField('APIDEL REVENUE', 'apidelRevenue', TextEditingController(text: '--')),
              _buildAboutField('CLIENT TYPE', 'clientType', TextEditingController(text: '--')),
              _buildAboutField('DEAL NAME', 'title', _nameController),
              _buildAboutField('AMOUNT', 'amount', _amountController),
              _buildAboutField(
                'DEAL STAGE',
                'stage',
                TextEditingController(text: _dealStage),
                options: _dealStages,
                onSelectedOption: (selected) {
                  setState(() {
                    _dealStage = selected;
                  });
                  _saveDealChanges();
                },
              ),
              _buildAboutField('CLOSE DATE', 'closeDate', _closeDateController),
              _buildAboutField('COMPANY', 'company', _companyController),
              _buildAboutField('PIPELINE', 'pipeline', _pipelineController),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 2: ACTIVITIES TAB
  // ==========================================
  Widget _buildActivitiesTab() {
    return ListView(
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
              // 1. Horizontal Sub-Tabs Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(_activitySubTabs.length, (index) {
                    final isSelected = _selectedActivitySubTab == index;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedActivitySubTab = index;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: isSelected
                                  ? const Color(0xFF1E293B)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Text(
                          _activitySubTabs[index],
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w600,
                            color: isSelected
                                ? const Color(0xFF1E293B)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Search activities Bar
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _searchActivitiesController,
                  onChanged: (_) {
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    hintText: 'Search activities',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF94A3B8),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF94A3B8),
                      size: 20,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 3. Filter Controls Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          InkWell(
                            onTap: _showDateFilterDialog,
                            child: Row(
                              children: [
                                Text(
                                  '$_selectedDateFilter ',
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
                          const SizedBox(width: 14),

                          PopupMenuButton<String>(
                            onSelected: (val) {
                              setState(() {
                                _selectedAssigneeFilter = val;
                              });
                            },
                            itemBuilder: (context) {
                              final options = <String>[
                                'Activity assigned to',
                                'Admin User',
                                'Unassigned',
                              ];
                              for (final u in _userList) {
                                final name = '${u['firstName'] ?? u['first_name'] ?? ''} ${u['lastName'] ?? u['last_name'] ?? ''}'.trim();
                                if (name.isNotEmpty && !options.contains(name)) {
                                  options.add(name);
                                }
                              }
                              return options
                                  .map((s) => PopupMenuItem(
                                        value: s,
                                        child: Text(s,
                                            style: GoogleFonts.poppins(fontSize: 13)),
                                      ))
                                  .toList();
                            },
                            child: Row(
                              children: [
                                Text(
                                  '$_selectedAssigneeFilter ',
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
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  InkWell(
                    onTap: () {
                      setState(() {
                        _isActivitiesCollapsed = !_isActivitiesCollapsed;
                      });
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isActivitiesCollapsed ? 'Expand all ' : 'Collapse all ',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF00A884),
                          ),
                        ),
                        Icon(
                          _isActivitiesCollapsed
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.keyboard_arrow_up_rounded,
                          color: const Color(0xFF00A884),
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 4. Activity Content Grouped by Time
              if (!_isActivitiesCollapsed) ...[
                if (_isLoadingActivities)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFF00A884)),
                    ),
                  )
                else if (_filteredActivities.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(
                            Icons.assignment_outlined,
                            size: 44,
                            color: Color(0xFFCBD5E1),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No activities found matching your filters',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  Text(
                    'Activities (${_filteredActivities.length})',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._filteredActivities.map((act) {
                    final type = (act['type'] ?? 'activity').toString().toUpperCase();
                    final title = act['title'] ?? act['notes'] ?? 'Activity';
                    final ownerName = act['ownerName'] ?? act['assignedTo'] ?? 'Admin User';
                    final createdAt = act['createdAt'] ?? act['scheduledAt'] ?? '';

                    IconData actIcon = Icons.task_alt_rounded;
                    if (type.contains('CALL')) actIcon = Icons.phone_outlined;
                    if (type.contains('MEETING')) actIcon = Icons.videocam_outlined;
                    if (type.contains('NOTE')) actIcon = Icons.description_outlined;
                    if (type.contains('EMAIL')) actIcon = Icons.mail_outline_rounded;

                    return InkWell(
                      onTap: () => _showActivityDetailsModal(act),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE6F4F1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                actIcon,
                                color: const Color(0xFF00A884),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        size: 18,
                                        color: Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 2),
                                      Expanded(
                                        child: Text(
                                          title.toString(),
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF1E293B),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.person_outline_rounded,
                                        size: 14,
                                        color: Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        ownerName.toString(),
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                      if (createdAt.toString().isNotEmpty) ...[
                                        const SizedBox(width: 14),
                                        const Icon(
                                          Icons.access_time_rounded,
                                          size: 14,
                                          color: Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            createdAt.toString(),
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: const Color(0xFF64748B),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (act['notes'] != null && act['notes'].toString().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      act['notes'].toString(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: const Color(0xFF475569),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showActivityDetailsModal(Map<String, dynamic> act) {
    final type = (act['type'] ?? act['activityType'] ?? 'Activity').toString().toUpperCase();
    final title = act['title'] ?? act['notes'] ?? act['type'] ?? 'Activity';
    final ownerName = act['creatorName'] ?? act['ownerName'] ?? act['assignedTo'] ?? 'Admin User';
    final description = act['description'] ?? act['notes'] ?? act['message'] ?? '';
    final status = act['status'] ?? 'Completed';
    final priority = act['priority'] ?? 'Normal';
    final rawDate = act['createdAt'] ?? act['scheduledAt'] ?? act['activityDate'] ?? '';

    String formattedDate = '';
    if (rawDate.toString().isNotEmpty) {
      try {
        final dt = DateTime.parse(rawDate.toString()).toLocal();
        final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
        final ampm = dt.hour >= 12 ? 'PM' : 'AM';
        final min = dt.minute.toString().padLeft(2, '0');
        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        formattedDate = '${months[dt.month - 1]} ${dt.day}, ${dt.year} at $h:$min $ampm';
      } catch (_) {
        formattedDate = rawDate.toString();
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title.toString(),
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 10),
              _buildDetailRow('Type', type),
              _buildDetailRow('Assigned / Created By', ownerName.toString()),
              if (formattedDate.isNotEmpty) _buildDetailRow('Date', formattedDate),
              _buildDetailRow('Status', status.toString()),
              if (act['priority'] != null) _buildDetailRow('Priority', priority.toString()),
              if (act['outcome'] != null) _buildDetailRow('Outcome', act['outcome'].toString()),
              if (description.toString().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Details / Changes:',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    description.toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF1E293B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDateFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(16),
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FILTER BY CREATE DATE',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._dateFilterOptions.map((opt) {
                      final bool isSelected = _selectedDateFilter == opt;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedDateFilter = opt;
                          });
                          Navigator.of(context).pop();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                opt,
                                style: GoogleFonts.poppins(
                                  fontSize: 13.5,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFF334155),
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_rounded,
                                  color: Color(0xFF00A884),
                                  size: 18,
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const Divider(height: 24),
                    Text(
                      'CUSTOM RANGE',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Start',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                height: 36,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: const Color(0xFF00A884)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _startDateController,
                                        style: GoogleFonts.poppins(fontSize: 12),
                                        decoration: const InputDecoration(
                                          hintText: 'dd-mm-',
                                          border: InputBorder.none,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.calendar_today_rounded,
                                      size: 14,
                                      color: Color(0xFF64748B),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'End',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                height: 36,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: const Color(0xFFCBD5E1)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _endDateController,
                                        style: GoogleFonts.poppins(fontSize: 12),
                                        decoration: const InputDecoration(
                                          hintText: 'dd-mm-',
                                          border: InputBorder.none,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.calendar_today_rounded,
                                      size: 14,
                                      color: Color(0xFF64748B),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF64D2B7),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Text(
                          'Apply Range',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // TAB 3: ASSOCIATIONS TAB
  // ==========================================
  Widget _buildAssociationsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Card 1: Bingo record summary (+ AI)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF64748B),
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Bingo record summary',
                        style: GoogleFonts.poppins(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE11D48),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '+ AI',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Generate an AI-powered summary of the profile details and recent history of this record.',
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  color: const Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              if (_aiSummary != null && _aiSummary!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECDD3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _aiSummary!,
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1E293B),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoadingAiSummary
                      ? null
                      : () {
                          final dealId = widget.deal?.id;
                          if (dealId != null && dealId.isNotEmpty) {
                            _fetchAiSummary('deal', dealId);
                          }
                        },
                  icon: _isLoadingAiSummary
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFE11D48),
                          ),
                        )
                      : const Icon(Icons.auto_awesome,
                          color: Color(0xFFE11D48), size: 16),
                  label: Text(
                    _isLoadingAiSummary ? 'Summarizing...' : 'Summarize',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFE11D48),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE11D48)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Card 2: Company
        _buildAssociationCard(
          title: 'Company',
          description: 'No company associated',
          buttonText: 'Create company',
          entityType: 'company',
          associatedItems: _associatedCompanies,
          onPressed: () async {
            final res = await AddAssociationModal.show(context, entityType: 'company');
            if (res != null && res['action'] == 'add_existing') {
              final selected = res['selected'] as List;
              setState(() {
                for (final item in selected) {
                  final map = Map<String, dynamic>.from(item as Map);
                  if (!_associatedCompanies.any((c) => c['id'] == map['id'])) {
                    _associatedCompanies.add(map);
                  }
                }
              });
            }
          },
        ),

        // Card 3: Contacts
        _buildAssociationCard(
          title: 'Contacts',
          description: 'No contacts associated',
          buttonText: 'Create contact',
          entityType: 'contact',
          associatedItems: _associatedContacts,
          onPressed: () async {
            final res = await AddAssociationModal.show(context, entityType: 'contact');
            if (res != null && res['action'] == 'add_existing') {
              final selected = res['selected'] as List;
              setState(() {
                for (final item in selected) {
                  final map = Map<String, dynamic>.from(item as Map);
                  if (!_associatedContacts.any((c) => c['id'] == map['id'])) {
                    _associatedContacts.add(map);
                  }
                }
              });
            }
          },
        ),

        // Card 4: Tasks
        _buildAssociationCard(
          title: 'Tasks',
          description: 'Track the tasks associated with this record.',
          buttonText: 'Create task',
          entityType: 'task',
          associatedItems: _associatedTasks,
          isTeal: true,
          topActionText: '+ Add',
          onPressed: () async {
            final dealId = widget.deal?.id;
            final res = await CreateTaskModal.show(context, dealId: dealId);
            if (res != null) {
              setState(() {
                _associatedTasks.add({'name': res.title});
                _selectedActivitySubTab = 4; // Select Tasks subtab
                _tabController.animateTo(1); // Switch to Activities tab
              });
              _fetchActivities();
            }
          },
        ),
      ],
    );
  }

  void _navigateToEntityDetails(String entityType, Map<String, dynamic> item) {
    final id = (item['id'] ?? '').toString();
    final name = (item['name'] ?? item['title'] ?? item['company_name'] ?? item['contact_name'] ?? '').toString();
    final subtext = (item['subtext'] ?? item['email'] ?? item['domain'] ?? '').toString();

    if (entityType == 'contact') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ContactDetailsScreen(
            contact: ContactModel(
              id: id,
              firstName: name,
              email: subtext,
            ),
          ),
        ),
      );
    } else if (entityType == 'company') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CompanyDetailsScreen(
            company: CompanyModel(
              id: id,
              name: name,
              domain: subtext,
            ),
          ),
        ),
      );
    } else if (entityType == 'deal') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DealDetailsScreen(
            deal: DealModel(
              id: id,
              title: name,
              amount: 0,
              stage: '',
              probability: 0,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildAssociationCard({
    required String title,
    required String description,
    required String buttonText,
    required String entityType,
    List<Map<String, dynamic>> associatedItems = const [],
    bool isTeal = false,
    String? topActionText,
    VoidCallback? onPressed,
  }) {
    final bool hasItems = associatedItems.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  if (hasItems) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${associatedItems.length}',
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (topActionText != null || hasItems)
                InkWell(
                  onTap: onPressed,
                  child: Text(
                    topActionText ?? '+ Add',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF00A884),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (!hasItems)
            Text(
              description,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                color: const Color(0xFF64748B),
              ),
            )
          else
            Column(
              children: associatedItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final name = (item['name'] ?? item['title'] ?? item['company_name'] ?? item['contact_name'] ?? '').toString();
                final subtext = (item['subtext'] ?? item['email'] ?? item['domain'] ?? '').toString();
                final initialLetter = name.isNotEmpty ? name[0] : 'W';
                final isPrimary = item['isPrimary'] == true ||
                    item['primary'] == true ||
                    (!associatedItems.any((i) => i['isPrimary'] == true || i['primary'] == true) && index == 0);

                return Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            initialLetter,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E40AF),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: InkWell(
                                    onTap: () => _navigateToEntityDetails(entityType, item),
                                    child: Text(
                                      name,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF00A884),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                if (isPrimary) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFFBFDBFE)),
                                    ),
                                    child: Text(
                                      'PRIMARY',
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF1E40AF),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (subtext.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtext,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_vert,
                          color: Color(0xFF64748B),
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onSelected: (value) {
                          if (value == 'primary') {
                            setState(() {
                              for (var i in associatedItems) {
                                i['isPrimary'] = false;
                                i['primary'] = false;
                              }
                              item['isPrimary'] = true;
                              item['primary'] = true;
                            });
                          } else if (value == 'remove') {
                            setState(() {
                              associatedItems.remove(item);
                            });
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem<String>(
                            value: 'primary',
                            child: Text(
                              'Set as primary',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'remove',
                            child: Text(
                              'Remove association',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: const Color(0xFFEF4444),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: isTeal || hasItems
                      ? const Color(0xFF00A884)
                      : const Color(0xFFCBD5E1),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(
                hasItems
                    ? '+ Add another ${title.toLowerCase().substring(0, title.length - 1)}'
                    : buttonText,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isTeal || hasItems
                      ? const Color(0xFF00A884)
                      : const Color(0xFF334155),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // HELPER WIDGETS
  // ==========================================
  Widget _buildActionButton(IconData icon, String label) {
    return InkWell(
      onTap: () => _openActivityModal(label),
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
            ),
            child: Icon(
              icon,
              size: 18,
              color: const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  void _openActivityModal(String type) async {
    final dealId = widget.deal?.id;
    final name = widget.deal?.title.isNotEmpty == true ? widget.deal!.title : 'xyzzzz';
    dynamic result;

    if (type == 'Task') {
      result = await CreateTaskModal.show(context, dealId: dealId, associatedRecordName: name);
    } else if (type == 'Note') {
      result = await CreateNoteModal.show(context, dealId: dealId, associatedRecordName: name);
    } else if (type == 'Email') {
      result = await CreateEmailModal.show(context, dealId: dealId, associatedRecordName: name);
    } else if (type == 'Call') {
      result = await LogCallModal.show(context, dealId: dealId, associatedRecordName: name, activityType: type);
    } else if (type == 'Meeting') {
      result = await LogMeetingModal.show(context, dealId: dealId, associatedRecordName: name);
    }

    if (mounted && result != null && result != false) {
      setState(() {
        _selectedDateFilter = 'All time';
        _selectedAssigneeFilter = 'Activity assigned to';
        _searchActivitiesController.clear();
        if (type == 'Task') {
          _selectedActivitySubTab = 4; // Tasks subtab
        } else if (type == 'Note') {
          _selectedActivitySubTab = 1;
        } else if (type == 'Email') {
          _selectedActivitySubTab = 2;
        } else if (type == 'Call') {
          _selectedActivitySubTab = 3;
        } else if (type == 'Meeting') {
          _selectedActivitySubTab = 5;
        }
        _tabController.animateTo(1); // Switch to Activities tab
      });
      _fetchActivities();
    }
  }

  Widget _buildAboutField(
    String label,
    String key,
    TextEditingController controller, {
    bool isReadOnly = false,
    List<String>? options,
    ValueChanged<String>? onSelectedOption,
  }) {
    final bool isEditing = _editingFieldKey == key;
    final String val = controller.text.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF475569),
                  letterSpacing: 0.5,
                ),
              ),
              if (!isReadOnly && !isEditing)
                InkWell(
                  onTap: () {
                    setState(() {
                      _editingFieldKey = key;
                    });
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(2.0),
                    child: Icon(
                      Icons.mode_edit_outline_rounded,
                      size: 15,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (options != null && options.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (selected) {
                if (onSelectedOption != null) {
                  onSelectedOption(selected);
                }
              },
              itemBuilder: (context) => options
                  .map(
                    (opt) => PopupMenuItem<String>(
                      value: opt,
                      child: Text(
                        opt,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  )
                  .toList(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      val.isNotEmpty ? val : '--',
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        color: val.isNotEmpty && val != '--'
                            ? const Color(0xFF1E293B)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF64748B),
                      size: 18,
                    ),
                  ],
                ),
              ),
            )
          else if (isEditing && !isReadOnly)
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFF00A884), width: 1.5),
                    ),
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        color: const Color(0xFF1E293B),
                      ),
                      decoration: const InputDecoration(
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    setState(() {
                      _editingFieldKey = null;
                    });
                    _saveDealChanges();
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00A884),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () {
                    setState(() {
                      _editingFieldKey = null;
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF64748B),
                      size: 18,
                    ),
                  ),
                ),
              ],
            )
          else
            InkWell(
              onTap: isReadOnly
                  ? null
                  : () {
                      setState(() {
                        _editingFieldKey = key;
                      });
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  val.isNotEmpty ? val : '--',
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    color: val.isNotEmpty
                        ? const Color(0xFF1E293B)
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
