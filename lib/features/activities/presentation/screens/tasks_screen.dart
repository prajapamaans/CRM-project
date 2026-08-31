import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/navigation/route_names.dart';
import '../../../../core/navigation/route_paths.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:provider/provider.dart';
import 'package:crmproject/core/widgets/app_refresh_indicator.dart';
import '../../../../core/models/master_dropdown_model.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/repositories/master_data_repository.dart';
import '../../../../core/utils/filter_query_utils.dart';
import '../../../departments/presentation/providers/department_provider.dart';
import '../widgets/create_task_modal.dart';
import '../../../companies/presentation/providers/company_provider.dart';
import '../../../deals/presentation/providers/deal_provider.dart';
import '../../../contacts/presentation/providers/contact_provider.dart';
import '../../../../core/widgets/search_and_filter_bar.dart';
import '../widgets/task_inline_filter_section.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  int _selectedSegment = 0; // 0: All, 1: Pending, 2: Completed
  String _searchQuery = '';
  Timer? _searchDebounce;
  final List<TaskModel> _tasks = [];
  bool _isLoadingTasks = false;
  bool _showFiltersRow = false;
  int _currentPage = 1;
  final int _pageSize = 25;
  int _totalTasks = 0;
  String? _errorMessage;

  /// Id of the task whose details view was opened from this list. Held by id so
  /// the highlight survives a reload of the list.
  String? _selectedTaskId;

  // Filter dropdown state
  String _selectedCreateDate = 'Create date';
  String _selectedStatusFilter = 'Status';
  String _selectedPriorityFilter = 'Priority';
  String _selectedCompanyFilter = 'Company';
  String _selectedContactFilter = 'Contact';
  String _selectedDealFilter = 'Deal';
  String _selectedOwnerFilter = 'Owner';

  // Sort state
  String _selectedSortOption = 'Most Recent';
  ContactSortOption _currentSortOption = ContactSortOption.mostRecent;

  // API Master Data
  List<MasterDropdownOptionModel> _taskStatuses = [];
  List<MasterDropdownOptionModel> _taskPriorities = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _deals = [];

  final List<String> _sortOptions = const [
    'Most Recent',
    'Due Date (Earliest)',
    'Due Date (Latest)',
    'Priority',
    'A to Z',
    'Z to A',
  ];

  String? _lastDepartmentId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CompanyProvider>().fetchCompanies();
      context.read<ContactProvider>().fetchContacts();
      context.read<DealProvider>().fetchDeals();
      _loadMasterDataAndFetchTasks();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentDeptId = context.watch<DepartmentProvider>().selectedDepartmentId;
    if (_lastDepartmentId != currentDeptId) {
      _lastDepartmentId = currentDeptId;
      _fetchTasks(page: 1);
    }
  }

  Future<void> _loadMasterDataAndFetchTasks() async {
    final repository = MasterDataRepositoryImpl();
    final apiService = ApiService();

    try {
      try {
        _taskStatuses = await repository.getMasterDropdownByKey('task_status', includeInactive: false);
      } catch (_) {}
      try {
        _taskPriorities = await repository.getMasterDropdownByKey('task_priority', includeInactive: false);
      } catch (_) {}

      try {
        final uResp = await apiService.get('/users');
        if (uResp.data != null) {
          final raw = uResp.data;
          if (raw is List) {
            _users = raw.whereType<Map<String, dynamic>>().toList();
          } else if (raw is Map && raw['data'] is List) {
            _users = (raw['data'] as List).whereType<Map<String, dynamic>>().toList();
          }
        }
      } catch (_) {}

      try {
        final cResp = await apiService.get('/companies', queryParameters: {'limit': 200});
        if (cResp.data != null) {
          final raw = cResp.data;
          if (raw is List) {
            _companies = raw.whereType<Map<String, dynamic>>().toList();
          } else if (raw is Map && raw['data'] is List) {
            _companies = (raw['data'] as List).whereType<Map<String, dynamic>>().toList();
          }
        }
      } catch (_) {}

      try {
        final contResp = await apiService.get('/contacts', queryParameters: {'limit': 200});
        if (contResp.data != null) {
          final raw = contResp.data;
          if (raw is List) {
            _contacts = raw.whereType<Map<String, dynamic>>().toList();
          } else if (raw is Map && raw['data'] is List) {
            _contacts = (raw['data'] as List).whereType<Map<String, dynamic>>().toList();
          }
        }
      } catch (_) {}

      try {
        final dResp = await apiService.get('/deals', queryParameters: {'limit': 200});
        if (dResp.data != null) {
          final raw = dResp.data;
          if (raw is List) {
            _deals = raw.whereType<Map<String, dynamic>>().toList();
          } else if (raw is Map && raw['data'] is List) {
            _deals = (raw['data'] as List).whereType<Map<String, dynamic>>().toList();
          }
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('[LOAD MASTER DATA ERROR]: $e');
    }

    await _fetchTasks(page: 1);
  }

  String _getSortField() {
    switch (_selectedSortOption) {
      case 'Due Date (Earliest)':
      case 'Due Date (Latest)':
        return 'dueDate';
      case 'A to Z':
      case 'Z to A':
        return 'title';
      case 'Priority':
        return 'priority';
      case 'Most Recent':
      default:
        return 'createdAt';
    }
  }

  String _getSortOrder() {
    switch (_selectedSortOption) {
      case 'Due Date (Earliest)':
      case 'A to Z':
        return 'asc';
      case 'Due Date (Latest)':
      case 'Z to A':
      case 'Priority':
      case 'Most Recent':
      default:
        return 'desc';
    }
  }

  // ---------------------------------------------------------------------------
  // Pill label → record id
  //
  // The Company / Contact / Deal pills list display names, drawn from both the
  // provider caches and this screen's own lookups. `/api/activities` filters by
  // id, so the chosen name is resolved back to one; both sources are searched
  // because either may be where the name came from.
  // ---------------------------------------------------------------------------

  String? _resolveCompanyId() {
    if (_selectedCompanyFilter == 'Company') return null;
    final wanted = _selectedCompanyFilter.trim().toLowerCase();

    for (final c in context.read<CompanyProvider>().companies) {
      if (c.name.trim().toLowerCase() == wanted) return c.id;
    }
    for (final c in _companies) {
      final name = (c['name'] ?? c['companyName'] ?? c['company_name'] ?? c['title'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      if (name.isNotEmpty && name == wanted) {
        final id = (c['id'] ?? c['_id'])?.toString();
        if (id != null && id.isNotEmpty) return id;
      }
    }

    debugPrint('[TasksScreen] company filter "$_selectedCompanyFilter" has no id — not sent');
    return null;
  }

  String? _resolveContactId() {
    if (_selectedContactFilter == 'Contact') return null;
    final wanted = _selectedContactFilter.trim().toLowerCase();

    for (final c in context.read<ContactProvider>().contacts) {
      final name = '${c.firstName ?? ''} ${c.lastName ?? ''}'.trim().toLowerCase();
      if (name.isNotEmpty && name == wanted) return c.id;
    }
    for (final c in _contacts) {
      final fn = (c['firstName'] ?? c['first_name'] ?? '').toString().trim();
      final ln = (c['lastName'] ?? c['last_name'] ?? '').toString().trim();
      final name = '$fn $ln'.trim().isNotEmpty
          ? '$fn $ln'.trim().toLowerCase()
          : (c['name'] ?? c['fullName'] ?? c['email'] ?? '').toString().trim().toLowerCase();
      if (name.isNotEmpty && name == wanted) {
        final id = (c['id'] ?? c['_id'])?.toString();
        if (id != null && id.isNotEmpty) return id;
      }
    }

    debugPrint('[TasksScreen] contact filter "$_selectedContactFilter" has no id — not sent');
    return null;
  }

  String? _resolveDealId() {
    if (_selectedDealFilter == 'Deal') return null;
    final wanted = _selectedDealFilter.trim().toLowerCase();

    for (final d in context.read<DealProvider>().deals) {
      if (d.title.trim().toLowerCase() == wanted) return d.id;
    }
    for (final d in _deals) {
      final title = (d['title'] ?? d['name'] ?? d['dealName'] ?? d['deal_name'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      if (title.isNotEmpty && title == wanted) {
        final id = (d['id'] ?? d['_id'])?.toString();
        if (id != null && id.isNotEmpty) return id;
      }
    }

    debugPrint('[TasksScreen] deal filter "$_selectedDealFilter" has no id — not sent');
    return null;
  }

  Future<void> _fetchTasks({int? page, bool resetPage = false}) async {
    if (!mounted) return;
    if (_isLoadingTasks) return;

    final targetPage = resetPage ? 1 : (page ?? _currentPage);

    setState(() {
      _isLoadingTasks = true;
      _errorMessage = null;
      if (resetPage) _currentPage = 1;
    });

    final apiService = ApiService();
    final deptId = context.read<DepartmentProvider>().selectedDepartmentId;

    final queryParams = <String, dynamic>{
      'page': targetPage,
      'limit': _pageSize,
      'sort': _getSortField(),
      'order': _getSortOrder(),
    };

    if (deptId != null && deptId.isNotEmpty) {
      queryParams['department_id'] = deptId;
    }

    if (_searchQuery.trim().isNotEmpty) {
      queryParams['search'] = _searchQuery.trim();
    }

    if (_selectedSegment == 1) {
      queryParams['status'] = 'pending';
    } else if (_selectedSegment == 2) {
      queryParams['status'] = 'completed';
    } else if (_selectedStatusFilter != 'Status') {
      queryParams['status'] = _selectedStatusFilter.toLowerCase();
    }

    if (_selectedPriorityFilter != 'Priority') {
      queryParams['priority'] = _selectedPriorityFilter.toLowerCase();
    }

    if (_selectedOwnerFilter != 'Owner') {
      final matchedUser = _users.firstWhere(
        (u) => '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim().toLowerCase() == _selectedOwnerFilter.toLowerCase(),
        orElse: () => {},
      );
      if (matchedUser.containsKey('id') || matchedUser.containsKey('_id')) {
        queryParams['ownerId'] = matchedUser['id'] ?? matchedUser['_id'];
      }
    }

    // The Create date pill used to be recorded and then never used — it now
    // becomes the documented `createdDateRange` value.
    final createdDateRange = FilterDateRange.toQueryValue(_selectedCreateDate);
    if (createdDateRange != null) {
      queryParams['createdDateRange'] = createdDateRange;
    }

    // Company / Contact / Deal pills hold the record's display name; the API
    // filters by id, so the name is resolved back to one here.
    final companyId = _resolveCompanyId();
    if (companyId != null) queryParams['companyId'] = companyId;

    final contactId = _resolveContactId();
    if (contactId != null) queryParams['contactId'] = contactId;

    final dealId = _resolveDealId();
    if (dealId != null) queryParams['dealId'] = dealId;

    debugPrint('[TasksScreen] GET /activities query: $queryParams');

    try {
      final response = await apiService.get(
        '/activities',
        queryParameters: queryParams,
      );

      final dynamic rawData = response.data;
      List<dynamic> records = [];
      int total = 0;
      int resPage = targetPage;

      if (rawData is Map<String, dynamic>) {
        if (rawData['data'] is List) {
          records = rawData['data'] as List;
        } else if (rawData['activities'] is List) {
          records = rawData['activities'] as List;
        } else if (rawData['items'] is List) {
          records = rawData['items'] as List;
        }

        if (rawData['meta'] is Map<String, dynamic>) {
          final meta = rawData['meta'] as Map<String, dynamic>;
          total = (meta['total'] ?? meta['totalRecords'] ?? meta['count']) as int? ?? records.length;
          resPage = (meta['page'] as int?) ?? targetPage;
        } else if (rawData['total'] is int) {
          total = rawData['total'] as int;
        } else {
          total = records.length;
        }
      } else if (rawData is List) {
        records = rawData;
        total = rawData.length;
      }

      final loadedTasks = records.whereType<Map>().map((e) {
        final item = Map<String, dynamic>.from(e);
        final id = (item['id'] ?? item['_id'])?.toString();
        final title = item['title'] as String? ?? item['subject'] as String? ?? item['notes'] as String? ?? 'Untitled Activity';
        final dueDate = item['dueDate'] as String? ?? item['due_date'] as String? ?? item['scheduledAt'] as String? ?? item['createdAt'] as String? ?? '8/11/2026';
        final priority = item['priority'] as String? ?? 'None';
        final status = item['status'] as String? ?? 'pending';
        final assignedTo = item['ownerName'] as String? ?? item['assignedTo'] as String? ?? item['creatorName'] as String? ?? 'Admin User';
        final notes = item['description'] as String? ?? item['notes'] as String? ?? '';
        final taskType = (item['type'] ?? item['taskType'] ?? 'task').toString();

        return TaskModel(
          id: id,
          title: title,
          dueDate: dueDate,
          priority: priority,
          status: status,
          assignedTo: assignedTo,
          notes: notes,
          taskType: taskType,
          rawMap: item,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _tasks.clear();
          _tasks.addAll(loadedTasks);
          _totalTasks = total;
          _currentPage = resPage;
          _isLoadingTasks = false;
        });
      }
    } catch (e) {
      debugPrint('[FETCH /api/activities ERROR]: $e');
      if (mounted) {
        setState(() {
          _isLoadingTasks = false;
          _errorMessage = 'Failed to load tasks. Please check your connection and try again.';
        });
      }
    }
  }

  void _onSearchChanged(String val) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _searchQuery = val;
        });
        _fetchTasks(resetPage: true);
      }
    });
  }



  @override
  Widget build(BuildContext context) {
    final totalPages = _totalTasks == 0 ? 1 : ((_totalTasks - 1) ~/ _pageSize) + 1;
    final startIndex = _totalTasks == 0 ? 0 : (_currentPage - 1) * _pageSize + 1;
    final endIndex = math.min(_currentPage * _pageSize, _totalTasks);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F4F1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.fact_check_outlined,
                      color: Color(0xFF00A884),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Tasks',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_totalTasks',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final newTask = await CreateTaskModal.show(context);
                      if (newTask != null && mounted) {
                        setState(() {
                          _tasks.removeWhere((t) => t.id == newTask.id);
                          _tasks.insert(0, newTask);
                          _totalTasks += 1;
                        });
                        _fetchTasks(resetPage: true);
                      }
                    },
                    icon: const Icon(Icons.add, size: 18, color: Colors.white),
                    label: Text(
                      'Task',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A884),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                children: [
                  SearchAndFilterBar(
                    searchHint: 'Search tasks...',
                    allLabel: 'All Tasks',
                    mineLabel: 'Mine Tasks',
                    onSearchChanged: _onSearchChanged,
                    onSegmentChanged: (index) {
                      setState(() {
                        _selectedSegment = index;
                      });
                      _fetchTasks(resetPage: true);
                    },
                    isFilterActive: _selectedCreateDate != 'Create date' ||
                        _selectedStatusFilter != 'Status' ||
                        _selectedPriorityFilter != 'Priority' ||
                        _selectedCompanyFilter != 'Company' ||
                        _selectedContactFilter != 'Contact' ||
                        _selectedDealFilter != 'Deal' ||
                        _selectedOwnerFilter != 'Owner',
                    isFilterExpanded: _showFiltersRow,
                    onToggleFilterExpanded: () {
                      setState(() {
                        _showFiltersRow = !_showFiltersRow;
                      });
                    },
                    onClearTap: () {
                      setState(() {
                        _selectedCreateDate = 'Create date';
                        _selectedStatusFilter = 'Status';
                        _selectedPriorityFilter = 'Priority';
                        _selectedCompanyFilter = 'Company';
                        _selectedContactFilter = 'Contact';
                        _selectedDealFilter = 'Deal';
                        _selectedOwnerFilter = 'Owner';
                        _searchQuery = '';
                      });
                      _fetchTasks(resetPage: true);
                    },
                  ),

                  if (_showFiltersRow)
                    TaskInlineFilterSection(
                      selectedOwnerId: _selectedOwnerFilter != 'Owner' ? _selectedOwnerFilter : 'all',
                      selectedCreateDate: _selectedCreateDate != 'Create date' ? _selectedCreateDate : 'All time',
                      selectedStatus: _selectedStatusFilter != 'Status' ? _selectedStatusFilter : 'All statuses',
                      selectedPriority: _selectedPriorityFilter != 'Priority' ? _selectedPriorityFilter : 'ALL PRIORITIES',
                      selectedCompany: _selectedCompanyFilter != 'Company' ? _selectedCompanyFilter : 'All companies',
                      selectedContact: _selectedContactFilter != 'Contact' ? _selectedContactFilter : 'All contacts',
                      selectedDeal: _selectedDealFilter != 'Deal' ? _selectedDealFilter : 'All deals',
                      users: _users,
                      companies: _companies,
                      contacts: _contacts,
                      deals: _deals,
                      taskStatuses: _taskStatuses.map((s) => s.label).toList(),
                      taskPriorities: _taskPriorities.map((p) => p.label).toList(),
                      onOwnerChanged: (val) {
                        setState(() => _selectedOwnerFilter = (val == null || val == 'all') ? 'Owner' : val);
                        _fetchTasks(resetPage: true);
                      },
                      onCreateDateChanged: (val) {
                        setState(() => _selectedCreateDate = (val == null || val == 'All time') ? 'Create date' : val);
                        _fetchTasks(resetPage: true);
                      },
                      onStatusChanged: (val) {
                        setState(() => _selectedStatusFilter = (val == null || val == 'All statuses') ? 'Status' : val);
                        _fetchTasks(resetPage: true);
                      },
                      onPriorityChanged: (val) {
                        setState(() => _selectedPriorityFilter = (val == null || val == 'ALL PRIORITIES') ? 'Priority' : val);
                        _fetchTasks(resetPage: true);
                      },
                      onCompanyChanged: (val) {
                        setState(() => _selectedCompanyFilter = (val == null || val == 'All companies') ? 'Company' : val);
                        _fetchTasks(resetPage: true);
                      },
                      onContactChanged: (val) {
                        setState(() => _selectedContactFilter = (val == null || val == 'All contacts') ? 'Contact' : val);
                        _fetchTasks(resetPage: true);
                      },
                      onDealChanged: (val) {
                        setState(() => _selectedDealFilter = (val == null || val == 'All deals') ? 'Deal' : val);
                        _fetchTasks(resetPage: true);
                      },
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: AppRefreshIndicator(
                          onRefresh: () async {
                            await _fetchTasks(resetPage: true);
                          },
                          child: _isLoadingTasks
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF00A884),
                                  ),
                                )
                              : _errorMessage != null && _tasks.isEmpty
                                  ? ListView(
                                      physics: const AlwaysScrollableScrollPhysics(
                                          parent: BouncingScrollPhysics()),
                                      children: [
                                        const SizedBox(height: 100),
                                        Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.error_outline_rounded,
                                                size: 40,
                                                color: Color(0xFFF25C54),
                                              ),
                                              const SizedBox(height: 8),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                                child: Text(
                                                  _errorMessage!,
                                                  textAlign: TextAlign.center,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 13,
                                                    color: const Color(0xFF64748B),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              ElevatedButton.icon(
                                                onPressed: () => _fetchTasks(page: 1),
                                                icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                                                label: Text(
                                                  'Retry',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF00A884),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  : _tasks.isEmpty
                                      ? ListView(
                                          physics: const AlwaysScrollableScrollPhysics(
                                              parent: BouncingScrollPhysics()),
                                          children: [
                                            const SizedBox(height: 120),
                                            Center(
                                              child: Text(
                                                'No tasks found.',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 13,
                                                  color: const Color(0xFF64748B),
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : ListView.builder(
                                          physics: const AlwaysScrollableScrollPhysics(
                                              parent: BouncingScrollPhysics()),
                                          padding: const EdgeInsets.symmetric(horizontal: 14),
                                          itemCount: _tasks.length,
                                          itemBuilder: (context, index) {
                                            final task = _tasks[index];
                                            return _buildTaskCard(task);
                                          },
                                        ),
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            RichText(
                              text: TextSpan(
                                text: _totalTasks == 0
                                    ? '0-0 of '
                                    : '$startIndex-$endIndex of ',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                ),
                                children: [
                                  TextSpan(
                                    text: '$_totalTasks',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                TextButton.icon(
                                  onPressed: _currentPage > 1 && !_isLoadingTasks
                                      ? () => _fetchTasks(page: _currentPage - 1)
                                      : null,
                                  icon: const Icon(Icons.chevron_left_rounded, size: 16),
                                  label: Text(
                                    'Prev',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: _currentPage > 1 ? const Color(0xFF00A884) : const Color(0xFF94A3B8),
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$_currentPage/$totalPages',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                TextButton(
                                  onPressed: _currentPage < totalPages && !_isLoadingTasks
                                      ? () => _fetchTasks(page: _currentPage + 1)
                                      : null,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Next',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right_rounded, size: 16),
                                    ],
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: _currentPage < totalPages ? const Color(0xFF00A884) : const Color(0xFF94A3B8),
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
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
            ),
          ],
        ),
      ),
    );
  }



  Color _getPriorityColor(String priority) {
    final match = _taskPriorities.firstWhere(
      (p) => p.value.toLowerCase() == priority.toLowerCase() || p.label.toLowerCase() == priority.toLowerCase(),
      orElse: () => MasterDropdownOptionModel(id: '', value: '', label: ''),
    );
    if (match.color != null && match.color!.isNotEmpty) {
      try {
        final hex = match.color!.replaceAll('#', '');
        return Color(int.parse('0xFF$hex'));
      } catch (_) {}
    }
    switch (priority.toLowerCase()) {
      case 'high':
        return const Color(0xFFF25C54);
      case 'medium':
        return const Color(0xFFFFC254);
      case 'low':
        return const Color(0xFF5FB6AD);
      default:
        return const Color(0xFF99ACC2);
    }
  }

  Widget _buildTaskCard(TaskModel task) {
    final bool isCompleted = task.status.toLowerCase() == 'completed';
    final bool isSelected = task.id != null && task.id == _selectedTaskId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFE6F4F1) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? const Color(0xFF00A884) : const Color(0xFFCBD5E1),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: () async {
          // Mark this task as the selected one before opening its details.
          setState(() => _selectedTaskId = task.id);

          final act = task.rawMap ?? {};

          String? compId = (act['companyId'] ?? act['company_id'] ?? (act['company'] is Map ? act['company']['id'] : null))?.toString();

          String? contactId = (act['contactId'] ?? act['contact_id'] ?? (act['contact'] is Map ? act['contact']['id'] : null))?.toString();

          String? dealId = (act['dealId'] ?? act['deal_id'] ?? (act['deal'] is Map ? act['deal']['id'] : null))?.toString();

          if (act['associations'] is Map) {
            final assocMap = act['associations'] as Map;
            if ((compId == null || compId.isEmpty) && assocMap['Companies'] is List && (assocMap['Companies'] as List).isNotEmpty) {
              final item = (assocMap['Companies'] as List).first;
              if (item is Map) {
                compId = (item['id'] ?? item['_id'] ?? item['objectId'])?.toString();
              }
            }
            if ((contactId == null || contactId.isEmpty) && assocMap['Contacts'] is List && (assocMap['Contacts'] as List).isNotEmpty) {
              final item = (assocMap['Contacts'] as List).first;
              if (item is Map) {
                contactId = (item['id'] ?? item['_id'] ?? item['objectId'])?.toString();
              }
            }
            if ((dealId == null || dealId.isEmpty) && assocMap['Deals'] is List && (assocMap['Deals'] as List).isNotEmpty) {
              final item = (assocMap['Deals'] as List).first;
              if (item is Map) {
                dealId = (item['id'] ?? item['_id'] ?? item['objectId'])?.toString();
              }
            }
          } else if (act['associations'] is List) {
            for (final item in (act['associations'] as List)) {
              if (item is Map) {
                final id = (item['objectId'] ?? item['id'] ?? item['_id'])?.toString();
                final type = (item['objectType'] ?? item['type'])?.toString().toLowerCase();
                if (id != null && id.isNotEmpty) {
                  if ((type == 'company' || type == 'companies') && (compId == null || compId.isEmpty)) {
                    compId = id;
                  } else if ((type == 'contact' || type == 'contacts') && (contactId == null || contactId.isEmpty)) {
                    contactId = id;
                  } else if ((type == 'deal' || type == 'deals') && (dealId == null || dealId.isEmpty)) {
                    dealId = id;
                  }
                }
              }
            }
          }

          if (compId != null && compId.isNotEmpty) {
            await context.pushNamed(
              RouteNames.companyDetails,
              pathParameters: {RoutePaths.idParam: compId},
              queryParameters: RoutePaths.recordActivityQuery(task.id),
            );
            _fetchTasks(resetPage: true);
          } else if (contactId != null && contactId.isNotEmpty) {
            await context.pushNamed(
              RouteNames.contactDetails,
              pathParameters: {RoutePaths.idParam: contactId},
              queryParameters: RoutePaths.recordActivityQuery(task.id),
            );
            _fetchTasks(resetPage: true);
          } else if (dealId != null && dealId.isNotEmpty) {
            await context.pushNamed(
              RouteNames.dealDetails,
              pathParameters: {RoutePaths.idParam: dealId},
              queryParameters: RoutePaths.recordActivityQuery(task.id),
            );
            _fetchTasks(resetPage: true);
          } else {
            // /activities/tasks/details/:id
            final taskId = task.id;
            if (taskId == null || taskId.isEmpty) return;
            final refreshed = await context.pushNamed<bool>(
              RouteNames.taskDetails,
              pathParameters: {RoutePaths.idParam: taskId},
            );
            if (refreshed == true) {
              _fetchTasks(resetPage: true);
            }
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Square Checkbox icon (Image 1 style)
              GestureDetector(
                onTap: () {
                  setState(() {
                    final newStatus = isCompleted ? 'pending' : 'completed';
                    final index = _tasks.indexOf(task);
                    if (index != -1) {
                      _tasks[index] = TaskModel(
                        id: task.id,
                        title: task.title,
                        dueDate: task.dueDate,
                        priority: task.priority,
                        status: newStatus,
                        assignedTo: task.assignedTo,
                        notes: task.notes,
                        taskType: task.taskType,
                        queue: task.queue,
                        activityDateText: task.activityDateText,
                        reminderText: task.reminderText,
                        rawMap: task.rawMap,
                      );
                    }
                  });
                },
                child: Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(top: 2, right: 12),
                  decoration: BoxDecoration(
                    color: isCompleted ? const Color(0xFFE6F4F1) : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isCompleted ? const Color(0xFF00A884) : const Color(0xFFCBD5E1),
                      width: 1.5,
                    ),
                  ),
                  child: isCompleted
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Color(0xFF00A884),
                        )
                      : (task.taskType != null && !task.taskType!.toLowerCase().contains('task'))
                          ? Icon(
                              task.taskType!.toLowerCase().contains('note')
                                  ? Icons.description_outlined
                                  : (task.taskType!.toLowerCase().contains('email')
                                      ? Icons.mail_outline_rounded
                                      : (task.taskType!.toLowerCase().contains('call')
                                          ? Icons.phone_outlined
                                          : (task.taskType!.toLowerCase().contains('meeting')
                                              ? Icons.videocam_outlined
                                              : Icons.task_alt_rounded))),
                              size: 15,
                              color: const Color(0xFF00A884),
                            )
                          : null,
                ),
              ),

              // Title and Due / Priority / Assigned Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isCompleted ? const Color(0xFF64748B) : const Color(0xFF1E293B),
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Due: ${task.dueDate}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Assigned: ${task.assignedTo}',
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),

              // Chevron Right Arrow (Image 1 style)
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFCBD5E1),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
