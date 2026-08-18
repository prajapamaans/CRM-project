import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/network/network_exception.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../datasource/remote/auth_remote_datasource.dart';
import '../models/email_details_response_model.dart';
import '../models/login_response_model.dart';
import '../models/team_member_model.dart';
import '../models/user_model.dart';

abstract class AuthRepository {
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
  Future<void> logout();
  Future<String?> getToken();
  Future<String?> getRefreshToken();
  Future<bool> switchDepartment(String departmentId);
}

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final SecureStorageService _storageService;

  AuthRepositoryImpl({
    AuthRemoteDataSource? remoteDataSource,
    SecureStorageService? storageService,
  })  : _remoteDataSource = remoteDataSource ?? AuthRemoteDataSourceImpl(),
        _storageService = storageService ?? SecureStorageService();

  @override
  Future<EmailDetailsResponseModel> getEmailDetails(String email) async {
    try {
      final response = await _remoteDataSource.getEmailDetails(email);
      debugPrint('==================================================');
      debugPrint('[POST /auth/email-details SUCCESS] ${response.toJson()}');
      debugPrint('==================================================');
      return response;
    } on NetworkException catch (e) {
      debugPrint('[POST /auth/email-details ERROR] NetworkException: ${e.message}');
      return EmailDetailsResponseModel(
        success: false,
        message: e.message,
      );
    } catch (e) {
      debugPrint('[POST /auth/email-details ERROR] Unexpected error: $e');
      return EmailDetailsResponseModel(
        success: false,
        message: 'An unexpected error occurred.',
      );
    }
  }

  @override
  Future<LoginResponseModel> login(
    String email,
    String password, {
    String? departmentId,
  }) async {
    try {
      final response = await _remoteDataSource.login(
        email,
        password,
        departmentId: departmentId,
      );

      // Print complete Login Response during development
      debugPrint('==================================================');
      debugPrint('[LOGIN API RESPONSE] ${response.toJson()}');
      debugPrint('==================================================');

      if (response.success) {
        if (response.accessToken != null && response.accessToken!.isNotEmpty) {
          await _storageService.saveToken(response.accessToken!);
        }
        if (response.refreshToken != null && response.refreshToken!.isNotEmpty) {
          await _storageService.saveRefreshToken(response.refreshToken!);
        }

        // Print stored token for verification
        final storedToken = await _storageService.getToken();
        debugPrint('[VERIFICATION] Stored Access Token: $storedToken');
        debugPrint('==================================================');
      }

      return response;
    } on NetworkException catch (e) {
      debugPrint('[LOGIN API ERROR] NetworkException: ${e.message}');
      return LoginResponseModel(
        success: false,
        message: e.message,
      );
    } catch (e) {
      debugPrint('[LOGIN API ERROR] Unexpected error: $e');
      return LoginResponseModel(
        success: false,
        message: 'An unexpected error occurred during login.',
      );
    }
  }

  @override
  Future<UserModel> getMe() async {
    try {
      final user = await _remoteDataSource.getMe();
      debugPrint('[GET /auth/me SUCCESS] User: ${user.fullName}, Role: ${user.role}, Dept: ${user.departmentName}');
      return user;
    } on NetworkException catch (e) {
      debugPrint('[GET /auth/me ERROR] NetworkException: ${e.message}');
      rethrow;
    }
  }

  @override
  Future<List<TeamMemberModel>> getTeamMembers({
    String? role,
    String? departmentId,
    String? departmentName,
  }) async {
    try {
      return await _remoteDataSource.getTeamMembers(
        role: role,
        departmentId: departmentId,
        departmentName: departmentName,
      );
    } catch (e) {
      debugPrint('[GET /api/auth/team ERROR]: $e');
      if (e is DioException) {
        throw NetworkException.fromDioException(e);
      }
      throw NetworkException(message: e.toString());
    }
  }

  @override
  Future<void> logout() async {
    await _storageService.clear();
  }

  @override
  Future<String?> getToken() async {
    return await _storageService.getToken();
  }

  @override
  Future<String?> getRefreshToken() async {
    return await _storageService.getRefreshToken();
  }

  @override
  Future<bool> switchDepartment(String departmentId) async {
    try {
      final newToken = await _remoteDataSource.switchDepartment(departmentId);
      if (newToken != null && newToken.isNotEmpty) {
        await _storageService.saveToken(newToken);
        debugPrint('[AuthRepository.switchDepartment SUCCESS] Swapped access token for department: $departmentId');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[AuthRepository.switchDepartment ERROR]: $e');
      return false;
    }
  }
}
