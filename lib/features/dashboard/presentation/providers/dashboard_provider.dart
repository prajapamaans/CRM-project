import 'package:flutter/material.dart';
import '../../data/models/activity_stats_model.dart';
import '../../data/models/dashboard_unified_model.dart';
import '../../data/repositories/dashboard_repository.dart';

class DashboardProvider extends ChangeNotifier {
  final DashboardRepository _repository;

  DashboardProvider({DashboardRepository? repository})
      : _repository = repository ?? DashboardRepositoryImpl();

  ActivityStatsModel? _stats;
  DashboardUnifiedResponseModel? _unifiedFeed;

  bool _isLoadingStats = false;
  bool _isLoadingFeed = false;
  String? _statsError;
  String? _feedError;

  ActivityStatsModel? get stats => _stats;
  DashboardUnifiedResponseModel? get unifiedFeed => _unifiedFeed;
  List<DashboardActivityItem> get activities => _unifiedFeed?.data ?? [];

  bool get isLoadingStats => _isLoadingStats;
  bool get isLoadingFeed => _isLoadingFeed;
  bool get isLoading => _isLoadingStats || _isLoadingFeed;
  String? get statsError => _statsError;
  String? get feedError => _feedError;

  Future<void> loadDashboardData({String? ownerId}) async {
    await Future.wait([
      fetchActivityStats(ownerId: ownerId),
      fetchDashboardUnified(ownerId: ownerId),
    ]);
  }

  Future<void> fetchActivityStats({String? ownerId}) async {
    _isLoadingStats = true;
    _statsError = null;
    notifyListeners();

    try {
      _stats = await _repository.getActivityStats(ownerId: ownerId);
    } catch (e) {
      _statsError = e.toString();
    } finally {
      _isLoadingStats = false;
      notifyListeners();
    }
  }

  Future<void> fetchDashboardUnified({
    String? ownerId,
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

  /// Clears cached dashboard state to prevent stale data during department switch.
  void clearData() {
    _stats = null;
    _unifiedFeed = null;
    _statsError = null;
    _feedError = null;
    _isLoadingStats = false;
    _isLoadingFeed = false;
    notifyListeners();
  }
}
