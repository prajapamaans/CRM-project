import 'package:flutter_test/flutter_test.dart';
import 'package:crmproject/features/contacts/presentation/providers/contact_provider.dart';
import 'package:crmproject/features/contacts/data/repositories/contact_repository.dart';
import 'package:crmproject/features/contacts/data/datasource/remote/contact_remote_datasource.dart';
import 'package:crmproject/features/contacts/data/models/contact_model.dart';

class MockContactRepository implements ContactRepository {
  int fetchCallCount = 0;

  @override
  Future<PaginatedContactsResponse> getContacts({
    String? page,
    String? limit,
    String? search,
    String? ownerId,
    String? departmentId,
    bool? ignorePermissions,
    String? lifecycleStage,
    String? leadStatus,
    String? createdDateRange,
    String? sort,
    String? order,
  }) async {
    fetchCallCount++;
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 100));
    return PaginatedContactsResponse(
      contacts: [
        const ContactModel(
          id: '1',
          firstName: 'John',
          lastName: 'Doe',
          email: 'john@example.com',
        )
      ],
      total: 1,
      page: 1,
      limit: 25,
    );
  }

  @override
  Future<ContactModel> createContact(Map<String, dynamic> data) async => throw UnimplementedError();
  @override
  Future<ContactModel> updateContact(String id, Map<String, dynamic> data) async => throw UnimplementedError();
  @override
  Future<bool> deleteContact(String id, {String? departmentId}) async => throw UnimplementedError();
  @override
  Future<ContactModel> getContactById(String id) async => throw UnimplementedError();
}

void main() {
  test('Rapid fetch calls trigger only ONE API call due to concurrency guard', () async {
    final mockRepo = MockContactRepository();
    final provider = ContactProvider(repository: mockRepo);

    // Fire 5 rapid fetch calls simultaneously
    final future1 = provider.fetchContacts(refresh: true);
    final future2 = provider.fetchContacts(refresh: true);
    final future3 = provider.fetchContacts(refresh: true);
    final future4 = provider.fetchContacts(refresh: true);
    final future5 = provider.fetchContacts(refresh: true);

    await Future.wait([future1, future2, future3, future4, future5]);

    // Assert that repository was only called ONCE
    expect(mockRepo.fetchCallCount, equals(1));
    expect(provider.contacts.length, equals(1));
    expect(provider.isLoading, isFalse);
  });
}
