import 'package:flutter/foundation.dart';
import '../datasources/master_data_remote_datasource.dart';
import '../models/master_dropdown_model.dart';

abstract class MasterDataRepository {
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

class MasterDataRepositoryImpl implements MasterDataRepository {
  final MasterDataRemoteDataSource _remoteDataSource;

  MasterDataRepositoryImpl({MasterDataRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? MasterDataRemoteDataSourceImpl();

  @override
  Future<List<MspOptionModel>> getMspOptions() async {
    try {
      return await _remoteDataSource.getMspOptions();
    } catch (e) {
      debugPrint('[GET /api/msp-options ERROR]: $e');
      return [];
    }
  }

  @override
  Future<List<LifecycleStageModel>> getLifecycleStages({required String entityType}) async {
    try {
      return await _remoteDataSource.getLifecycleStages(entityType: entityType);
    } catch (e) {
      debugPrint('[GET /api/lifecycle-stages ERROR]: $e');
      return [];
    }
  }

  @override
  Future<List<MasterDropdownOptionModel>> getMasterDropdownByKey(
    String key, {
    bool includeInactive = false,
  }) async {
    try {
      return await _remoteDataSource.getMasterDropdownByKey(
        key,
        includeInactive: includeInactive,
      );
    } catch (e) {
      debugPrint('[GET /api/master-dropdowns/key/$key ERROR]: $e');
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getDepartments() async {
    try {
      return await _remoteDataSource.getDepartments();
    } catch (e) {
      debugPrint('[GET /api/departments ERROR]: $e');
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getNotifications({bool? isRead, int? limit, String? departmentId}) async {
    try {
      return await _remoteDataSource.getNotifications(isRead: isRead, limit: limit, departmentId: departmentId);
    } catch (e) {
      debugPrint('[GET /api/activities/notifications ERROR]: $e');
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getDealStages() async {
    try {
      return await _remoteDataSource.getDealStages();
    } catch (e) {
      debugPrint('[GET /api/deals/stages ERROR]: $e');
      return [];
    }
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
    try {
      return await _remoteDataSource.getActivities(
        ownerId: ownerId,
        status: status,
        limit: limit,
        type: type,
        page: page,
        contactId: contactId,
        companyId: companyId,
        dealId: dealId,
        departmentId: departmentId,
      );
    } catch (e) {
      debugPrint('[GET /api/activities ERROR]: $e');
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getUnifiedTimeline({
    String? contactId,
    String? companyId,
    String? dealId,
    int? page,
    int? limit,
  }) async {
    try {
      return await _remoteDataSource.getUnifiedTimeline(
        contactId: contactId,
        companyId: companyId,
        dealId: dealId,
        page: page,
        limit: limit,
      );
    } catch (e) {
      debugPrint('[GET /api/activities/unified-timeline ERROR]: $e');
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getEmailTemplates({bool flat = true}) async {
    try {
      return await _remoteDataSource.getEmailTemplates(flat: flat);
    } catch (e) {
      debugPrint('[GET /api/email-templates/list ERROR]: $e');
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>> createEmailTemplate(Map<String, dynamic> data) async {
    try {
      return await _remoteDataSource.createEmailTemplate(data);
    } catch (e) {
      debugPrint('[POST /api/email-templates/list ERROR]: $e');
      return {};
    }
  }

  @override
  Future<Map<String, dynamic>> updateEmailTemplate(String id, Map<String, dynamic> data) async {
    try {
      return await _remoteDataSource.updateEmailTemplate(id, data);
    } catch (e) {
      debugPrint('[PUT /api/email-templates/list/$id ERROR]: $e');
      return {};
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getMeetingSchedulers() async {
    try {
      return await _remoteDataSource.getMeetingSchedulers();
    } catch (e) {
      debugPrint('[GET /api/meeting-schedulers ERROR]: $e');
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>> getSequences({int page = 1, int limit = 20}) async {
    try {
      return await _remoteDataSource.getSequences(page: page, limit: limit);
    } catch (e) {
      debugPrint('[GET /api/sequences ERROR]: $e');
      return {'success': false, 'data': [], 'meta': {'total': 0, 'page': page, 'limit': limit}};
    }
  }

  @override
  Future<Map<String, dynamic>> getSequenceById(String id) async {
    try {
      return await _remoteDataSource.getSequenceById(id);
    } catch (e) {
      debugPrint('[GET /api/sequences/$id ERROR]: $e');
      return {};
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getSequenceEnrollments(String id) async {
    try {
      return await _remoteDataSource.getSequenceEnrollments(id);
    } catch (e) {
      debugPrint('[GET /api/sequences/$id/enrollments ERROR]: $e');
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>> getSequencePerformance(String id) async {
    try {
      return await _remoteDataSource.getSequencePerformance(id);
    } catch (e) {
      debugPrint('[GET /api/sequences/$id/performance ERROR]: $e');
      return {};
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getSequenceLogs(String id) async {
    try {
      return await _remoteDataSource.getSequenceLogs(id);
    } catch (e) {
      debugPrint('[GET /api/sequences/$id/logs ERROR]: $e');
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getReportsScope() async {
    try {
      return await _remoteDataSource.getReportsScope();
    } catch (e) {
      debugPrint('[GET /api/reports/scope ERROR]: $e');
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getReportsUsers({int limit = 200}) async {
    try {
      return await _remoteDataSource.getReportsUsers(limit: limit);
    } catch (e) {
      debugPrint('[GET /api/reports/users ERROR]: $e');
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getReportsDashboards() async {
    try {
      return await _remoteDataSource.getReportsDashboards();
    } catch (e) {
      debugPrint('[GET /api/reports/dashboards ERROR]: $e');
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>> getReportsDashboardsDefault({String? departmentId}) async {
    try {
      return await _remoteDataSource.getReportsDashboardsDefault(departmentId: departmentId);
    } catch (e) {
      debugPrint('[GET /api/reports/dashboards/default ERROR]: $e');
      return {};
    }
  }
}
