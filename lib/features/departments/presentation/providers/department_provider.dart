// ============================================================================
// FILE PURPOSE & ARCHITECTURE OVERVIEW:
// ============================================================================
// What does this file do?
// -----------------------
// `department_provider.dart` is the central state management provider for organization departments
// in the APIDEL CRM application. It tracks the currently selected department ID (`selectedDepartmentId`),
// department permissions based on user role (`SUPER_ADMIN`, `ADMIN`, `USER`), persists choices to
// secure local storage, and handles cross-provider data cache clearing and re-fetching when switching departments.
//
// How does the application workflow work in this file?
// ---------------------------------------------------
// 1. **Initialization (`_loadInitialStoredDepartment` & `initFromUser`)**:
//    - Restores saved department selections and user role from `SecureStorageService`.
//    - Populates available departments list from user profile or backend defaults (`DepartmentConstants`).
// 2. **Department Switch Execution (`changeDepartment`)**:
//    - Sets `_isSwitchingDepartment = true` to display the top loading overlay.
//    - Persists the new department ID and name to local storage.
//    - Calls `_clearAllProviderData` to reset stale cached state in `DashboardProvider`, `ContactProvider`,
//      `CompanyProvider`, `DealProvider`, and `MasterDataProvider`.
//    - Calls `_reloadAllDepartmentData` via `Future.wait` to query backend REST APIs passing `department_id=<newId>`.
//    - Resets `_isSwitchingDepartment = false` and calls `notifyListeners()`.
//
// Explanation of Key Flutter & Project Keywords / Concepts:
// --------------------------------------------------------
// • `ChangeNotifier`: A class provided by Flutter that allows objects to send change notifications to listeners.
// • `notifyListeners()`: Broadcasts a signal to all listening widgets (`Consumer`, `context.watch`) to rebuild.
// • `SecureStorageService`: Encrypted local storage wrapper (`flutter_secure_storage`) for persisting department choices.
// • `enum DepartmentState`: Tracks discrete UI state phases (`initial`, `loading`, `loaded`, `empty`, `error`).
// • `Future.wait`: Concurrently executes multiple asynchronous provider API calls during department switching.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/network_exception.dart';
import '../../../../core/providers/master_data_provider.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../authentication/data/models/user_model.dart';
import '../../../authentication/data/repositories/auth_repository.dart';
import '../../../companies/presentation/providers/company_provider.dart';
import '../../../contacts/presentation/providers/contact_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../deals/presentation/providers/deal_provider.dart';
import '../../data/models/department_model.dart';
import '../../data/repositories/department_repository.dart';

/// Enum representing current state phase of department operations
enum DepartmentState { initial, loading, loaded, empty, error }

/// Constants for default fallback department UUIDs
class DepartmentConstants {
  static const String apacId = 'a1b2c3d4-0000-0000-0000-000000000002';
  static const String australiaId = 'a1b2c3d4-0000-0000-0000-000000000003';
  static const String talentAcquisitionNightId = 'a1b2c3d4-0000-0000-0000-000000000001';
}

/// Centralized DepartmentProvider managing selected department state and cross-provider re-fetching.
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

  // Hardcoded default department list fallbacks
  static final List<DepartmentModel> defaultDepartments = [
    const DepartmentModel(id: DepartmentConstants.apacId, name: 'APAC Team'),
    const DepartmentModel(id: DepartmentConstants.australiaId, name: 'Australia'),
    const DepartmentModel(id: DepartmentConstants.talentAcquisitionNightId, name: 'Talent Acquisition Night'),
  ];

  // Getters for department state variables
  DepartmentState get state => _state;
  List<DepartmentModel> get departments => _departments;
  List<DepartmentModel> get availableDepartments => _departments.isNotEmpty ? _departments : defaultDepartments;
  bool get isLoading => _isLoading;
  bool get isSwitchingDepartment => _isSwitchingDepartment;
  String? get error => _error;
  bool get isEmpty => _state == DepartmentState.empty || (_state == DepartmentState.loaded && _departments.isEmpty);

  String get selectedDepartmentId => _selectedDepartmentId ?? DepartmentConstants.apacId;
  String get selectedDepartmentName => _selectedDepartmentName ?? 'APAC Team';
  String? get assignedDepartmentId => _assignedDepartmentId;
  String get userRole => _userRole;

  // Role validation getters
  bool get isSuperAdmin =>
      _userRole.toUpperCase() == 'SUPER_ADMIN' ||
      _userRole.toUpperCase() == 'SUPERADMIN' ||
      _userRole.toUpperCase() == 'SUPER ADMIN';

  bool get isAdmin =>
      _userRole.toUpperCase() == 'ADMIN' ||
      _userRole.toUpperCase() == 'ADMINISTRATOR';

  bool get isUser => !isSuperAdmin && !isAdmin;

  bool get canSwitchDepartment => true;

  /// Restores saved department selections and user role from encrypted local storage.
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

    final savedId = await _storageService.getSelectedDepartmentId();
    final savedName = await _storageService.getSelectedDepartmentName();

    if (savedId != null && savedId.isNotEmpty) {
      _selectedDepartmentId = savedId;
      _selectedDepartmentName = savedName ??
          (_departments.isNotEmpty ? _departments.firstWhere((d) => d.id == savedId, orElse: () => _departments.first).name : 'APAC Team');
    } else if (assignedId.isNotEmpty) {
      _selectedDepartmentId = assignedId;
      _selectedDepartmentName = user.departmentName ?? (_departments.isNotEmpty ? _departments.first.name : 'APAC Team');
    } else {
      _selectedDepartmentId = DepartmentConstants.apacId;
      _selectedDepartmentName = 'APAC Team';
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

  /// Switches active department globally across the app.
  /// Resets stale provider state, updates storage, and reloads all department-specific data.
  Future<void> changeDepartment(
    BuildContext context,
    String departmentId,
    String departmentName,
  ) async {
    final prevDeptId = _selectedDepartmentId;
    final prevDeptName = _selectedDepartmentName;

    debugPrint('[DEPARTMENT] Switching department:');
    debugPrint('  Previous ID: $prevDeptId ($prevDeptName)');
    debugPrint('  New ID:      $departmentId ($departmentName)');

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
        // 0. Call POST /api/auth/switch-department to swap JWT access token for the selected department
        debugPrint('[DEPARTMENT] Requesting new JWT token from /api/auth/switch-department for departmentId: $departmentId');
        try {
          final authRepo = AuthRepositoryImpl();
          await authRepo.switchDepartment(departmentId);
        } catch (e) {
          debugPrint('[DepartmentProvider] Warning during token swap: $e');
        }

        if (!context.mounted) return;

        // 1. Clear stale cached data across active feature providers
        debugPrint('[STATE UPDATE] Clearing stale provider caches for new department selection');
        _clearAllProviderData(context);

        // 2. Reload department-specific data concurrently
        await _reloadAllDepartmentData(context);
      }
    } catch (e) {
      debugPrint('[DepartmentProvider] Error switching department data: $e');
    } finally {
      _isSwitchingDepartment = false;
      notifyListeners();
      debugPrint('[DEPARTMENT] Department switch completed. Displaying data for ID: $departmentId ($departmentName)');
    }
  }

  /// Clears cached state across active feature Providers
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

  /// Triggers concurrent re-fetching of department-specific APIs
  Future<void> _reloadAllDepartmentData(BuildContext context) async {
    try {
      final dashboardProvider = context.read<DashboardProvider>();
      final contactProvider = context.read<ContactProvider>();
      final companyProvider = context.read<CompanyProvider>();
      final dealProvider = context.read<DealProvider>();
      final masterDataProvider = context.read<MasterDataProvider>();

      final currentDeptId = selectedDepartmentId;
      final currentDeptName = selectedDepartmentName;

      debugPrint('[API REQUEST] Reloading all data for departmentId: $currentDeptId ($currentDeptName)');

      await Future.wait<void>([
        dashboardProvider.loadDashboardData(departmentId: currentDeptId, departmentName: currentDeptName),
        contactProvider.fetchContacts(refresh: true, departmentId: currentDeptId),
        companyProvider.fetchCompanies(refresh: true, departmentId: currentDeptId),
        dealProvider.fetchDeals(refresh: true, departmentId: currentDeptId),
        dealProvider.fetchDealStats(departmentId: currentDeptId),
        masterDataProvider.fetchAllMasterData(departmentId: currentDeptId),
      ]);

      debugPrint('[API RESPONSE] Successfully fetched all department data for ID: $currentDeptId');
    } catch (e) {
      debugPrint('[DepartmentProvider] Error reloading department data: $e');
    }
  }
}
