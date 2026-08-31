import 'package:flutter/material.dart';
import '../../../../core/utils/filter_query_utils.dart';
import '../../data/models/company_model.dart';
import '../../data/repositories/company_repository.dart';
import 'package:crmproject/features/contacts/presentation/providers/contact_provider.dart';

class CompanyProvider extends ChangeNotifier {
  final CompanyRepository _repository;

  CompanyProvider({CompanyRepository? repository})
      : _repository = repository ?? CompanyRepositoryImpl();

  List<CompanyModel> _companies = [];
  CompanyModel? _selectedCompany;
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
  /// MSP is only ever applied here — `GET /api/companies` has no parameter for
  /// it.
  List<CompanyModel> get companies {
    List<CompanyModel> filtered = List.from(_companies);

    final ownerPill = FilterValue.orNull(_selectedOwnerId);
    if (ownerPill != null) {
      filtered = narrowInMemory(
        rows: filtered,
        filter: 'Company owner',
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
        test: (c) => FilterValue.matchesLifecycleStage(_selectedLifecycleStage, c.lifecycleStage),
        storedValue: (c) => c.lifecycleStage,
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

    // Apply Default Most Recent Sorting (newest first)
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

  /// The owner the request is scoped to: the Company owner pill when one is
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

  CompanyModel? get selectedCompany => _selectedCompany;
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
    final visible = companies;
    return visible.length < _companies.length ? visible.length : _totalCount;
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
    notifyListeners();
    debugPrint('[CompanyProvider] filter changed: $changed → ${describeFilters()}');
    fetchCompanies(refresh: true);
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
    debugPrint('[CompanyProvider] CLEAR — before: ${describeFilters()}');

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

    debugPrint('[CompanyProvider] CLEAR — after: ${describeFilters()}');
    notifyListeners();
    fetchCompanies(refresh: true);
  }

  void setStageFilter(String? stage) {
    _selectedLifecycleStage = stage;
    _applyFilterChange('lifecycleStage');
  }

  String? _currentDepartmentId;
  String? get currentDepartmentId => _currentDepartmentId;

  /// Sets the All/Mine segment scope and reloads.
  ///
  /// This is the only path that may set the scope to null, which is why it is
  /// separate from [fetchCompanies] — there, an omitted `ownerId` has to mean
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
    return fetchCompanies(refresh: true);
  }

  Future<void> fetchCompanies({
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
    // call that turns back at the guard below must not bump the counter, or it
    // would mark the request already in flight as superseded.
    final int requestSeq;

    if (refresh) {
      _currentPage = 1;
      _isLoading = true;
      _error = null;
      if (search != null) _currentSearch = search;
      // Only a caller that names the segment scope changes it; a bare
      // fetchCompanies() is a refresh and must keep the scope it was on.
      if (ownerId != null) _currentOwnerId = ownerId;
      if (ignorePermissions != null) _currentIgnorePermissions = ignorePermissions;
      requestSeq = ++_requestSeq;
      notifyListeners();
    } else {
      if (_isLoadingMore || !_hasMore) return;
      requestSeq = ++_requestSeq;
      _isLoadingMore = true;
      notifyListeners();
    }

    try {
      final res = await _repository.getCompanies(
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
        debugPrint('[CompanyProvider] Ignoring stale response for department: $requestedDeptId (active: $_currentDepartmentId)');
        return;
      }
      if (requestSeq != _requestSeq) {
        debugPrint('[CompanyProvider] Ignoring superseded response #$requestSeq (latest: $_requestSeq)');
        return;
      }

      if (refresh) {
        _companies = res.companies;
      } else {
        _companies.addAll(res.companies);
      }

      _totalCount = res.total > 0 ? res.total : _companies.length;
      _hasMore = _companies.length < _totalCount && res.companies.isNotEmpty;
    } catch (e) {
      if (requestedDeptId == _currentDepartmentId) {
        _error = e.toString();
      }
    } finally {
      if (requestedDeptId == _currentDepartmentId) {
        _isLoading = false;
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  void clearData() {
    _companies = [];
    _selectedCompany = null;
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

  Future<void> changePage(int page) async {
    if (page < 1 || page > totalPages || _isLoading) return;
    _currentPage = page;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _repository.getCompanies(
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

      _companies = res.companies;
      _totalCount = res.total > 0 ? res.total : _companies.length;
      _hasMore = _currentPage < totalPages;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads the next page. The active filters are read from provider state
  /// inside [fetchCompanies], so every subsequent page carries the same query
  /// as page 1 — and, after Clear, the same absence of one.
  Future<void> loadMoreCompanies() async {
    if (_hasMore && !_isLoadingMore && !_isLoading) {
      _currentPage++;
      await fetchCompanies(refresh: false);
    }
  }

  Future<CompanyModel?> fetchCompanyById(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _selectedCompany = await _repository.getCompanyById(id);
      return _selectedCompany;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createCompany(Map<String, dynamic> companyData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newCompany = await _repository.createCompany(companyData);
      _companies.insert(0, newCompany);
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

  Future<bool> updateCompany(String id, Map<String, dynamic> companyData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _repository.updateCompany(id, companyData);
      final index = _companies.indexWhere((c) => c.id.toString() == id.toString());
      if (index != -1) {
        _companies[index] = res;
      } else {
        _companies.insert(0, res);
      }
      _selectedCompany = res;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteCompany(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _repository.deleteCompany(id);
      if (success) {
        _companies.removeWhere((c) => c.id == id);
        _totalCount = (_totalCount - 1).clamp(0, 999999);
        if (_selectedCompany?.id == id) {
          _selectedCompany = null;
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
}
