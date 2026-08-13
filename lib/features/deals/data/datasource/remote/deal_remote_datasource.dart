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
  Future<DealStatsModel> getDealStats();
  Future<PaginatedDealsResponse> getDeals({
    int? page,
    int? limit,
    String? search,
    String? stage,
    String? ownerId,
    bool? ignorePermissions,
  });
  Future<DealModel> createDeal(Map<String, dynamic> dealData);
  Future<DealModel> updateDeal(String id, Map<String, dynamic> dealData);
}

class DealRemoteDataSourceImpl implements DealRemoteDataSource {
  final ApiService _apiService;

  DealRemoteDataSourceImpl({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  @override
  Future<DealStatsModel> getDealStats() async {
    final response = await _apiService.get(ApiConstants.dealsStats);
    debugPrint('[GET /api/deals/stats SUCCESS]: ${response.data}');

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
    bool? ignorePermissions,
  }) async {
    final queryParameters = <String, dynamic>{};
    if (page != null) queryParameters['page'] = page;
    if (limit != null) queryParameters['limit'] = limit;
    if (search != null && search.isNotEmpty) queryParameters['search'] = search;
    if (stage != null && stage.isNotEmpty) queryParameters['stage'] = stage;
    if (ownerId != null && ownerId.isNotEmpty) {
      queryParameters['ownerId'] = ownerId;
    }
    if (ignorePermissions == true) {
      queryParameters['ignorePermissions'] = 'true';
    }

    final response = await _apiService.get(
      ApiConstants.deals,
      queryParameters: queryParameters,
    );

    debugPrint('[GET /api/deals SUCCESS]: ${response.data}');

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

      if (rawData.containsKey('meta') && rawData['meta'] is Map<String, dynamic>) {
        final meta = rawData['meta'] as Map<String, dynamic>;
        total = (meta['total'] as num?)?.toInt() ?? 0;
        pageNum = (meta['page'] as num?)?.toInt() ?? pageNum;
        limitNum = (meta['limit'] as num?)?.toInt() ?? limitNum;
      }

      if (total == 0) {
        total = (rawData['total'] as num?)?.toInt() ??
            (rawData['totalCount'] as num?)?.toInt() ??
            (rawData['count'] as num?)?.toInt() ??
            0;
      }
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
    dynamic rawData;
    try {
      final response = await _apiService.put(
        '${ApiConstants.deals}/$id',
        data: dealData,
      );
      debugPrint('[PUT /api/deals/$id SUCCESS]: ${response.data}');
      rawData = response.data;
    } catch (e) {
      debugPrint('[PUT /api/deals/$id FAILED, RETRYING PATCH]: $e');
      try {
        final response = await _apiService.patch(
          '${ApiConstants.deals}/$id',
          data: dealData,
        );
        debugPrint('[PATCH /api/deals/$id SUCCESS]: ${response.data}');
        rawData = response.data;
      } catch (patchErr) {
        debugPrint('[PATCH /api/deals/$id FAILED TOO]: $patchErr');
        rethrow;
      }
    }

    if (rawData is Map<String, dynamic>) {
      final data = rawData.containsKey('data') && rawData['data'] is Map<String, dynamic>
          ? rawData['data'] as Map<String, dynamic>
          : rawData;
      return DealModel.fromJson({'id': id, ...data, ...dealData});
    }
    return DealModel.fromJson({'id': id, ...dealData});
  }
}
