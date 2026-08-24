import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../../core/network/api_constants.dart';
import '../../../../../core/network/api_service.dart';
import '../../models/email_details_request_model.dart';
import '../../models/email_details_response_model.dart';
import '../../models/login_request_model.dart';
import '../../models/login_response_model.dart';
import '../../models/team_member_model.dart';
import '../../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<EmailDetailsResponseModel> getEmailDetails(String email);

  Future<LoginResponseModel> login(
    String email,
    String password, {
    String? departmentId,
  });

  Future<UserModel> getMe();

  Future<List<TeamMemberModel>> getTeamMembers({
    String? role,
    String? departmentId,
    String? departmentName,
  });

  Future<String?> switchDepartment(String departmentId);

  Future<bool> createUser({
    required String firstName,
    required String lastName,
    required String email,
    required String role,
    required String departmentId,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiService _apiService;

  AuthRemoteDataSourceImpl({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  @override
  Future<EmailDetailsResponseModel> getEmailDetails(String email) async {
    final request = EmailDetailsRequestModel(email: email);
    final response = await _apiService.post(
      ApiConstants.emailDetails,
      data: request.toJson(),
    );
    return EmailDetailsResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<LoginResponseModel> login(
    String email,
    String password, {
    String? departmentId,
  }) async {
    final request = LoginRequestModel(
      email: email,
      password: password,
      departmentId: departmentId,
    );

    final response = await _apiService.post(
      ApiConstants.login,
      data: request.toJson(),
    );

    return LoginResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<UserModel> getMe() async {
    final response = await _apiService.get(ApiConstants.me);
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<TeamMemberModel>> getTeamMembers({
    String? role,
    String? departmentId,
    String? departmentName,
  }) async {
    final queryParams = <String, dynamic>{};
    if (role != null && role.isNotEmpty) queryParams['role'] = role;
    if (departmentName != null && departmentName.isNotEmpty) queryParams['department'] = departmentName;

    // Header option to instruct interceptors to fetch ALL data across all departments
    final Options options = Options(headers: {
      'X-Department-Id': 'all',
      'departmentId': 'all',
      'department_id': 'all',
    });

    final Map<String, TeamMemberModel> uniqueMembers = {};

    void addMembersFromData(dynamic rawData) {
      List<dynamic> list = [];
      if (rawData is List) {
        list = rawData;
      } else if (rawData is Map<String, dynamic>) {
        if (rawData['data'] is List) {
          list = rawData['data'] as List;
        } else if (rawData['users'] is List) {
          list = rawData['users'] as List;
        } else if (rawData['team'] is List) {
          list = rawData['team'] as List;
        } else if (rawData['members'] is List) {
          list = rawData['members'] as List;
        }
      }

      for (var item in list) {
        if (item is Map<String, dynamic>) {
          final model = TeamMemberModel.fromJson(item);
          final key = model.id.isNotEmpty ? model.id : model.email.toLowerCase().trim();
          if (key.isNotEmpty) {
            uniqueMembers[key] = model;
          }
        }
      }
    }

    // 1. Fetch from /api/auth/team
    try {
    final response = await _apiService.get(
      ApiConstants.team,
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
      options: options,
    );
    debugPrint('[GET /api/auth/team SUCCESS]: ${response.data}');
      addMembersFromData(response.data);
    } catch (e) {
      debugPrint('[GET /api/auth/team WARNING]: $e');
    }

    // 2. Fetch from /users (with limit 1000) to ensure complete list of users
    try {
      final userQueryParams = <String, dynamic>{'limit': 1000, ...queryParams};
      final userResp = await _apiService.get(
        '/users',
        queryParameters: userQueryParams,
        options: options,
      );
      debugPrint('[GET /users SUCCESS]: ${userResp.data}');
      addMembersFromData(userResp.data);
    } catch (e) {
      debugPrint('[GET /users WARNING]: $e');
    }

    return uniqueMembers.values.toList();
  }

  @override
  Future<String?> switchDepartment(String departmentId) async {
    final response = await _apiService.post(
      ApiConstants.switchDepartment,
      data: {'departmentId': departmentId},
    );
    debugPrint('[POST /api/auth/switch-department SUCCESS]: ${response.data}');

    final Map<String, dynamic>? resMap = response.data is Map<String, dynamic> ? response.data as Map<String, dynamic> : null;
    if (resMap != null && resMap['data'] is Map<String, dynamic>) {
      final dataMap = resMap['data'] as Map<String, dynamic>;
      return dataMap['access_token']?.toString() ?? dataMap['accessToken']?.toString();
    }
    return null;
  }

  @override
  Future<bool> createUser({
    required String firstName,
    required String lastName,
    required String email,
    required String role,
    required String departmentId,
  }) async {
    final payload = <String, dynamic>{
      'first_name': firstName,
      'firstName': firstName,
      'last_name': lastName,
      'lastName': lastName,
      'email': email,
      'role': role,
      'department_id': departmentId,
      'departmentId': departmentId,
      'department_ids': [departmentId],
      'departmentIds': [departmentId],
    };

    final Options options = Options(headers: {
      'X-Department-Id': departmentId,
      'departmentId': departmentId,
      'department_id': departmentId,
    });

    try {
      final response = await _apiService.post(
        '/users',
        data: payload,
        options: options,
      );
      debugPrint('[POST /users SUCCESS]: ${response.data}');
      return true;
    } catch (e) {
      debugPrint('[POST /users WARNING]: $e. Retrying /auth/team...');
      try {
        final response = await _apiService.post(
          ApiConstants.team,
          data: payload,
          options: options,
        );
        debugPrint('[POST /auth/team SUCCESS]: ${response.data}');
        return true;
      } catch (e2) {
        debugPrint('[POST /auth/team WARNING]: $e2');
        rethrow;
      }
    }
  }
}
