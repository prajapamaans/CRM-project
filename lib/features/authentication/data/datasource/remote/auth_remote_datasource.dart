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
    if (departmentId != null && departmentId.isNotEmpty) queryParams['department_id'] = departmentId;
    if (departmentName != null && departmentName.isNotEmpty) queryParams['department'] = departmentName;

    Options? options;
    if (departmentId != null && departmentId.isNotEmpty) {
      options = Options(headers: {
        'X-Department-Id': departmentId,
        'departmentId': departmentId,
        'department_id': departmentId,
      });
    }

    final response = await _apiService.get(
      ApiConstants.team,
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
      options: options,
    );
    debugPrint('[GET /api/auth/team SUCCESS]: ${response.data}');

    final dynamic rawData = response.data;
    List<dynamic> list = [];

    if (rawData is List) {
      list = rawData;
    } else if (rawData is Map<String, dynamic> && rawData.containsKey('data')) {
      final dataField = rawData['data'];
      if (dataField is List) list = dataField;
    }

    return list.map((e) => TeamMemberModel.fromJson(e as Map<String, dynamic>)).toList();
  }
}
