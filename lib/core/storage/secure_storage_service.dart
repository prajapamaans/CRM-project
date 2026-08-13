import 'package:shared_preferences/shared_preferences.dart';

/// Service interface/wrapper for local persistent storage using SharedPreferences.
class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();

  factory SecureStorageService() => _instance;

  SecureStorageService._internal();

  static const String _keyAccessToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keySelectedDepartmentId = 'selected_department_id';
  static const String _keySelectedDepartmentName = 'selected_department_name';
  static const String _keyAssignedDepartmentId = 'assigned_department_id';
  static const String _keyUserRole = 'user_role';
  static const String _keyUserTeamId = 'user_team_id';

  String? _accessToken;
  String? _refreshToken;
  String? _selectedDepartmentId;
  String? _selectedDepartmentName;
  String? _assignedDepartmentId;
  String? _userRole;
  String? _userTeamId;

  /// Saves the active authentication access token persistently.
  Future<void> saveToken(String token) async {
    _accessToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccessToken, token);
  }

  /// Saves the active authentication refresh token persistently.
  Future<void> saveRefreshToken(String refreshToken) async {
    _refreshToken = refreshToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRefreshToken, refreshToken);
  }

  /// Retrieves the active access token.
  Future<String?> getToken() async {
    if (_accessToken != null) return _accessToken;
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_keyAccessToken);
    return _accessToken;
  }

  /// Retrieves the active refresh token.
  Future<String?> getRefreshToken() async {
    if (_refreshToken != null) return _refreshToken;
    final prefs = await SharedPreferences.getInstance();
    _refreshToken = prefs.getString(_keyRefreshToken);
    return _refreshToken;
  }

  /// Saves the active department ID.
  Future<void> saveSelectedDepartmentId(String departmentId) async {
    _selectedDepartmentId = departmentId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedDepartmentId, departmentId);
  }

  /// Gets the active department ID.
  Future<String?> getSelectedDepartmentId() async {
    if (_selectedDepartmentId != null) return _selectedDepartmentId;
    final prefs = await SharedPreferences.getInstance();
    _selectedDepartmentId = prefs.getString(_keySelectedDepartmentId);
    return _selectedDepartmentId;
  }

  /// Saves the active department name.
  Future<void> saveSelectedDepartmentName(String name) async {
    _selectedDepartmentName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedDepartmentName, name);
  }

  /// Gets the active department name.
  Future<String?> getSelectedDepartmentName() async {
    if (_selectedDepartmentName != null) return _selectedDepartmentName;
    final prefs = await SharedPreferences.getInstance();
    _selectedDepartmentName = prefs.getString(_keySelectedDepartmentName);
    return _selectedDepartmentName;
  }

  /// Saves assigned department ID.
  Future<void> saveAssignedDepartmentId(String departmentId) async {
    _assignedDepartmentId = departmentId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAssignedDepartmentId, departmentId);
  }

  /// Gets assigned department ID.
  Future<String?> getAssignedDepartmentId() async {
    if (_assignedDepartmentId != null) return _assignedDepartmentId;
    final prefs = await SharedPreferences.getInstance();
    _assignedDepartmentId = prefs.getString(_keyAssignedDepartmentId);
    return _assignedDepartmentId;
  }

  /// Saves user role.
  Future<void> saveUserRole(String role) async {
    _userRole = role;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserRole, role);
  }

  /// Gets user role.
  Future<String?> getUserRole() async {
    if (_userRole != null) return _userRole;
    final prefs = await SharedPreferences.getInstance();
    _userRole = prefs.getString(_keyUserRole);
    return _userRole;
  }

  /// Saves user team ID.
  Future<void> saveUserTeamId(String teamId) async {
    _userTeamId = teamId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserTeamId, teamId);
  }

  /// Gets user team ID.
  Future<String?> getUserTeamId() async {
    if (_userTeamId != null) return _userTeamId;
    final prefs = await SharedPreferences.getInstance();
    _userTeamId = prefs.getString(_keyUserTeamId);
    return _userTeamId;
  }

  /// Saves a custom string value locally.
  Future<void> saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  /// Retrieves a custom string value locally.
  Future<String?> getString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  /// Saves a custom boolean value locally.
  Future<void> saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  /// Retrieves a custom boolean value locally.
  Future<bool?> getBool(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key);
  }

  /// Removes a custom key from local storage.
  Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  /// Clears all stored authentication tokens and persistent storage.
  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    _selectedDepartmentId = null;
    _selectedDepartmentName = null;
    _assignedDepartmentId = null;
    _userRole = null;
    _userTeamId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keySelectedDepartmentId);
    await prefs.remove(_keySelectedDepartmentName);
    await prefs.remove(_keyAssignedDepartmentId);
    await prefs.remove(_keyUserRole);
    await prefs.remove(_keyUserTeamId);
  }
}
