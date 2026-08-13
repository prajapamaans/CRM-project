import 'package:flutter/foundation.dart';
import '../../../../../core/network/api_constants.dart';
import '../../../../../core/network/api_service.dart';
import '../../models/activity_stats_model.dart';
import '../../models/dashboard_unified_model.dart';

abstract class DashboardRemoteDataSource {
  Future<ActivityStatsModel> getActivityStats({String? ownerId});
  Future<DashboardUnifiedResponseModel> getDashboardUnified({
    String? ownerId,
    String? startDate,
    String? endDate,
    int? page,
    int? limit,
  });
}

class DashboardRemoteDataSourceImpl implements DashboardRemoteDataSource {
  final ApiService _apiService;

  DashboardRemoteDataSourceImpl({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  @override
  Future<ActivityStatsModel> getActivityStats({String? ownerId}) async {
    final queryParameters = <String, dynamic>{};
    if (ownerId != null && ownerId.isNotEmpty) {
      queryParameters['ownerId'] = ownerId;
    }

    final response = await _apiService.get(
      ApiConstants.activitiesStats,
      queryParameters: queryParameters,
    );

    debugPrint('[GET /api/activities/stats SUCCESS]: ${response.data}');

    final Map<String, dynamic> data = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : {};

    return ActivityStatsModel.fromJson(data);
  }

  @override
  Future<DashboardUnifiedResponseModel> getDashboardUnified({
    String? ownerId,
    String? startDate,
    String? endDate,
    int? page,
    int? limit,
  }) async {
    final queryParameters = <String, dynamic>{};
    if (ownerId != null && ownerId.isNotEmpty) queryParameters['ownerId'] = ownerId;
    if (startDate != null && startDate.isNotEmpty) queryParameters['startDate'] = startDate;
    if (endDate != null && endDate.isNotEmpty) queryParameters['endDate'] = endDate;
    if (page != null) queryParameters['page'] = page;
    if (limit != null) queryParameters['limit'] = limit;

    final response = await _apiService.get(
      ApiConstants.activitiesDashboardUnified,
      queryParameters: queryParameters,
    );

    debugPrint('[GET /api/activities/dashboard-unified SUCCESS]: ${response.data}');

    final Map<String, dynamic> data = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : {};

    return DashboardUnifiedResponseModel.fromJson(data);
  }
}
