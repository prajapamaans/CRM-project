import 'package:flutter/material.dart';
import '../../../../core/utils/filter_query_utils.dart';
import '../../data/models/contact_model.dart';
import '../../data/repositories/contact_repository.dart';

enum ContactSortOption { aToZ, zToA, mostRecent }

class ContactProvider extends ChangeNotifier {
  final ContactRepository _repository;

  ContactProvider({ContactRepository? repository})
      : _repository = repository ?? ContactRepositoryImpl();

  List<ContactModel> _contacts = [];
  ContactModel? _selectedContact;
  int _totalCount = 0;
  int _currentPage = 1;
  final int _limit = 25;
  bool _hasMore = true;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  String? _currentSearch;
  String? _currentOwnerId;
  bool? _currentIgnorePermissions;

  /// Increments on every request so a superseded one cannot write its result.
  int _requestSeq = 0;

  /// The query a refresh currently in flight is fetching, so an identical
  /// repeat can be collapsed into it rather than hitting the API again.
  String? _inFlightSignature;

  /// Everything that goes into the request. Two refreshes with the same
  /// signature would return the same rows, so only one needs to be sent; a
  /// filter change produces a different signature and always gets its own.
  String get _querySignature => [
        _currentPage,
        _limit,
        _currentSearch,
        _ownerQuery,
        _currentDepartmentId,
        _currentIgnorePermissions,
        _lifecycleStageQuery,
        _leadStatusQuery,
        _createdDateRangeQuery,
      ].join('|');

  // Filter properties
  String? _selectedOwnerId;
  String? _selectedLifecycleStage;
  String? _selectedLeadStatus;
  String? _selectedCreateDate;
  String? _selectedMsp;

  // Sorting
  ContactSortOption _sortOption = ContactSortOption.mostRecent;

  /// Every filter is sent to the API *and* re-applied here.
  ///
  /// The request carries `ownerId`, `lifecycleStage`, `leadStatus` and
  /// `createdDateRange`, which narrows the whole dataset rather than one page.
  /// But a deployment that does not implement one of those parameters ignores
  /// it and returns everything, and relying on the server alone meant the
  /// filter then did nothing at all. So the same conditions are checked again
  /// on what comes back: when the server did filter this pass drops nothing,
  /// and when it did not the user still sees a filtered list.
  ///
  /// MSP is only ever applied here — `GET /api/contacts` has no parameter for
  /// it.
  List<ContactModel> get contacts {
    List<ContactModel> filtered = List.from(_contacts);

    final ownerPill = FilterValue.orNull(_selectedOwnerId);
    if (ownerPill != null) {
      filtered = narrowInMemory(
        rows: filtered,
        filter: 'Contact owner',
        selection: ownerPill,
        test: (c) => c.ownerId == ownerPill,
        storedValue: (c) => c.ownerId,
      );
    }

    if (FilterValue.orNull(_selectedLifecycleStage) != null) {
      filtered = narrowInMemory(
        rows: filtered,
        filter: 'Lifecycle stage',
        selection: _selectedLifecycleStage,
        // The row may carry the stage as a name or as an id, so both are tried.
        test: (c) =>
            FilterValue.matchesLifecycleStage(_selectedLifecycleStage, c.lifecycleStage) ||
            FilterValue.matchesLifecycleStage(_selectedLifecycleStage, c.lifecycleStageId),
        storedValue: (c) => c.lifecycleStage ?? c.lifecycleStageId,
      );
    }

    if (FilterValue.orNull(_selectedLeadStatus) != null) {
      filtered = narrowInMemory(
        rows: filtered,
        filter: 'Lead status',
        selection: _selectedLeadStatus,
        test: (c) => FilterValue.matchesSlug(_selectedLeadStatus, c.leadStatus),
        storedValue: (c) => c.leadStatus,
      );
    }

    if (!FilterDateRange.isUnset(_selectedCreateDate)) {
      filtered = narrowInMemory(
        rows: filtered,
        filter: 'Create date',
        selection: _selectedCreateDate,
        test: (c) => FilterDateRange.matches(_selectedCreateDate, c.createdAt),
        storedValue: (c) => c.createdAt,
      );
    }

    if (_mspFilterValue != null) {
      filtered = narrowInMemory(
        rows: filtered,
        filter: 'MSP',
        selection: _mspFilterValue,
        test: (c) => (c.msp ?? '').toLowerCase().contains(_mspFilterValue!.toLowerCase()),
        storedValue: (c) => c.msp,
      );
    }

    // Most recent first. The API is asked for this order too; re-sorting here
    // keeps it right when a page arrives in a different order.
    filtered.sort((a, b) {
      final dateA = DateTime.tryParse(a.createdAt ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = DateTime.tryParse(b.createdAt ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      return dateB.compareTo(dateA);
    });

    return filtered;
  }

  // ---------------------------------------------------------------------------
  // Filter → query parameters
  // ---------------------------------------------------------------------------

  /// The owner the request is scoped to: the Contact owner pill when one is
  /// chosen, otherwise the All/Mine segment. Both map to `ownerId`, so the
  /// explicit pill wins.
  String? get _ownerQuery => FilterValue.orNull(_selectedOwnerId) ?? _currentOwnerId;

  String? get _lifecycleStageQuery => FilterValue.lifecycleStage(_selectedLifecycleStage);

  String? get _leadStatusQuery {
    final value = FilterValue.orNull(_selectedLeadStatus);
    return value == null ? null : FilterValue.slugify(value);
  }

  String? get _createdDateRangeQuery => FilterDateRange.toQueryValue(_selectedCreateDate);

  /// Null unless a real MSP is picked. No API parameter exists for it.
  String? get _mspFilterValue => FilterValue.orNull(_selectedMsp);

  ContactModel? get selectedContact => _selectedContact;
  String? get selectedStage => _selectedLifecycleStage;
  String? get selectedOwnerId => _selectedOwnerId;
  String? get selectedLeadStatus => _selectedLeadStatus;
  String? get selectedCreateDate => _selectedCreateDate;
  String? get selectedMsp => _selectedMsp;
  ContactSortOption get sortOption => _sortOption;

  bool get isFilterActive =>
      FilterValue.orNull(_selectedOwnerId) != null ||
      FilterValue.orNull(_selectedLifecycleStage) != null ||
      FilterValue.orNull(_selectedLeadStatus) != null ||
      _mspFilterValue != null ||
      !FilterDateRange.isUnset(_selectedCreateDate);

  /// The server's total for the current query.
  ///
  /// If nothing was dropped after the response, the API honoured the filters
  /// and its total is authoritative. If rows *were* dropped, the API did not
  /// filter, so its total counts records the user cannot see — the visible
  /// count is the truthful one.
  int get totalCount {
    final visible = contacts;
    return visible.length < _contacts.length ? visible.length : _totalCount;
  }
  int get currentPage => _currentPage;
  int get limit => _limit;
  int get totalPages {
    final count = (totalCount / _limit).ceil();
    return count > 0 ? count : 1;
  }
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;

  void setSortOption(ContactSortOption option) {
    _sortOption = option;
    notifyListeners();
  }

  /// Changing any filter replaces just that one, resets to page 1 and asks the
  /// API again — the other filters ride along in the same request.
  void setOwnerFilter(String? ownerId) {
    _selectedOwnerId = ownerId;
    _applyFilterChange('owner');
  }

  void setLifecycleStageFilter(String? stage) {
    _selectedLifecycleStage = stage;
    _applyFilterChange('lifecycleStage');
  }

  void setLeadStatusFilter(String? status) {
    _selectedLeadStatus = status;
    _applyFilterChange('leadStatus');
  }

  void setCreateDateFilter(String? date) {
    _selectedCreateDate = date;
    _applyFilterChange('createDate');
  }

  void setMspFilter(String? msp) {
    _selectedMsp = msp;
    // MSP narrows the loaded rows rather than the query, so no refetch is
    // needed — but the page count and list have to be recomputed.
    _currentPage = 1;
    notifyListeners();
  }

  void _applyFilterChange(String changed) {
    _currentPage = 1;
    _hasMore = true;
    // Drop the rows fetched under the previous filter so the screen never
    // shows data that was gathered for an older selection while the new
    // request is in flight.
    _contacts = [];
    _totalCount = 0;
    notifyListeners();
    debugPrint('[ContactProvider] filter changed: $changed → ${describeFilters()}');
    fetchContacts(refresh: true);
  }

  /// The active filter state, for logging.
  String describeFilters() => 'owner=${FilterValue.orNull(_selectedOwnerId) ?? '-'} '
      'stage=${_lifecycleStageQuery ?? '-'} '
      'leadStatus=${_leadStatusQuery ?? '-'} '
      'createdDateRange=${_createdDateRangeQuery ?? '-'} '
      'msp=${_mspFilterValue ?? '-'} '
      'search=${_currentSearch ?? '-'}';

  /// Removes every filter and reloads the full, unfiltered first page.
  ///
  /// The segment scope (`_currentOwnerId`), the department and the permission
  /// scope are deliberately untouched: they are not filter pills, and dropping
  /// them would silently change which records the user is allowed to see.
  void clearAllFilters() {
    debugPrint('[ContactProvider] CLEAR — before: ${describeFilters()}');

    _selectedOwnerId = null;
    _selectedLifecycleStage = null;
    _selectedLeadStatus = null;
    _selectedCreateDate = null;
    _selectedMsp = null;
    _currentSearch = null;
    _currentPage = 1;
    _hasMore = true;
    _error = null;
    _sortOption = ContactSortOption.mostRecent;
    // Drop the filtered rows so the screen shows a spinner (and then the
    // unfiltered set) rather than the just-cleared filters' data.
    _contacts = [];
    _totalCount = 0;

    debugPrint('[ContactProvider] CLEAR — after: ${describeFilters()}');
    notifyListeners();
    fetchContacts(refresh: true);
  }

  String? _currentDepartmentId;
  String? get currentDepartmentId => _currentDepartmentId;

  /// Sets the All/Mine segment scope and reloads.
  ///
  /// This is the only path that may set the scope to null, which is why it is
  /// separate from [fetchContacts] — there, an omitted `ownerId` has to mean
  /// "leave the scope alone" so that a refresh or a filter change does not
  /// silently drop the user out of the Mine segment.
  Future<void> setSegmentScope({
    String? ownerId,
    bool? ignorePermissions,
    String? departmentId,
    String? search,
  }) {
    _currentOwnerId = ownerId;
    _currentIgnorePermissions = ignorePermissions;
    if (departmentId != null) _currentDepartmentId = departmentId;
    _currentSearch = (search != null && search.isEmpty) ? null : search ?? _currentSearch;
    _currentPage = 1;
    _hasMore = true;
    // The scope/search changed, so the rows gathered under the previous query
    // must not stay on screen while the new one loads.
    _contacts = [];
    _totalCount = 0;
    return fetchContacts(refresh: true);
  }

  Future<void> fetchContacts({
    String? search,
    String? ownerId,
    String? departmentId,
    bool? ignorePermissions,
    bool refresh = true,
  }) async {
    if (departmentId != null) {
      _currentDepartmentId = departmentId;
    }

    final requestedDeptId = _currentDepartmentId;

    // Changing two filters quickly leaves two requests in flight. Each one
    // claims a sequence number and only the newest is allowed to write its
    // result, so a slower earlier response cannot overwrite the current query.
    //
    // The number is claimed only once a call is going to reach the API — a
    // call that turns back at a guard below must not bump the counter, or it
    // would mark the request already in flight as superseded and its result
    // would be thrown away.
    final int requestSeq;

    if (refresh) {
      if (search != null) _currentSearch = search;
      // Only a caller that names the segment scope changes it; a bare
      // fetchContacts() is a refresh and must keep the scope it was on.
      if (ownerId != null) _currentOwnerId = ownerId;
      if (ignorePermissions != null) _currentIgnorePermissions = ignorePermissions;
      _currentPage = 1;

      final signature = _querySignature;
      if (_isLoading && _inFlightSignature == signature) {
        debugPrint('[ContactProvider] Skipping duplicate in-flight refresh');
        return;
      }

      requestSeq = ++_requestSeq;
      _isLoading = true;
      _error = null;
      _inFlightSignature = signature;
      notifyListeners();
    } else {
      if (_isLoadingMore || !_hasMore) return;
      requestSeq = ++_requestSeq;
      _isLoadingMore = true;
      notifyListeners();
    }

    try {
      final res = await _repository.getContacts(
        page: _currentPage.toString(),
        limit: _limit.toString(),
        search: _currentSearch,
        ownerId: _ownerQuery,
        departmentId: _currentDepartmentId,
        ignorePermissions: _currentIgnorePermissions,
        lifecycleStage: _lifecycleStageQuery,
        leadStatus: _leadStatusQuery,
        createdDateRange: _createdDateRangeQuery,
        sort: 'created_at',
        order: 'desc',
      );

      // Race condition guard: ignore stale response if department changed while waiting
      if (requestedDeptId != _currentDepartmentId) {
        debugPrint('[ContactProvider] Ignoring stale response for department: $requestedDeptId (active: $_currentDepartmentId)');
        return;
      }
      if (requestSeq != _requestSeq) {
        debugPrint('[ContactProvider] Ignoring superseded response #$requestSeq (latest: $_requestSeq)');
        return;
      }

      if (refresh) {
        _contacts = res.contacts;
      } else {
        _contacts.addAll(res.contacts);
      }

      _totalCount = res.total > 0 ? res.total : _contacts.length;
      _hasMore = _contacts.length < _totalCount && res.contacts.isNotEmpty;
    } catch (e) {
      if (requestedDeptId == _currentDepartmentId) {
        _error = e.toString();
      }
    } finally {
      // Only the newest request releases the in-flight marker; a superseded
      // one must not clear the flag out from under the request that replaced it.
      if (requestSeq == _requestSeq) _inFlightSignature = null;
      if (requestedDeptId == _currentDepartmentId && requestSeq == _requestSeq) {
        _isLoading = false;
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> changePage(int page) async {
    if (page < 1 || page > totalPages || _isLoading) return;
    _currentPage = page;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _repository.getContacts(
        page: _currentPage.toString(),
        limit: _limit.toString(),
        search: _currentSearch,
        ownerId: _ownerQuery,
        departmentId: _currentDepartmentId,
        ignorePermissions: _currentIgnorePermissions,
        lifecycleStage: _lifecycleStageQuery,
        leadStatus: _leadStatusQuery,
        createdDateRange: _createdDateRangeQuery,
        sort: 'created_at',
        order: 'desc',
      );

      _contacts = res.contacts;
      _totalCount = res.total > 0 ? res.total : _contacts.length;
      _hasMore = _currentPage < totalPages;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads the next page. The active filters are read from provider state
  /// inside [fetchContacts], so every subsequent page carries the same query
  /// as page 1 — and, after Clear, the same absence of one.
  Future<void> loadMoreContacts() async {
    if (_hasMore && !_isLoadingMore && !_isLoading) {
      _currentPage++;
      await fetchContacts(refresh: false);
    }
  }

  Future<ContactModel?> fetchContactById(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _selectedContact = await _repository.getContactById(id);
      return _selectedContact;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createContact(Map<String, dynamic> contactData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newContact = await _repository.createContact(contactData);
      _contacts.insert(0, newContact);
      _totalCount++;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateContact(String id, Map<String, dynamic> contactData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _repository.updateContact(id, contactData);
      final index = _contacts.indexWhere((c) => c.id.toString() == id.toString());
      if (index != -1) {
        _contacts[index] = res;
      } else {
        _contacts.insert(0, res);
      }
      _selectedContact = res;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[updateContact error, applying optimistic local update]: $e');
      if (_selectedContact != null && _selectedContact!.id.toString() == id.toString()) {
        final updated = _selectedContact!.copyWith(
          firstName: (contactData['firstName'] ?? contactData['first_name'])?.toString().isNotEmpty == true
              ? (contactData['firstName'] ?? contactData['first_name']).toString()
              : _selectedContact!.firstName,
          lastName: (contactData['lastName'] ?? contactData['last_name'])?.toString().isNotEmpty == true
              ? (contactData['lastName'] ?? contactData['last_name']).toString()
              : _selectedContact!.lastName,
          email: contactData['email']?.toString().isNotEmpty == true ? contactData['email'].toString() : _selectedContact!.email,
          phone: contactData['phone']?.toString().isNotEmpty == true ? contactData['phone'].toString() : _selectedContact!.phone,
          jobTitle: (contactData['jobTitle'] ?? contactData['job_title'])?.toString().isNotEmpty == true
              ? (contactData['jobTitle'] ?? contactData['job_title']).toString()
              : _selectedContact!.jobTitle,
          companyName: (contactData['companyName'] ?? contactData['company_name'])?.toString().isNotEmpty == true
              ? (contactData['companyName'] ?? contactData['company_name']).toString()
              : _selectedContact!.companyName,
          ownerName: (contactData['ownerName'] ?? contactData['owner_name'])?.toString().isNotEmpty == true
              ? (contactData['ownerName'] ?? contactData['owner_name']).toString()
              : _selectedContact!.ownerName,
          lifecycleStage: (contactData['lifecycleStage'] ?? contactData['lifecycle_stage'])?.toString().isNotEmpty == true
              ? (contactData['lifecycleStage'] ?? contactData['lifecycle_stage']).toString()
              : _selectedContact!.lifecycleStage,
          leadStatus: (contactData['leadStatus'] ?? contactData['lead_status'])?.toString().isNotEmpty == true
              ? (contactData['leadStatus'] ?? contactData['lead_status']).toString()
              : _selectedContact!.leadStatus,
        );
        _selectedContact = updated;
        final idx = _contacts.indexWhere((c) => c.id.toString() == id.toString());
        if (idx != -1) _contacts[idx] = updated;
        notifyListeners();
        return true;
      }
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteContact(String id, {String? departmentId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final targetDeptId = departmentId ?? _currentDepartmentId;
      final success = await _repository.deleteContact(id, departmentId: targetDeptId);
      if (success) {
        _contacts.removeWhere((c) => c.id == id);
        _totalCount = (_totalCount - 1).clamp(0, 999999);
        if (_selectedContact?.id == id) {
          _selectedContact = null;
        }
      }
      return success;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearData() {
    _contacts = [];
    _selectedContact = null;
    _totalCount = 0;
    _currentPage = 1;
    _hasMore = true;
    _isLoading = false;
    _isLoadingMore = false;
    _error = null;
    _currentSearch = null;
    _currentOwnerId = null;
    _currentDepartmentId = null;
    _currentIgnorePermissions = null;
    _selectedOwnerId = null;
    _selectedLifecycleStage = null;
    _selectedLeadStatus = null;
    _selectedCreateDate = null;
    _sortOption = ContactSortOption.mostRecent;
    notifyListeners();
  }
}
