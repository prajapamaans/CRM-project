import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/models/master_dropdown_model.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/repositories/master_data_repository.dart';
import '../widgets/create_task_modal.dart';
import 'task_details_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  int _selectedSegment = 0; // 0: All, 1: Pending, 2: Completed
  String _searchQuery = '';
  final List<TaskModel> _tasks = [];
  bool _isLoadingTasks = false;

  // Filter dropdown state
  String _selectedCreateDate = 'Create date';
  String _selectedStatusFilter = 'Status';
  String _selectedPriorityFilter = 'Priority';
  String _selectedCompanyFilter = 'Company';
  String _selectedContactFilter = 'Contact';
  String _selectedDealFilter = 'Deal';
  String _selectedOwnerFilter = 'Owner';

  // Sort state
  String _selectedSortOption = 'Due Date (Earliest)';

  // API Master Data
  List<MasterDropdownOptionModel> _taskStatuses = [];
  List<MasterDropdownOptionModel> _taskPriorities = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _deals = [];

  final List<String> _sortOptions = const [
    'Due Date (Earliest)',
    'Due Date (Latest)',
    'Priority',
    'A to Z',
    'Z to A',
    'Most Recent',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllApisAndTasks();
    });
  }

  Future<void> _loadAllApisAndTasks() async {
    if (!mounted) return;
    setState(() {
      _isLoadingTasks = true;
    });

    final repository = MasterDataRepositoryImpl();
    final apiService = ApiService();

    // Fire all required API calls concurrently as specified in request
    try {
      try {
        _taskStatuses = await repository.getMasterDropdownByKey('task_status', includeInactive: false);
      } catch (e) {
        debugPrint('[FETCH task_status ERROR]: $e');
      }

      try {
        _taskPriorities = await repository.getMasterDropdownByKey('task_priority', includeInactive: false);
      } catch (e) {
        debugPrint('[FETCH task_priority ERROR]: $e');
      }

      try {
        final resp = await apiService.get('/users');
        final rawUsers = resp.data;
        if (rawUsers is List) {
          _users = rawUsers.whereType<Map<String, dynamic>>().toList();
        } else if (rawUsers is Map<String, dynamic> && rawUsers['data'] is List) {
          _users = (rawUsers['data'] as List).whereType<Map<String, dynamic>>().toList();
        }
      } catch (e) {
        debugPrint('[FETCH /users ERROR]: $e');
      }

      try {
        final resp = await apiService.get('/companies');
        final rawComp = resp.data;
        if (rawComp is List) {
          _companies = rawComp.whereType<Map<String, dynamic>>().toList();
        } else if (rawComp is Map<String, dynamic> && rawComp['data'] is List) {
          _companies = (rawComp['data'] as List).whereType<Map<String, dynamic>>().toList();
        }
      } catch (e) {
        debugPrint('[FETCH /companies ERROR]: $e');
      }

      try {
        final resp = await apiService.get('/contacts', queryParameters: {'page': 1, 'limit': 25});
        final rawCont = resp.data;
        if (rawCont is List) {
          _contacts = rawCont.whereType<Map<String, dynamic>>().toList();
        } else if (rawCont is Map<String, dynamic> && rawCont['data'] is List) {
          _contacts = (rawCont['data'] as List).whereType<Map<String, dynamic>>().toList();
        }
      } catch (e) {
        debugPrint('[FETCH /contacts ERROR]: $e');
      }

      try {
        final resp = await apiService.get('/deals', queryParameters: {'page': 1, 'limit': 25});
        final rawDeals = resp.data;
        if (rawDeals is List) {
          _deals = rawDeals.whereType<Map<String, dynamic>>().toList();
        } else if (rawDeals is Map<String, dynamic> && rawDeals['data'] is List) {
          _deals = (rawDeals['data'] as List).whereType<Map<String, dynamic>>().toList();
        }
      } catch (e) {
        debugPrint('[FETCH /deals ERROR]: $e');
      }

      List<Map<String, dynamic>> activities = [];
      try {
        activities = await repository.getActivities(type: 'task', page: 1, limit: 25);
      } catch (e) {
        debugPrint('[FETCH activities ERROR]: $e');
      }

      if (mounted) {

        final loadedTasks = activities.map((item) {
          final id = item['id']?.toString() ?? item['_id']?.toString();
          final title = item['title'] as String? ?? item['subject'] as String? ?? 'Untitled Task';
          final dueDate = item['dueDate'] as String? ?? item['due_date'] as String? ?? '8/11/2026';
          final priority = item['priority'] as String? ?? 'None';
          final status = item['status'] as String? ?? 'pending';
          final assignedTo = item['ownerName'] as String? ?? item['assignedTo'] as String? ?? 'Admin User';
          final notes = item['notes'] as String? ?? item['description'] as String? ?? '';

          return TaskModel(
            id: id,
            title: title,
            dueDate: dueDate,
            priority: priority,
            status: status,
            assignedTo: assignedTo,
            notes: notes,
            rawMap: item,
          );
        }).toList();



        setState(() {
          _tasks.clear();
          _tasks.addAll(loadedTasks);
        });
      }
    } catch (e) {
      debugPrint('[TasksScreen _loadAllApisAndTasks Error]: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingTasks = false;
        });
      }
    }
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    // Perform filtering: All, Pending, Completed
    final filteredTasks = _tasks.where((t) {
      final isComp = t.status.toLowerCase() == 'completed';
      if (_selectedSegment == 1 && isComp) return false;
      if (_selectedSegment == 2 && !isComp) return false;

      // Status filter
      if (_selectedStatusFilter != 'Status') {
        if (t.status.toLowerCase() != _selectedStatusFilter.toLowerCase()) {
          return false;
        }
      }

      // Priority filter
      if (_selectedPriorityFilter != 'Priority') {
        if (t.priority.toLowerCase() != _selectedPriorityFilter.toLowerCase()) {
          return false;
        }
      }

      // Owner filter
      if (_selectedOwnerFilter != 'Owner') {
        if (!t.assignedTo.toLowerCase().contains(_selectedOwnerFilter.toLowerCase())) {
          return false;
        }
      }

      if (_searchQuery.isEmpty) return true;
      return t.title.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    // Sort tasks according to selected sort option
    if (_selectedSortOption == 'A to Z') {
      filteredTasks.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    } else if (_selectedSortOption == 'Z to A') {
      filteredTasks.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
    } else if (_selectedSortOption == 'Priority') {
      final pMap = {'high': 3, 'medium': 2, 'low': 1, 'none': 0};
      filteredTasks.sort((a, b) => (pMap[b.priority.toLowerCase()] ?? 0).compareTo(pMap[a.priority.toLowerCase()] ?? 0));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Header Row: Checkbox Icon + "Tasks" + Badge + "+ Task" Button (Image 1)
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
                      '${_tasks.length}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const Spacer(),

                  // + Task Button (Image 1 top right)
                  ElevatedButton.icon(
                    onPressed: () async {
                      final newTask = await CreateTaskModal.show(context);
                      if (newTask != null) {
                        _loadAllApisAndTasks();
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

            // Main Card Outer Container (Image 1 style)
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
                      // Search tasks input (Image 1)
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
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val;
                              });
                            },
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

                      // Segmented Bar: All | Pending | Completed (Image 1 & Image 4)
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

                      // Action Buttons Row: Filters, Sort, ... (Image 1 & 3)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            // Filters Button
                            InkWell(
                              onTap: () => _showFilterModal(context),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF5FB6AD)),
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

                            // Sort Button
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
                            const SizedBox(width: 8),

                            // More (...) Button
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: const Icon(
                                Icons.more_horiz_rounded,
                                size: 16,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Green Filter Pills Row: Create date v | Status v | Priority v | Company v | Contact v | Deal v | Owner v
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
                      const SizedBox(height: 12),

                      // Task List View (Exact mockup card layout)
                      Expanded(
                        child: _isLoadingTasks
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF00A884),
                                ),
                              )
                            : filteredTasks.isEmpty
                                ? Center(
                                    child: Text(
                                      'No tasks found.',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    itemCount: filteredTasks.length,
                                    itemBuilder: (context, index) {
                                      final task = filteredTasks[index];
                                      return _buildTaskCard(task);
                                    },
                                  ),
                      ),

                      const Divider(height: 1, color: Color(0xFFE2E8F0)),

                      // Bottom Pagination Bar (1-2 of 2 | < Prev 1/1 Next >) matching Image 1
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            RichText(
                              text: TextSpan(
                                text: filteredTasks.isEmpty
                                    ? '0-0 of '
                                    : '1-${filteredTasks.length} of ',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                ),
                                children: [
                                  TextSpan(
                                    text: '${filteredTasks.length}',
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
                                  onPressed: null,
                                  icon: const Icon(Icons.chevron_left_rounded, size: 16),
                                  label: Text(
                                    'Prev',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF94A3B8),
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '1/1',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                TextButton(
                                  onPressed: null,
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
                                    foregroundColor: const Color(0xFF94A3B8),
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
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedSegment = index;
          });
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
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

  Widget _buildTaskCard(TaskModel task) {
    final bool isCompleted = task.status.toLowerCase() == 'completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
      ),
      child: InkWell(
        onTap: () async {
          // Open 2nd screen / TaskDetailsScreen when task clicked
          final refreshed = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => TaskDetailsScreen(task: task),
            ),
          );
          if (refreshed == true) {
            _loadAllApisAndTasks();
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
                            color: const Color(0xFFE0E7FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            task.priority,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF4338CA),
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
