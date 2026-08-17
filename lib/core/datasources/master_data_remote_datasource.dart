import 'package:flutter/foundation.dart';
import '../network/api_constants.dart';
import '../network/api_service.dart';
import '../models/master_dropdown_model.dart';

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
  });
  Future<List<Map<String, dynamic>>> getUnifiedTimeline({
    String? contactId,
    String? companyId,
    String? dealId,
    int? page,
    int? limit,
  });
  Future<List<Map<String, dynamic>>> getEmailTemplates({bool flat = true});
  Future<Map<String, dynamic>> createEmailTemplate(Map<String, dynamic> data);
  Future<Map<String, dynamic>> updateEmailTemplate(String id, Map<String, dynamic> data);
  Future<List<Map<String, dynamic>>> getMeetingSchedulers();
  Future<Map<String, dynamic>> getSequences({int page = 1, int limit = 20});
  Future<Map<String, dynamic>> getSequenceById(String id);
  Future<List<Map<String, dynamic>>> getSequenceEnrollments(String id);
  Future<Map<String, dynamic>> getSequencePerformance(String id);
  Future<List<Map<String, dynamic>>> getSequenceLogs(String id);
  Future<List<Map<String, dynamic>>> getReportsScope();
  Future<List<Map<String, dynamic>>> getReportsUsers({int limit = 200});
  Future<List<Map<String, dynamic>>> getReportsDashboards();
  Future<Map<String, dynamic>> getReportsDashboardsDefault({String? departmentId});
}

class MasterDataRemoteDataSourceImpl implements MasterDataRemoteDataSource {
  final ApiService _apiService;

  MasterDataRemoteDataSourceImpl({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  @override
  Future<List<MspOptionModel>> getMspOptions() async {
    final response = await _apiService.get(ApiConstants.mspOptions);
    debugPrint('[GET ${ApiConstants.mspOptions} SUCCESS]: ${response.data}');

    final dynamic rawData = response.data;
    List<dynamic> list = [];

    if (rawData is List) {
      list = rawData;
    } else if (rawData is Map<String, dynamic>) {
      if (rawData['data'] is List) {
        list = rawData['data'] as List;
      } else if (rawData['items'] is List) {
        list = rawData['items'] as List;
      } else if (rawData.containsKey('id') && rawData.containsKey('name')) {
        return [MspOptionModel.fromJson(rawData)];
      }
    }

    return list
        .whereType<Map<String, dynamic>>()
        .map((json) => MspOptionModel.fromJson(json))
        .toList();
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
  }) async {
    final queryParameters = <String, dynamic>{};
    if (ownerId != null && ownerId.isNotEmpty) queryParameters['ownerId'] = ownerId;
    if (status != null && status.isNotEmpty) queryParameters['status'] = status;
    if (limit != null) queryParameters['limit'] = limit.toString();
    if (page != null) queryParameters['page'] = page.toString();
    if (type != null && type.isNotEmpty) queryParameters['type'] = type;
    if (contactId != null && contactId.isNotEmpty) queryParameters['contactId'] = contactId;
    if (companyId != null && companyId.isNotEmpty) queryParameters['companyId'] = companyId;
    if (dealId != null && dealId.isNotEmpty) queryParameters['dealId'] = dealId;
    if (departmentId != null && departmentId.isNotEmpty) {
      queryParameters['department_id'] = departmentId;
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

    debugPrint('========== DEPARTMENT API TRACE ==========');
    debugPrint('Screen: Activities ($type)');
    debugPrint('API: ${ApiConstants.activities}?type=$type');
    debugPrint('Selected Department ID: $departmentId');
    debugPrint('Request department_id: $departmentId');
    debugPrint('Response status: ${response.statusCode}');
    debugPrint('First returned record departmentId: $firstRecordDeptId');
    debugPrint('==========================================');

    if (firstRecordDeptId != null && departmentId != null && firstRecordDeptId != departmentId) {
      debugPrint('REQUESTED DEPARTMENT: $departmentId');
      debugPrint('RETURNED RECORD DEPARTMENT: $firstRecordDeptId');
    }

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
    if (contactId != null && contactId.isNotEmpty) queryParameters['contactId'] = contactId;
    if (companyId != null && companyId.isNotEmpty) queryParameters['companyId'] = companyId;
    if (dealId != null && dealId.isNotEmpty) queryParameters['dealId'] = dealId;
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
  Future<List<Map<String, dynamic>>> getEmailTemplates({bool flat = true}) async {
    final response = await _apiService.get(
      ApiConstants.emailTemplatesList,
      queryParameters: {'flat': flat.toString()},
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
    final response = await _apiService.post(
      ApiConstants.emailTemplatesList,
      data: data,
    );
    debugPrint('[POST ${ApiConstants.emailTemplatesList} SUCCESS]: ${response.data}');
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
  Future<Map<String, dynamic>> updateEmailTemplate(String id, Map<String, dynamic> data) async {
    final response = await _apiService.put(
      '${ApiConstants.emailTemplatesList}/$id',
      data: data,
    );
    debugPrint('[PUT ${ApiConstants.emailTemplatesList}/$id SUCCESS]: ${response.data}');
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
  Future<Map<String, dynamic>> getReportsDashboardsDefault({String? departmentId}) async {
    final queryParameters = <String, dynamic>{};
    if (departmentId != null && departmentId.isNotEmpty) {
      queryParameters['department_id'] = departmentId;
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
