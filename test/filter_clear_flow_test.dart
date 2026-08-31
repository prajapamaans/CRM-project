import 'package:flutter_test/flutter_test.dart';

import 'package:crmproject/features/contacts/data/datasource/remote/contact_remote_datasource.dart';
import 'package:crmproject/features/contacts/data/models/contact_model.dart';
import 'package:crmproject/features/contacts/data/repositories/contact_repository.dart';
import 'package:crmproject/features/contacts/presentation/providers/contact_provider.dart';

/// One captured `GET /api/contacts`.
class _Request {
  _Request(this.params);
  final Map<String, String?> params;

  /// The keys that carried a value — what would actually reach the query
  /// string, since the datasource drops null and empty ones.
  Set<String> get sentKeys =>
      params.entries.where((e) => e.value != null && e.value!.isNotEmpty).map((e) => e.key).toSet();

  String? operator [](String key) => params[key];
}

/// Records every request and returns a fixed page, so what the provider asks
/// for can be asserted without a backend.
class _FakeContactRepository implements ContactRepository {
  final List<_Request> requests = [];
  int total = 137;

  /// Per-request latency, consumed in order. Lets a slow first response be
  /// made to land after a fast second one.
  List<Duration> delays = const [];

  /// When true the fake behaves like a backend that implements the filter
  /// parameters: the rows it returns carry the values that were asked for, so
  /// the provider's own re-check drops nothing.
  ///
  /// When false it behaves like one that ignores them and returns everything —
  /// the case the in-memory fallback exists for.
  bool honoursFilters = true;

  /// Simulates a list response whose rows carry no `createdAt` — nothing a
  /// date filter can be compared against.
  bool omitCreatedAt = false;

  /// Simulates a real empty result, which must still show as empty.
  bool returnsNothing = false;

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
    requests.add(_Request({
      'page': page,
      'limit': limit,
      'search': search,
      'ownerId': ownerId,
      'departmentId': departmentId,
      'lifecycleStage': lifecycleStage,
      'leadStatus': leadStatus,
      'createdDateRange': createdDateRange,
      'sort': sort,
      'order': order,
    }));

    final index = requests.length - 1;
    if (index < delays.length && delays[index] > Duration.zero) {
      await Future<void>.delayed(delays[index]);
    }

    final now = DateTime.now().toUtc().toIso8601String();
    ContactModel row(String id) => ContactModel(
          id: id,
          email: '$id@example.com',
          createdAt: omitCreatedAt ? null : now,
          ownerId: honoursFilters ? ownerId : 'someone-else',
          lifecycleStage: honoursFilters ? lifecycleStage : 'a-stage-nobody-picked',
          leadStatus: honoursFilters ? leadStatus : 'a-status-nobody-picked',
        );

    return PaginatedContactsResponse(
      contacts: returnsNothing ? const [] : [row('c1'), row('c2')],
      total: returnsNothing ? 0 : total,
      page: int.tryParse(page ?? '1') ?? 1,
      limit: int.tryParse(limit ?? '25') ?? 25,
    );
  }

  @override
  Future<ContactModel> getContactById(String id) async => throw UnimplementedError();
  @override
  Future<ContactModel> createContact(Map<String, dynamic> data) async => throw UnimplementedError();
  @override
  Future<ContactModel> updateContact(String id, Map<String, dynamic> data) async =>
      throw UnimplementedError();
  @override
  Future<bool> deleteContact(String id) async => throw UnimplementedError();
}

/// Waits for the fire-and-forget fetch a filter change kicks off.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late _FakeContactRepository repo;
  late ContactProvider provider;

  setUp(() {
    repo = _FakeContactRepository();
    provider = ContactProvider(repository: repo);
  });

  group('a filter reaches the API', () {
    test('lifecycle stage is sent as the stored slug, not the display label', () async {
      provider.setLifecycleStageFilter('Marketing Qualified Lead');
      await _settle();

      expect(repo.requests.last['lifecycleStage'], 'marketing_qualified');
    });

    test('create date becomes a createdDateRange', () async {
      provider.setCreateDateFilter('Today');
      await _settle();

      expect(repo.requests.last['createdDateRange'], isNotNull);
      expect(repo.requests.last['createdDateRange'], matches(RegExp(r'^\d{4}-\d{2}-\d{2},\d{4}-\d{2}-\d{2}$')));
    });

    test('every request asks for newest first', () async {
      await provider.fetchContacts();

      expect(repo.requests.last['sort'], 'created_at');
      expect(repo.requests.last['order'], 'desc');
    });
  });

  group('filters combine rather than replace each other', () {
    test('all four ride along in one request', () async {
      await provider.setSegmentScope(ownerId: null, ignorePermissions: true);
      provider.setLifecycleStageFilter('Customer');
      await _settle();
      provider.setLeadStatusFilter('In progress');
      await _settle();
      provider.setCreateDateFilter('This month');
      await _settle();
      provider.setOwnerFilter('user-7');
      await _settle();

      final last = repo.requests.last;
      expect(last['lifecycleStage'], 'customer');
      expect(last['leadStatus'], 'in_progress');
      expect(last['createdDateRange'], isNotNull);
      expect(last['ownerId'], 'user-7');
    });

    test('changing one filter replaces only that one', () async {
      provider.setLifecycleStageFilter('Customer');
      await _settle();
      provider.setLeadStatusFilter('New');
      await _settle();
      provider.setLifecycleStageFilter('Lead');
      await _settle();

      final last = repo.requests.last;
      expect(last['lifecycleStage'], 'lead', reason: 'replaced');
      expect(last['leadStatus'], 'new', reason: 'still applied');
    });

    test('the owner pill wins over the Mine segment, and both use ownerId', () async {
      await provider.setSegmentScope(ownerId: 'me', ignorePermissions: false);
      expect(repo.requests.last['ownerId'], 'me');

      provider.setOwnerFilter('someone-else');
      await _settle();
      expect(repo.requests.last['ownerId'], 'someone-else');
    });
  });

  group('Clear', () {
    test('drops every filter parameter from the next request', () async {
      provider.setLifecycleStageFilter('Customer');
      await _settle();
      provider.setLeadStatusFilter('New');
      await _settle();
      provider.setCreateDateFilter('This month');
      await _settle();
      provider.setOwnerFilter('user-7');
      await _settle();
      provider.setMspFilter('Magnit');

      final filtered = repo.requests.last;
      expect(filtered.sentKeys, containsAll(['lifecycleStage', 'leadStatus', 'createdDateRange', 'ownerId']));

      provider.clearAllFilters();
      await _settle();

      final cleared = repo.requests.last;
      // Absent, not blank: an empty value would still read as a filter.
      expect(cleared['lifecycleStage'], isNull);
      expect(cleared['leadStatus'], isNull);
      expect(cleared['createdDateRange'], isNull);
      expect(cleared['ownerId'], isNull);
      expect(cleared['search'], isNull);
      expect(
        cleared.sentKeys,
        unorderedEquals(['page', 'limit', 'sort', 'order']),
        reason: 'only paging and ordering should survive Clear',
      );
    });

    test('resets the filter state the UI reads back', () async {
      provider.setOwnerFilter('user-7');
      await _settle();
      provider.setLifecycleStageFilter('Customer');
      await _settle();
      provider.setLeadStatusFilter('New');
      await _settle();
      provider.setCreateDateFilter('Today');
      await _settle();
      provider.setMspFilter('Magnit');
      expect(provider.isFilterActive, isTrue);

      provider.clearAllFilters();
      await _settle();

      expect(provider.selectedOwnerId, isNull);
      expect(provider.selectedStage, isNull);
      expect(provider.selectedLeadStatus, isNull);
      expect(provider.selectedCreateDate, isNull);
      expect(provider.selectedMsp, isNull);
      expect(provider.isFilterActive, isFalse);
    });

    test('resets pagination to page 1 and refetches', () async {
      // changePage is bounded by totalPages, which is only known once a page
      // has come back.
      await provider.fetchContacts();
      final before = repo.requests.length;
      await provider.changePage(3);
      expect(provider.currentPage, 3);

      provider.clearAllFilters();
      await _settle();

      expect(provider.currentPage, 1);
      expect(repo.requests.last['page'], '1');
      expect(repo.requests.length, greaterThan(before + 1), reason: 'Clear must issue a fresh request');
    });

    test('keeps the segment and permission scope, which are not filters', () async {
      await provider.setSegmentScope(ownerId: 'me', ignorePermissions: false, departmentId: 'dept-1');

      provider.clearAllFilters();
      await _settle();

      final cleared = repo.requests.last;
      expect(cleared['ownerId'], 'me', reason: 'the Mine segment is scope, not a filter pill');
      expect(cleared['departmentId'], 'dept-1', reason: 'department switching must survive Clear');
    });

    test('the count goes back to the server total', () async {
      provider.setMspFilter('Magnit');
      await _settle();
      // MSP has no API parameter, so the count falls back to the loaded rows.
      expect(provider.totalCount, isNot(137));

      provider.clearAllFilters();
      await _settle();
      expect(provider.totalCount, 137);
    });
  });

  group('filtered results are never mixed with unfiltered rows', () {
    // The user's contract: after selecting a filter, only records matching the
    // selection may be shown. Rows the server (or the in-memory re-check)
    // cannot attribute to the selection must not be surfaced just to keep the
    // list non-empty — doing so shows unfiltered/foreign data.
    //
    // By default the fake behaves like a backend that ignores the filter
    // parameters and returns rows carrying values nobody selected.
    setUp(() => repo.honoursFilters = false);

    test('when the server honours the filter, only matching rows show', () async {
      repo.honoursFilters = true;
      // The fake returns rows carrying the asked-for values, the in-memory
      // re-check keeps them all, so the list shows them.
      provider.setLifecycleStageFilter('Customer');
      await _settle();

      expect(provider.contacts, hasLength(2));
      expect(
        provider.contacts.every((c) => c.lifecycleStage == 'customer'),
        isTrue,
        reason: 'every displayed row must match the selected filter',
      );
    });

    test('when nothing matches, the list is empty instead of showing unfiltered rows', () async {
      // honoursFilters = false: the fake ignores the filter and returns rows
      // carrying a value nobody selected. No row matches, so the screen must
      // NOT fall back to showing all of them.
      await provider.fetchContacts();
      expect(provider.contacts, hasLength(2));

      provider.setLifecycleStageFilter('Customer');
      await _settle();

      expect(
        provider.contacts,
        isEmpty,
        reason: 'unmatched rows must never be shown as a filter result',
      );
    });

    test('holds for every filter, including a missing created date', () async {
      repo.omitCreatedAt = true;

      for (final apply in <void Function()>[
        () => provider.setOwnerFilter('user-7'),
        () => provider.setLifecycleStageFilter('Customer'),
        () => provider.setLeadStatusFilter('New'),
        () => provider.setCreateDateFilter('Today'),
        () => provider.setMspFilter('Magnit'),
      ]) {
        provider.clearAllFilters();
        await _settle();
        apply();
        await _settle();
        // The fake returned rows that carry the "someone else / nobody picked"
        // values, none of which match the selection — so the screen must not
        // fall back to showing them. It shows the (empty) filtered set.
        final shown = provider.contacts;
        expect(
          shown.isEmpty,
          isTrue,
          reason: 'rows that do not match the selection must never be shown',
        );
      }
    });

    test('a genuinely empty response still shows as empty', () async {
      repo.returnsNothing = true;
      provider.setLifecycleStageFilter('Customer');
      await _settle();

      expect(provider.contacts, isEmpty, reason: 'the API itself returned no rows');
    });

    test('the parameter is still sent, so a backend that adds support just works', () async {
      provider.setLifecycleStageFilter('Customer');
      await _settle();

      expect(repo.requests.last['lifecycleStage'], 'customer');
    });
  });

  group('rapid filter changes', () {
    test('the newest query wins even if an earlier response lands last', () async {
      // First request is slow, second is fast: without a sequence guard the
      // slow one would land second and repaint the list with the old filter.
      repo.delays = [const Duration(milliseconds: 60), Duration.zero];

      provider.setLifecycleStageFilter('Customer');
      provider.setLifecycleStageFilter('Lead');
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(repo.requests.length, 2, reason: 'neither change is dropped');
      expect(provider.selectedStage, 'Lead');
      expect(provider.isLoading, isFalse);
    });
  });

  group('pagination carries the filters', () {
    test('page 2 repeats the same query as page 1', () async {
      provider.setLifecycleStageFilter('Customer');
      await _settle();
      await provider.fetchContacts();

      await provider.changePage(2);

      final page2 = repo.requests.last;
      expect(page2['page'], '2');
      expect(page2['lifecycleStage'], 'customer');
    });

    test('loading more after Clear stays unfiltered', () async {
      provider.setLifecycleStageFilter('Customer');
      await _settle();

      provider.clearAllFilters();
      await _settle();

      await provider.loadMoreContacts();

      final more = repo.requests.last;
      expect(more['lifecycleStage'], isNull);
      expect(more['page'], '2');
    });

    test('changing a filter resets to page 1', () async {
      await provider.fetchContacts();
      await provider.changePage(3);
      expect(provider.currentPage, 3);

      provider.setLeadStatusFilter('New');
      await _settle();

      expect(provider.currentPage, 1);
      expect(repo.requests.last['page'], '1');
    });
  });
}
