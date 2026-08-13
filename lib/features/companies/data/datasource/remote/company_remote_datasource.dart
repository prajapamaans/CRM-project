import 'package:flutter/foundation.dart';
import '../../../../../core/network/api_constants.dart';
import '../../../../../core/network/api_service.dart';
import '../../models/company_model.dart';

class PaginatedCompaniesResponse {
  final List<CompanyModel> companies;
  final int total;
  final int page;
  final int limit;

  PaginatedCompaniesResponse({
    required this.companies,
    required this.total,
    required this.page,
    required this.limit,
  });
}

abstract class CompanyRemoteDataSource {
  Future<PaginatedCompaniesResponse> getCompanies({
    String? page,
    String? limit,
    String? search,
    String? ownerId,
    bool? ignorePermissions,
  });

  Future<CompanyModel> getCompanyById(String id);

  Future<CompanyModel> createCompany(Map<String, dynamic> companyData);

  Future<CompanyModel> updateCompany(String id, Map<String, dynamic> companyData);

  Future<bool> deleteCompany(String id);
}

class CompanyRemoteDataSourceImpl implements CompanyRemoteDataSource {
  final ApiService _apiService;

  CompanyRemoteDataSourceImpl({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  @override
  Future<PaginatedCompaniesResponse> getCompanies({
    String? page,
    String? limit,
    String? search,
    String? ownerId,
    bool? ignorePermissions,
  }) async {
    final queryParameters = <String, dynamic>{};
    if (page != null) queryParameters['page'] = page;
    if (limit != null) queryParameters['limit'] = limit;
    if (search != null && search.isNotEmpty) queryParameters['search'] = search;
    if (ownerId != null && ownerId.isNotEmpty) queryParameters['ownerId'] = ownerId;
    if (ignorePermissions != null) {
      final val = ignorePermissions ? 'true' : 'false';
      queryParameters['ignorePermissions'] = val;
      queryParameters['ignore_permissions'] = val;
    }

    final response = await _apiService.get(
      ApiConstants.companies,
      queryParameters: queryParameters,
    );

    debugPrint('[GET /api/companies SUCCESS]: ${response.data}');

    final dynamic rawData = response.data;
    List<dynamic> list = [];
    int total = 0;
    int pageNum = int.tryParse(page ?? '1') ?? 1;
    int limitNum = int.tryParse(limit ?? '25') ?? 25;

    if (rawData is List) {
      list = rawData;
      total = list.length;
    } else if (rawData is Map<String, dynamic>) {
      if (rawData.containsKey('data') && rawData['data'] is List) {
        list = rawData['data'] as List;
      } else if (rawData.containsKey('companies') && rawData['companies'] is List) {
        list = rawData['companies'] as List;
      } else if (rawData.containsKey('items') && rawData['items'] is List) {
        list = rawData['items'] as List;
      }

      if (rawData.containsKey('meta') && rawData['meta'] is Map<String, dynamic>) {
        final meta = rawData['meta'] as Map<String, dynamic>;
        total = (meta['total'] as num?)?.toInt() ??
            (meta['totalCount'] as num?)?.toInt() ??
            (meta['total_count'] as num?)?.toInt() ??
            (meta['count'] as num?)?.toInt() ??
            (meta['itemCount'] as num?)?.toInt() ??
            0;
        pageNum = (meta['page'] as num?)?.toInt() ?? pageNum;
        limitNum = (meta['limit'] as num?)?.toInt() ?? limitNum;
      }

      if (total == 0) {
        total = (rawData['total'] as num?)?.toInt() ??
            (rawData['totalCount'] as num?)?.toInt() ??
            (rawData['total_count'] as num?)?.toInt() ??
            (rawData['count'] as num?)?.toInt() ??
            (rawData['totalCompanies'] as num?)?.toInt() ??
            (rawData['total_companies'] as num?)?.toInt() ??
            0;
      }
    }

    if (total == 0 && list.isNotEmpty) {
      total = list.length;
    }

    // Client-side pagination fallback if backend returns full unsliced list
    List<dynamic> pageList = list;
    if (rawData is List && list.length > limitNum) {
      final startIndex = (pageNum - 1) * limitNum;
      if (startIndex < list.length) {
        final endIndex = (startIndex + limitNum).clamp(0, list.length);
        pageList = list.sublist(startIndex, endIndex);
      }
    }

    final companies = pageList
        .whereType<Map>()
        .map((e) => CompanyModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return PaginatedCompaniesResponse(
      companies: companies,
      total: total,
      page: pageNum,
      limit: limitNum,
    );
  }

  @override
  Future<CompanyModel> getCompanyById(String id) async {
    final response = await _apiService.get(
      '${ApiConstants.companies}/$id',
    );

    debugPrint('[GET /api/companies/$id SUCCESS]: ${response.data}');

    final dynamic rawData = response.data;
    if (rawData is Map<String, dynamic>) {
      final data = rawData.containsKey('data') && rawData['data'] is Map<String, dynamic>
          ? rawData['data'] as Map<String, dynamic>
          : rawData;
      return CompanyModel.fromJson(data);
    }
    throw Exception('Invalid response format for getCompanyById');
  }

  @override
  Future<CompanyModel> createCompany(Map<String, dynamic> companyData) async {
    final response = await _apiService.post(
      ApiConstants.companies,
      data: companyData,
    );

    debugPrint('[POST /api/companies SUCCESS]: ${response.data}');

    final dynamic rawData = response.data;
    if (rawData is Map<String, dynamic>) {
      final data = rawData.containsKey('data') && rawData['data'] is Map<String, dynamic>
          ? rawData['data'] as Map<String, dynamic>
          : rawData;
      return CompanyModel.fromJson(data);
    }
    throw Exception('Invalid response format for createCompany');
  }

  @override
  Future<CompanyModel> updateCompany(String id, Map<String, dynamic> companyData) async {
    dynamic rawData;
    try {
      final response = await _apiService.patch(
        '${ApiConstants.companies}/$id',
        data: companyData,
      );
      debugPrint('[PATCH /api/companies/$id SUCCESS]: ${response.data}');
      rawData = response.data;
    } catch (e) {
      debugPrint('[PATCH /api/companies/$id FAILED, RETRYING PUT]: $e');
      try {
        final response = await _apiService.put(
          '${ApiConstants.companies}/$id',
          data: companyData,
        );
        debugPrint('[PUT /api/companies/$id SUCCESS]: ${response.data}');
        rawData = response.data;
      } catch (putErr) {
        debugPrint('[PUT /api/companies/$id FAILED TOO]: $putErr');
        rethrow;
      }
    }

    if (rawData is Map<String, dynamic>) {
      final data = rawData.containsKey('data') && rawData['data'] is Map<String, dynamic>
          ? rawData['data'] as Map<String, dynamic>
          : rawData;
      return CompanyModel.fromJson({'id': id, ...data, ...companyData});
    }
    return CompanyModel.fromJson({'id': id, ...companyData});
  }

  @override
  Future<bool> deleteCompany(String id) async {
    final response = await _apiService.delete(
      '${ApiConstants.companies}/$id',
    );

    debugPrint('[DELETE /api/companies/$id SUCCESS]: ${response.statusCode}');
    return response.statusCode == 200 || response.statusCode == 204;
  }
}
