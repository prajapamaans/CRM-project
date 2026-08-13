import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/network/network_exception.dart';
import '../../../../core/providers/master_data_provider.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../authentication/data/models/user_model.dart';
import '../../../companies/presentation/providers/company_provider.dart';
import '../../../contacts/presentation/providers/contact_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../deals/presentation/providers/deal_provider.dart';
import '../../data/models/department_model.dart';
import '../../data/repositories/department_repository.dart';

enum DepartmentState { initial, loading, loaded, empty, error }

class DepartmentConstants {
  static const String apacId = 'a1b2c3d4-0000-0000-0000-000000000002';
  static const String australiaId = 'a1b2c3d4-0000-0000-0000-000000000003';
  static const String talentAcquisitionNightId = 'a1b2c3d4-0000-0000-0000-000000000001';
}

/// Centralized DepartmentProvider for managing global selected department ID,
/// role access, department switching, cache resetting, and notifying listeners.
class DepartmentProvider extends ChangeNotifier {
  final DepartmentRepository _repository;
  final SecureStorageService _storageService;

  DepartmentState _state = DepartmentState.initial;
  List<DepartmentModel> _departments = [];
  bool _isLoading = false;
  bool _isSwitchingDepartment = false;
  String? _error;

  String? _selectedDepartmentId;
  String? _selectedDepartmentName;
  String? _assignedDepartmentId;
  String _userRole = 'USER';

  DepartmentProvider({
    DepartmentRepository? repository,
    SecureStorageService? storageService,
  })  : _repository = repository ?? DepartmentRepositoryImpl(),
        _storageService = storageService ?? SecureStorageService() {
    _loadInitialStoredDepartment();
  }

  DepartmentState get state => _state;
  List<DepartmentModel> get departments => _departments;
  List<DepartmentModel> get availableDepartments => _departments;
  bool get isLoading => _isLoading;
  bool get isSwitchingDepartment => _isSwitchingDepartment;
  String? get error => _error;
  bool get isEmpty => _state == DepartmentState.empty || (_state == DepartmentState.loaded && _departments.isEmpty);

  String get selectedDepartmentId => _selectedDepartmentId ?? DepartmentConstants.apacId;
  String get selectedDepartmentName => _selectedDepartmentName ?? 'APAC Team';
  String? get assignedDepartmentId => _assignedDepartmentId;
  String get userRole => _userRole;

  bool get isSuperAdmin =>
      _userRole.toUpperCase() == 'SUPER_ADMIN' ||
      _userRole.toUpperCase() == 'SUPERADMIN' ||
      _userRole.toUpperCase() == 'SUPER ADMIN';

  bool get isAdmin =>
      _userRole.toUpperCase() == 'ADMIN' ||
      _userRole.toUpperCase() == 'ADMINISTRATOR';

  bool get isUser => !isSuperAdmin && !isAdmin;

  bool get canSwitchDepartment => isSuperAdmin;

  Future<void> _loadInitialStoredDepartment() async {
    final storedDeptId = await _storageService.getSelectedDepartmentId();
    final storedDeptName = await _storageService.getSelectedDepartmentName();
    final storedRole = await _storageService.getUserRole();
    final storedAssignedId = await _storageService.getAssignedDepartmentId();

    if (storedRole != null && storedRole.isNotEmpty) {
      _userRole = storedRole;
    }
    if (storedAssignedId != null && storedAssignedId.isNotEmpty) {
      _assignedDepartmentId = storedAssignedId;
    }
    if (storedDeptId != null && storedDeptId.isNotEmpty) {
      _selectedDepartmentId = storedDeptId;
    }
    if (storedDeptName != null && storedDeptName.isNotEmpty) {
      _selectedDepartmentName = storedDeptName;
    }
    notifyListeners();
  }

  /// Initializes department details upon user login or profile load
  Future<void> initFromUser(UserModel user) async {
    _userRole = user.role ?? 'USER';
    await _storageService.saveUserRole(_userRole);

    if (user.departments.isNotEmpty) {
      _departments = user.departments
          .map((d) => DepartmentModel(id: d.id, name: d.name))
          .toList();
    }

    final assignedId = user.departmentId ??
        (user.departments.isNotEmpty ? user.departments.first.id : '');
    _assignedDepartmentId = assignedId;
    if (assignedId.isNotEmpty) {
      await _storageService.saveAssignedDepartmentId(assignedId);
    }

    if (!isSuperAdmin) {
      // Non super-admins are strictly locked to assigned department
      _selectedDepartmentId = assignedId;
      _selectedDepartmentName = user.departmentName ??
          (_departments.isNotEmpty ? _departments.firstWhere((d) => d.id == assignedId, orElse: () => _departments.first).name : '');
    } else {
      // Super admin can restore previous selection or fallback to assigned/default
      final savedId = await _storageService.getSelectedDepartmentId();
      final savedName = await _storageService.getSelectedDepartmentName();

      if (savedId != null && savedId.isNotEmpty) {
        _selectedDepartmentId = savedId;
        _selectedDepartmentName = savedName ??
            (_departments.isNotEmpty ? _departments.firstWhere((d) => d.id == savedId, orElse: () => _departments.first).name : '');
      } else {
        _selectedDepartmentId = assignedId;
        _selectedDepartmentName = user.departmentName ?? (_departments.isNotEmpty ? _departments.first.name : '');
      }
    }

    await _storageService.saveSelectedDepartmentId(_selectedDepartmentId!);
    await _storageService.saveSelectedDepartmentName(_selectedDepartmentName!);

    notifyListeners();
  }

  /// Fetches departments from remote backend API and merges defaults if necessary.
  Future<void> fetchDepartments({bool includeDeleted = true}) async {
    _isLoading = true;
    _state = DepartmentState.loading;
    _error = null;
    notifyListeners();

    try {
      final result = await _repository.getDepartments(includeDeleted: includeDeleted);
      if (result.isNotEmpty) {
        _departments = result;
      }
      _isLoading = false;
      _state = DepartmentState.loaded;
      notifyListeners();
    } on NetworkException catch (e) {
      _error = e.message;
      _state = DepartmentState.error;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load departments.';
      _state = DepartmentState.error;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Creates a new department and reloads the department list
  Future<bool> createDepartment(String name) async {
    try {
      final newDept = await _repository.createDepartment(name);
      _departments.add(newDept);
      notifyListeners();
      await fetchDepartments();
      return true;
    } catch (e) {
      debugPrint('[DepartmentProvider createDepartment error]: $e');
      return false;
    }
  }

  /// Renames an existing department by ID
  Future<bool> renameDepartment(String id, String newName) async {
    try {
      await _repository.updateDepartment(id, newName);
      final index = _departments.indexWhere((d) => d.id == id);
      if (index != -1) {
        _departments[index] = DepartmentModel(
          id: id,
          name: newName,
          slug: _departments[index].slug,
          deletedAt: _departments[index].deletedAt,
        );
        if (_selectedDepartmentId == id) {
          _selectedDepartmentName = newName;
          await _storageService.saveSelectedDepartmentName(newName);
        }
        notifyListeners();
      }
      await fetchDepartments();
      return true;
    } catch (e) {
      debugPrint('[DepartmentProvider renameDepartment error]: $e');
      return false;
    }
  }

  /// Archives (soft-deletes) a department by ID
  Future<bool> archiveDepartment(String id) async {
    try {
      await _repository.deleteDepartment(id);
      _departments.removeWhere((d) => d.id == id);
      notifyListeners();
      await fetchDepartments();
      return true;
    } catch (e) {
      debugPrint('[DepartmentProvider archiveDepartment error]: $e');
      return false;
    }
  }

  /// Allows Super Admin to switch active department across the entire app.
  /// Automatically resets all feature provider states, updates global storage,
  /// and reloads all department-specific data.
  Future<void> changeDepartment(
    BuildContext context,
    String departmentId,
    String departmentName,
  ) async {
    if (!canSwitchDepartment) {
      debugPrint('[DepartmentProvider] Switching denied: User role $_userRole cannot switch departments.');
      return;
    }

    if (_selectedDepartmentId == departmentId && !_isSwitchingDepartment) {
      return;
    }

    _isSwitchingDepartment = true;
    _selectedDepartmentId = departmentId;
    _selectedDepartmentName = departmentName;
    notifyListeners();

    await _storageService.saveSelectedDepartmentId(departmentId);
    await _storageService.saveSelectedDepartmentName(departmentName);

    try {
      if (context.mounted) {
        // 1. Reset & clear stale cached data from providers
        _clearAllProviderData(context);

        // 2. Reload all department-specific data asynchronously
        await _reloadAllDepartmentData(context);
      }
    } catch (e) {
      debugPrint('[DepartmentProvider] Error switching department data: $e');
    } finally {
      _isSwitchingDepartment = false;
      notifyListeners();
    }
  }

  /// Clears cached state across active Providers
  void _clearAllProviderData(BuildContext context) {
    try {
      context.read<DashboardProvider>().clearData();
      context.read<ContactProvider>().clearData();
      context.read<CompanyProvider>().clearData();
      context.read<DealProvider>().clearData();
      context.read<MasterDataProvider>().clearData();
    } catch (e) {
      debugPrint('[DepartmentProvider] Warning during provider cleardown: $e');
    }
  }

  /// Trigger concurrency load of department-specific APIs
  Future<void> _reloadAllDepartmentData(BuildContext context) async {
    try {
      final dashboardProvider = context.read<DashboardProvider>();
      final contactProvider = context.read<ContactProvider>();
      final companyProvider = context.read<CompanyProvider>();
      final dealProvider = context.read<DealProvider>();
      final masterDataProvider = context.read<MasterDataProvider>();

      await Future.wait<void>([
        dashboardProvider.loadDashboardData(),
        contactProvider.fetchContacts(refresh: true),
        companyProvider.fetchCompanies(refresh: true),
        dealProvider.fetchDeals(refresh: true),
        dealProvider.fetchDealStats(),
        masterDataProvider.fetchAllMasterData(),
      ]);
    } catch (e) {
      debugPrint('[DepartmentProvider] Error reloading department data: $e');
    }
  }
}
