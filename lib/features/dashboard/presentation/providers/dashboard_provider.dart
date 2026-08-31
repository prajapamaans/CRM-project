import 'package:flutter/material.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/repositories/master_data_repository.dart';
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

  DashboardProvider({DashboardRepository? repository})
      : _repository = repository ?? DashboardRepositoryImpl();

  ActivityStatsModel? _stats;
  DashboardUnifiedResponseModel? _unifiedFeed;
  Map<String, dynamic>? _reportsDashboardData;
  List<Map<String, dynamic>> _dashboardTasks = [];
  List<ActivityLeaderboardItem> _activityLeaderboard = [];
  List<ContactOwnerCountItem> _contactOwnerCounts = [];
  List<CallAndMeetingRepItem> _callAndMeetingTotals = [];
  String _leaderboardSubtitleLabel = 'LAST 7 DAYS';

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
  List<DashboardActivityItem> get activities => _unifiedFeed?.data ?? [];
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
    // Clear previous state to prevent showing stale data while loading new department
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
          departmentId: departmentId, departmentName: departmentName),
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
      _dashboardTasks = fetched;
    } catch (e) {
      debugPrint('[DashboardProvider fetchDashboardTasks Error]: $e');
      _tasksError = e.toString();
    } finally {
      _isLoadingTasks = false;
      notifyListeners();
    }
  }

  /// Reusable date + status task classification mechanism.
  /// Uses [scheduledAt] (fallback to dueDate), converts UTC to local timezone,
  /// and compares calendar date with [date].
  TaskWorkGroup getTasksForDate(DateTime date) {
    final targetYear = date.year;
    final targetMonth = date.month;
    final targetDay = date.day;

    final List<Map<String, dynamic>> pending = [];
    final List<Map<String, dynamic>> completed = [];

    for (final task in _dashboardTasks) {
      final rawScheduled = task['scheduledAt'] ??
          task['scheduled_at'] ??
          task['dueDate'] ??
          task['due_date'];

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

      // Convert UTC timestamp to local timezone before calendar date comparison
      final localDt = dt.isUtc ? dt.toLocal() : dt;

      if (localDt.year == targetYear &&
          localDt.month == targetMonth &&
          localDt.day == targetDay) {
        final statusVal = (task['status'] ?? 'pending').toString().trim().toLowerCase();
        if (statusVal == 'completed') {
          completed.add(task);
        } else {
          pending.add(task);
        }
      }
    }

    return TaskWorkGroup(pendingTasks: pending, completedTasks: completed);
  }

  /// Toggles task status between pending and completed.
  Future<void> toggleTaskStatus(String taskId, String newStatus) async {
    try {
      // Optimistically update local state
      final index = _dashboardTasks.indexWhere(
        (t) => (t['id'] ?? t['_id'])?.toString() == taskId,
      );
      if (index != -1) {
        _dashboardTasks[index] = Map<String, dynamic>.from(_dashboardTasks[index])
          ..['status'] = newStatus;
        notifyListeners();
      }

      await ApiService().patch('/activities/$taskId', data: {'status': newStatus});
    } catch (e) {
      debugPrint('[DashboardProvider toggleTaskStatus Error]: $e');
    }
  }

  Future<void> fetchActivityStats({
    String? ownerId,
    String? departmentId,
    String? startDate,
    String? endDate,
  }) async {
    _isLoadingStats = true;
    _statsError = null;
    notifyListeners();

    try {
      _stats = await _repository.getActivityStats(
        ownerId: ownerId,
        departmentId: departmentId,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      _statsError = e.toString();
    } finally {
      _isLoadingStats = false;
      notifyListeners();
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
    _isLoadingFeed = true;
    _feedError = null;
    notifyListeners();

    try {
      _unifiedFeed = await _repository.getDashboardUnified(
        ownerId: ownerId,
        departmentId: departmentId,
        startDate: startDate,
        endDate: endDate,
        page: page,
        limit: limit,
      );
    } catch (e) {
      _feedError = e.toString();
    } finally {
      _isLoadingFeed = false;
      notifyListeners();
    }
  }

  Future<void> fetchReportsDashboardsDefault({String? departmentId, String? departmentName}) async {
    try {
      final repo = MasterDataRepositoryImpl();
      final data = await repo.getReportsDashboardsDefault(departmentId: departmentId);

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
      _activityLeaderboard = items;

      debugPrint('[4] Final grouped leaderboard items count: ${items.length}');
      for (final item in items) {
        debugPrint('  Rep: ${item.repName} | Calls: ${item.callCount} | Emails: ${item.emailCount} | Meetings: ${item.meetingCount} | Notes: ${item.noteCount} | Tasks: ${item.taskCount} | Total: ${item.totalCount}');
      }
      debugPrint('====================================================');
    } catch (e) {
      debugPrint('[DashboardProvider fetchActivityLeaderboard Error]: $e');
      _leaderboardError = e.toString();
    } finally {
      _isLoadingLeaderboard = false;
      notifyListeners();
    }
  }

  /// Fetches real contact counts for "LAST 30 DAYS" grouped by contact owner.
  Future<void> fetchContactOwnerCounts({
    String? departmentId,
    List<TeamMemberModel>? teamMembers,
    List<Map<String, dynamic>>? reportUsers,
  }) async {
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
      _contactOwnerCounts = items;
    } catch (e) {
      debugPrint('[DashboardProvider fetchContactOwnerCounts Error]: $e');
      _contactCountsError = e.toString();
    } finally {
      _isLoadingContactCounts = false;
      notifyListeners();
    }
  }

  /// Fetches real call and meeting totals for "LAST 90 DAYS" grouped by representative.
  Future<void> fetchCallAndMeetingTotals({
    String? departmentId,
    List<TeamMemberModel>? teamMembers,
    List<Map<String, dynamic>>? reportUsers,
  }) async {
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
      _callAndMeetingTotals = items;
    } catch (e) {
      debugPrint('[DashboardProvider fetchCallAndMeetingTotals Error]: $e');
      _callAndMeetingError = e.toString();
    } finally {
      _isLoadingCallAndMeeting = false;
      notifyListeners();
    }
  }

  /// Clears cached dashboard state to prevent stale data during department switch.
  void clearData() {
    _stats = null;
    _unifiedFeed = null;
    _reportsDashboardData = null;
    _activityLeaderboard = [];
    _contactOwnerCounts = [];
    _callAndMeetingTotals = [];
    _statsError = null;
    _feedError = null;
    _leaderboardError = null;
    _contactCountsError = null;
    _callAndMeetingError = null;
    _isLoadingStats = false;
    _isLoadingFeed = false;
    _isLoadingLeaderboard = false;
    _isLoadingContactCounts = false;
    _isLoadingCallAndMeeting = false;
    notifyListeners();
  }
}
