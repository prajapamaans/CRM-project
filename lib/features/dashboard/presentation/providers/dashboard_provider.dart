import 'package:flutter/material.dart';
import '../../../../core/repositories/master_data_repository.dart';
import '../../data/models/activity_stats_model.dart';
import '../../data/models/dashboard_unified_model.dart';
import '../../data/repositories/dashboard_repository.dart';

class DashboardProvider extends ChangeNotifier {
  final DashboardRepository _repository;

  DashboardProvider({DashboardRepository? repository})
      : _repository = repository ?? DashboardRepositoryImpl();

  ActivityStatsModel? _stats;
  DashboardUnifiedResponseModel? _unifiedFeed;
  Map<String, dynamic>? _reportsDashboardData;

  bool _isLoadingStats = false;
  bool _isLoadingFeed = false;
  String? _statsError;
  String? _feedError;

  ActivityStatsModel? get stats => _stats;
  DashboardUnifiedResponseModel? get unifiedFeed => _unifiedFeed;
  Map<String, dynamic>? get reportsDashboardData => _reportsDashboardData;
  List<DashboardActivityItem> get activities => _unifiedFeed?.data ?? [];

  bool get isLoadingStats => _isLoadingStats;
  bool get isLoadingFeed => _isLoadingFeed;
  bool get isLoading => _isLoadingStats || _isLoadingFeed;
  String? get statsError => _statsError;
  String? get feedError => _feedError;

  Future<void> loadDashboardData({String? ownerId, String? departmentId, String? departmentName}) async {
    // Clear previous state to prevent showing stale data while loading new department
    _stats = null;
    _unifiedFeed = null;
    _reportsDashboardData = null;
    notifyListeners();

    await Future.wait([
      fetchActivityStats(ownerId: ownerId, departmentId: departmentId),
      fetchDashboardUnified(ownerId: ownerId, departmentId: departmentId),
      fetchReportsDashboardsDefault(departmentId: departmentId, departmentName: departmentName),
    ]);
  }

  Future<void> fetchActivityStats({String? ownerId, String? departmentId}) async {
    _isLoadingStats = true;
    _statsError = null;
    notifyListeners();

    try {
      _stats = await _repository.getActivityStats(ownerId: ownerId, departmentId: departmentId);
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

  /// Clears cached dashboard state to prevent stale data during department switch.
  void clearData() {
    _stats = null;
    _unifiedFeed = null;
    _reportsDashboardData = null;
    _statsError = null;
    _feedError = null;
    _isLoadingStats = false;
    _isLoadingFeed = false;
    notifyListeners();
  }
}
