import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crmproject/features/authentication/data/models/login_response_model.dart';
import 'package:crmproject/features/authentication/data/models/email_details_response_model.dart';
import 'package:crmproject/features/authentication/data/models/team_member_model.dart';
import 'package:crmproject/features/authentication/data/models/user_model.dart';
import 'package:crmproject/features/authentication/data/repositories/auth_repository.dart';
import 'package:crmproject/features/authentication/presentation/providers/auth_provider.dart';

const apacId = 'a1b2c3d4-0000-0000-0000-000000000002';
const australiaId = 'a1b2c3d4-0000-0000-0000-000000000003';

/// Records the department each team request was scoped to and answers with
/// people who belong to it, the way a department-silo'd backend would.
class _FakeAuthRepository implements AuthRepository {
  final List<String?> teamRequests = [];

  @override
  Future<List<TeamMemberModel>> getTeamMembers({
    String? role,
    String? departmentId,
    String? departmentName,
  }) async {
    teamRequests.add(departmentId);
    final label = departmentId == australiaId ? 'Australia' : 'APAC';
    return [
      TeamMemberModel(
        id: '$departmentId-1',
        firstName: label,
        lastName: 'Member',
        email: '${label.toLowerCase()}@example.com',
        departmentId: departmentId,
      ),
    ];
  }

  @override
  Future<EmailDetailsResponseModel> getEmailDetails(String email) async => throw UnimplementedError();
  @override
  Future<LoginResponseModel> login(String email, String password, {String? departmentId}) async =>
      throw UnimplementedError();
  @override
  Future<UserModel> getMe() async => throw UnimplementedError();
  @override
  Future<bool> createUser({
    required String firstName,
    required String lastName,
    required String email,
    required String role,
    required String departmentId,
  }) async =>
      throw UnimplementedError();
  @override
  Future<void> logout() async {}
  @override
  Future<String?> getToken() async => null;
  @override
  Future<String?> getRefreshToken() async => null;
  @override
  Future<bool> switchDepartment(String departmentId) async => true;
}

void main() {
  late _FakeAuthRepository repo;
  late AuthProvider provider;

  setUp(() {
    // DepartmentProvider persists the selection here; AuthProvider reads it
    // back so both agree on one source of truth.
    SharedPreferences.setMockInitialValues({'selected_department_id': apacId});
    repo = _FakeAuthRepository();
    provider = AuthProvider(repository: repo);
  });

  group('team members follow the selected department', () {
    test('a call with no department uses the stored selection, not "all"', () async {
      await provider.fetchTeamMembers();

      expect(repo.teamRequests, [apacId]);
      expect(
        repo.teamRequests.single,
        isNot('all'),
        reason: 'the datasource used to force every department, which is what '
            'put other departments people in every owner dropdown',
      );
    });

    test('switching department reloads the team for the new one', () async {
      await provider.fetchTeamMembers();
      expect(provider.teamMembers.single.firstName, 'APAC');

      await provider.reloadTeamForDepartment(australiaId);

      expect(repo.teamRequests, [apacId, australiaId]);
      expect(provider.teamDepartmentId, australiaId);
      expect(provider.teamMembers.single.firstName, 'Australia');
    });

    test('the previous department people are gone, not merged in', () async {
      await provider.fetchTeamMembers();
      await provider.reloadTeamForDepartment(australiaId);

      expect(provider.teamMembers, hasLength(1));
      expect(
        provider.teamMembers.any((m) => m.departmentId == apacId),
        isFalse,
        reason: 'APAC people must not remain selectable under Australia',
      );
    });

    test('later calls stay on the department last switched to', () async {
      await provider.reloadTeamForDepartment(australiaId);
      repo.teamRequests.clear();

      // A dropdown opening somewhere in the app, naming no department.
      await provider.fetchTeamMembers();

      expect(repo.teamRequests, [australiaId]);
    });

    test('an explicit department still wins', () async {
      await provider.reloadTeamForDepartment(australiaId);
      repo.teamRequests.clear();

      await provider.fetchTeamMembers(departmentId: apacId);

      expect(repo.teamRequests, [apacId]);
    });
  });
}
