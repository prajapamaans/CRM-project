import 'package:flutter/foundation.dart';
import '../../../../../core/network/api_constants.dart';
import '../../../../../core/network/api_service.dart';
import '../../../../../core/utils/filter_query_utils.dart';
import '../../models/contact_model.dart';

class PaginatedContactsResponse {
  final List<ContactModel> contacts;
  final int total;
  final int page;
  final int limit;

  PaginatedContactsResponse({
    required this.contacts,
    required this.total,
    required this.page,
    required this.limit,
  });
}

abstract class ContactRemoteDataSource {
  Future<PaginatedContactsResponse> getContacts({
    String? page,
    String? limit,
    String? search,
    String? ownerId,
    String? departmentId,
    bool? ignorePermissions,
    String? lifecycleStage,
    String? leadStatus,
    String? createdDateRange,
    String? sort,
    String? order,
  });

  Future<ContactModel> getContactById(String id);

  Future<ContactModel> createContact(Map<String, dynamic> contactData);

  Future<ContactModel> updateContact(String id, Map<String, dynamic> contactData);

  Future<bool> deleteContact(String id, {String? departmentId});
}

class ContactRemoteDataSourceImpl implements ContactRemoteDataSource {
  final ApiService _apiService;

  ContactRemoteDataSourceImpl({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  @override
  Future<PaginatedContactsResponse> getContacts({
    String? page,
    String? limit,
    String? search,
    String? ownerId,
    String? departmentId,
    bool? ignorePermissions,
    String? lifecycleStage,
    String? leadStatus,
    String? createdDateRange,
    String? sort,
    String? order,
  }) async {
    // Only non-empty values are added. An empty `page=` fails Zod validation
    // with a 400, and an empty filter value would read as a real filter
    // server-side — after Clear, the key has to be gone, not blank.
    final queryParameters = <String, dynamic>{};
    if (page != null && page.isNotEmpty) queryParameters['page'] = page;
    if (limit != null && limit.isNotEmpty) queryParameters['limit'] = limit;
    if (search != null && search.isNotEmpty) queryParameters['search'] = search;
    if (sort != null && sort.isNotEmpty) queryParameters['sort'] = sort;
    if (order != null && order.isNotEmpty) queryParameters['order'] = order;
    if (ownerId != null && ownerId.isNotEmpty) {
      // The documented name is `ownerId`; `owner_id` is kept alongside it
      // because that is the spelling this client has always sent.
      queryParameters['ownerId'] = ownerId;
      queryParameters['owner_id'] = ownerId;
    }
    if (lifecycleStage != null && lifecycleStage.isNotEmpty) {
      queryParameters['lifecycleStage'] = lifecycleStage;
      queryParameters['lifecycle_stage'] = lifecycleStage;
      final slug = FilterValue.slugify(lifecycleStage);
      if (slug.isNotEmpty && slug != lifecycleStage) {
        queryParameters['lifecycleStageSlug'] = slug;
        queryParameters['lifecycle_stage_slug'] = slug;
      }
    }
    if (leadStatus != null && leadStatus.isNotEmpty) {
      queryParameters['leadStatus'] = leadStatus;
      queryParameters['lead_status'] = leadStatus;
      final slug = FilterValue.slugify(leadStatus);
      if (slug.isNotEmpty && slug != leadStatus) {
        queryParameters['leadStatusSlug'] = slug;
        queryParameters['lead_status_slug'] = slug;
      }
    }
    if (createdDateRange != null && createdDateRange.isNotEmpty) {
      queryParameters['createdDateRange'] = createdDateRange;
      queryParameters['created_date_range'] = createdDateRange;
    }
    if (departmentId != null && departmentId.isNotEmpty) {
      queryParameters['department_id'] = departmentId;
    }
    if (ignorePermissions == true) {
      queryParameters['ignore_permissions'] = 'true';
      queryParameters['ignorePermissions'] = 'true';
    }

    debugPrint('[GET ${ApiConstants.contacts}] query: $queryParameters');

    final response = await _apiService.get(
      ApiConstants.contacts,
      queryParameters: queryParameters,
    );

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
      } else if (rawData.containsKey('contacts') && rawData['contacts'] is List) {
        list = rawData['contacts'] as List;
      } else if (rawData.containsKey('items') && rawData['items'] is List) {
        list = rawData['items'] as List;
      }

      if (rawData.containsKey('meta') && rawData['meta'] is Map<String, dynamic>) {
        final meta = rawData['meta'] as Map<String, dynamic>;
        total = (meta['total'] as num?)?.toInt() ??
            (meta['totalCount'] as num?)?.toInt() ??
            (meta['total_count'] as num?)?.toInt() ??
            (meta['count'] as num?)?.toInt() ??
            list.length;
      } else {
        total = (rawData['total'] as num?)?.toInt() ??
            (rawData['count'] as num?)?.toInt() ??
            (rawData['totalCount'] as num?)?.toInt() ??
            list.length;
      }
    }

    final String? firstRecordDeptId = list.isNotEmpty && list.first is Map
        ? (list.first['departmentId'] ?? list.first['department_id'] ?? list.first['department']?['id'])?.toString()
        : null;

    debugPrint('========== DEPARTMENT API TRACE ==========');
    debugPrint('Screen: Contacts');
    debugPrint('API: ${ApiConstants.contacts}');
    debugPrint('Selected Department ID: $departmentId');
    debugPrint('Request department_id: $departmentId');
    debugPrint('Response status: ${response.statusCode}');
    debugPrint('First returned record departmentId: $firstRecordDeptId');
    debugPrint('==========================================');

    if (firstRecordDeptId != null && departmentId != null && firstRecordDeptId != departmentId) {
      debugPrint('REQUESTED DEPARTMENT: $departmentId');
      debugPrint('RETURNED RECORD DEPARTMENT: $firstRecordDeptId');
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

    final contacts = pageList
        .whereType<Map>()
        .map((e) => ContactModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return PaginatedContactsResponse(
      contacts: contacts,
      total: total,
      page: pageNum,
      limit: limitNum,
    );
  }

  @override
  Future<ContactModel> getContactById(String id) async {
    final response = await _apiService.get(
      '${ApiConstants.contacts}/$id',
    );

    debugPrint('[GET /api/contacts/$id SUCCESS]: ${response.data}');

    final dynamic rawData = response.data;
    if (rawData is Map<String, dynamic>) {
      final data = rawData.containsKey('data') && rawData['data'] is Map<String, dynamic>
          ? rawData['data'] as Map<String, dynamic>
          : rawData;
      return ContactModel.fromJson(data);
    }
    throw Exception('Invalid response format for getContactById');
  }

  @override
  Future<ContactModel> createContact(Map<String, dynamic> contactData) async {
    final response = await _apiService.post(
      ApiConstants.contacts,
      data: contactData,
    );

    debugPrint('[POST /api/contacts SUCCESS]: ${response.data}');

    final dynamic rawData = response.data;
    if (rawData is Map<String, dynamic>) {
      final data = rawData.containsKey('data') && rawData['data'] is Map<String, dynamic>
          ? rawData['data'] as Map<String, dynamic>
          : rawData;
      return ContactModel.fromJson(data);
    }
    throw Exception('Invalid response format for createContact');
  }

  @override
  Future<ContactModel> updateContact(String id, Map<String, dynamic> contactData) async {
    dynamic rawData;
    try {
      final response = await _apiService.patch(
        '${ApiConstants.contacts}/$id',
        data: contactData,
      );
      debugPrint('[PATCH /api/contacts/$id SUCCESS]: ${response.data}');
      rawData = response.data;
    } catch (e) {
      // PATCH is the only update route; retrying with PUT just doubled the
      // wait before the failure surfaced.
      debugPrint('[PATCH /api/contacts/$id FAILED]: $e');
      rethrow;
    }

    if (rawData is Map<String, dynamic>) {
      final data = rawData.containsKey('data') && rawData['data'] is Map<String, dynamic>
          ? rawData['data'] as Map<String, dynamic>
          : rawData;
      return ContactModel.fromJson(data);
    }
    return ContactModel.fromJson({'id': id, ...contactData});
  }

  @override
  Future<bool> deleteContact(String id, {String? departmentId}) async {
    if (id.isEmpty) {
      debugPrint('[DELETE CONTACT ERROR]: Cannot delete contact with empty ID');
      return false;
    }

    final queryParams = <String, dynamic>{};
    if (departmentId != null && departmentId.isNotEmpty) {
      queryParams['department_id'] = departmentId;
    }

    dynamic response;
    try {
      response = await _apiService.delete(
        '${ApiConstants.contacts}/$id',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
    } catch (e) {
      debugPrint('[DELETE /api/contacts/$id primary error, trying path without params]: $e');
      try {
        response = await _apiService.delete('${ApiConstants.contacts}/$id');
      } catch (e2) {
        debugPrint('[DELETE /api/contacts/$id query param error, trying fallback]: $e2');
        try {
          final fallbackParams = <String, dynamic>{'id': id};
          if (departmentId != null && departmentId.isNotEmpty) {
            fallbackParams['department_id'] = departmentId;
          }
          response = await _apiService.delete(
            ApiConstants.contacts,
            queryParameters: fallbackParams,
          );
        } catch (_) {
          rethrow;
        }
      }
    }

    final statusCode = response.statusCode ?? 0;
    debugPrint('[DELETE /api/contacts/$id SUCCESS]: $statusCode');
    return statusCode >= 200 && statusCode < 300;
  }
}
