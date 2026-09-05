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
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/utils/activity_delete.dart';
import '../../../../core/utils/activity_utils.dart';
import '../../../../core/utils/activity_task_fields.dart';
import '../../../../core/utils/department_aware_state.dart';
import '../../../../core/repositories/master_data_repository.dart';
import '../../../../core/utils/filter_query_utils.dart';
import '../../../../core/utils/list_scroll_utils.dart';
import '../../../../core/utils/task_query_builder.dart';
import '../../../../core/utils/task_status_filter.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../departments/presentation/providers/department_provider.dart';
import '../../../navigation/presentation/providers/navigation_provider.dart';
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

class _TasksScreenState extends State<TasksScreen> with DepartmentAwareState {
  /// All / Pending / Completed. Drives both the `status` sent to the API and
  /// the check applied to what comes back.
  TaskStatusTab _statusTab = TaskStatusTab.all;

  /// Ids of the tasks ticked for deletion. Only ids that are currently on
  /// screen are kept, so a delete can never reach a task the user cannot see.
  final Set<String> _selectedForDelete = {};
  bool _isDeleting = false;
  bool _isCompleting = false;

  String _searchQuery = '';
  Timer? _searchDebounce;
  final List<TaskModel> _tasks = [];
  bool _isLoadingTasks = false;

  /// Incremented for every request; only the newest one is allowed to write
  /// its answer into the list.
  int _requestSeq = 0;

  /// The department the tasks on screen belong to.
  String? _loadedDepartmentId;

  bool _showFiltersRow = false;
  int _currentPage = 1;
  final int _pageSize = 25;
  int _totalTasks = 0;
  String? _errorMessage;

  /// Id of the task whose details view was opened from this list. Held by id so
  /// the highlight survives a reload of the list.
  String? _selectedTaskId;

  /// A task another screen asked for — tapping its notification — applied once
  /// the list has loaded. [_appliedFocusId] remembers which request has already
  /// been honoured, so the same one is not re-applied on every rebuild.
  String? _pendingFocusId;
  String? _appliedFocusId;
  bool _hasLoadedOnce = false;

  /// Marks the highlighted row so it can be scrolled to once it is built.
  final GlobalKey _selectedTileKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

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
    _scrollController.dispose();
    super.dispose();
  }

  /// Highlights the task another screen asked for and brings it into view.
  ///
  /// Does nothing until the list has loaded — [_fetchTasks] calls back in once
  /// it has. A task that is not in the loaded page (deleted, on another page,
  /// or hidden by the selected tab) leaves the screen as it is rather than
  /// scrolling somewhere arbitrary.
  Future<void> _applyPendingFocus() async {
    final id = _pendingFocusId;
    if (id == null || !_hasLoadedOnce || _isLoadingTasks) return;

    _pendingFocusId = null;

    if (!_tasks.any((t) => t.id == id)) {
      debugPrint('[TasksScreen] task $id was asked for but is not in the loaded page');
      return;
    }
    if (!mounted) return;

    setState(() => _selectedTaskId = id);
    await ensureListItemVisible(
      controller: _scrollController,
      itemKey: _selectedTileKey,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The previous department's tasks — and the company/contact/deal/user
    // lists behind the filter pills — are wiped as soon as the switch starts,
    // so none of them stay on screen while the access token is being swapped.
    // The reload runs once that swap is done: the API reads the department
    // from the token, so fetching any earlier answers with the department
    // being left.
    watchDepartmentChanges(
      (_) => _loadMasterDataAndFetchTasks(),
      onSwitchStarted: _clearDepartmentScopedData,
    );

    // A task opened from elsewhere in the app — tapping its notification. The
    // id arrives on `NavigationProvider`; the row is highlighted once the list
    // holding it has loaded.
    final requested = context.watch<NavigationProvider>().focusedActivityId;
    if (requested != null && requested != _appliedFocusId) {
      _appliedFocusId = requested;
      _pendingFocusId = requested;
      // Off the build phase: applying the focus calls setState.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyPendingFocus();
      });
    }
  }

  /// Drops everything on screen that belongs to one department.
  void _clearDepartmentScopedData() {
    if (!mounted) return;
    setState(() {
      _tasks.clear();
      _totalTasks = 0;
      _currentPage = 1;
      _loadedDepartmentId = null;
      _selectedTaskId = null;
      _selectedForDelete.clear();
      _users = [];
      _companies = [];
      _contacts = [];
      _deals = [];
    });
  }

  Future<void> _loadMasterDataAndFetchTasks() async {
    final repository = MasterDataRepositoryImpl();
    final apiService = ApiService();

    // These four lists populate the Company / Contact / Deal / Owner filter
    // pills. They used to be fetched unscoped, so the pills offered records
    // belonging to other departments.
    final deptId = currentDepartmentId();
    final deptScope = {'department_id': deptId, 'departmentId': deptId};

    try {
      try {
        _taskStatuses = await repository.getMasterDropdownByKey('task_status', includeInactive: false);
      } catch (_) {}
      try {
        _taskPriorities = await repository.getMasterDropdownByKey('task_priority', includeInactive: false);
      } catch (_) {}

      try {
        final uResp = await apiService.get('/users', queryParameters: deptScope);
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
        final cResp = await apiService.get('/companies', queryParameters: {'limit': 200, ...deptScope});
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
        final contResp = await apiService.get('/contacts', queryParameters: {'limit': 200, ...deptScope});
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
        final dResp = await apiService.get('/deals', queryParameters: {'limit': 200, ...deptScope});
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

  /// The `sort` value for the selected sort option.
  ///
  /// These are activity column names as `/api/activities` spells them —
  /// camelCase, and a task's due date is its `scheduledAt`. `created_at` and
  /// `dueDate` are not columns on that table, so sorting by them left the
  /// order up to whatever the backend falls back to.
  String _getSortField() {
    switch (_selectedSortOption) {
      case 'Due Date (Earliest)':
      case 'Due Date (Latest)':
        return 'scheduledAt';
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

    final targetPage = resetPage ? 1 : (page ?? _currentPage);

    // A newer request always wins. The in-flight one is not cancelled — Dio
    // has no handle on it here — but its answer is dropped when it lands, so
    // a slow reply for the department just left cannot repopulate the list.
    // This also replaces an early return on "already loading", which used to
    // make a department switch during a fetch do nothing at all.
    final requestSeq = ++_requestSeq;

    setState(() {
      _isLoadingTasks = true;
      _errorMessage = null;
      if (resetPage) _currentPage = 1;
    });

    final apiService = ApiService();

    // The selected department, read at the moment the request is built. The
    // same value is checked again when the response lands.
    final deptId = context.read<DepartmentProvider>().selectedDepartmentId;
    // Read here, while the context is still safe to use, for the request log.
    final loggedInUserId = context.read<AuthProvider>().currentUser?.id;

    // The All / Pending / Completed tab and the Status pill both set the same
    // field, so the tab wins while it is narrowing and the pill applies under
    // All. The value is the backend's own, taken from `task_status`.
    final tabStatus = taskStatusValueFor(_statusTab, statusOptions: _taskStatuses);
    String? status;
    if (tabStatus != null) {
      status = tabStatus;
      if (_selectedStatusFilter != 'Status') {
        debugPrint('[TasksScreen] status pill "$_selectedStatusFilter" is not sent '
            'while the ${_statusTab.name} tab is selected');
      }
    } else if (_selectedStatusFilter != 'Status') {
      status = _selectedStatusFilter.toLowerCase();
    }

    String? ownerId;
    if (_selectedOwnerFilter != 'Owner') {
      final matchedUser = _users.firstWhere(
        (u) => '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim().toLowerCase() == _selectedOwnerFilter.toLowerCase(),
        orElse: () => {},
      );
      ownerId = (matchedUser['id'] ?? matchedUser['_id'])?.toString();
    }

    final queryParams = buildTaskListQuery(
      page: targetPage,
      limit: _pageSize,
      departmentId: deptId,
      sort: _getSortField(),
      order: _getSortOrder(),
      search: _searchQuery,
      status: status,
      priority: _selectedPriorityFilter != 'Priority' ? _selectedPriorityFilter.toLowerCase() : null,
      ownerId: ownerId,
      // The Create date pill used to be recorded and then never used — it now
      // becomes the documented `createdDateRange` value.
      createdDateRange: FilterDateRange.toQueryValue(_selectedCreateDate),
      // Company / Contact / Deal pills hold the record's display name; the API
      // filters by id, so the name is resolved back to one here.
      companyId: _resolveCompanyId(),
      contactId: _resolveContactId(),
      dealId: _resolveDealId(),
    );

    debugPrint('[TasksScreen] GET ${ApiConstants.activities} query: $queryParams');

    try {
      final response = await apiService.get(
        ApiConstants.activities,
        queryParameters: queryParams,
      );

      if (!mounted) return;

      // Anything that arrives after a newer request went out, or after the
      // department changed, is thrown away rather than rendered.
      final currentDeptId = context.read<DepartmentProvider>().selectedDepartmentId;
      if (!shouldApplyTaskResponse(
        responseSeq: requestSeq,
        latestSeq: _requestSeq,
        requestedDepartmentId: deptId,
        selectedDepartmentId: currentDeptId,
      )) {
        debugPrint('[TasksScreen] dropped a stale response asked for department $deptId '
            '(request $requestSeq of $_requestSeq, $currentDeptId is selected now)');
        return;
      }

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

      // One line per request, so a count that disagrees with the Web CRM can
      // be settled by comparing the two requests rather than the two screens.
      // `meta.total` is the count this screen shows: it is the total for the
      // filters that were actually sent, so the All tab reports every task and
      // the Completed tab reports the completed ones.
      debugPrint('========== TASKS API ==========\n'
          'Request URL       : ${ApiConstants.baseUrl}${ApiConstants.activities}\n'
          'Query Parameters  : $queryParams\n'
          'Status tab        : ${_statusTab.name} (status=${status ?? 'none'})\n'
          'Department ID     : ${deptId.isEmpty ? '(from token)' : deptId}\n'
          'Logged-in User ID : ${loggedInUserId ?? 'unknown'}\n'
          'Response Status   : ${response.statusCode}\n'
          'meta.total        : $total\n'
          'meta.page         : $resPage\n'
          'meta.limit        : $_pageSize\n'
          'data.length       : ${records.length}\n'
          '===============================');

      // Everything below comes from the row the API returned. Where a field is
      // missing the record says so — no placeholder person, date or status is
      // filled in on its behalf.
      final loadedTasks = records.whereType<Map>().map((e) {
        final item = Map<String, dynamic>.from(e);
        final id = (item['id'] ?? item['_id'])?.toString();
        final title = (item['title'] ?? item['subject'] ?? item['notes'] ?? 'Untitled task').toString();
        final dueDate = activityDueLabel(item) ?? '—';
        final priority = (item['priority'] ?? '').toString();
        final status = (item['status'] ?? '').toString();
        final assignedTo = activityAssigneeLabel(item) ?? 'Unassigned';
        final notes = parseActivityDescription(item['description'] ?? item['notes'] ?? '');
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
          queue: item['queue']?.toString() ?? 'None',
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
          _loadedDepartmentId = deptId;
          // A tick only survives while its task is still on screen, so a
          // reload, a page change or a deletion cannot leave a selection
          // pointing at something the user is no longer looking at.
          final loadedIds = loadedTasks.map((t) => t.id).whereType<String>().toSet();
          _selectedForDelete.removeWhere((id) => !loadedIds.contains(id));
          if (_selectedTaskId != null && !loadedIds.contains(_selectedTaskId)) {
            _selectedTaskId = null;
          }
        });
        debugPrint('[TasksScreen] loaded ${loadedTasks.length} of $total task(s) '
            'for department $deptId (page $resPage)');
        _logStatusMismatch(loadedTasks);
        // The list is populated now, so a task requested by a notification —
        // including one requested before this load started — can be located.
        _hasLoadedOnce = true;
        _applyPendingFocus();
      }
    } catch (e) {
      debugPrint('[FETCH ${ApiConstants.activities} ERROR]: $e');
      // An error from a request that has already been superseded must not
      // replace the newer request's state either.
      if (mounted && requestSeq == _requestSeq) {
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

  // ---------------------------------------------------------------------------
  // Status tabs
  // ---------------------------------------------------------------------------

  /// The loaded tasks that belong under the selected tab.
  ///
  /// `status` is sent to the API as well, so this is normally the whole page.
  /// It is applied again here because the tab's promise — a completed task
  /// never shows under Pending — has to hold even if the backend ignores the
  /// parameter, and it is checked against the status the API itself returned.
  /// True while the loaded rows belong to a department that is no longer the
  /// selected one — the gap between the switch and the new response landing.
  bool get _isShowingOtherDepartment {
    final loaded = _loadedDepartmentId;
    if (loaded == null) return false;
    // The dependency on the provider is already established by
    // `watchDepartmentChanges`, so this only reads the current value.
    return loaded != context.read<DepartmentProvider>().selectedDepartmentId;
  }

  List<TaskModel> get _visibleTasks {
    // Rows belonging to the previous department are never rendered, not even
    // for the frame between the switch and the reload.
    if (_isShowingOtherDepartment) return const [];
    if (_statusTab == TaskStatusTab.all) return List.unmodifiable(_tasks);
    return _tasks
        .where((t) => taskStatusMatchesTab(t.status, _statusTab, statusOptions: _taskStatuses))
        .toList();
  }

  /// Reports rows the API returned that the selected tab does not accept —
  /// the signal that the backend ignored the `status` it was sent.
  void _logStatusMismatch(List<TaskModel> loaded) {
    if (_statusTab == TaskStatusTab.all || loaded.isEmpty) return;
    final dropped = loaded
        .where((t) => !taskStatusMatchesTab(t.status, _statusTab, statusOptions: _taskStatuses))
        .toList();
    if (dropped.isEmpty) return;
    debugPrint('[TasksScreen] the ${_statusTab.name} tab hid ${dropped.length} of '
        '${loaded.length} loaded rows, with statuses ${dropped.map((t) => t.status).toSet()} — '
        'the API returned rows the status filter did not ask for.');
  }

  void _onStatusTabChanged(TaskStatusTab tab) {
    if (_statusTab == tab) return;
    setState(() {
      _statusTab = tab;
      // Ticks are dropped so a delete can only ever act on what is on screen.
      _selectedForDelete.clear();
    });
    _fetchTasks(resetPage: true);
  }

  String get _emptyListMessage {
    switch (_statusTab) {
      case TaskStatusTab.pending:
        return 'No pending tasks.';
      case TaskStatusTab.completed:
        return 'No completed tasks.';
      case TaskStatusTab.all:
        return 'No tasks found.';
    }
  }

  // ---------------------------------------------------------------------------
  // Selection and deletion
  // ---------------------------------------------------------------------------

  void _toggleSelection(TaskModel task) {
    final id = task.id;
    if (id == null || id.isEmpty) {
      debugPrint('[TasksScreen] "${task.title}" has no id and cannot be selected for deletion');
      return;
    }
    setState(() {
      if (!_selectedForDelete.remove(id)) _selectedForDelete.add(id);
    });
  }

  /// The ticked tasks that are actually on screen under the current tab.
  List<TaskModel> get _tasksToDelete => _visibleTasks
      .where((t) => t.id != null && _selectedForDelete.contains(t.id))
      .toList();

  Future<void> _confirmAndDeleteSelected() async {
    final targets = _tasksToDelete;
    if (targets.isEmpty || _isDeleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          targets.length == 1 ? 'Delete task' : 'Delete ${targets.length} tasks',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          targets.length == 1
              ? 'Are you sure you want to delete "${targets.single.title}"? This cannot be undone.'
              : 'Are you sure you want to delete these ${targets.length} tasks? This cannot be undone.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);

    final result = await deleteActivities(targets.map((t) => t.id!));
    final failed = result.failed;
    final deletedCount = result.deleted.length;

    if (!mounted) return;

    setState(() {
      _isDeleting = false;
      // Only what the backend actually removed loses its tick; anything that
      // failed stays selected and on screen so it can be retried.
      _selectedForDelete
        ..clear()
        ..addAll(failed);
    });

    if (deletedCount > 0) {
      // The current page and every filter are kept, so the list comes back
      // under the same tab the user was working in.
      await _fetchTasks(page: _currentPage);
      if (mounted && _tasks.isEmpty && _currentPage > 1) {
        await _fetchTasks(page: _currentPage - 1);
      }
    }

    if (!mounted) return;

    if (failed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deletedCount == 1 ? 'Task deleted successfully' : '$deletedCount tasks deleted successfully',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          backgroundColor: const Color(0xFF00A884),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deletedCount > 0
                ? '$deletedCount deleted, ${failed.length} could not be deleted. Please try again.'
                : 'Could not delete ${failed.length == 1 ? 'the task' : 'the selected tasks'}. Please try again.',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _markSelectedAsCompleted() async {
    final targets = _tasksToDelete;
    if (targets.isEmpty || _isCompleting || _isDeleting) return;

    setState(() => _isCompleting = true);

    final apiService = ApiService();
    int completedCount = 0;
    int failedCount = 0;

    for (final task in targets) {
      if (task.id == null || task.id!.isEmpty) continue;
      try {
        await apiService.put(
          '${ApiConstants.activities}/${task.id}',
          data: {'status': 'completed'},
        );
        completedCount++;
      } catch (e) {
        debugPrint('[Mark completed PUT error for ${task.id}]: $e');
        try {
          await apiService.patch(
            '${ApiConstants.activities}/${task.id}',
            data: {'status': 'completed'},
          );
          completedCount++;
        } catch (patchErr) {
          debugPrint('[Mark completed PATCH error for ${task.id}]: $patchErr');
          failedCount++;
        }
      }
    }

    if (!mounted) return;

    setState(() {
      _isCompleting = false;
      _selectedForDelete.clear();
    });

    if (completedCount > 0) {
      await _fetchTasks(page: _currentPage);
    }

    if (!mounted) return;

    if (failedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            completedCount == 1 ? 'Task completed successfully' : '$completedCount tasks marked as completed',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          backgroundColor: const Color(0xFF00A884),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            completedCount > 0
                ? '$completedCount completed, $failedCount could not be updated.'
                : 'Failed to update selected tasks. Please try again.',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    final visibleTasks = _visibleTasks;
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
                          // Shown straight away, matched by id so a second save
                          // of the same task cannot list it twice. The count is
                          // deliberately left alone — it is `meta.total` from
                          // the reload below, never a number incremented here.
                          _tasks.removeWhere((t) => t.id == newTask.id);
                          _tasks.insert(0, newTask);
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
                    filterBeforeSearch: true,
                    searchHint: 'Search tasks...',
                    // The list is scoped by the All / Pending / Completed tabs
                    // below, so the All / Mine pill is not shown here.
                    showSegments: false,
                    onSearchChanged: _onSearchChanged,
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

                  const SizedBox(height: 10),
                  _buildStatusTabs(),

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
                      if (_tasksToDelete.isNotEmpty) _buildSelectionBar(),
                      Expanded(
                        child: AppRefreshIndicator(
                          onRefresh: () async {
                            await _fetchTasks(resetPage: true);
                          },
                          // A department switch shows the spinner straight
                          // away rather than an empty list, because the reload
                          // for the new department is about to go out.
                          child: _isLoadingTasks || _isShowingOtherDepartment
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
                                  : visibleTasks.isEmpty
                                      ? ListView(
                                          physics: const AlwaysScrollableScrollPhysics(
                                              parent: BouncingScrollPhysics()),
                                          children: [
                                            const SizedBox(height: 120),
                                            Center(
                                              child: Text(
                                                _emptyListMessage,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 13,
                                                  color: const Color(0xFF64748B),
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : ListView.builder(
                                          controller: _scrollController,
                                          physics: const AlwaysScrollableScrollPhysics(
                                              parent: BouncingScrollPhysics()),
                                          padding: const EdgeInsets.symmetric(horizontal: 14),
                                          itemCount: visibleTasks.length,
                                          itemBuilder: (context, index) {
                                            final task = visibleTasks[index];
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
                            // The range gives way to the pager instead of
                            // pushing it past the edge of the row.
                            Flexible(
                              child: RichText(
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
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



  /// All | Pending | Completed.
  Widget _buildStatusTabs() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 36,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                _buildStatusTabItem(TaskStatusTab.all, 'All'),
                _buildStatusTabItem(TaskStatusTab.pending, 'Pending'),
                _buildStatusTabItem(TaskStatusTab.completed, 'Completed'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusTabItem(TaskStatusTab tab, String label) {
    final isSelected = _statusTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: _isDeleting ? null : () => _onStatusTabChanged(tab),
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    )
                  ]
                : [],
          ),
          child: Center(
            // The app scales its text, so "Completed" is allowed to shrink
            // inside its third of the row rather than overflow it.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  label,
                  maxLines: 1,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? const Color(0xFF111827) : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Shown only while something is ticked.
  Widget _buildSelectionBar() {
    final count = _tasksToDelete.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFFE6F4F1),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: (_isDeleting || _isCompleting) ? null : () => setState(_selectedForDelete.clear),
            icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
            tooltip: 'Clear selection',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              count == 1 ? '1 selected' : '$count selected',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
          ),
          const SizedBox(width: 4),
          ElevatedButton.icon(
            onPressed: (_isDeleting || _isCompleting) ? null : _markSelectedAsCompleted,
            icon: _isCompleting
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_circle_outline_rounded, size: 14, color: Colors.white),
            label: Text(
              'Complete',
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A884),
              disabledBackgroundColor: const Color(0xFF00A884),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
          const SizedBox(width: 6),
          ElevatedButton.icon(
            onPressed: (_isDeleting || _isCompleting) ? null : _confirmAndDeleteSelected,
            icon: _isDeleting
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.delete_outline_rounded, size: 14, color: Colors.white),
            label: Text(
              'Delete',
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              disabledBackgroundColor: const Color(0xFFEF4444),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
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

  /// A small rounded label — the status and priority the API returned.
  Widget _buildTaskChip(String text, {required Color background, required Color foreground}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }

  Widget _buildTaskCard(TaskModel task) {
    final bool isCompleted =
        taskStatusMatchesTab(task.status, TaskStatusTab.completed, statusOptions: _taskStatuses);
    final bool isSelected = task.id != null && task.id == _selectedTaskId;
    final bool isTicked = task.id != null && _selectedForDelete.contains(task.id);
    final bool isSelecting = _selectedForDelete.isNotEmpty;

    // The contact, company or deal this task hangs off, when the row names one.
    final String? relatedRecord =
        task.rawMap == null ? null : activityRelatedRecordLabel(task.rawMap!);

    return Container(
      // The key rides along with the highlight so the highlighted row can
      // always be scrolled to, however it came to be highlighted.
      key: isSelected ? _selectedTileKey : null,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isTicked
            ? const Color(0xFFFFF1F0)
            : (isSelected ? const Color(0xFFE6F4F1) : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTicked
              ? const Color(0xFFEF4444)
              : (isSelected ? const Color(0xFF00A884) : const Color(0xFFCBD5E1)),
          width: isTicked || isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: () async {
          // While a selection is being built, tapping a card adds to it rather
          // than navigating away from it.
          if (isSelecting) {
            _toggleSelection(task);
            return;
          }

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
              // Selection checkbox — ticking tasks is what the Delete button
              // acts on.
              GestureDetector(
                onTap: () => _toggleSelection(task),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(top: 2, right: 12),
                  decoration: BoxDecoration(
                    color: isTicked ? const Color(0xFFEF4444) : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isTicked ? const Color(0xFFEF4444) : const Color(0xFFCBD5E1),
                      width: 1.5,
                    ),
                  ),
                  child: isTicked
                      ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                      : null,
                ),
              ),

              // Activity type icon, previously shown inside the box above.
              if (task.taskType != null && !task.taskType!.toLowerCase().contains('task'))
                Padding(
                  padding: const EdgeInsets.only(top: 3, right: 8),
                  child: Icon(
                    task.taskType!.toLowerCase().contains('note')
                        ? Icons.description_outlined
                        : (task.taskType!.toLowerCase().contains('email')
                            ? Icons.mail_outline_rounded
                            : (task.taskType!.toLowerCase().contains('call')
                                ? Icons.phone_outlined
                                : (task.taskType!.toLowerCase().contains('meeting')
                                    ? Icons.videocam_outlined
                                    : Icons.task_alt_rounded))),
                    size: 16,
                    color: const Color(0xFF00A884),
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
                    // Wrap, not Row: a long due date and the status chip move
                    // onto a second line instead of overflowing the card.
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Due: ${task.dueDate}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(0xFF475569),
                          ),
                        ),
                        if (task.status.trim().isNotEmpty)
                          // The status exactly as the API returned it, so what
                          // the tabs filter on stays visible on the card.
                          _buildTaskChip(
                            task.status,
                            background: isCompleted ? const Color(0xFFE6F4F1) : const Color(0xFFF1F5F9),
                            foreground: isCompleted ? const Color(0xFF00A884) : const Color(0xFF64748B),
                          ),
                        if (task.priority.trim().isNotEmpty &&
                            task.priority.trim().toLowerCase() != 'none')
                          _buildTaskChip(
                            task.priority,
                            background: _getPriorityColor(task.priority).withValues(alpha: 0.12),
                            foreground: _getPriorityColor(task.priority),
                          ),
                      ],
                    ),
                    if (parseActivityDescription(task.notes).trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        parseActivityDescription(task.notes).trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      relatedRecord == null
                          ? 'Assigned: ${task.assignedTo}'
                          : 'Assigned: ${task.assignedTo}  ·  $relatedRecord',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
