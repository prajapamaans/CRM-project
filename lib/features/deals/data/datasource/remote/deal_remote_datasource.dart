import 'package:flutter/foundation.dart';
import '../../../../../core/network/api_constants.dart';
import '../../../../../core/network/api_service.dart';
import '../../models/deal_model.dart';
import '../../models/deal_stats_model.dart';

class PaginatedDealsResponse {
  final List<DealModel> deals;
  final int total;
  final int page;
  final int limit;

  PaginatedDealsResponse({
    required this.deals,
    required this.total,
    required this.page,
    required this.limit,
  });
}

abstract class DealRemoteDataSource {
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

class DealRemoteDataSourceImpl implements DealRemoteDataSource {
  final ApiService _apiService;

  DealRemoteDataSourceImpl({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  @override
  Future<DealStatsModel> getDealStats({String? departmentId}) async {
    final queryParameters = <String, dynamic>{};
    if (departmentId != null && departmentId.isNotEmpty) {
      queryParameters['department_id'] = departmentId;
    }
    final response = await _apiService.get(ApiConstants.dealsStats, queryParameters: queryParameters);

    debugPrint('========== DEPARTMENT API TRACE ==========');
    debugPrint('Screen: Deal Stats');
    debugPrint('API: ${ApiConstants.dealsStats}');
    debugPrint('Selected Department ID: $departmentId');
    debugPrint('Request department_id: $departmentId');
    debugPrint('Response status: ${response.statusCode}');
    debugPrint('==========================================');

    final Map<String, dynamic> data = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : {};

    return DealStatsModel.fromJson(data);
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
    final queryParameters = <String, dynamic>{};
    if (page != null) queryParameters['page'] = page;
    if (limit != null) queryParameters['limit'] = limit;
    if (search != null && search.isNotEmpty) queryParameters['search'] = search;
    if (stage != null && stage.isNotEmpty) queryParameters['stage'] = stage;
    if (ownerId != null && ownerId.isNotEmpty) queryParameters['owner_id'] = ownerId;
    if (departmentId != null && departmentId.isNotEmpty) {
      queryParameters['department_id'] = departmentId;
    }
    if (ignorePermissions == true) {
      queryParameters['ignore_permissions'] = 'true';
    }

    final response = await _apiService.get(
      ApiConstants.deals,
      queryParameters: queryParameters,
    );

    final dynamic rawData = response.data;
    List<dynamic> list = [];
    int total = 0;
    int pageNum = page ?? 1;
    int limitNum = limit ?? 25;

    if (rawData is List) {
      list = rawData;
      total = list.length;
    } else if (rawData is Map<String, dynamic>) {
      if (rawData.containsKey('data') && rawData['data'] is List) {
        list = rawData['data'] as List;
      } else if (rawData.containsKey('deals') && rawData['deals'] is List) {
        list = rawData['deals'] as List;
      } else if (rawData.containsKey('items') && rawData['items'] is List) {
        list = rawData['items'] as List;
      }
      total = (rawData['total'] as num?)?.toInt() ?? (rawData['count'] as num?)?.toInt() ?? list.length;
    }

    final String? firstRecordDeptId = list.isNotEmpty && list.first is Map
        ? (list.first['departmentId'] ?? list.first['department_id'] ?? list.first['department']?['id'])?.toString()
        : null;

    debugPrint('========== DEPARTMENT API TRACE ==========');
    debugPrint('Screen: Deals');
    debugPrint('API: ${ApiConstants.deals}');
    debugPrint('Selected Department ID: $departmentId');
    debugPrint('Request department_id: $departmentId');
    debugPrint('Response status: ${response.statusCode}');
    debugPrint('First returned record departmentId: $firstRecordDeptId');
    debugPrint('==========================================');

    if (firstRecordDeptId != null && departmentId != null && firstRecordDeptId != departmentId) {
      debugPrint('REQUESTED DEPARTMENT: $departmentId');
      debugPrint('RETURNED RECORD DEPARTMENT: $firstRecordDeptId');
    }

    if (rawData is Map<String, dynamic> && rawData.containsKey('meta') && rawData['meta'] is Map<String, dynamic>) {
      final meta = rawData['meta'] as Map<String, dynamic>;
      total = (meta['total'] as num?)?.toInt() ?? 0;
      pageNum = (meta['page'] as num?)?.toInt() ?? pageNum;
      limitNum = (meta['limit'] as num?)?.toInt() ?? limitNum;
    }

    if (total == 0 && rawData is Map<String, dynamic>) {
      total = (rawData['total'] as num?)?.toInt() ??
          (rawData['totalCount'] as num?)?.toInt() ??
          (rawData['count'] as num?)?.toInt() ??
          0;
    }

    if (total == 0 && list.isNotEmpty) {
      total = list.length;
    }

    // Only apply client-side sublisting if rawData was a flat unsliced List (without backend meta pagination)
    List<dynamic> pageList = list;
    if (rawData is List && list.length > limitNum) {
      final startIndex = (pageNum - 1) * limitNum;
      if (startIndex < list.length) {
        final endIndex = (startIndex + limitNum).clamp(0, list.length);
        pageList = list.sublist(startIndex, endIndex);
      }
    }

    final deals = pageList
        .whereType<Map>()
        .map((e) => DealModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return PaginatedDealsResponse(
      deals: deals,
      total: total,
      page: pageNum,
      limit: limitNum,
    );
  }

  @override
  Future<DealModel> createDeal(Map<String, dynamic> dealData) async {
    final response = await _apiService.post(
      ApiConstants.deals,
      data: dealData,
    );

    debugPrint('[POST /api/deals SUCCESS]: ${response.data}');

    final Map<String, dynamic> data = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : (response.data is Map
            ? Map<String, dynamic>.from(response.data as Map)
            : {});

    final dealJson = (data.containsKey('data') && data['data'] is Map<String, dynamic>)
        ? data['data'] as Map<String, dynamic>
        : data;

    return DealModel.fromJson(dealJson);
  }

  @override
  Future<DealModel> updateDeal(String id, Map<String, dynamic> dealData) async {
    // PATCH /api/deals/:id is the documented update route. Trying PUT first
    // cost every save a full failed round trip before the real request.
    final response = await _apiService.patch(
      '${ApiConstants.deals}/$id',
      data: dealData,
    );
    debugPrint('[PATCH /api/deals/$id SUCCESS]: ${response.data}');
    final dynamic rawData = response.data;

    if (rawData is Map<String, dynamic>) {
      final data = rawData.containsKey('data') && rawData['data'] is Map<String, dynamic>
          ? rawData['data'] as Map<String, dynamic>
          : rawData;
      return DealModel.fromJson({'id': id, ...data, ...dealData});
    }
    return DealModel.fromJson({'id': id, ...dealData});
  }

  @override
  Future<DealModel> getDealById(String id) async {
    final response = await _apiService.get(
      '${ApiConstants.deals}/$id',
    );

    debugPrint('[GET /api/deals/$id SUCCESS]: ${response.data}');

    final dynamic rawData = response.data;
    if (rawData is Map<String, dynamic>) {
      final data = rawData.containsKey('data') && rawData['data'] is Map<String, dynamic>
          ? rawData['data'] as Map<String, dynamic>
          : rawData;
      return DealModel.fromJson(data);
    }
    throw Exception('Invalid response format for getDealById');
  }

  @override
  Future<bool> deleteDeal(String id) async {
    final response = await _apiService.delete('${ApiConstants.deals}/$id');
    return response.statusCode == 200 || response.statusCode == 204;
  }
}
