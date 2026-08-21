import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../../core/network/network_exception.dart';
import '../datasource/remote/deal_remote_datasource.dart';
import '../models/deal_model.dart';
import '../models/deal_stats_model.dart';

abstract class DealRepository {
  Future<DealStatsModel> getDealStats({String? departmentId});
  Future<PaginatedDealsResponse> getDeals({
    int? page,
    int? limit,
    String? search,
    String? stage,
    String? ownerId,
    String? departmentId,
    bool? ignorePermissions,
  });
  Future<DealModel> createDeal(Map<String, dynamic> dealData);
  Future<DealModel> updateDeal(String id, Map<String, dynamic> dealData);
  Future<bool> deleteDeal(String id);
  Future<DealModel> getDealById(String id);
}

class DealRepositoryImpl implements DealRepository {
  final DealRemoteDataSource _remoteDataSource;

  DealRepositoryImpl({DealRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? DealRemoteDataSourceImpl();

  @override
  Future<DealStatsModel> getDealStats({String? departmentId}) async {
    try {
      return await _remoteDataSource.getDealStats(departmentId: departmentId);
    } catch (e) {
      debugPrint('[GET /api/deals/stats ERROR]: $e');
      if (e is DioException) {
        throw NetworkException.fromDioException(e);
      }
      throw NetworkException(message: e.toString());
    }
  }

  @override
  Future<PaginatedDealsResponse> getDeals({
    int? page,
    int? limit,
    String? search,
    String? stage,
    String? ownerId,
    String? departmentId,
    bool? ignorePermissions,
  }) async {
    try {
      return await _remoteDataSource.getDeals(
        page: page,
        limit: limit,
        search: search,
        stage: stage,
        ownerId: ownerId,
        departmentId: departmentId,
        ignorePermissions: ignorePermissions,
      );
    } catch (e) {
      debugPrint('[GET /api/deals ERROR]: $e');
      if (e is DioException) {
        throw NetworkException.fromDioException(e);
      }
      throw NetworkException(message: e.toString());
    }
  }

  @override
  Future<DealModel> createDeal(Map<String, dynamic> dealData) async {
    try {
      return await _remoteDataSource.createDeal(dealData);
    } catch (e) {
      debugPrint('[POST /api/deals ERROR]: $e');
      if (e is DioException) {
        throw NetworkException.fromDioException(e);
      }
      throw NetworkException(message: e.toString());
    }
  }

  @override
  Future<DealModel> updateDeal(String id, Map<String, dynamic> dealData) async {
    try {
      return await _remoteDataSource.updateDeal(id, dealData);
    } catch (e) {
      debugPrint('[PUT /api/deals/$id ERROR]: $e');
      if (e is DioException) {
        throw NetworkException.fromDioException(e);
      }
      throw NetworkException(message: e.toString());
    }
  }

  @override
  Future<DealModel> getDealById(String id) async {
    try {
      return await _remoteDataSource.getDealById(id);
    } catch (e) {
      debugPrint('[GET /api/deals/$id ERROR]: $e');
      if (e is DioException) {
        throw NetworkException.fromDioException(e);
      }
      throw NetworkException(message: e.toString());
    }
  }

  @override
  Future<bool> deleteDeal(String id) async {
    try {
      return await _remoteDataSource.deleteDeal(id);
    } catch (e) {
      debugPrint('[DELETE /api/deals/$id ERROR]: $e');
      if (e is DioException) {
        throw NetworkException.fromDioException(e);
      }
      throw NetworkException(message: e.toString());
    }
  }
}
