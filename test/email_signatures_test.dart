import 'package:flutter_test/flutter_test.dart';
import 'package:crmproject/core/models/email_signature_model.dart';
import 'package:crmproject/core/network/api_constants.dart';

void main() {
  group('Email Signature Unit Tests', () {
    test('ApiConstants.emailSignatures equals /email-signatures', () {
      expect(ApiConstants.emailSignatures, '/email-signatures');
    });

    test('EmailSignatureModel.fromJson parses backend signature response correctly', () {
      final jsonMap = {
        'id': 'c5e5f5f1-5b6c-4e1d-96a7-09adff32500a',
        'name': 'Sales Director Signature',
        'body': '<p><strong>Saurav Singh</strong></p>',
        'isDefault': true,
        'createdAt': '2026-08-29T04:01:41.702Z',
        'updatedAt': '2026-08-29T04:01:41.702Z',
      };

      final model = EmailSignatureModel.fromJson(jsonMap);

      expect(model.id, 'c5e5f5f1-5b6c-4e1d-96a7-09adff32500a');
      expect(model.name, 'Sales Director Signature');
      expect(model.body, '<p><strong>Saurav Singh</strong></p>');
      expect(model.isDefault, isTrue);
      expect(model.createdAt, '2026-08-29T04:01:41.702Z');
    });

    test('EmailSignatureModel.toJson produces expected API payload format', () {
      final model = EmailSignatureModel(
        id: '',
        name: 'New Signature',
        body: '<p>Body text</p>',
        isDefault: false,
      );

      final jsonMap = model.toJson();

      expect(jsonMap['name'], 'New Signature');
      expect(jsonMap['body'], '<p>Body text</p>');
      expect(jsonMap['isDefault'], isFalse);
      expect(jsonMap.containsKey('id'), isFalse);
    });
  });
}
