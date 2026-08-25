import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:provider/provider.dart';
import 'package:crmproject/core/widgets/app_refresh_indicator.dart';
import '../../../../core/models/master_dropdown_model.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/repositories/master_data_repository.dart';
import '../../../departments/presentation/providers/department_provider.dart';
import '../widgets/create_task_modal.dart';
import 'task_details_screen.dart';
import '../../../companies/presentation/screens/company_details_screen.dart';
import '../../../companies/data/models/company_model.dart';
import '../../../contacts/presentation/screens/contact_details_screen.dart';
import '../../../contacts/data/models/contact_model.dart';
import '../../../deals/presentation/screens/deal_details_screen.dart';
import '../../../deals/data/models/deal_model.dart';

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

  void _showSortMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'SORT BY',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              ..._sortOptions.map((opt) {
                final bool isSelected = _selectedSortOption == opt;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedSortOption = opt;
                    });
                    Navigator.pop(context);
                    _fetchTasks(resetPage: true);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          opt,
                          style: GoogleFonts.poppins(
                            fontSize: 13.5,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        if (isSelected)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF00A884),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showFilterModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filters',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedCreateDate = 'Create date';
                        _selectedStatusFilter = 'Status';
                        _selectedPriorityFilter = 'Priority';
                        _selectedCompanyFilter = 'Company';
                        _selectedContactFilter = 'Contact';
                        _selectedDealFilter = 'Deal';
                        _selectedOwnerFilter = 'Owner';
                      });
                      Navigator.pop(context);
                      _fetchTasks(resetPage: true);
                    },
                    child: Text(
                      'Reset All',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF00A884),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 10,
                children: [
                  _buildDropdownPill(
                    label: _selectedCreateDate,
                    items: const ['Create date', 'Today', 'This Week', 'This Month'],
                    onSelected: (val) => setState(() => _selectedCreateDate = val),
                  ),
                  _buildDropdownPill(
                    label: _selectedStatusFilter,
                    items: _taskStatuses.isNotEmpty
                        ? ['Status', ..._taskStatuses.map((s) => s.label)]
                        : const ['Status', 'Pending', 'Completed', 'Reopened'],
                    onSelected: (val) => setState(() => _selectedStatusFilter = val),
                  ),
                  _buildDropdownPill(
                    label: _selectedPriorityFilter,
                    items: _taskPriorities.isNotEmpty
                        ? ['Priority', ..._taskPriorities.map((p) => p.label)]
                        : const ['Priority', 'None', 'Low', 'Medium', 'High'],
                    onSelected: (val) => setState(() => _selectedPriorityFilter = val),
                  ),
                  _buildDropdownPill(
                    label: _selectedCompanyFilter,
                    items: _companies.isNotEmpty
                        ? ['Company', ..._companies.map((c) => c['name'] as String? ?? 'Company')]
                        : const ['Company'],
                    onSelected: (val) => setState(() => _selectedCompanyFilter = val),
                  ),
                  _buildDropdownPill(
                    label: _selectedContactFilter,
                    items: _contacts.isNotEmpty
                        ? [
                            'Contact',
                            ..._contacts.map((c) => '${c['firstName'] ?? ''} ${c['lastName'] ?? ''}'.trim())
                          ]
                        : const ['Contact'],
                    onSelected: (val) => setState(() => _selectedContactFilter = val),
                  ),
                  _buildDropdownPill(
                    label: _selectedDealFilter,
                    items: _deals.isNotEmpty
                        ? ['Deal', ..._deals.map((d) => d['title'] as String? ?? 'Deal')]
                        : const ['Deal'],
                    onSelected: (val) => setState(() => _selectedDealFilter = val),
                  ),
                  _buildDropdownPill(
                    label: _selectedOwnerFilter,
                    items: _users.isNotEmpty
                        ? [
                            'Owner',
                            ..._users.map((u) => '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim())
                          ]
                        : const ['Owner', 'Admin User'],
                    onSelected: (val) => setState(() => _selectedOwnerFilter = val),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
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
                      if (newTask != null) {
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
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                        child: Container(
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: TextField(
                            onChanged: _onSearchChanged,
                            decoration: InputDecoration(
                              hintText: 'Search tasks',
                              hintStyle: GoogleFonts.poppins(
                                fontSize: 13,
                                color: const Color(0xFF94A3B8),
                              ),
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: Color(0xFF94A3B8),
                                size: 18,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              _buildSegmentButton('All', 0),
                              _buildSegmentButton('Pending', 1),
                              _buildSegmentButton('Completed', 2),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _showFiltersRow = !_showFiltersRow;
                                });
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: _showFiltersRow ? const Color(0xFFE6F4F1) : Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _showFiltersRow ? const Color(0xFF00A884) : const Color(0xFF5FB6AD),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.tune_rounded,
                                      size: 14,
                                      color: Color(0xFF00A884),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Filters',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF00A884),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _showSortMenu(context),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.swap_vert_rounded,
                                      size: 14,
                                      color: Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Sort',
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
                          ],
                        ),
                      ),
                      if (_showFiltersRow) ...[
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildDropdownPill(
                                  icon: Icons.calendar_today_outlined,
                                  label: _selectedCreateDate,
                                  items: const ['Create date', 'Today', 'This Week', 'This Month'],
                                  onSelected: (val) => setState(() => _selectedCreateDate = val),
                                ),
                                const SizedBox(width: 6),
                                _buildDropdownPill(
                                  label: _selectedStatusFilter,
                                  items: _taskStatuses.isNotEmpty
                                      ? ['Status', ..._taskStatuses.map((s) => s.label)]
                                      : const ['Status', 'Pending', 'Completed', 'Reopened'],
                                  onSelected: (val) => setState(() => _selectedStatusFilter = val),
                                ),
                                const SizedBox(width: 6),
                                _buildDropdownPill(
                                  label: _selectedPriorityFilter,
                                  items: _taskPriorities.isNotEmpty
                                      ? ['Priority', ..._taskPriorities.map((p) => p.label)]
                                      : const ['Priority', 'None', 'Low', 'Medium', 'High'],
                                  onSelected: (val) => setState(() => _selectedPriorityFilter = val),
                                ),
                                const SizedBox(width: 6),
                                _buildDropdownPill(
                                  icon: Icons.bookmark_border_rounded,
                                  label: _selectedCompanyFilter,
                                  items: _companies.isNotEmpty
                                      ? ['Company', ..._companies.map((c) => c['name'] as String? ?? 'Company')]
                                      : const ['Company'],
                                  onSelected: (val) => setState(() => _selectedCompanyFilter = val),
                                ),
                                const SizedBox(width: 6),
                                _buildDropdownPill(
                                  icon: Icons.person_outline_rounded,
                                  label: _selectedContactFilter,
                                  items: _contacts.isNotEmpty
                                      ? [
                                          'Contact',
                                          ..._contacts.map((c) => '${c['firstName'] ?? ''} ${c['lastName'] ?? ''}'.trim())
                                        ]
                                      : const ['Contact'],
                                  onSelected: (val) => setState(() => _selectedContactFilter = val),
                                ),
                                const SizedBox(width: 6),
                                _buildDropdownPill(
                                  icon: Icons.attach_money_rounded,
                                  label: _selectedDealFilter,
                                  items: _deals.isNotEmpty
                                      ? ['Deal', ..._deals.map((d) => d['title'] as String? ?? 'Deal')]
                                      : const ['Deal'],
                                  onSelected: (val) => setState(() => _selectedDealFilter = val),
                                ),
                                const SizedBox(width: 6),
                                _buildDropdownPill(
                                  label: _selectedOwnerFilter,
                                  items: _users.isNotEmpty
                                      ? [
                                          'Owner',
                                          ..._users.map((u) => '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim())
                                        ]
                                      : const ['Owner', 'Admin User'],
                                  onSelected: (val) => setState(() => _selectedOwnerFilter = val),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
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

  Widget _buildSegmentButton(String title, int index) {
    final bool isSelected = _selectedSegment == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedSegment != index) {
            setState(() {
              _selectedSegment = index;
            });
            _fetchTasks(resetPage: true);
          }
        },
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? const Color(0xFF00A884) : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownPill({
    IconData? icon,
    required String label,
    required List<String> items,
    required ValueChanged<String> onSelected,
  }) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (context) => items
          .map((item) => PopupMenuItem(
                value: item,
                child: Text(item, style: GoogleFonts.poppins(fontSize: 12.5)),
              ))
          .toList(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: const Color(0xFF00A884)),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF00A884),
            ),
          ),
          const SizedBox(width: 2),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: Color(0xFF00A884),
          ),
        ],
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
    final priorityColor = _getPriorityColor(task.priority);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
      ),
      child: InkWell(
        onTap: () async {
          final act = task.rawMap ?? {};

          String? compId = (act['companyId'] ?? act['company_id'] ?? (act['company'] is Map ? act['company']['id'] : null))?.toString();
          String? compName = (act['companyName'] ?? act['company_name'] ?? (act['company'] is Map ? act['company']['name'] : null))?.toString();

          String? contactId = (act['contactId'] ?? act['contact_id'] ?? (act['contact'] is Map ? act['contact']['id'] : null))?.toString();
          String? contactName = (act['contactName'] ?? act['contact_name'] ?? (act['contact'] is Map ? act['contact']['name'] : null))?.toString();

          String? dealId = (act['dealId'] ?? act['deal_id'] ?? (act['deal'] is Map ? act['deal']['id'] : null))?.toString();
          String? dealName = (act['dealName'] ?? act['deal_name'] ?? (act['deal'] is Map ? act['deal']['title'] : null))?.toString();

          if (act['associations'] is Map) {
            final assocMap = act['associations'] as Map;
            if ((compId == null || compId.isEmpty) && assocMap['Companies'] is List && (assocMap['Companies'] as List).isNotEmpty) {
              final item = (assocMap['Companies'] as List).first;
              if (item is Map) {
                compId = (item['id'] ?? item['_id'] ?? item['objectId'])?.toString();
                compName = (item['name'] ?? item['title'])?.toString();
              }
            }
            if ((contactId == null || contactId.isEmpty) && assocMap['Contacts'] is List && (assocMap['Contacts'] as List).isNotEmpty) {
              final item = (assocMap['Contacts'] as List).first;
              if (item is Map) {
                contactId = (item['id'] ?? item['_id'] ?? item['objectId'])?.toString();
                contactName = (item['name'] ?? item['title'])?.toString();
              }
            }
            if ((dealId == null || dealId.isEmpty) && assocMap['Deals'] is List && (assocMap['Deals'] as List).isNotEmpty) {
              final item = (assocMap['Deals'] as List).first;
              if (item is Map) {
                dealId = (item['id'] ?? item['_id'] ?? item['objectId'])?.toString();
                dealName = (item['name'] ?? item['title'])?.toString();
              }
            }
          } else if (act['associations'] is List) {
            for (final item in (act['associations'] as List)) {
              if (item is Map) {
                final id = (item['objectId'] ?? item['id'] ?? item['_id'])?.toString();
                final type = (item['objectType'] ?? item['type'])?.toString().toLowerCase();
                final name = (item['name'] ?? item['title'])?.toString();
                if (id != null && id.isNotEmpty) {
                  if ((type == 'company' || type == 'companies') && (compId == null || compId.isEmpty)) {
                    compId = id;
                    compName = name;
                  } else if ((type == 'contact' || type == 'contacts') && (contactId == null || contactId.isEmpty)) {
                    contactId = id;
                    contactName = name;
                  } else if ((type == 'deal' || type == 'deals') && (dealId == null || dealId.isEmpty)) {
                    dealId = id;
                    dealName = name;
                  }
                }
              }
            }
          }

          if (compId != null && compId.isNotEmpty) {
            Map<String, dynamic> match = _companies.firstWhere(
              (c) => (c['id'] ?? c['_id'])?.toString() == compId,
              orElse: () => {'id': compId, 'name': compName ?? 'Company'},
            );
            final companyModel = CompanyModel(
              id: (match['id'] ?? match['_id'])?.toString() ?? compId,
              name: (match['name'] ?? compName ?? 'Company').toString(),
            );
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CompanyDetailsScreen(company: companyModel, initialTabIndex: 1),
              ),
            );
            _fetchTasks(resetPage: true);
          } else if (contactId != null && contactId.isNotEmpty) {
            Map<String, dynamic> match = _contacts.firstWhere(
              (c) => (c['id'] ?? c['_id'])?.toString() == contactId,
              orElse: () => {'id': contactId, 'firstName': contactName ?? 'Contact', 'email': ''},
            );
            final contactModel = ContactModel(
              id: (match['id'] ?? match['_id'])?.toString() ?? contactId,
              firstName: match['firstName']?.toString() ?? contactName ?? 'Contact',
              lastName: match['lastName']?.toString(),
              email: match['email']?.toString() ?? '',
            );
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ContactDetailsScreen(contact: contactModel, initialTabIndex: 1),
              ),
            );
            _fetchTasks(resetPage: true);
          } else if (dealId != null && dealId.isNotEmpty) {
            Map<String, dynamic> match = _deals.firstWhere(
              (d) => (d['id'] ?? d['_id'])?.toString() == dealId,
              orElse: () => {'id': dealId, 'title': dealName ?? 'Deal'},
            );
            final dealModel = DealModel(
              id: (match['id'] ?? match['_id'])?.toString() ?? dealId,
              title: (match['title'] ?? dealName ?? 'Deal').toString(),
              amount: (match['amount'] as num?)?.toDouble() ?? 0.0,
              stage: (match['stage'] ?? match['stageName'] ?? '').toString(),
              probability: (match['probability'] as num?)?.toInt() ?? 0,
            );
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DealDetailsScreen(deal: dealModel, initialTabIndex: 1),
              ),
            );
            _fetchTasks(resetPage: true);
          } else {
            final refreshed = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => TaskDetailsScreen(task: task),
              ),
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
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: priorityColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: priorityColor.withValues(alpha: 0.4), width: 0.8),
                          ),
                          child: Text(
                            task.priority,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: priorityColor,
                            ),
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
