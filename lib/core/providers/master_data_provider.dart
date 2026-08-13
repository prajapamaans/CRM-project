import 'package:flutter/material.dart';
import '../models/master_dropdown_model.dart';
import '../repositories/master_data_repository.dart';

class MasterDataProvider extends ChangeNotifier {
  final MasterDataRepository _repository;

  MasterDataProvider({MasterDataRepository? repository})
      : _repository = repository ?? MasterDataRepositoryImpl();

  List<LifecycleStageModel> _companyLifecycleStages = [];
  List<LifecycleStageModel> _contactLifecycleStages = [];
  List<MasterDropdownOptionModel> _companyIndustryOptions = [];
  List<MasterDropdownOptionModel> _companyTypeOptions = [];
  List<MasterDropdownOptionModel> _contactLeadStatusOptions = [];
  List<MasterDropdownOptionModel> _meetingOutcomeOptions = [];
  List<MspOptionModel> _mspOptions = [];
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _notifications = [];

  bool _isLoading = false;
  String? _error;

  List<LifecycleStageModel> get companyLifecycleStages => _companyLifecycleStages;
  List<LifecycleStageModel> get contactLifecycleStages => _contactLifecycleStages;
  List<MasterDropdownOptionModel> get companyIndustryOptions => _companyIndustryOptions;
  List<MasterDropdownOptionModel> get companyTypeOptions => _companyTypeOptions;
  List<MasterDropdownOptionModel> get contactLeadStatusOptions => _contactLeadStatusOptions;
  List<MasterDropdownOptionModel> get meetingOutcomeOptions => _meetingOutcomeOptions;
  List<MspOptionModel> get mspOptions => _mspOptions;
  List<Map<String, dynamic>> get departments => _departments;
  List<Map<String, dynamic>> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Loads master options for Company entity
  Future<void> fetchCompanyMasterData() async {
    await fetchAllMasterData();
  }

  List<Map<String, dynamic>> _dealStages = [];
  List<Map<String, dynamic>> _unreadNotifications = [];
  List<Map<String, dynamic>> _pendingActivities = [];
  List<Map<String, dynamic>> _reportsScope = [];
  List<Map<String, dynamic>> _reportsUsers = [];
  List<Map<String, dynamic>> _reportsDashboards = [];
  Map<String, dynamic> _defaultReportDashboard = {};

  List<Map<String, dynamic>> get dealStages => _dealStages;
  List<Map<String, dynamic>> get unreadNotifications => _unreadNotifications;
  List<Map<String, dynamic>> get pendingActivities => _pendingActivities;
  List<Map<String, dynamic>> get reportsScope => _reportsScope;
  List<Map<String, dynamic>> get reportsUsers => _reportsUsers;
  List<Map<String, dynamic>> get reportsDashboards => _reportsDashboards;
  Map<String, dynamic> get defaultReportDashboard => _defaultReportDashboard;

  /// Loads master options across Company & Contact entities, Departments, Notifications, Deal Stages, Pending Activities, and Reports APIs.
  Future<void> fetchAllMasterData({String? currentUserId, String? departmentId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.getLifecycleStages(entityType: 'company'),
        _repository.getLifecycleStages(entityType: 'contact'),
        _repository.getMasterDropdownByKey('company_industry', includeInactive: false),
        _repository.getMasterDropdownByKey('company_type', includeInactive: false),
        _repository.getMasterDropdownByKey('contact_lead_status', includeInactive: false),
        _repository.getMspOptions(),
        _repository.getDepartments(),
        _repository.getNotifications(),
        _repository.getDealStages(),
        _repository.getNotifications(isRead: false, limit: 10),
        _repository.getActivities(
          ownerId: currentUserId ?? '311fee58-ba54-42b9-8795-f3ba19255b20',
          status: 'pending',
          limit: 10,
          type: 'task',
        ),
        _repository.getMasterDropdownByKey('meeting_outcome', includeInactive: false),
        _repository.getReportsScope(),
        _repository.getReportsUsers(limit: 200),
        _repository.getReportsDashboards(),
        _repository.getReportsDashboardsDefault(departmentId: departmentId),
      ]);

      _companyLifecycleStages = results[0] as List<LifecycleStageModel>;
      _contactLifecycleStages = results[1] as List<LifecycleStageModel>;
      _companyIndustryOptions = results[2] as List<MasterDropdownOptionModel>;
      _companyTypeOptions = results[3] as List<MasterDropdownOptionModel>;
      _contactLeadStatusOptions = results[4] as List<MasterDropdownOptionModel>;
      _mspOptions = results[5] as List<MspOptionModel>;
      _departments = results[6] as List<Map<String, dynamic>>;
      _notifications = results[7] as List<Map<String, dynamic>>;
      _dealStages = results[8] as List<Map<String, dynamic>>;
      _unreadNotifications = results[9] as List<Map<String, dynamic>>;
      _pendingActivities = results[10] as List<Map<String, dynamic>>;
      _meetingOutcomeOptions = results[11] as List<MasterDropdownOptionModel>;
      _reportsScope = results[12] as List<Map<String, dynamic>>;
      _reportsUsers = results[13] as List<Map<String, dynamic>>;
      _reportsDashboards = results[14] as List<Map<String, dynamic>>;
      _defaultReportDashboard = results[15] as Map<String, dynamic>;
    } catch (e) {
      _error = e.toString();
      debugPrint('[MasterDataProvider fetchAllMasterData error]: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clears master data cache during department switch.
  void clearData() {
    _notifications = [];
    _unreadNotifications = [];
    _pendingActivities = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
