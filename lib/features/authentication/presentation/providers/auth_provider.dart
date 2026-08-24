import 'package:flutter/foundation.dart';
import '../../../../core/network/network_exception.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../data/models/email_details_response_model.dart';
import '../../data/models/login_response_model.dart';
import '../../data/models/team_member_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';

enum AuthState { initial, loading, authenticated, unauthenticated, error }

/// Provider managing authentication state and delegating network calls to AuthRepository.
class AuthProvider extends ChangeNotifier {
  final AuthRepository _repository;

  AuthState _state = AuthState.initial;
  EmailDetailsResponseModel? _emailDetails;
  LoginResponseModel? _loginResponse;
  UserModel? _currentUser;
  List<TeamMemberModel> _teamMembers = [];
  bool _isLoading = false;
  String? _error;

  AuthProvider({AuthRepository? repository})
      : _repository = repository ?? AuthRepositoryImpl();

  AuthState get state => _state;
  EmailDetailsResponseModel? get emailDetails => _emailDetails;
  LoginResponseModel? get loginResponse => _loginResponse;
  UserModel? get currentUser => _currentUser;
  List<TeamMemberModel> get teamMembers => _teamMembers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _state == AuthState.authenticated && _currentUser != null;

  /// Fetches email details pre-login via POST /auth/email-details.
  Future<EmailDetailsResponseModel?> fetchEmailDetails(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _repository.getEmailDetails(email);
      _emailDetails = response;
      _isLoading = false;
      notifyListeners();
      return response;
    } catch (e) {
      _error = 'Failed to fetch email details.';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Performs user authentication via POST /auth/login, then immediately fetches
  /// full user profile via GET /auth/me before allowing navigation to Dashboard.
  Future<bool> login(String email, String password, {String? departmentId}) async {
    _isLoading = true;
    _state = AuthState.loading;
    _error = null;
    notifyListeners();

    try {
      final result = await _repository.login(
        email,
        password,
        departmentId: departmentId,
      );

      if (result.success) {
        _loginResponse = result;
        
        // Call GET /auth/me immediately after successful login
        final userProfileSuccess = await fetchUserProfile();
        return userProfileSuccess;
      } else {
        _error = result.message ?? 'Login failed. Please check credentials.';
        _state = AuthState.error;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e is NetworkException
          ? e.message
          : 'An unexpected authentication error occurred.';
      _state = AuthState.error;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Calls GET /auth/me to retrieve authenticated user details, permissions, role, teamId, and department.
  Future<bool> fetchUserProfile() async {
    try {
      final user = await _repository.getMe();
      _currentUser = user;

      // Validate normal user department permission:
      final roleUpper = user.role?.toUpperCase().replaceAll(' ', '_') ?? '';
      final isNormalUser = roleUpper != 'SUPER_ADMIN' && roleUpper != 'SUPERADMIN' && roleUpper != 'ADMIN';
      final hasNoDept = user.departments.isEmpty && (user.departmentId == null || user.departmentId!.isEmpty);

      if (isNormalUser && hasNoDept) {
        _error = 'Access denied: You do not have permission to access the department.';
        _state = AuthState.error;
        _isLoading = false;
        _currentUser = null;
        notifyListeners();
        return false;
      }

      final storage = SecureStorageService();
      if (user.role != null && user.role!.isNotEmpty) {
        await storage.saveUserRole(user.role!);
      }
      if (user.teamId != null && user.teamId!.isNotEmpty) {
        await storage.saveUserTeamId(user.teamId!);
      } else if (user.departmentId != null && user.departmentId!.isNotEmpty) {
        await storage.saveUserTeamId(user.departmentId!);
      }

      // Also fetch team members after profile load
      fetchTeamMembers();

      _state = AuthState.authenticated;
      _isLoading = false;
      _error = null;
      notifyListeners();
      return true;
    } on NetworkException catch (e) {
      _error = e.message;
      _state = AuthState.error;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Failed to load user profile.';
      _state = AuthState.error;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Calls GET /api/auth/team to retrieve team members by optional role and department filter.
  Future<List<TeamMemberModel>> fetchTeamMembers({
    String? role,
    String? departmentId,
    String? departmentName,
  }) async {
    try {
      _teamMembers = await _repository.getTeamMembers(
        role: role,
        departmentId: departmentId,
        departmentName: departmentName,
      );
      notifyListeners();
      return _teamMembers;
    } catch (e) {
      debugPrint('[AuthProvider fetchTeamMembers ERROR]: $e');
      return [];
    }
  }

  /// Filters cached team members by role and/or department locally.
  List<TeamMemberModel> getUsersByRoleAndDepartment({
    String? role,
    String? departmentId,
    String? departmentName,
  }) {
    return _teamMembers.where((user) {
      final matchesRole = (role == null || role.isEmpty) ||
          (user.role != null && user.role!.toLowerCase().contains(role.toLowerCase()));

      final matchesDeptId = (departmentId == null || departmentId.isEmpty) ||
          user.departmentId == departmentId;

      final matchesDeptName = (departmentName == null || departmentName.isEmpty) ||
          (user.departmentName != null &&
              user.departmentName!.toLowerCase().contains(departmentName.toLowerCase()));

      return matchesRole && matchesDeptId && matchesDeptName;
    }).toList();
  }

  /// Creates a new user in backend under selected departmentId and refreshes member list.
  Future<bool> createUser({
    required String firstName,
    required String lastName,
    required String email,
    required String role,
    required String departmentId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _repository.createUser(
        firstName: firstName,
        lastName: lastName,
        email: email,
        role: role,
        departmentId: departmentId,
      );
      if (success) {
        await fetchTeamMembers();
      }
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _error = e is NetworkException ? e.message : 'Failed to create user.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Clears active auth session locally.
  Future<void> logout() async {
    await _repository.logout();
    _loginResponse = null;
    _currentUser = null;
    _teamMembers = [];
    _state = AuthState.unauthenticated;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
