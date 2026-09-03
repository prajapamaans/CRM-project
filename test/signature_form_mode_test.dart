import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:crmproject/core/models/email_signature_model.dart';
import 'package:crmproject/core/repositories/master_data_repository.dart';
import 'package:crmproject/features/activities/presentation/widgets/create_signature_modal.dart';
import 'package:crmproject/features/authentication/presentation/providers/auth_provider.dart';

/// Answers the two signature writes and records which one the form chose.
class _FakeMasterDataRepository implements MasterDataRepository {
  final List<Map<String, dynamic>> created = [];
  final List<({String id, Map<String, dynamic> data})> updated = [];

  @override
  Future<EmailSignatureModel> createEmailSignature(Map<String, dynamic> data) async {
    created.add(data);
    return EmailSignatureModel(
      id: 'freshly-created-id',
      name: data['name']?.toString() ?? '',
      body: data['body']?.toString() ?? '',
    );
  }

  @override
  Future<EmailSignatureModel> updateEmailSignature(String id, Map<String, dynamic> data) async {
    updated.add((id: id, data: data));
    return EmailSignatureModel(
      id: id,
      name: data['name']?.toString() ?? '',
      body: data['body']?.toString() ?? '',
    );
  }

  // Nothing else in the repository is reachable from this form.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used by the signature form');
}

const _existing = 'c5e5f5f1-5b6c-4e1d-96a7-09adff32500a';

Widget _host(_FakeMasterDataRepository repo, {EmailSignatureModel? signatureToEdit}) {
  return ChangeNotifierProvider<AuthProvider>(
    create: (_) => AuthProvider(),
    child: MaterialApp(
      home: Scaffold(
        body: CreateSignatureModal(
          signatureToEdit: signatureToEdit,
          repository: repo,
        ),
      ),
    ),
  );
}

Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.text('Save signature'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  late _FakeMasterDataRepository repo;

  setUp(() => repo = _FakeMasterDataRepository());

  testWidgets('an empty form creates a signature', (tester) async {
    await tester.pumpWidget(_host(repo));

    await tester.enterText(find.byType(TextFormField).first, 'Sales Director');
    await tester.enterText(find.byType(TextFormField).last, 'Regards, Sam');
    await _save(tester);

    expect(repo.created, hasLength(1));
    expect(repo.updated, isEmpty);
    expect(repo.created.single['name'], 'Sales Director');
  });

  testWidgets('a form opened on an existing signature updates it', (tester) async {
    await tester.pumpWidget(_host(
      repo,
      signatureToEdit: EmailSignatureModel(
        id: _existing,
        name: 'Sales Director',
        body: '<p>Regards, Sam</p>',
        isDefault: true,
      ),
    ));

    // The saved record is loaded into the form, then changed.
    expect(find.text('Sales Director'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Renamed signature');
    await tester.enterText(find.byType(TextFormField).last, '<p>Regards, Samantha</p>');
    await _save(tester);

    expect(repo.created, isEmpty, reason: 'editing must not add a second signature');
    expect(repo.updated, hasLength(1));
    expect(repo.updated.single.id, _existing, reason: 'the record keeps the id it was opened with');
    expect(repo.updated.single.data['name'], 'Renamed signature');
    expect(repo.updated.single.data.containsKey('id'), isFalse);
  });

  testWidgets('editing survives a rebuild of the form', (tester) async {
    await tester.pumpWidget(_host(
      repo,
      signatureToEdit: EmailSignatureModel(id: _existing, name: 'Sales', body: '<p>x</p>'),
    ));

    // Typing rebuilds the modal repeatedly; the edit id must not be lost.
    await tester.enterText(find.byType(TextFormField).last, '<p>one</p>');
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).last, '<p>two</p>');
    await tester.pump();
    await _save(tester);

    expect(repo.updated.single.id, _existing);
    expect(repo.created, isEmpty);
  });

  testWidgets('a record with no id is refused rather than duplicated', (tester) async {
    await tester.pumpWidget(_host(
      repo,
      signatureToEdit: EmailSignatureModel(id: '', name: 'Sales', body: '<p>x</p>'),
    ));

    await _save(tester);

    expect(repo.created, isEmpty);
    expect(repo.updated, isEmpty);
    expect(find.textContaining('missing its ID'), findsOneWidget);
  });
}
