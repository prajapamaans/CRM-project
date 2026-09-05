import 'package:flutter/material.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_service.dart';
import '../../data/models/meeting_scheduler_model.dart';

/// Provider for managing state and API integration for Meeting Schedulers.
class MeetingSchedulerProvider extends ChangeNotifier {
  final ApiService _apiService;

  MeetingSchedulerProvider({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  List<MeetingScheduler> _schedulers = [];
  bool _isLoading = false;
  String? _error;

  List<MeetingScheduler> get schedulers => _schedulers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Fetches ALL meeting schedulers from GET /api/meeting-schedulers
  Future<void> fetchMeetingSchedulers({bool isRefresh = false}) async {
    if (!isRefresh) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final response = await _apiService
          .get(ApiConstants.meetingSchedulers)
          .timeout(const Duration(seconds: 8));

      final rawData = response.data;
      List<dynamic> listData = [];

      if (rawData is Map<String, dynamic>) {
        if (rawData['data'] is List) {
          listData = rawData['data'] as List;
        } else if (rawData['schedulers'] is List) {
          listData = rawData['schedulers'] as List;
        } else if (rawData['items'] is List) {
          listData = rawData['items'] as List;
        }
      } else if (rawData is List) {
        listData = rawData;
      }

      final List<MeetingScheduler> fetched = listData
          .whereType<Map>()
          .map((e) => MeetingScheduler.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      _schedulers = fetched;
      _error = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('[MeetingSchedulerProvider fetch error]: $e');
      _error = 'Failed to load meeting schedulers. ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Adds or updates a scheduler in the local list
  void addOrUpdateScheduler(MeetingScheduler scheduler) {
    final idx = _schedulers.indexWhere((s) => s.id == scheduler.id);
    if (idx != -1) {
      _schedulers[idx] = scheduler;
    } else {
      _schedulers.insert(0, scheduler);
    }
    notifyListeners();
  }

  /// Removes a scheduler from the local list
  void removeScheduler(String id) {
    _schedulers.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  /// Deletes a meeting scheduler from backend DELETE /api/meeting-schedulers/:id and updates local list.
  Future<bool> deleteMeetingScheduler(String id) async {
    try {
      await _apiService.delete('${ApiConstants.meetingSchedulers}/$id');
      _schedulers.removeWhere((s) => s.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[MeetingSchedulerProvider delete error]: $e');
      // Even if server returns 404, clean up locally
      _schedulers.removeWhere((s) => s.id == id);
      notifyListeners();
      return false;
    }
  }
}
