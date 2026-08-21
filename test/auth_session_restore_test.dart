// Regression tests for cold-start session restore.
//
// The app persists the access + refresh tokens at login (AuthRepositoryImpl.login)
// and AuthInterceptor reads the token back on every request. Nothing, however,
// restores the *provider* state at startup, so SplashScreen's
// `authProvider.isAuthenticated` check is always false on a cold start.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crmproject/core/storage/secure_storage_service.dart';
import 'package:crmproject/features/authentication/data/models/email_details_response_model.dart';
import 'package:crmproject/features/authentication/data/models/login_response_model.dart';
import 'package:crmproject/features/authentication/data/models/team_member_model.dart';
import 'package:crmproject/features/authentication/data/models/user_model.dart';
import 'package:crmproject/features/authentication/data/repositories/auth_repository.dart';
import 'package:crmproject/features/authentication/presentation/providers/auth_provider.dart';

/// Stands in for the network layer. `getMe` succeeds, exactly as it would for a
/// user whose stored token is still valid.
class FakeAuthRepository implements AuthRepository {
  int getMeCallCount = 0;

  @override
  Future<UserModel> getMe() async {
    getMeCallCount++;
    return UserModel(
      id: 'user-1',
      email: 'user@example.com',
      firstName: 'Ada',
      lastName: 'Lovelace',
      role: 'normal_user',
      departmentId: 'dept-1',
      departmentName: 'Sales',
      departments: [UserDepartment(id: 'dept-1', name: 'Sales')],
    );
  }

  @override
  Future<List<TeamMemberModel>> getTeamMembers({
    String? role,
    String? departmentId,
    String? departmentName,
  }) async => [];

  @override
  Future<String?> getToken() async => SecureStorageService().getToken();

  @override
  Future<String?> getRefreshToken() async =>
      SecureStorageService().getRefreshToken();

  @override
  Future<EmailDetailsResponseModel> getEmailDetails(String email) async =>
      throw UnimplementedError();

  @override
  Future<LoginResponseModel> login(
    String email,
    String password, {
    String? departmentId,
  }) async => throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  Future<bool> switchDepartment(String departmentId) async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Simulate a device that completed a login on a previous launch.
    SharedPreferences.setMockInitialValues({
      'access_token': 'persisted.jwt.token',
      'refresh_token': 'persisted-refresh-token',
      'selected_department_id': 'dept-1',
    });
  });

  test('the access token really is persisted across launches', () async {
    final token = await SecureStorageService().getToken();
    expect(token, 'persisted.jwt.token');
  });

  test(
    'BUG: a freshly constructed AuthProvider is unauthenticated despite a '
    'persisted token, so SplashScreen always routes to LoginScreen',
    () async {
      final repo = FakeAuthRepository();
      final provider = AuthProvider(repository: repo);

      // Give any restore-on-construction work a chance to run.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // The token is on disk and the session is valid...
      expect(await SecureStorageService().getToken(), isNotEmpty);

      // ...but nothing ever asked the backend who this token belongs to.
      expect(
        repo.getMeCallCount,
        0,
        reason: 'AuthProvider never calls getMe() at startup',
      );

      // This is the exact expression SplashScreen line 80 evaluates.
      expect(
        provider.isAuthenticated,
        isFalse,
        reason: 'isLoggedIn is false at splash, so the user is sent to '
            'LoginScreen and the entire prefetch block is skipped',
      );
    },
  );

  test(
    'the session WOULD restore correctly if fetchUserProfile() were called at '
    'startup — the only missing piece is the call',
    () async {
      final repo = FakeAuthRepository();
      final provider = AuthProvider(repository: repo);

      final ok = await provider.fetchUserProfile();

      expect(ok, isTrue);
      expect(repo.getMeCallCount, 1);
      expect(provider.isAuthenticated, isTrue);
      expect(provider.currentUser?.fullName, 'Ada Lovelace');
    },
  );
}
