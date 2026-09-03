import 'package:flutter/foundation.dart';
import '../../../../../core/network/api_constants.dart';
import '../../../../../core/network/api_service.dart';
import '../../models/activity_stats_model.dart';
import '../../models/dashboard_unified_model.dart';

abstract class DashboardRemoteDataSource {
  Future<ActivityStatsModel> getActivityStats({
    String? ownerId,
    String? departmentId,
    String? startDate,
    String? endDate,
  });
  Future<DashboardUnifiedResponseModel> getDashboardUnified({
    String? ownerId,
    String? departmentId,
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
  Future<ActivityStatsModel> getActivityStats({
    String? ownerId,
    String? departmentId,
    String? startDate,
    String? endDate,
  }) async {
    final queryParameters = <String, dynamic>{};
    if (ownerId != null && ownerId.isNotEmpty) {
      queryParameters['ownerId'] = ownerId;
      queryParameters['owner_id'] = ownerId;
    }
    if (departmentId != null && departmentId.isNotEmpty) {
      queryParameters['departmentId'] = departmentId;
      queryParameters['department_id'] = departmentId;
    }
    if (startDate != null && startDate.isNotEmpty) {
      queryParameters['startDate'] = startDate;
    }
    if (endDate != null && endDate.isNotEmpty) {
      queryParameters['endDate'] = endDate;
    }

    final queryUri = Uri(queryParameters: queryParameters.map((k, v) => MapEntry(k, v.toString())));
    final fullUrl = '${ApiConstants.activitiesStats}${queryUri.query.isNotEmpty ? '?${queryUri.query}' : ''}';

    debugPrint('==================================================');
    debugPrint('[DASHBOARD STATS API REQUEST]');
    debugPrint('Selected Department ID: ${departmentId ?? 'NONE'}');
    debugPrint('Dashboard Start Date: ${startDate ?? 'NONE'}');
    debugPrint('Dashboard End Date: ${endDate ?? 'NONE'}');
    debugPrint('Dashboard API URL: $fullUrl');
    debugPrint('==================================================');

    final response = await _apiService.get(
      ApiConstants.activitiesStats,
      queryParameters: queryParameters,
    );

    debugPrint('==================================================');
    debugPrint('[DASHBOARD STATS API RESPONSE]');
    debugPrint('Response Status: ${response.statusCode}');
    debugPrint('==================================================');

    final Map<String, dynamic> data = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : {};

    return ActivityStatsModel.fromJson(data);
  }

  @override
  Future<DashboardUnifiedResponseModel> getDashboardUnified({
    String? ownerId,
    String? departmentId,
    String? startDate,
    String? endDate,
    int? page,
    int? limit,
  }) async {
    final queryParameters = <String, dynamic>{};
    if (ownerId != null && ownerId.isNotEmpty) {
      queryParameters['ownerId'] = ownerId;
      queryParameters['owner_id'] = ownerId;
    }
    if (departmentId != null && departmentId.isNotEmpty) {
      queryParameters['departmentId'] = departmentId;
      queryParameters['department_id'] = departmentId;
    }
    if (startDate != null && startDate.isNotEmpty) queryParameters['startDate'] = startDate;
    if (endDate != null && endDate.isNotEmpty) queryParameters['endDate'] = endDate;
    if (page != null) queryParameters['page'] = page;
    if (limit != null) queryParameters['limit'] = limit;

    final queryUri = Uri(queryParameters: queryParameters.map((k, v) => MapEntry(k, v.toString())));
    final fullUrl = '${ApiConstants.activitiesDashboardUnified}${queryUri.query.isNotEmpty ? '?${queryUri.query}' : ''}';

    debugPrint('========== DASHBOARD DEPARTMENT DEBUG ==========');
    debugPrint('Selected Department ID: ${departmentId ?? 'NONE'}');
    debugPrint('Start Date: ${startDate ?? 'NONE'}');
    debugPrint('End Date: ${endDate ?? 'NONE'}');
    debugPrint('API: ${ApiConstants.activitiesDashboardUnified}');
    debugPrint('Department Query Parameter: department_id');
    debugPrint('Full API URL: $fullUrl');
    debugPrint('===============================================');

    final response = await _apiService.get(
      ApiConstants.activitiesDashboardUnified,
      queryParameters: queryParameters,
    );

    final Map<String, dynamic> data = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : {};

    final result = DashboardUnifiedResponseModel.fromJson(data);

    debugPrint('==================================================');
    debugPrint('[DASHBOARD UNIFIED API RESPONSE]');
    debugPrint('Response Status: ${response.statusCode}');
    debugPrint('Response Activity Count: ${result.data.length}');
    debugPrint('==================================================');

    return result;
  }
}
