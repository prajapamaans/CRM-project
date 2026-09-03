import 'package:flutter/material.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/network/network_exception.dart';
import '../../../../core/repositories/master_data_repository.dart';
import '../../../../core/storage/follow_up_link_storage.dart';
import '../../../../core/utils/department_scope.dart';
import '../../../../core/utils/follow_up_task_request.dart';
import '../../../authentication/data/models/team_member_model.dart';
import '../../data/models/activity_stats_model.dart';
import '../../data/models/dashboard_unified_model.dart';
import '../../data/models/dashboard_leaderboard_model.dart';
import '../../data/repositories/dashboard_repository.dart';

class TaskWorkGroup {
  final List<Map<String, dynamic>> pendingTasks;
  final List<Map<String, dynamic>> completedTasks;

  TaskWorkGroup({
    required this.pendingTasks,
    required this.completedTasks,
  });

  int get pendingCount => pendingTasks.length;
  int get completedCount => completedTasks.length;
  int get totalCount => pendingCount + completedCount;

  int get progressPercent {
    if (totalCount == 0) return 0;
    return ((completedCount / totalCount) * 100).round();
  }
}

class DashboardProvider extends ChangeNotifier {
  final DashboardRepository _repository;
  final ApiService _apiService;

  /// Which department every in-flight request was issued for.
  ///
  /// The Dashboard fires seven requests at once and the user can change
  /// department while they are in the air. Without this, whichever answer came
  /// back last won — so a slow request for the department they just left could
  /// repaint the Dashboard with its records under the new department's name.
  final DepartmentRequestGuard _guard = DepartmentRequestGuard();

  // One key per section, so reloading one does not discard another's answer.
  static const String _statsKey = 'stats';
  static const String _feedKey = 'feed';
  static const String _reportsKey = 'reports';
  static const String _tasksKey = 'tasks';
  static const String _leaderboardKey = 'leaderboard';
  static const String _contactCountsKey = 'contactCounts';
  static const String _callMeetingKey = 'callAndMeeting';

  DashboardProvider({DashboardRepository? repository, ApiService? apiService})
      : _repository = repository ?? DashboardRepositoryImpl(),
        _apiService = apiService ?? ApiService();

  /// The department the Dashboard is currently showing, as last requested.
  String get activeDepartmentId => _guard.activeDepartmentId;

  ActivityStatsModel? _stats;
  DashboardUnifiedResponseModel? _unifiedFeed;
  Map<String, dynamic>? _reportsDashboardData;
  List<Map<String, dynamic>> _dashboardTasks = [];
  List<ActivityLeaderboardItem> _activityLeaderboard = [];
  List<ContactOwnerCountItem> _contactOwnerCounts = [];
  List<CallAndMeetingRepItem> _callAndMeetingTotals = [];
  String _leaderboardSubtitleLabel = 'LAST 7 DAYS';
  String? _currentOwnerId;
  String? _currentDepartmentId;

  bool _isLoadingStats = false;
  bool _isLoadingFeed = false;
  bool _isLoadingTasks = false;
  bool _isLoadingLeaderboard = false;
  bool _isLoadingContactCounts = false;
  bool _isLoadingCallAndMeeting = false;

  String? _statsError;
  String? _feedError;
  String? _tasksError;
  String? _leaderboardError;
  String? _contactCountsError;
  String? _callAndMeetingError;

  ActivityStatsModel? get stats => _stats;
  DashboardUnifiedResponseModel? get unifiedFeed => _unifiedFeed;
  Map<String, dynamic>? get reportsDashboardData => _reportsDashboardData;
  List<DashboardActivityItem> get activities {
    final items = _unifiedFeed?.data ?? [];
    if (_currentOwnerId != null && _currentOwnerId!.isNotEmpty) {
      return items.where((item) {
        if (item.ownerId != null && item.ownerId!.isNotEmpty && item.ownerId != _currentOwnerId) {
          return false;
        }
        return true;
      }).toList();
    }
    return items;
  }
  List<Map<String, dynamic>> get dashboardTasks => _dashboardTasks;
  List<ActivityLeaderboardItem> get activityLeaderboard => _activityLeaderboard;
  List<ContactOwnerCountItem> get contactOwnerCounts => _contactOwnerCounts;
  List<CallAndMeetingRepItem> get callAndMeetingTotals => _callAndMeetingTotals;
  String get leaderboardSubtitleLabel => _leaderboardSubtitleLabel;

  bool get isLoadingStats => _isLoadingStats;
  bool get isLoadingFeed => _isLoadingFeed;
  bool get isLoadingTasks => _isLoadingTasks;
  bool get isLoadingLeaderboard => _isLoadingLeaderboard;
  bool get isLoadingContactCounts => _isLoadingContactCounts;
  bool get isLoadingCallAndMeeting => _isLoadingCallAndMeeting;
  bool get isLoading =>
      _isLoadingStats ||
      _isLoadingFeed ||
      _isLoadingTasks ||
      _isLoadingLeaderboard ||
      _isLoadingContactCounts ||
      _isLoadingCallAndMeeting;

  String? get statsError => _statsError;
  String? get feedError => _feedError;
  String? get tasksError => _tasksError;
  String? get leaderboardError => _leaderboardError;
  String? get contactCountsError => _contactCountsError;
  String? get callAndMeetingError => _callAndMeetingError;

  Future<void> loadDashboardData({
    String? ownerId,
    String? departmentId,
    String? departmentName,
    String? startDate,
    String? endDate,
    String? subtitleLabel,
    List<TeamMemberModel>? teamMembers,
    List<Map<String, dynamic>>? reportUsers,
  }) async {
    _currentOwnerId = ownerId;
    _currentDepartmentId = departmentId;

    debugPrint('==================================================');
    debugPrint('[DASHBOARD PROVIDER DATA LOAD]');
    debugPrint('Mode: ${ownerId != null && ownerId.isNotEmpty ? "MY_WORK" : "TEAM"}');
    debugPrint('Logged-in / Owner ID: ${ownerId ?? 'NONE (TEAM MODE)'}');
    debugPrint('Selected Department Name: ${departmentName ?? 'N/A'}');
    debugPrint('Selected Department ID: ${departmentId ?? 'N/A'}');
    debugPrint('Dashboard Start Date: ${startDate ?? 'N/A'}');
    debugPrint('Dashboard End Date: ${endDate ?? 'N/A'}');
    debugPrint('==================================================');

    // Clear previous state to prevent showing stale data while loading new department/mode
    _stats = null;
    _unifiedFeed = null;
    _reportsDashboardData = null;
    _dashboardTasks = [];
    _activityLeaderboard = [];
    _contactOwnerCounts = [];
    _callAndMeetingTotals = [];
    notifyListeners();

    await Future.wait([
      fetchActivityStats(
        ownerId: ownerId,
        departmentId: departmentId,
        startDate: startDate,
        endDate: endDate,
      ),
      fetchDashboardUnified(
        ownerId: ownerId,
        departmentId: departmentId,
        startDate: startDate,
        endDate: endDate,
      ),
      fetchReportsDashboardsDefault(
          departmentId: departmentId, ownerId: ownerId, departmentName: departmentName),
      fetchDashboardTasks(
        ownerId: ownerId,
        departmentId: departmentId,
      ),
      fetchActivityLeaderboard(
          startDate: startDate,
          endDate: endDate,
          subtitleLabel: subtitleLabel,
          departmentId: departmentId,
          teamMembers: teamMembers,
          reportUsers: reportUsers),
      fetchContactOwnerCounts(
          departmentId: departmentId,
          teamMembers: teamMembers,
          reportUsers: reportUsers),
      fetchCallAndMeetingTotals(
          departmentId: departmentId,
          teamMembers: teamMembers,
          reportUsers: reportUsers),
    ]);
  }

  Future<void> fetchDashboardTasks({
    String? ownerId,
    String? departmentId,
  }) async {
    final ticket = _guard.begin(_tasksKey, departmentId);
    _isLoadingTasks = true;
    _tasksError = null;
    notifyListeners();

    try {
      final masterRepo = MasterDataRepositoryImpl();
      // Fetch type=task with limit=200 and no status filter so both pending and completed are returned
      final fetched = await masterRepo.getActivities(
        type: 'task',
        limit: 200,
        ownerId: ownerId,
        departmentId: departmentId,
      );
      if (!_guard.mayApply(_tasksKey, ticket, departmentId)) return;
      _dashboardTasks = fetched;
    } catch (e) {
      debugPrint('[DashboardProvider fetchDashboardTasks Error]: $e');
      if (!_guard.mayApply(_tasksKey, ticket, departmentId)) return;
      _tasksError = e.toString();
    } finally {
      // A superseded request must not clear the loading flag either — the
      // request that replaced it is still running.
      if (_guard.mayApply(_tasksKey, ticket, departmentId)) {
        _isLoadingTasks = false;
        notifyListeners();
      }
    }
  }

  /// Reusable date + status task classification mechanism.
  /// Uses [scheduledAt] (fallback to dueDate/createdAt), converts UTC to local timezone,
  /// and compares calendar date with [date].
  TaskWorkGroup getTasksForDate(DateTime date) {
    final targetYear = date.year;
    final targetMonth = date.month;
    final targetDay = date.day;

    final List<Map<String, dynamic>> pending = [];
    final List<Map<String, dynamic>> completed = [];

    // Combine candidate tasks from _dashboardTasks AND _unifiedFeed.data
    final List<Map<String, dynamic>> candidateTasks = [..._dashboardTasks];
    final Set<String> existingIds = candidateTasks
        .map((t) => (t['id'] ?? t['_id'])?.toString())
        .whereType<String>()
        .toSet();

    if (_unifiedFeed != null) {
      for (final act in _unifiedFeed!.data) {
        final actType = (act.type ?? '').toLowerCase();
        if (actType == 'task' || actType == 'to-do' || actType == 'todo') {
          if (!existingIds.contains(act.id)) {
            existingIds.add(act.id);
            candidateTasks.add({
              'id': act.id,
              'title': act.title,
              'type': act.type,
              'status': act.status,
              'scheduledAt': act.dueDate ?? act.createdAt,
              'dueDate': act.dueDate,
              'createdAt': act.createdAt,
              'description': act.description,
              'ownerId': act.ownerId,
              'ownerName': act.ownerName,
            });
          }
        }
      }
    }

    int totalCandidates = candidateTasks.length;
    int deptMatchedCount = 0;
    int ownerMatchedCount = 0;
    int finalMatchedCount = 0;

    for (final task in candidateTasks) {
      // 1. Department Filter Check
      final taskDeptId = (task['departmentId'] ??
              task['department_id'] ??
              (task['department'] is Map ? task['department']['id'] : null) ??
              (task['department'] is Map ? task['department']['_id'] : null))
          ?.toString()
          .trim();
      bool deptMatch = true;
      if (_currentDepartmentId != null && _currentDepartmentId!.isNotEmpty) {
        if (taskDeptId != null && taskDeptId.isNotEmpty && taskDeptId != _currentDepartmentId) {
          deptMatch = false;
        }
      }
      if (deptMatch) deptMatchedCount++;

      // 2. Owner Filter Check (for MY WORK mode)
      bool ownerMatch = true;
      if (_currentOwnerId != null && _currentOwnerId!.isNotEmpty) {
        final taskOwnerId = (task['ownerId'] ??
                task['owner_id'] ??
                (task['owner'] is Map ? task['owner']['id'] : null) ??
                (task['owner'] is Map ? task['owner']['_id'] : null) ??
                task['userId'] ??
                task['user_id'])
            ?.toString()
            .trim();
        if (taskOwnerId != null && taskOwnerId.isNotEmpty && taskOwnerId != _currentOwnerId) {
          ownerMatch = false;
        }
      }
      if (ownerMatch) ownerMatchedCount++;

      if (!deptMatch || !ownerMatch) continue;
      finalMatchedCount++;

      final rawScheduled = task['scheduledAt'] ??
          task['scheduled_at'] ??
          task['dueDate'] ??
          task['due_date'] ??
          task['createdAt'] ??
          task['created_at'];

      if (rawScheduled == null) continue;

      DateTime? dt;
      if (rawScheduled is DateTime) {
        dt = rawScheduled;
      } else {
        final str = rawScheduled.toString().trim();
        if (str.isNotEmpty) {
          dt = DateTime.tryParse(str);
        }
      }

      if (dt == null) continue;

      final utcDt = dt.toUtc();
      final localDt = dt.isUtc ? dt.toLocal() : dt;

      final matchesLocal = (localDt.year == targetYear &&
          localDt.month == targetMonth &&
          localDt.day == targetDay);

      final matchesUtc = (utcDt.year == targetYear &&
          utcDt.month == targetMonth &&
          utcDt.day == targetDay);

      if (matchesLocal || matchesUtc) {
        final statusVal = (task['status'] ?? 'pending').toString().trim().toLowerCase();
        if (statusVal == 'completed') {
          completed.add(task);
        } else {
          pending.add(task);
        }
      }
    }

    debugPrint('========== DASHBOARD MY WORK DEBUG ==========');
    debugPrint('Mode: ${_currentOwnerId != null && _currentOwnerId!.isNotEmpty ? "MY_WORK" : "TEAM"}');
    debugPrint('Selected Department ID: ${_currentDepartmentId ?? 'NONE'}');
    debugPrint('Logged-in User ID: ${_currentOwnerId ?? 'NONE (TEAM MODE)'}');
    debugPrint('Target Date: ${date.toIso8601String()}');
    debugPrint('Total Candidates: $totalCandidates');
    debugPrint('Department Matching Records: $deptMatchedCount');
    debugPrint('Owner Matching Records: $ownerMatchedCount');
    debugPrint('Final My Work Records: $finalMatchedCount');
    debugPrint('Pending Tasks for Date: ${pending.length}');
    debugPrint('Completed Tasks for Date: ${completed.length}');
    debugPrint('==============================================');

    return TaskWorkGroup(pendingTasks: pending, completedTasks: completed);
  }

  /// The follow-up already created for a given task in this session, so a
  /// second Create task — a double tap, or a retry after a slow response —
  /// hands back the task that exists instead of posting another one.
  final Map<String, Map<String, dynamic>> _followUpsCreated = {};

  /// Tasks whose follow-up is mid-flight right now.
  final Set<String> _followUpsInFlight = {};

  /// Moves a task between pending and completed through the API.
  ///
  /// The row on screen is moved first so the checkbox answers immediately, but
  /// a request that fails puts it back the way it was and throws: a task that
  /// the server did not complete must never be left looking completed, and the
  /// caller needs the failure to show it and to hold back the follow-up popup.
  ///
  /// Answers with the task as it now stands — the server's own row when it
  /// sent one back, which is what carries the real `completedAt`.
  ///
  /// [departmentId] scopes the write to the department the user is working in,
  /// the same way every other department-scoped call in the app does. Leave it
  /// out and the API falls back to the department in the access token.
  Future<Map<String, dynamic>> setTaskStatus(
    String taskId,
    String newStatus, {
    String? departmentId,
  }) async {
    final index = _dashboardTasks.indexWhere(
      (t) => (t['id'] ?? t['_id'])?.toString() == taskId,
    );
    final previous = index == -1 ? null : _dashboardTasks[index];

    if (previous != null) {
      _dashboardTasks[index] = Map<String, dynamic>.from(previous)
        ..['status'] = newStatus;
      notifyListeners();
    }

    try {
      final data = await _writeTaskStatus(taskId, newStatus, departmentId);

      final merged = <String, dynamic>{
        ...?previous,
        ...data,
        'status': (data['status'] ?? newStatus).toString(),
      };
      if (index != -1) {
        _dashboardTasks[index] = merged;
        notifyListeners();
      }
      return merged;
    } catch (e) {
      debugPrint('[DashboardProvider setTaskStatus Error]: $e');
      if (previous != null && index != -1) {
        _dashboardTasks[index] = previous;
        notifyListeners();
      }
      rethrow;
    }
  }

  /// Writes the status and returns whatever activity object came back.
  ///
  /// Completing goes through `PATCH /activities/:id/complete`, the endpoint
  /// built for it, so the server stamps the completion time itself. Where that
  /// route is not deployed it falls back to the general update, which the API
  /// documents as accepting `status` and `completedAt` together.
  Future<Map<String, dynamic>> _writeTaskStatus(
    String taskId,
    String newStatus,
    String? departmentId,
  ) async {
    final path = '${ApiConstants.activities}/$taskId';
    final scope = departmentQuery(departmentId);

    if (newStatus == 'completed') {
      try {
        final res = await _apiService.patch(
          '$path/complete',
          queryParameters: scope,
        );
        return _unwrapActivity(res.data);
      } on NetworkException catch (e) {
        if (e.statusCode != 404 && e.statusCode != 405) rethrow;
        debugPrint('[DashboardProvider] /complete unavailable, updating status directly');
      }
      final res = await _apiService.patch(
        path,
        queryParameters: scope,
        data: {
          'status': 'completed',
          'completedAt': DateTime.now().toUtc().toIso8601String(),
        },
      );
      return _unwrapActivity(res.data);
    }

    final res = await _apiService.patch(
      path,
      queryParameters: scope,
      data: {'status': newStatus},
    );
    return _unwrapActivity(res.data);
  }

  /// Creates the follow-up to [original], due at [scheduledAt].
  ///
  /// The task is a real one: `POST /api/activities`, keeping the original's
  /// title, owner, priority, queue, reminder and every record it was linked
  /// to.
  ///
  /// [departmentId] is the department the user is working in — whichever one
  /// that is — and it goes on the request as `departmentId` / `department_id`,
  /// the pair every department-scoped call in this app sends, on top of the
  /// headers `AuthInterceptor` adds. It is checked against
  /// [selectedDepartmentId] first, so a department switched while the popup was
  /// open abandons the create rather than filing it under the wrong one.
  ///
  /// Throws when the create fails. The original task stays completed either
  /// way; nothing about it is rolled back.
  Future<Map<String, dynamic>> createFollowUpTask({
    required Map<String, dynamic> original,
    required DateTime scheduledAt,
    required String departmentId,
    required String selectedDepartmentId,
  }) async {
    if (departmentId != selectedDepartmentId) {
      throw StateError(
        'The department changed while the follow-up was being set up, '
        'so it was not created.',
      );
    }

    final originalId = activityId(original);
    if (originalId == null) {
      throw StateError('This task has no id, so a follow-up cannot be linked to it.');
    }

    final alreadyCreated = _followUpsCreated[originalId];
    if (alreadyCreated != null) return alreadyCreated;
    if (!_followUpsInFlight.add(originalId)) {
      throw StateError('A follow-up for this task is already being created.');
    }

    try {
      final payload = buildFollowUpTaskPayload(
        original: original,
        scheduledAt: scheduledAt,
      );
      final scope = departmentQuery(departmentId);
      debugPrint('[POST ${ApiConstants.activities} FOLLOW-UP]: '
          'department=${departmentId.isEmpty ? '(from token)' : departmentId} '
          'payload=$payload');

      final res = await _apiService.post(
        ApiConstants.activities,
        queryParameters: scope,
        data: payload,
      );
      final created = _unwrapActivity(res.data);
      final createdId = activityId(created);

      if (createdId != null) {
        _followUpsCreated[originalId] = created;
        await _recordFollowUpLink(
          originalId: originalId,
          followUpId: createdId,
          departmentId: departmentId,
        );
      }

      // Show it without waiting for the next fetch; the refresh that follows
      // replaces it with the server's own copy.
      if (created.isNotEmpty) {
        _dashboardTasks = [..._dashboardTasks, created];
        notifyListeners();
      }

      return created;
    } finally {
      _followUpsInFlight.remove(originalId);
    }
  }

  /// Ties the follow-up back to the task it came from.
  ///
  /// The activities API has no parent field, so the link goes on as a tag,
  /// which is the one place the server will hold it. A tag that will not save
  /// is not worth failing a created task over — the local copy still carries
  /// the link — so it is logged and left.
  Future<void> _recordFollowUpLink({
    required String originalId,
    required String followUpId,
    required String departmentId,
  }) async {
    await FollowUpLinkStorage.link(
      originalTaskId: originalId,
      followUpTaskId: followUpId,
    );

    try {
      await _apiService.post(
        '${ApiConstants.activities}/$followUpId/tags',
        queryParameters: departmentQuery(departmentId),
        data: {'tag': followUpTag(originalId)},
      );
    } catch (e) {
      debugPrint('[DashboardProvider follow-up tag not saved]: $e');
    }
  }

  /// The activity object out of whichever envelope it arrived in.
  static Map<String, dynamic> _unwrapActivity(dynamic raw) {
    if (raw is! Map) return {};
    final map = Map<String, dynamic>.from(raw);
    for (final key in ['data', 'activity', 'task']) {
      final nested = map[key];
      if (nested is Map) return Map<String, dynamic>.from(nested);
    }
    return map;
  }

  Future<void> fetchActivityStats({
    String? ownerId,
    String? departmentId,
    String? startDate,
    String? endDate,
  }) async {
    final ticket = _guard.begin(_statsKey, departmentId);
    _isLoadingStats = true;
    _statsError = null;
    notifyListeners();

    try {
      final stats = await _repository.getActivityStats(
        ownerId: ownerId,
        departmentId: departmentId,
        startDate: startDate,
        endDate: endDate,
      );
      if (!_guard.mayApply(_statsKey, ticket, departmentId)) return;
      _stats = stats;
    } catch (e) {
      if (!_guard.mayApply(_statsKey, ticket, departmentId)) return;
      _statsError = e.toString();
    } finally {
      if (_guard.mayApply(_statsKey, ticket, departmentId)) {
        _isLoadingStats = false;
        notifyListeners();
      }
    }
  }

  Future<void> fetchDashboardUnified({
    String? ownerId,
    String? departmentId,
    String? startDate,
    String? endDate,
    int page = 1,
    int limit = 20,
  }) async {
    final ticket = _guard.begin(_feedKey, departmentId);
    _isLoadingFeed = true;
    _feedError = null;
    notifyListeners();

    try {
      final feed = await _repository.getDashboardUnified(
        ownerId: ownerId,
        departmentId: departmentId,
        startDate: startDate,
        endDate: endDate,
        page: page,
        limit: limit,
      );
      if (!_guard.mayApply(_feedKey, ticket, departmentId)) return;
      _unifiedFeed = feed;

      final sampleGroup = getTasksForDate(DateTime.tryParse(startDate ?? '') ?? DateTime.now());
      debugPrint('========== MOBILE DASHBOARD DEBUG ==========');
      debugPrint('Department Name: ${departmentId == "a1b2c3d4-0000-0000-0000-000000000001" ? "Talent Acquisition (Night)" : (departmentId ?? 'NONE')}');
      debugPrint('Department ID: ${departmentId ?? 'NONE'}');
      debugPrint('Start Date: ${startDate ?? 'NONE'}');
      debugPrint('End Date: ${endDate ?? 'NONE'}');
      debugPrint('API: ${ApiConstants.activitiesDashboardUnified}');
      debugPrint('Pending tasks received: ${sampleGroup.pendingCount}');
      debugPrint('Completed tasks received: ${sampleGroup.completedCount}');
      debugPrint('=============================================');
    } catch (e) {
      if (!_guard.mayApply(_feedKey, ticket, departmentId)) return;
      _feedError = e.toString();
    } finally {
      if (_guard.mayApply(_feedKey, ticket, departmentId)) {
        _isLoadingFeed = false;
        notifyListeners();
      }
    }
  }

  Future<void> fetchReportsDashboardsDefault({String? departmentId, String? ownerId, String? departmentName}) async {
    final ticket = _guard.begin(_reportsKey, departmentId);
    try {
      final repo = MasterDataRepositoryImpl();
      final data = await repo.getReportsDashboardsDefault(departmentId: departmentId, ownerId: ownerId);

      // The department may have changed while this was in the air.
      if (!_guard.mayApply(_reportsKey, ticket, departmentId)) return;

      // Validate scope against requested department
      final dynamic scope = data['scope'] ?? data['data']?['scope'];
      if (scope is Map<String, dynamic> && departmentId != null && departmentId.isNotEmpty) {
        final scopeSelected = scope['selected']?.toString();
        final scopeLabel = scope['label']?.toString();

        debugPrint('[Dashboard Scope Validation]');
        debugPrint('Expected Dept ID: $departmentId | Scope Selected: $scopeSelected');
        debugPrint('Expected Dept Name: $departmentName | Scope Label: $scopeLabel');

        if (scopeSelected != null && scopeSelected.isNotEmpty && scopeSelected != departmentId) {
          debugPrint('ERROR: Department mismatch');
          debugPrint('Requested: $departmentId');
          debugPrint('Received: $scopeSelected');
          _reportsDashboardData = null;
          notifyListeners();
          return;
        }
      }

      _reportsDashboardData = data;
      notifyListeners();
    } catch (e) {
      debugPrint('[DashboardProvider fetchReportsDashboardsDefault Error]: $e');
    }
  }

  /// Multi-source owner resolution helper that resolves owner name from:
  /// 1. userMap (combined from /api/auth/team and /api/reports/users)
  /// 2. Inline owner / assignee map in payload (firstName + lastName)
  /// 3. Inline ownerName / owner_name string in payload
  /// 4. Inline creatorFirstName & creatorLastName in payload
  /// 5. User (truncated ID) or 'Unassigned'
  String _resolveOwnerName(Map<String, dynamic> map, Map<String, String> userMap) {
    final ownerId = (map['ownerId'] ?? map['owner_id'] ?? map['owner']?['id'] ?? map['owner']?['_id'] ?? '').toString().trim();

    // 1. Match against combined user lookup map
    if (ownerId.isNotEmpty && userMap.containsKey(ownerId)) {
      return userMap[ownerId]!;
    }

    // 2. Inline owner/assignee map
    final ownerObj = map['owner'] ?? map['assignee'] ?? map['user'];
    if (ownerObj is Map) {
      final first = (ownerObj['firstName'] ?? ownerObj['first_name'] ?? ownerObj['name'] ?? '').toString().trim();
      final last = (ownerObj['lastName'] ?? ownerObj['last_name'] ?? '').toString().trim();
      final full = '$first $last'.trim();
      if (full.isNotEmpty && full != 'null') return full;
    }

    // 3. Inline ownerName string
    final rawOwnerName = (map['ownerName'] ?? map['owner_name'] ?? map['assignee'] ?? '').toString().trim();
    if (rawOwnerName.isNotEmpty && rawOwnerName != 'null') {
      return rawOwnerName;
    }

    // 4. Inline creatorFirstName & creatorLastName
    final creatorFirst = (map['creatorFirstName'] ?? map['creator_first_name'] ?? '').toString().trim();
    final creatorLast = (map['creatorLastName'] ?? map['creator_last_name'] ?? '').toString().trim();
    final creatorFull = '$creatorFirst $creatorLast'.trim();
    if (creatorFull.isNotEmpty && creatorFull != 'null') {
      return creatorFull;
    }

    // 5. Fallback to truncated owner ID or Unassigned
    if (ownerId.isNotEmpty) {
      return ownerId.length > 8 ? 'User (${ownerId.substring(0, 8)})' : ownerId;
    }

    return 'Unassigned';
  }

  /// Builds a combined user lookup dictionary from teamMembers (/api/auth/team)
  /// and reportUsers (/api/reports/users).
  Map<String, String> _buildUserLookupMap({
    List<TeamMemberModel>? teamMembers,
    List<Map<String, dynamic>>? reportUsers,
  }) {
    final Map<String, String> map = {};

    if (teamMembers != null) {
      for (final tm in teamMembers) {
        if (tm.id.isNotEmpty && tm.fullName.isNotEmpty) {
          map[tm.id] = tm.fullName;
        }
      }
    }

    if (reportUsers != null) {
      for (final u in reportUsers) {
        final id = (u['id'] ?? u['userId'] ?? u['_id'] ?? '').toString().trim();
        final first = (u['firstName'] ?? u['first_name'] ?? u['name'] ?? '').toString().trim();
        final last = (u['lastName'] ?? u['last_name'] ?? '').toString().trim();
        final full = '$first $last'.trim();
        if (id.isNotEmpty && full.isNotEmpty && full != 'null') {
          map.putIfAbsent(id, () => full);
        }
      }
    }

    return map;
  }

  /// Fetches real activity data for the selected timeframe and groups by representative for Activity Leaderboard.
  Future<void> fetchActivityLeaderboard({
    String? startDate,
    String? endDate,
    String? subtitleLabel,
    String? departmentId,
    List<TeamMemberModel>? teamMembers,
    List<Map<String, dynamic>>? reportUsers,
  }) async {
    final ticket = _guard.begin(_leaderboardKey, departmentId);
    _isLoadingLeaderboard = true;
    _leaderboardError = null;
    if (subtitleLabel != null && subtitleLabel.isNotEmpty) {
      _leaderboardSubtitleLabel = subtitleLabel;
    }
    notifyListeners();

    try {
      final now = DateTime.now();

      DateTime? cutoffDate;
      if (startDate != null && startDate.isNotEmpty) {
        cutoffDate = DateTime.tryParse(startDate);
      } else if (subtitleLabel == 'LAST 7 DAYS') {
        cutoffDate = now.subtract(const Duration(days: 7));
      } else if (subtitleLabel == 'LAST 30 DAYS') {
        cutoffDate = now.subtract(const Duration(days: 30));
      } else if (subtitleLabel == 'LAST 90 DAYS') {
        cutoffDate = now.subtract(const Duration(days: 90));
      } else if (subtitleLabel == 'ALL TIME') {
        cutoffDate = null;
      } else {
        cutoffDate = now.subtract(const Duration(days: 7));
      }

      final userMap = _buildUserLookupMap(teamMembers: teamMembers, reportUsers: reportUsers);

      final masterRepo = MasterDataRepositoryImpl();
      List<dynamic> list = [];
      try {
        list = await masterRepo.getActivities(departmentId: departmentId, limit: 200);
      } catch (e) {
        final api = ApiService();
        final queryParams = <String, dynamic>{'limit': 200};
        if (departmentId != null && departmentId.isNotEmpty) {
          queryParams['department_id'] = departmentId;
        }
        try {
          final res = await api.get('/activities', queryParameters: queryParams);
          if (res.data is List) {
            list = res.data;
          } else if (res.data is Map<String, dynamic> && res.data['data'] is List) {
            list = res.data['data'] as List;
          }
        } catch (_) {}
      }

      debugPrint('========== ACTIVITY LEADERBOARD DEBUG LOG ==========');
      debugPrint('[1] Activities received from API: ${list.length}');
      debugPrint('[2] Combined user lookup entries: ${userMap.length}');
      debugPrint('[3] Subtitle Label: $_leaderboardSubtitleLabel | Cutoff Date: $cutoffDate');

      final Map<String, Map<String, int>> countsByRep = {};

      void processItem(Map<String, dynamic> map, bool checkDate) {
        if (checkDate && cutoffDate != null) {
          final rawDate = map['scheduledAt'] ?? map['scheduled_at'] ?? map['createdAt'] ?? map['created_at'];
          if (rawDate != null) {
            final dt = DateTime.tryParse(rawDate.toString());
            if (dt != null) {
              final localDt = dt.isUtc ? dt.toLocal() : dt;
              if (localDt.isBefore(cutoffDate)) return;
            }
          }
        }

        final repName = _resolveOwnerName(map, userMap);
        final rawType = (map['type'] ?? 'task').toString().trim().toLowerCase();

        countsByRep.putIfAbsent(
            repName, () => {'call': 0, 'email': 0, 'meeting': 0, 'note': 0, 'task': 0});

        if (rawType.contains('call')) {
          countsByRep[repName]!['call'] = (countsByRep[repName]!['call'] ?? 0) + 1;
        } else if (rawType.contains('email')) {
          countsByRep[repName]!['email'] = (countsByRep[repName]!['email'] ?? 0) + 1;
        } else if (rawType.contains('meeting') || rawType.contains('schedule')) {
          countsByRep[repName]!['meeting'] = (countsByRep[repName]!['meeting'] ?? 0) + 1;
        } else if (rawType.contains('note')) {
          countsByRep[repName]!['note'] = (countsByRep[repName]!['note'] ?? 0) + 1;
        } else {
          countsByRep[repName]!['task'] = (countsByRep[repName]!['task'] ?? 0) + 1;
        }
      }

      for (final item in list) {
        if (item is Map) {
          processItem(Map<String, dynamic>.from(item), true);
        }
      }

      final items = countsByRep.entries.map((e) {
        return ActivityLeaderboardItem(
          repName: e.key,
          callCount: e.value['call'] ?? 0,
          emailCount: e.value['email'] ?? 0,
          meetingCount: e.value['meeting'] ?? 0,
          noteCount: e.value['note'] ?? 0,
          taskCount: e.value['task'] ?? 0,
        );
      }).toList();

      items.sort((a, b) => b.totalCount.compareTo(a.totalCount));
      if (!_guard.mayApply(_leaderboardKey, ticket, departmentId)) return;
      _activityLeaderboard = items;

      debugPrint('[4] Final grouped leaderboard items count: ${items.length}');
      for (final item in items) {
        debugPrint('  Rep: ${item.repName} | Calls: ${item.callCount} | Emails: ${item.emailCount} | Meetings: ${item.meetingCount} | Notes: ${item.noteCount} | Tasks: ${item.taskCount} | Total: ${item.totalCount}');
      }
      debugPrint('====================================================');
    } catch (e) {
      debugPrint('[DashboardProvider fetchActivityLeaderboard Error]: $e');
      if (!_guard.mayApply(_leaderboardKey, ticket, departmentId)) return;
      _leaderboardError = e.toString();
    } finally {
      if (_guard.mayApply(_leaderboardKey, ticket, departmentId)) {
        _isLoadingLeaderboard = false;
        notifyListeners();
      }
    }
  }

  /// Fetches real contact counts for "LAST 30 DAYS" grouped by contact owner.
  Future<void> fetchContactOwnerCounts({
    String? departmentId,
    List<TeamMemberModel>? teamMembers,
    List<Map<String, dynamic>>? reportUsers,
  }) async {
    final ticket = _guard.begin(_contactCountsKey, departmentId);
    _isLoadingContactCounts = true;
    _contactCountsError = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final startDate = now.subtract(const Duration(days: 30));

      final startStr = "${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}";
      final endStr = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final userMap = _buildUserLookupMap(teamMembers: teamMembers, reportUsers: reportUsers);

      final api = ApiService();
      List<dynamic> allContacts = [];
      int page = 1;
      int limit = 100;
      bool hasMore = true;

      while (hasMore && page <= 5) {
        final queryParams = <String, dynamic>{
          'range': '30_days',
          'startDate': startStr,
          'endDate': endStr,
          'page': page,
          'limit': limit,
        };
        if (departmentId != null && departmentId.isNotEmpty) {
          queryParams['department_id'] = departmentId;
        }

        dynamic responseData;
        try {
          final res = await api.get(ApiConstants.reportsContacts, queryParameters: queryParams);
          responseData = res.data;
        } catch (e) {
          final res = await api.get('/contacts', queryParameters: queryParams);
          responseData = res.data;
        }

        List<dynamic> pageList = [];
        int totalRecords = 0;

        if (responseData is List) {
          pageList = responseData;
          totalRecords = pageList.length;
        } else if (responseData is Map<String, dynamic>) {
          if (responseData['data'] is List) {
            pageList = responseData['data'] as List;
          } else if (responseData['contacts'] is List) {
            pageList = responseData['contacts'] as List;
          } else if (responseData['items'] is List) {
            pageList = responseData['items'] as List;
          }

          if (responseData['meta'] is Map) {
            totalRecords = (responseData['meta']['total'] as num?)?.toInt() ?? 0;
          } else {
            totalRecords = (responseData['total'] as num?)?.toInt() ?? 0;
          }
        }

        if (pageList.isEmpty) {
          hasMore = false;
        } else {
          allContacts.addAll(pageList);
          if (totalRecords > 0 && allContacts.length >= totalRecords) {
            hasMore = false;
          } else if (pageList.length < limit) {
            hasMore = false;
          } else {
            page++;
          }
        }
      }

      final Map<String, int> countsByOwner = {};

      for (final item in allContacts) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);

        // Pre-aggregated check
        if (map.containsKey('owner') && map.containsKey('count') && map['owner'] != null) {
          final ownerName = map['owner'].toString().trim();
          final countVal = (map['count'] as num?)?.toInt() ?? 0;
          if (ownerName.isNotEmpty) {
            countsByOwner[ownerName] = (countsByOwner[ownerName] ?? 0) + countVal;
            continue;
          }
        }

        // Date check: createdAt in last 30 days
        final rawDate = map['createdAt'] ?? map['created_at'] ?? map['updatedAt'] ?? map['updated_at'];
        if (rawDate != null) {
          final dt = DateTime.tryParse(rawDate.toString());
          if (dt != null) {
            final localDt = dt.isUtc ? dt.toLocal() : dt;
            if (localDt.isBefore(startDate)) {
              continue; // Skip contacts created before 30 days ago
            }
          }
        }

        final ownerName = _resolveOwnerName(map, userMap);
        countsByOwner[ownerName] = (countsByOwner[ownerName] ?? 0) + 1;
      }

      final items = countsByOwner.entries.map((e) {
        return ContactOwnerCountItem(
          ownerName: e.key,
          contactCount: e.value,
        );
      }).toList();

      items.sort((a, b) => b.contactCount.compareTo(a.contactCount));
      if (!_guard.mayApply(_contactCountsKey, ticket, departmentId)) return;
      _contactOwnerCounts = items;
    } catch (e) {
      debugPrint('[DashboardProvider fetchContactOwnerCounts Error]: $e');
      if (!_guard.mayApply(_contactCountsKey, ticket, departmentId)) return;
      _contactCountsError = e.toString();
    } finally {
      if (_guard.mayApply(_contactCountsKey, ticket, departmentId)) {
        _isLoadingContactCounts = false;
        notifyListeners();
      }
    }
  }

  /// Fetches real call and meeting totals for "LAST 90 DAYS" grouped by representative.
  Future<void> fetchCallAndMeetingTotals({
    String? departmentId,
    List<TeamMemberModel>? teamMembers,
    List<Map<String, dynamic>>? reportUsers,
  }) async {
    final ticket = _guard.begin(_callMeetingKey, departmentId);
    _isLoadingCallAndMeeting = true;
    _callAndMeetingError = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final startDate = now.subtract(const Duration(days: 90));

      final startStr = "${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}";
      final endStr = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final userMap = _buildUserLookupMap(teamMembers: teamMembers, reportUsers: reportUsers);

      final queryParams = <String, dynamic>{
        'range': '90_days',
        'startDate': startStr,
        'endDate': endStr,
        'limit': 200,
      };
      if (departmentId != null && departmentId.isNotEmpty) {
        queryParams['department_id'] = departmentId;
      }

      final api = ApiService();
      dynamic responseData;
      try {
        final res = await api.get(ApiConstants.reportsActivities, queryParameters: queryParams);
        responseData = res.data;
      } catch (e) {
        final res = await api.get('/activities', queryParameters: queryParams);
        responseData = res.data;
      }

      List<dynamic> list = [];
      if (responseData is List) {
        list = responseData;
      } else if (responseData is Map<String, dynamic>) {
        if (responseData['data'] is List) {
          list = responseData['data'] as List;
        } else if (responseData['activities'] is List) {
          list = responseData['activities'] as List;
        } else if (responseData['items'] is List) {
          list = responseData['items'] as List;
        }
      }

      final Map<String, Map<String, int>> countsByRep = {};

      for (final item in list) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);

        final type = (map['type'] ?? '').toString().trim().toLowerCase();
        if (type != 'call' && type != 'meeting') continue;

        // Date check: timestamp within last 90 days
        final rawDate = map['scheduledAt'] ?? map['scheduled_at'] ?? map['createdAt'] ?? map['created_at'];
        if (rawDate != null) {
          final dt = DateTime.tryParse(rawDate.toString());
          if (dt != null) {
            final localDt = dt.isUtc ? dt.toLocal() : dt;
            if (localDt.isBefore(startDate)) continue;
          }
        }

        final repName = _resolveOwnerName(map, userMap);

        countsByRep.putIfAbsent(repName, () => {'call': 0, 'meeting': 0});
        if (type == 'call') {
          countsByRep[repName]!['call'] = (countsByRep[repName]!['call'] ?? 0) + 1;
        } else if (type == 'meeting') {
          countsByRep[repName]!['meeting'] = (countsByRep[repName]!['meeting'] ?? 0) + 1;
        }
      }

      final items = countsByRep.entries.map((e) {
        return CallAndMeetingRepItem(
          repName: e.key,
          callCount: e.value['call'] ?? 0,
          meetingCount: e.value['meeting'] ?? 0,
        );
      }).toList();

      items.sort((a, b) => b.totalCount.compareTo(a.totalCount));
      if (!_guard.mayApply(_callMeetingKey, ticket, departmentId)) return;
      _callAndMeetingTotals = items;
    } catch (e) {
      debugPrint('[DashboardProvider fetchCallAndMeetingTotals Error]: $e');
      if (!_guard.mayApply(_callMeetingKey, ticket, departmentId)) return;
      _callAndMeetingError = e.toString();
    } finally {
      if (_guard.mayApply(_callMeetingKey, ticket, departmentId)) {
        _isLoadingCallAndMeeting = false;
        notifyListeners();
      }
    }
  }

  /// Clears cached dashboard state to prevent stale data during department switch.
  void clearData() {
    // Everything in the air was asked for on behalf of the department being
    // left. Abandon it first, or an answer already on its way back would
    // repopulate what is being cleared here.
    _guard.abandonAll();

    _stats = null;
    _unifiedFeed = null;
    _reportsDashboardData = null;
    // The three work cards read from this. It used to survive a department
    // switch, which left the previous department's tasks under the new
    // department's name until the refetch landed.
    _dashboardTasks = [];
    _activityLeaderboard = [];
    _contactOwnerCounts = [];
    _callAndMeetingTotals = [];
    _statsError = null;
    _feedError = null;
    _tasksError = null;
    _leaderboardError = null;
    _contactCountsError = null;
    _callAndMeetingError = null;
    _isLoadingStats = false;
    _isLoadingFeed = false;
    _isLoadingTasks = false;
    _isLoadingLeaderboard = false;
    _isLoadingContactCounts = false;
    _isLoadingCallAndMeeting = false;

    // A follow-up created in the department being left must not be mistaken
    // for one already created in the department being entered.
    _followUpsCreated.clear();

    notifyListeners();
  }
}
