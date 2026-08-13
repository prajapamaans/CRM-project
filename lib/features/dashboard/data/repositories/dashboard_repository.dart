import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../../core/network/network_exception.dart';
import '../datasource/remote/dashboard_remote_datasource.dart';
import '../models/activity_stats_model.dart';
import '../models/dashboard_unified_model.dart';

abstract class DashboardRepository {
  Future<ActivityStatsModel> getActivityStats({String? ownerId});
  Future<DashboardUnifiedResponseModel> getDashboardUnified({
    String? ownerId,
    String? startDate,
    String? endDate,
    int? page,
    int? limit,
  });
}

class DashboardRepositoryImpl implements DashboardRepository {
  final DashboardRemoteDataSource _remoteDataSource;

  DashboardRepositoryImpl({DashboardRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? DashboardRemoteDataSourceImpl();

  @override
  Future<ActivityStatsModel> getActivityStats({String? ownerId}) async {
    try {
      return await _remoteDataSource.getActivityStats(ownerId: ownerId);
    } catch (e) {
      debugPrint('[GET /api/activities/stats ERROR]: $e');
      if (e is DioException) {
        throw NetworkException.fromDioException(e);
      }
      throw NetworkException(message: e.toString());
    }
  }

  @override
  Future<DashboardUnifiedResponseModel> getDashboardUnified({
    String? ownerId,
    String? startDate,
    String? endDate,
    int? page,
    int? limit,
  }) async {
    try {
      return await _remoteDataSource.getDashboardUnified(
        ownerId: ownerId,
        startDate: startDate,
        endDate: endDate,
        page: page,
        limit: limit,
      );
    } catch (e) {
      debugPrint('[GET /api/activities/dashboard-unified ERROR]: $e');
      if (e is DioException) {
        throw NetworkException.fromDioException(e);
      }
      throw NetworkException(message: e.toString());
    }
  }
}
