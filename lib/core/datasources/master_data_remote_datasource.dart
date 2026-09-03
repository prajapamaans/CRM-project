import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../network/api_constants.dart';
import '../network/api_service.dart';
import '../network/network_exception.dart';
import '../models/master_dropdown_model.dart';
import '../models/email_signature_model.dart';
import '../models/email_template_models.dart';

abstract class MasterDataRemoteDataSource {
  Future<List<LifecycleStageModel>> getLifecycleStages({required String entityType});
  Future<List<MasterDropdownOptionModel>> getMasterDropdownByKey(
    String key, {
    bool includeInactive = false,
  });
  Future<List<MspOptionModel>> getMspOptions();
  Future<List<Map<String, dynamic>>> getDepartments();
  Future<List<Map<String, dynamic>>> getNotifications({bool? isRead, int? limit, String? departmentId});
  Future<List<Map<String, dynamic>>> getDealStages();
  Future<List<Map<String, dynamic>>> getActivities({
    String? ownerId,
    String? status,
    int? limit,
    String? type,
    int? page,
    String? contactId,
    String? companyId,
    String? dealId,
    String? departmentId,
    String? sort,
    String? order,
    String? search,
    String? bookingSource,
    String? createdDateRange,
    String? priority,
  });
  Future<List<Map<String, dynamic>>> getUnifiedTimeline({
    String? contactId,
    String? companyId,
    String? dealId,
    int? page,
    int? limit,
  });
  Future<List<Map<String, dynamic>>> getEmailTemplates({bool flat = true, String? departmentId});
  Future<EmailTemplatesResponse> getEmailTemplatesFull({String? departmentId});
  Future<Map<String, dynamic>> createEmailTemplate(Map<String, dynamic> data);
  Future<Map<String, dynamic>> createEmailTemplateFolder(Map<String, dynamic> data);
  Future<Map<String, dynamic>> updateEmailTemplate(String id, Map<String, dynamic> data);
  Future<List<EmailSignatureModel>> getEmailSignatures();
  Future<EmailSignatureModel> createEmailSignature(Map<String, dynamic> data);
  Future<EmailSignatureModel> updateEmailSignature(String id, Map<String, dynamic> data);
  Future<bool> deleteEmailSignature(String id);
  Future<List<Map<String, dynamic>>> getMeetingSchedulers();
  Future<Map<String, dynamic>> getSequences({int page = 1, int limit = 20});
  Future<Map<String, dynamic>> getSequenceById(String id);
  Future<List<Map<String, dynamic>>> getSequenceEnrollments(String id);
  Future<Map<String, dynamic>> getSequencePerformance(String id);
  Future<List<Map<String, dynamic>>> getSequenceLogs(String id);
  Future<List<Map<String, dynamic>>> getReportsScope();
  Future<List<Map<String, dynamic>>> getReportsUsers({int limit = 200});
  Future<List<Map<String, dynamic>>> getReportsDashboards();
  Future<Map<String, dynamic>> getReportsDashboardsDefault({String? departmentId, String? ownerId});
}

class MasterDataRemoteDataSourceImpl implements MasterDataRemoteDataSource {
  final ApiService _apiService;

  MasterDataRemoteDataSourceImpl({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  /// `GET /api/msp-options` answers with a direct JSON array of names,
  /// e.g. `["Magnit", "Beeline", "agileOne"]` — there is no `data` wrapper.
  @override
  Future<List<MspOptionModel>> getMspOptions() async {
    final response = await _apiService.get(ApiConstants.mspOptions);
    debugPrint('[GET ${ApiConstants.mspOptions} SUCCESS]: ${response.data}');

    final dynamic rawData = response.data;
    List<dynamic> list = const [];

    if (rawData is List) {
      list = rawData;
    } else if (rawData is String && rawData.trim().isNotEmpty) {
      // Served without a JSON content type — decode it ourselves.
      final decoded = jsonDecode(rawData);
      if (decoded is List) list = decoded;
    } else if (rawData is Map) {
      final map = Map<String, dynamic>.from(rawData);
      final wrapped = map['data'] ?? map['items'] ?? map['mspOptions'];
      if (wrapped is List) list = wrapped;
    }

    final options = <MspOptionModel>[];
    final seen = <String>{};

    for (var i = 0; i < list.length; i++) {
      final entry = list[i];
      MspOptionModel? option;

      if (entry is String) {
        option = MspOptionModel.fromValue(entry, position: i);
      } else if (entry is Map) {
        option = MspOptionModel.fromJson(Map<String, dynamic>.from(entry));
      }

      if (option == null || option.name.isEmpty) continue;
      if (seen.add(option.name.toLowerCase())) options.add(option);
    }

    return options;
  }

  @override
  Future<List<LifecycleStageModel>> getLifecycleStages({required String entityType}) async {
    final response = await _apiService.get(
      ApiConstants.lifecycleStages,
      queryParameters: {'entityType': entityType},
    );

    debugPrint('[GET ${ApiConstants.lifecycleStages}?entityType=$entityType SUCCESS]: ${response.data}');

    final dynamic rawData = response.data;
    List<dynamic> list = [];

    if (rawData is List) {
      list = rawData;
    } else if (rawData is Map<String, dynamic>) {
      if (rawData['data'] is List) {
        list = rawData['data'] as List;
      } else if (rawData['items'] is List) {
        list = rawData['items'] as List;
      } else if (rawData['stages'] is List) {
        list = rawData['stages'] as List;
      }
    }

    return list
        .whereType<Map<String, dynamic>>()
        .map((json) => LifecycleStageModel.fromJson(json))
        .toList();
  }

  @override
  Future<List<MasterDropdownOptionModel>> getMasterDropdownByKey(
    String key, {
    bool includeInactive = false,
  }) async {
    final path = ApiConstants.masterDropdownByKey(key);
    final response = await _apiService.get(
      path,
      queryParameters: {'includeInactive': includeInactive.toString()},
    );

    debugPrint('[GET $path SUCCESS]: ${response.data}');

    final dynamic rawData = response.data;
    List<dynamic> list = [];

    if (rawData is List) {
      list = rawData;
    } else if (rawData is Map<String, dynamic>) {
      if (rawData['data'] is List) {
        list = rawData['data'] as List;
      } else if (rawData['data'] is Map<String, dynamic>) {
        final dataMap = rawData['data'] as Map<String, dynamic>;
        if (dataMap['options'] is List) {
          list = dataMap['options'] as List;
        } else if (dataMap['items'] is List) {
          list = dataMap['items'] as List;
        }
      } else if (rawData['options'] is List) {
        list = rawData['options'] as List;
      } else if (rawData['items'] is List) {
        list = rawData['items'] as List;
      } else if (rawData.containsKey('id') && rawData.containsKey('value')) {
        // Single object returned
        return [MasterDropdownOptionModel.fromJson(Map<String, dynamic>.from(rawData))];
      }
    }

    return list
        .whereType<Map>()
        .map((e) => MasterDropdownOptionModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getDepartments() async {
    final response = await _apiService.get(ApiConstants.departments);
    debugPrint('[GET ${ApiConstants.departments} SUCCESS]: ${response.data}');

    final dynamic rawData = response.data;
    List<dynamic> list = [];

    if (rawData is List) {
      list = rawData;
    } else if (rawData is Map<String, dynamic>) {
      if (rawData['data'] is List) {
        list = rawData['data'] as List;
      } else if (rawData['departments'] is List) {
        list = rawData['departments'] as List;
      } else if (rawData['items'] is List) {
        list = rawData['items'] as List;
      }
    }

    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getNotifications({bool? isRead, int? limit, String? departmentId}) async {
    final queryParameters = <String, dynamic>{};
    if (isRead != null) queryParameters['isRead'] = isRead.toString();
    if (limit != null) queryParameters['limit'] = limit.toString();
    if (departmentId != null && departmentId.isNotEmpty) {
      queryParameters['department_id'] = departmentId;
    }

    final response = await _apiService.get(
      ApiConstants.notifications,
      queryParameters: queryParameters,
    );

    final dynamic rawData = response.data;
    List<dynamic> list = [];

    if (rawData is List) {
      list = rawData;
    } else if (rawData is Map<String, dynamic>) {
      if (rawData['data'] is List) {
        list = rawData['data'] as List;
      } else if (rawData['notifications'] is List) {
        list = rawData['notifications'] as List;
      } else if (rawData['items'] is List) {
        list = rawData['items'] as List;
      }
    }

    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getDealStages() async {
    final response = await _apiService.get(ApiConstants.dealsStages);

    final dynamic rawData = response.data;
    List<dynamic> list = [];

    if (rawData is List) {
      list = rawData;
    } else if (rawData is Map<String, dynamic>) {
      if (rawData['data'] is List) {
        list = rawData['data'] as List;
      } else if (rawData['stages'] is List) {
        list = rawData['stages'] as List;
      } else if (rawData['items'] is List) {
        list = rawData['items'] as List;
      }
    }

    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getActivities({
    String? ownerId,
    String? status,
    int? limit,
    String? type,
    int? page,
    String? contactId,
    String? companyId,
    String? dealId,
    String? departmentId,
    String? sort,
    String? order,
    String? search,
    String? bookingSource,
    String? createdDateRange,
    String? priority,
  }) async {
    final queryParameters = <String, dynamic>{};
    if (ownerId != null && ownerId.isNotEmpty) {
      queryParameters['ownerId'] = ownerId;
      queryParameters['owner_id'] = ownerId;
    }
    if (status != null && status.isNotEmpty) queryParameters['status'] = status;
    if (limit != null) queryParameters['limit'] = limit.toString();
    if (page != null) queryParameters['page'] = page.toString();
    if (type != null && type.isNotEmpty) queryParameters['type'] = type;
    if (sort != null && sort.isNotEmpty) queryParameters['sort'] = sort;
    if (order != null && order.isNotEmpty) queryParameters['order'] = order;
    if (search != null && search.isNotEmpty) queryParameters['search'] = search;
    if (bookingSource != null && bookingSource.isNotEmpty) {
      queryParameters['bookingSource'] = bookingSource;
      queryParameters['booking_source'] = bookingSource;
    }
    if (createdDateRange != null && createdDateRange.isNotEmpty) {
      queryParameters['createdDateRange'] = createdDateRange;
      queryParameters['created_date_range'] = createdDateRange;
    }
    if (priority != null && priority.isNotEmpty) queryParameters['priority'] = priority;
    if (contactId != null && contactId.isNotEmpty) {
      queryParameters['contactId'] = contactId;
      queryParameters['contact_id'] = contactId;
    }
    if (companyId != null && companyId.isNotEmpty) {
      queryParameters['companyId'] = companyId;
      queryParameters['company_id'] = companyId;
    }
    if (dealId != null && dealId.isNotEmpty) {
      queryParameters['dealId'] = dealId;
      queryParameters['deal_id'] = dealId;
    }
    if (departmentId != null && departmentId.isNotEmpty) {
      queryParameters['department_id'] = departmentId;
      queryParameters['departmentId'] = departmentId;
    }

    final response = await _apiService.get(
      ApiConstants.activities,
      queryParameters: queryParameters,
    );

    final dynamic rawData = response.data;
    List<dynamic> list = [];

    if (rawData is List) {
      list = rawData;
    } else if (rawData is Map<String, dynamic>) {
      if (rawData['data'] is List) {
        list = rawData['data'] as List;
      } else if (rawData['activities'] is List) {
        list = rawData['activities'] as List;
      } else if (rawData['items'] is List) {
        list = rawData['items'] as List;
      }
    }

    final String? firstRecordDeptId = list.isNotEmpty && list.first is Map
        ? (list.first['departmentId'] ?? list.first['department_id'] ?? list.first['department']?['id'])?.toString()
        : null;

    debugPrint('========== DEPARTMENT DATA COMPARISON ==========');
    debugPrint('DEPARTMENT REQUESTED: $departmentId');
    debugPrint('REQUEST URL: ${ApiConstants.activities}?type=$type&department_id=$departmentId');
    debugPrint('HTTP STATUS: ${response.statusCode}');
    debugPrint('RECORD COUNT: ${list.length}');
    debugPrint('FIRST RECORD DEPT ID: $firstRecordDeptId');
    if (list.isNotEmpty) {
      final sampleIds = list.map((item) => item['id'] ?? item['_id']).take(5).toList();
      final sampleTitles = list.map((item) => item['title'] ?? item['subject'] ?? item['name']).take(5).toList();
      debugPrint('FIRST 5 RECORD IDS: $sampleIds');
      debugPrint('FIRST 5 RECORD TITLES: $sampleTitles');
      if (list.first is Map) {
        final firstMap = list.first as Map<String, dynamic>;
        debugPrint('RAW JSON KEYS IN FIRST RECORD: ${firstMap.keys.toList()}');
        debugPrint('DEPARTMENT FIELD IN RECORD: departmentId=${firstMap['departmentId']}, department_id=${firstMap['department_id']}, department=${firstMap['department']}');
      }
    }
    debugPrint('===============================================');

    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getUnifiedTimeline({
    String? contactId,
    String? companyId,
    String? dealId,
    int? page,
    int? limit,
  }) async {
    final queryParameters = <String, dynamic>{};
    if (contactId != null && contactId.isNotEmpty) {
      queryParameters['contactId'] = contactId;
      queryParameters['contact_id'] = contactId;
    }
    if (companyId != null && companyId.isNotEmpty) {
      queryParameters['companyId'] = companyId;
      queryParameters['company_id'] = companyId;
    }
    if (dealId != null && dealId.isNotEmpty) {
      queryParameters['dealId'] = dealId;
      queryParameters['deal_id'] = dealId;
    }
    if (page != null) queryParameters['page'] = page.toString();
    if (limit != null) queryParameters['limit'] = limit.toString();

    final response = await _apiService.get(
      ApiConstants.activitiesUnifiedTimeline,
      queryParameters: queryParameters,
    );
    debugPrint('[GET ${ApiConstants.activitiesUnifiedTimeline} SUCCESS]: ${response.data}');

    final dynamic rawData = response.data;
    List<dynamic> list = [];

    if (rawData is List) {
      list = rawData;
    } else if (rawData is Map<String, dynamic>) {
      if (rawData['data'] is List) {
        list = rawData['data'] as List;
      } else if (rawData['timeline'] is List) {
        list = rawData['timeline'] as List;
      } else if (rawData['items'] is List) {
        list = rawData['items'] as List;
      }
    }

    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  Future<EmailTemplatesResponse> getEmailTemplatesFull({String? departmentId}) async {
    final queryParameters = <String, dynamic>{
      'flat': 'true',
    };
    if (departmentId != null && departmentId.isNotEmpty) {
      queryParameters['departmentId'] = departmentId;
      queryParameters['department_id'] = departmentId;
    }

    final response = await _apiService.get(
      ApiConstants.emailTemplatesList,
      queryParameters: queryParameters,
    );
    debugPrint('[GET ${ApiConstants.emailTemplatesList} SUCCESS]: ${response.data}');

    final dynamic rawData = response.data;
    EmailTemplatesResponse parsed;

    if (rawData is Map<String, dynamic>) {
      parsed = EmailTemplatesResponse.fromJson(rawData);
    } else if (rawData is List) {
      // The listing answered with the templates themselves.
      parsed = EmailTemplatesResponse(
        success: true,
        folders: const [],
        templates: rawData
            .whereType<Map<String, dynamic>>()
            .map((e) => EmailTemplate.fromJson(e))
            .toList(),
        path: const [],
      );
    } else {
      parsed = const EmailTemplatesResponse(
        success: false,
        folders: [],
        templates: [],
        path: [],
      );
    }

    if (parsed.templates.isEmpty && parsed.folders.isEmpty) {
      // This request already asks with `flat=true`, so there is no second
      // listing left to try — an empty answer here is genuinely empty, or the
      // response carried its templates under a key this parse does not know.
      debugPrint('[GET ${ApiConstants.emailTemplatesList}] held no folders or templates '
          'for department ${departmentId ?? '(from headers)'}');
    }

    return parsed;
  }

  @override
  Future<List<Map<String, dynamic>>> getEmailTemplates({bool flat = true, String? departmentId}) async {
    final queryParameters = <String, dynamic>{
      'flat': flat.toString(),
    };
    if (departmentId != null && departmentId.isNotEmpty) {
      queryParameters['departmentId'] = departmentId;
      queryParameters['department_id'] = departmentId;
    }

    final response = await _apiService.get(
      ApiConstants.emailTemplatesList,
      queryParameters: queryParameters,
    );
    debugPrint('[GET ${ApiConstants.emailTemplatesList}?flat=$flat SUCCESS]: ${response.data}');

    final dynamic rawData = response.data;
    List<dynamic> list = [];

    if (rawData is Map<String, dynamic>) {
      if (rawData['templates'] is List) {
        list = rawData['templates'] as List;
      } else if (rawData['data'] is List) {
        list = rawData['data'] as List;
      } else if (rawData['items'] is List) {
        list = rawData['items'] as List;
      }
    } else if (rawData is List) {
      list = rawData;
    }

    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> createEmailTemplate(Map<String, dynamic> data) async {
    final payload = _templateWritePayload(data);
    debugPrint('[POST ${ApiConstants.emailTemplates}] payload=$payload');

    try {
      final response = await _apiService.post(
        ApiConstants.emailTemplates,
        data: payload,
      );
      debugPrint('[POST ${ApiConstants.emailTemplates} SUCCESS]: ${response.data}');
      return _templateWriteResult(response.data);
    } on NetworkException catch (e) {
      // A rejected template — a validation error, a permission problem — is
      // reported with what the server said. Only a missing route is worth
      // retrying elsewhere; posting a rejected body to the listing path was
      // just a second failure with a worse message.
      if (e.statusCode != 404 && e.statusCode != 405) {
        debugPrint('[POST ${ApiConstants.emailTemplates} REJECTED ${e.statusCode}]: '
            '${e.message} — ${e.data}');
        rethrow;
      }
      debugPrint('[POST ${ApiConstants.emailTemplates} unsupported (${e.statusCode}), '
          'retrying on ${ApiConstants.emailTemplatesList}]');
      final response = await _apiService.post(
        ApiConstants.emailTemplatesList,
        data: payload,
      );
      debugPrint('[POST ${ApiConstants.emailTemplatesList} SUCCESS]: ${response.data}');
      return _templateWriteResult(response.data);
    }
  }

  /// Prepares a template body for the API.
  ///
  /// Null values are dropped rather than sent: a template at the root level
  /// has no folder, and `"folderId": null` is rejected by a validator that
  /// would have accepted the key being absent. Ids that are blank strings go
  /// the same way, for the same reason.
  Map<String, dynamic> _templateWritePayload(Map<String, dynamic> data) {
    final payload = <String, dynamic>{};
    data.forEach((key, value) {
      if (value == null) return;
      if (key.toLowerCase().endsWith('id') && value is String && value.trim().isEmpty) return;
      payload[key] = value;
    });
    return payload;
  }

  Map<String, dynamic> _templateWriteResult(dynamic rawData) {
    if (rawData is Map<String, dynamic>) {
      if (rawData['data'] is Map<String, dynamic>) {
        return rawData['data'] as Map<String, dynamic>;
      }
      return rawData;
    }
    return {};
  }

  @override
  Future<Map<String, dynamic>> createEmailTemplateFolder(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.post(
        '${ApiConstants.emailTemplates}/folders',
        data: data,
      );
      debugPrint('[POST ${ApiConstants.emailTemplates}/folders SUCCESS]: ${response.data}');
      final dynamic rawData = response.data;
      if (rawData is Map<String, dynamic>) {
        return rawData;
      }
      return {};
    } catch (e) {
      debugPrint('[POST ${ApiConstants.emailTemplates}/folders error, fallback]: $e');
      try {
        final response = await _apiService.post(
          '${ApiConstants.emailTemplatesList}/folders',
          data: data,
        );
        final dynamic rawData = response.data;
        if (rawData is Map<String, dynamic>) {
          return rawData;
        }
      } catch (_) {}
      return {};
    }
  }

  @override
  Future<Map<String, dynamic>> updateEmailTemplate(String id, Map<String, dynamic> data) async {
    // Same sanitising as create: the id belongs in the path, and a null folder
    // is an absent key rather than a null value.
    final payload = _templateWritePayload(data)..remove('id');
    final path = '${ApiConstants.emailTemplates}/$id';
    debugPrint('[PUT $path] payload=$payload');

    try {
      final response = await _apiService.put(path, data: payload);
      debugPrint('[PUT $path SUCCESS]: ${response.data}');
      return _templateWriteResult(response.data);
    } on NetworkException catch (e) {
      if (e.statusCode != 404 && e.statusCode != 405) {
        debugPrint('[PUT $path REJECTED ${e.statusCode}]: ${e.message} — ${e.data}');
        rethrow;
      }
      debugPrint('[PUT $path unsupported (${e.statusCode}), retrying on the list path]');
      final response = await _apiService.put(
        '${ApiConstants.emailTemplatesList}/$id',
        data: payload,
      );
      debugPrint('[PUT ${ApiConstants.emailTemplatesList}/$id SUCCESS]: ${response.data}');
      return _templateWriteResult(response.data);
    }
  }

  @override
  Future<List<EmailSignatureModel>> getEmailSignatures() async {
    final response = await _apiService.get(ApiConstants.emailSignatures);
    debugPrint('[GET ${ApiConstants.emailSignatures} SUCCESS]: ${response.data}');

    final dynamic rawData = response.data;
    List<dynamic> list = [];

    if (rawData is List) {
      list = rawData;
    } else if (rawData is Map<String, dynamic>) {
      if (rawData['signatures'] is List) {
        list = rawData['signatures'] as List;
      } else if (rawData['data'] is List) {
        list = rawData['data'] as List;
      } else if (rawData['items'] is List) {
        list = rawData['items'] as List;
      }
    }

    return list
        .whereType<Map<String, dynamic>>()
        .map((e) => EmailSignatureModel.fromJson(e))
        .toList();
  }

  @override
  Future<EmailSignatureModel> createEmailSignature(Map<String, dynamic> data) async {
    final String? id = data['id']?.toString().trim();
    final bool isUpdate = id != null && id.isNotEmpty;

    // A payload that already carries an id belongs to an existing record, so it
    // is routed to the update endpoint rather than creating a second copy.
    if (isUpdate) {
      debugPrint('[createEmailSignature]: payload carries id $id, updating instead of creating.');
      return await updateEmailSignature(id, data);
    }

    final response = await _apiService.post(
      ApiConstants.emailSignatures,
      data: data,
    );
    debugPrint('[POST ${ApiConstants.emailSignatures} SUCCESS]: ${response.data}');

    final dynamic rawData = response.data;
    Map<String, dynamic> itemMap = {};

    if (rawData is Map<String, dynamic>) {
      if (rawData['signature'] is Map<String, dynamic>) {
        itemMap = rawData['signature'] as Map<String, dynamic>;
      } else if (rawData['data'] is Map<String, dynamic>) {
        itemMap = rawData['data'] as Map<String, dynamic>;
      } else {
        itemMap = rawData;
      }
    }

    return EmailSignatureModel.fromJson(itemMap);
  }

  @override
  Future<EmailSignatureModel> updateEmailSignature(String id, Map<String, dynamic> data) async {
    final signatureId = id.trim();
    if (signatureId.isEmpty) {
      // Writing an update with no id would land on the collection endpoint and
      // create a second record, which is exactly the duplicate we must avoid.
      throw ArgumentError('updateEmailSignature requires the id of an existing signature.');
    }

    // The id addresses the record in the path. Repeating it in the body is what
    // strict backends reject, and a rejected update used to fall through to a
    // create.
    final updatePayload = Map<String, dynamic>.from(data)..remove('id');
    final path = '${ApiConstants.emailSignatures}/$signatureId';

    Response<dynamic> response;
    try {
      response = await _apiService.put(path, data: updatePayload);
      debugPrint('[PUT $path SUCCESS]: ${response.data}');
    } on NetworkException catch (e) {
      // Only a missing route or an unsupported method is worth retrying with
      // PATCH. A 400/422 means the backend understood the update and refused
      // it, so retrying elsewhere would write the wrong thing.
      if (e.statusCode != 404 && e.statusCode != 405) rethrow;
      debugPrint('[PUT $path unsupported (${e.statusCode}), retrying with PATCH]');
      response = await _apiService.patch(path, data: updatePayload);
      debugPrint('[PATCH $path SUCCESS]: ${response.data}');
    }

    final dynamic rawData = response.data;
    Map<String, dynamic> itemMap = {};

    if (rawData is Map<String, dynamic>) {
      if (rawData['signature'] is Map<String, dynamic>) {
        itemMap = rawData['signature'] as Map<String, dynamic>;
      } else if (rawData['data'] is Map<String, dynamic>) {
        itemMap = rawData['data'] as Map<String, dynamic>;
      } else {
        itemMap = rawData;
      }
    }

    // Keep the record's identity even when the backend answers with a bare
    // acknowledgement, so callers see the same id they edited.
    if (itemMap['id'] == null && itemMap['_id'] == null) {
      itemMap = {...itemMap, 'id': signatureId};
    }

    final updated = EmailSignatureModel.fromJson(itemMap);
    if (updated.id != signatureId) {
      debugPrint('[PUT $path WARNING]: backend answered with id ${updated.id}, '
          'expected $signatureId — it may have created a new record instead of updating.');
    }
    return updated;
  }

  @override
  Future<bool> deleteEmailSignature(String id) async {
    try {
      await _apiService.delete('${ApiConstants.emailSignatures}/$id');
      return true;
    } catch (e) {
      debugPrint('[DELETE ${ApiConstants.emailSignatures}/$id Error]: $e');
      return false;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getMeetingSchedulers() async {
    final response = await _apiService.get(ApiConstants.meetingSchedulers);
    debugPrint('[GET ${ApiConstants.meetingSchedulers} SUCCESS]: ${response.data}');

    final dynamic rawData = response.data;
    List<dynamic> list = [];

    if (rawData is List) {
      list = rawData;
    } else if (rawData is Map<String, dynamic>) {
      if (rawData['data'] is List) {
        list = rawData['data'] as List;
      } else if (rawData['schedulers'] is List) {
        list = rawData['schedulers'] as List;
      } else if (rawData['items'] is List) {
        list = rawData['items'] as List;
      }
    }

    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> getSequences({int page = 1, int limit = 20}) async {
    final response = await _apiService.get(
      ApiConstants.sequences,
      queryParameters: {'page': page, 'limit': limit},
    );
    debugPrint('[GET ${ApiConstants.sequences} SUCCESS]: ${response.data}');

    final dynamic rawData = response.data;
    if (rawData is Map<String, dynamic>) {
      return rawData;
    }
    return {'success': true, 'data': [], 'meta': {'total': 0, 'page': page, 'limit': limit}};
  }

  @override
  Future<Map<String, dynamic>> getSequenceById(String id) async {
    final path = ApiConstants.sequenceById(id);
    final response = await _apiService.get(path);
    debugPrint('[GET $path SUCCESS]: ${response.data}');

    final dynamic rawData = response.data;
    if (rawData is Map<String, dynamic>) {
      if (rawData['data'] is Map<String, dynamic>) {
        return rawData['data'] as Map<String, dynamic>;
      }
      return rawData;
    }
    return {};
  }

  @override
  Future<List<Map<String, dynamic>>> getSequenceEnrollments(String id) async {
    final path = ApiConstants.sequenceEnrollments(id);
    final response = await _apiService.get(path);
    debugPrint('[GET $path SUCCESS]: ${response.data}');

    final dynamic rawData = response.data;
    List<dynamic> list = [];
    if (rawData is List) {
      list = rawData;
    } else if (rawData is Map<String, dynamic>) {
      if (rawData['data'] is List) {
        list = rawData['data'] as List;
      } else if (rawData['enrollments'] is List) {
        list = rawData['enrollments'] as List;
      }
    }
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  Future<Map<String, dynamic>> getSequencePerformance(String id) async {
    final path = ApiConstants.sequencePerformance(id);
    final response = await _apiService.get(path);
    debugPrint('[GET $path SUCCESS]: ${response.data}');

    final dynamic rawData = response.data;
    if (rawData is Map<String, dynamic>) {
      if (rawData['data'] is Map<String, dynamic>) {
        return rawData['data'] as Map<String, dynamic>;
      }
      return rawData;
    }
    return {};
  }

  @override
  Future<List<Map<String, dynamic>>> getSequenceLogs(String id) async {
    final path = ApiConstants.sequenceLogs(id);
    final response = await _apiService.get(path);
    debugPrint('[GET $path SUCCESS]: ${response.data}');

    final dynamic rawData = response.data;
    List<dynamic> list = [];
    if (rawData is List) {
      list = rawData;
    } else if (rawData is Map<String, dynamic>) {
      if (rawData['data'] is List) {
        list = rawData['data'] as List;
      } else if (rawData['logs'] is List) {
        list = rawData['logs'] as List;
      }
    }
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getReportsScope() async {
    final response = await _apiService.get(ApiConstants.reportsScope);
    debugPrint('[GET ${ApiConstants.reportsScope} SUCCESS]: ${response.data}');

    final dynamic rawData = response.data;
    List<dynamic> list = [];
    if (rawData is List) {
      list = rawData;
    } else if (rawData is Map<String, dynamic>) {
      if (rawData['data'] is List) {
        list = rawData['data'] as List;
      } else if (rawData['scopes'] is List) {
        list = rawData['scopes'] as List;
      }
    }
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getReportsUsers({int limit = 200}) async {
    final response = await _apiService.get(
      ApiConstants.reportsUsers,
      queryParameters: {'limit': limit.toString()},
    );
    debugPrint('[GET ${ApiConstants.reportsUsers} SUCCESS]: ${response.data}');

    final dynamic rawData = response.data;
    List<dynamic> list = [];
    if (rawData is List) {
      list = rawData;
    } else if (rawData is Map<String, dynamic>) {
      if (rawData['data'] is List) {
        list = rawData['data'] as List;
      } else if (rawData['users'] is List) {
        list = rawData['users'] as List;
      }
    }
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getReportsDashboards() async {
    final response = await _apiService.get(ApiConstants.reportsDashboards);
    debugPrint('[GET ${ApiConstants.reportsDashboards} SUCCESS]: ${response.data}');

    final dynamic rawData = response.data;
    List<dynamic> list = [];
    if (rawData is List) {
      list = rawData;
    } else if (rawData is Map<String, dynamic>) {
      if (rawData['data'] is List) {
        list = rawData['data'] as List;
      } else if (rawData['dashboards'] is List) {
        list = rawData['dashboards'] as List;
      }
    }
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  Future<Map<String, dynamic>> getReportsDashboardsDefault({String? departmentId, String? ownerId}) async {
    final queryParameters = <String, dynamic>{};
    if (departmentId != null && departmentId.isNotEmpty) {
      queryParameters['department_id'] = departmentId;
      queryParameters['departmentId'] = departmentId;
    }
    if (ownerId != null && ownerId.isNotEmpty) {
      queryParameters['ownerId'] = ownerId;
      queryParameters['owner_id'] = ownerId;
    }

    final response = await _apiService.get(
      ApiConstants.reportsDashboardsDefault,
      queryParameters: queryParameters,
    );

    final Map<String, dynamic> resData = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : {};

    final dynamic scope = resData['scope'] ?? resData['data']?['scope'];
    final scopeSelected = scope is Map ? scope['selected'] : null;
    final scopeLabel = scope is Map ? scope['label'] : null;

    final dynamic dataObj = resData['data'] ?? resData;
    final dynamic totalContactsOwned = dataObj is Map ? (dataObj['totalContactsOwned'] ?? dataObj['totalContacts'] ?? dataObj['contactsCount']) : null;
    final dynamic totalDealsOwned = dataObj is Map ? (dataObj['totalDealsOwned'] ?? dataObj['totalDeals'] ?? dataObj['dealsCount']) : null;
    final dynamic totalRevenueWon = dataObj is Map ? (dataObj['totalRevenueWon'] ?? dataObj['revenueWon'] ?? dataObj['revenue']) : null;
    final dynamic totalTasks = dataObj is Map ? (dataObj['totalTasks'] ?? dataObj['totalTask'] ?? dataObj['tasksCount']) : null;

    debugPrint('========== DEPARTMENT API TRACE ==========');
    debugPrint('Screen: Dashboard');
    debugPrint('API: ${ApiConstants.reportsDashboardsDefault}');
    debugPrint('');
    debugPrint('Selected Department: $scopeLabel');
    debugPrint('Selected Department ID: $departmentId');
    debugPrint('');
    debugPrint('Request department_id: $departmentId');
    debugPrint('');
    debugPrint('Response status: ${response.statusCode}');
    debugPrint('');
    debugPrint('First returned record departmentId: $scopeSelected');
    debugPrint('');
    debugPrint('Returned:');
    debugPrint('totalContactsOwned: $totalContactsOwned');
    debugPrint('totalDealsOwned: $totalDealsOwned');
    debugPrint('totalRevenueWon: $totalRevenueWon');
    debugPrint('totalTask: $totalTasks');
    debugPrint('==========================================');

    if (scopeSelected != null && departmentId != null && scopeSelected != departmentId) {
      debugPrint('REQUESTED DEPARTMENT: $departmentId');
      debugPrint('RETURNED RECORD DEPARTMENT: $scopeSelected');
    }

    return resData;
  }
}
