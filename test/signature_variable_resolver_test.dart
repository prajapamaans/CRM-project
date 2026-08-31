import 'package:flutter_test/flutter_test.dart';
import 'package:crmproject/core/utils/signature_variable_resolver.dart';
import 'package:crmproject/features/authentication/data/models/user_model.dart';

void main() {
  group('SignatureVariableResolver Unit Tests', () {
    final sampleUser = UserModel(
      id: 'usr_123',
      email: 'dev@apideltech.com',
      firstName: 'Admin',
      lastName: 'User',
      departmentName: 'APAC Team',
      position: null,
      phone: null,
    );

    test('1. Resolves fullName, firstName, lastName, email, departmentName correctly', () {
      const template = '<p><strong>{{sender.fullName}}</strong></p>'
          '<p>Email: {{sender.email}}</p>'
          '<p>Dept: {{sender.departmentName}}</p>';

      final resolved = SignatureVariableResolver.resolve(template, sampleUser);

      expect(resolved, contains('<p><strong>Admin User</strong></p>'));
      expect(resolved, contains('<p>Email: dev@apideltech.com</p>'));
      expect(resolved, contains('<p>Dept: APAC Team</p>'));
    });

    test('2. Handles null phone and null position safely without producing "null" or "null null"', () {
      const template = 'Phone: {{sender.phone}}, Position: {{sender.position}}';

      final resolved = SignatureVariableResolver.resolve(template, sampleUser);

      expect(resolved, isNot(contains('null')));
      expect(resolved, isNot(contains('null null')));
      expect(resolved, isNot(contains('{{sender.phone}}')));
      expect(resolved, isNot(contains('{{sender.position}}')));
      expect(resolved, equals('Phone: , Position: '));
    });

    test('3. Single name user constructs fullName without trailing or leading whitespace issues', () {
      final singleNameUser = UserModel(
        id: 'usr_456',
        email: 'single@example.com',
        firstName: 'SoloUser',
        lastName: '',
      );

      const template = 'Hello {{sender.fullName}}, your first name is {{sender.firstName}}';

      final resolved = SignatureVariableResolver.resolve(template, singleNameUser);

      expect(resolved, equals('Hello SoloUser, your first name is SoloUser'));
      expect(resolved, isNot(contains('null')));
    });

    test('4. Menu items contain all required signature variables', () {
      final values = SignatureVariableResolver.menuItems.map((i) => i['value']).toList();

      expect(values, contains('{{sender.fullName}}'));
      expect(values, contains('{{sender.firstName}}'));
      expect(values, contains('{{sender.lastName}}'));
      expect(values, contains('{{sender.email}}'));
      expect(values, contains('{{sender.phone}}'));
      expect(values, contains('{{sender.position}}'));
      expect(values, contains('{{sender.departmentName}}'));
    });
  });
}
