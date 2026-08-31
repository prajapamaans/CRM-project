import 'package:flutter/material.dart';
import '../../../../core/utils/filter_query_utils.dart';
import '../../data/models/deal_model.dart';
import '../../data/models/deal_stats_model.dart';
import '../../data/repositories/deal_repository.dart';
import 'package:crmproject/features/contacts/presentation/providers/contact_provider.dart';

class DealProvider extends ChangeNotifier {
  final DealRepository _repository;

  DealProvider({DealRepository? repository})
      : _repository = repository ?? DealRepositoryImpl();

  DealStatsModel? _stats;
  List<DealModel> _deals = [];
  int _totalCount = 0;
  int _currentPage = 1;
  final int _limit = 25;
  bool _isLoading = false;
  String? _error;
  String? _currentSearch;
  String? _currentOwnerId;
  bool? _currentIgnorePermissions;

  /// Increments on every request so a superseded one cannot write its result.
  int _requestSeq = 0;

  // Filter properties
  String? _selectedOwnerId;
  String? _selectedStage;
  String? _selectedPriority;
  String? _selectedCreateDate;
  String? _selectedStaleDays;
  String? _selectedMsp;

  // Sorting
  ContactSortOption _sortOption = ContactSortOption.mostRecent;

  DealStatsModel? get stats => _stats;

  /// Every filter is sent to the API *and* re-applied here.
  ///
  /// The request carries `ownerId`, `stage`, `createdDateRange` and
  /// `staleDays`, which narrows the whole dataset rather than one page. But a
  /// deployment that does not implement one of those parameters ignores it and
  /// returns everything, and relying on the server alone meant the filter then
  /// did nothing at all. So the same conditions are checked again on what
  /// comes back: when the server did filter this pass drops nothing, and when
  /// it did not the user still sees a filtered list.
  ///
  /// Priority and MSP are only ever applied here — `GET /api/deals` has no
  /// parameter for either.
  List<DealModel> get deals {
    List<DealModel> filtered = List.from(_deals);

    final ownerPill = FilterValue.orNull(_selectedOwnerId);
    if (ownerPill != null) {
      filtered = narrowInMemory(
        rows: filtered,
        filter: 'Deal owner',
        selection: ownerPill,
        test: (d) => d.ownerId == ownerPill,
        storedValue: (d) => d.ownerId,
      );
    }

    final stagePill = _stageQuery;
    if (stagePill != null) {
      filtered = narrowInMemory(
        rows: filtered,
        filter: 'Deal stage',
        selection: stagePill,
        test: (d) {
          final s = d.stage.toLowerCase();
          final sel = stagePill.toLowerCase();
          // Won / Lost / RFP-RFQ are family names rather than exact stages.
          if (sel == 'won') return s.contains('won');
          if (sel == 'lost') return s.contains('lost');
          if (sel == 'rfp/rfq') return s.contains('rfp') || s.contains('rfq');
          return FilterValue.matchesSlug(stagePill, d.stage);
        },
        storedValue: (d) => d.stage,
      );
    }

    final staleDays = int.tryParse(_staleDaysQuery ?? '');
    if (staleDays != null) {
      final now = DateTime.now();
      filtered = narrowInMemory(
        rows: filtered,
        filter: 'Stale days',
        selection: _selectedStaleDays,
        test: (d) {
          final dt = DateTime.tryParse(d.createdAt ?? '');
          return dt != null && now.difference(dt).inDays >= staleDays;
        },
        storedValue: (d) => d.createdAt,
      );
    }

    if (!FilterDateRange.isUnset(_selectedCreateDate)) {
      filtered = narrowInMemory(
        rows: filtered,
        filter: 'Create date',
        selection: _selectedCreateDate,
        test: (d) => FilterDateRange.matches(_selectedCreateDate, d.createdAt),
        storedValue: (d) => d.createdAt,
      );
    }

    if (_priorityFilterValue != null) {
      filtered = narrowInMemory(
        rows: filtered,
        filter: 'Priority',
        selection: _priorityFilterValue,
        test: (d) => FilterValue.matchesSlug(_priorityFilterValue, d.priority),
        storedValue: (d) => d.priority,
      );
    }

    if (_mspFilterValue != null) {
      filtered = narrowInMemory(
        rows: filtered,
        filter: 'MSP',
        selection: _mspFilterValue,
        test: (d) => (d.msp ?? '').toLowerCase().contains(_mspFilterValue!.toLowerCase()),
        storedValue: (d) => d.msp,
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

  /// The owner the request is scoped to: the Deal owner pill when one is
  /// chosen, otherwise the All/Mine segment. Both map to `ownerId`, so the
  /// explicit pill wins.
  String? get _ownerQuery => FilterValue.orNull(_selectedOwnerId) ?? _currentOwnerId;

  /// The stage pill's value, passed through as `stage`. `Won`/`Lost`/`RFP/RFQ`
  /// were matched by substring in memory; the API compares the stage itself,
  /// so the label is sent as-is.
  String? get _stageQuery => FilterValue.orNull(_selectedStage);

  String? get _createdDateRangeQuery => FilterDateRange.toQueryValue(_selectedCreateDate);

  /// `staleDays` — the number pulled out of labels like `30+ days`.
  String? get _staleDaysQuery {
    final label = FilterValue.orNull(_selectedStaleDays);
    if (label == null || label.toLowerCase() == 'all deals') return null;
    final digits = label.replaceAll(RegExp(r'[^\d]'), '');
    return digits.isEmpty ? null : digits;
  }

  /// Null unless a real value is picked. Neither has an API parameter.
  String? get _priorityFilterValue => FilterValue.orNull(_selectedPriority);
  String? get _mspFilterValue => FilterValue.orNull(_selectedMsp);

  String? get selectedStage => _selectedStage;
  String? get selectedOwnerId => _selectedOwnerId;
  String? get selectedPriority => _selectedPriority;
  String? get selectedCreateDate => _selectedCreateDate;
  String? get selectedStaleDays => _selectedStaleDays;
  String? get selectedMsp => _selectedMsp;
  ContactSortOption get sortOption => _sortOption;

  bool get isFilterActive =>
      FilterValue.orNull(_selectedOwnerId) != null ||
      _stageQuery != null ||
      _staleDaysQuery != null ||
      _priorityFilterValue != null ||
      _mspFilterValue != null ||
      !FilterDateRange.isUnset(_selectedCreateDate);

  /// The server's total for the current query.
  ///
  /// If nothing was dropped after the response, the API honoured the filters
  /// and its total is authoritative. If rows *were* dropped, the API did not
  /// filter, so its total counts records the user cannot see — the visible
  /// count is the truthful one.
  int get totalCount {
    final visible = deals;
    return visible.length < _deals.length ? visible.length : _totalCount;
  }
  int get currentPage => _currentPage;
  int get limit => _limit;
  int get totalPages {
    final count = (totalCount / _limit).ceil();
    return count > 0 ? count : 1;
  }
  bool get isLoading => _isLoading;
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

  void setStageFilter(String? stage) {
    _selectedStage = stage;
    _applyFilterChange('stage');
  }

  void setStaleDaysFilter(String? days) {
    _selectedStaleDays = days;
    _applyFilterChange('staleDays');
  }

  void setCreateDateFilter(String? date) {
    _selectedCreateDate = date;
    _applyFilterChange('createDate');
  }

  /// Priority and MSP narrow the loaded rows rather than the query — the deals
  /// endpoint has no parameter for either — so they need no refetch.
  void setMspFilter(String? msp) {
    _selectedMsp = msp;
    _currentPage = 1;
    notifyListeners();
  }

  void setPriorityFilter(String? priority) {
    _selectedPriority = priority;
    _currentPage = 1;
    notifyListeners();
  }

  void _applyFilterChange(String changed) {
    _currentPage = 1;
    notifyListeners();
    debugPrint('[DealProvider] filter changed: $changed → ${describeFilters()}');
    fetchDeals(refresh: true);
  }

  /// The active filter state, for logging.
  String describeFilters() => 'owner=${FilterValue.orNull(_selectedOwnerId) ?? '-'} '
      'stage=${_stageQuery ?? '-'} '
      'staleDays=${_staleDaysQuery ?? '-'} '
      'createdDateRange=${_createdDateRangeQuery ?? '-'} '
      'priority=${_priorityFilterValue ?? '-'} '
      'msp=${_mspFilterValue ?? '-'} '
      'search=${_currentSearch ?? '-'}';

  /// Removes every filter and reloads the full, unfiltered first page.
  ///
  /// The segment scope (`_currentOwnerId`), the department and the permission
  /// scope are deliberately untouched: they are not filter pills, and dropping
  /// them would silently change which records the user is allowed to see.
  void clearAllFilters() {
    debugPrint('[DealProvider] CLEAR — before: ${describeFilters()}');

    _selectedOwnerId = null;
    _selectedStage = null;
    _selectedPriority = null;
    _selectedCreateDate = null;
    _selectedStaleDays = null;
    _selectedMsp = null;
    _currentSearch = null;
    _currentPage = 1;
    _error = null;
    _sortOption = ContactSortOption.mostRecent;

    debugPrint('[DealProvider] CLEAR — after: ${describeFilters()}');
    notifyListeners();
    fetchDeals(refresh: true);
  }

  String? _currentDepartmentId;
  String? get currentDepartmentId => _currentDepartmentId;

  Future<void> fetchDealStats({String? departmentId}) async {
    final deptId = departmentId ?? _currentDepartmentId;
    try {
      _stats = await _repository.getDealStats(departmentId: deptId);
      notifyListeners();
    } catch (e) {
      debugPrint('[DealProvider fetchDealStats error]: $e');
    }
  }

  /// Sets the All/Mine segment scope and reloads.
  ///
  /// This is the only path that may set the scope to null, which is why it is
  /// separate from [fetchDeals] — there, an omitted `ownerId` has to mean
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
    return fetchDeals(refresh: true);
  }

  Future<void> fetchDeals({
    String? search,
    String? ownerId,
    String? departmentId,
    bool? ignorePermissions,
    int? limit,
    bool refresh = true,
  }) async {
    if (departmentId != null) {
      _currentDepartmentId = departmentId;
    }

    final requestedDeptId = _currentDepartmentId;
    // Changing two filters quickly leaves two requests in flight. Each one
    // claims a sequence number and only the newest is allowed to write its
    // result, so a slower earlier response cannot overwrite the current query.
    final requestSeq = ++_requestSeq;

    if (refresh) {
      _currentPage = 1;
      _isLoading = true;
      _error = null;
      if (search != null) _currentSearch = search;
      // Only a caller that names the segment scope changes it; a bare
      // fetchDeals() is a refresh and must keep the scope it was on.
      if (ownerId != null) _currentOwnerId = ownerId;
      if (ignorePermissions != null) _currentIgnorePermissions = ignorePermissions;
      notifyListeners();
    }

    try {
      final res = await _repository.getDeals(
        page: _currentPage,
        limit: limit ?? _limit,
        search: _currentSearch,
        ownerId: _ownerQuery,
        departmentId: _currentDepartmentId,
        ignorePermissions: _currentIgnorePermissions,
        stage: _stageQuery,
        createdDateRange: _createdDateRangeQuery,
        staleDays: _staleDaysQuery,
        sort: 'created_at',
        order: 'desc',
      );

      // Race condition guard: ignore stale response if department changed while waiting
      if (requestedDeptId != _currentDepartmentId) {
        debugPrint('[DealProvider] Ignoring stale response for department: $requestedDeptId (active: $_currentDepartmentId)');
        return;
      }
      if (requestSeq != _requestSeq) {
        debugPrint('[DealProvider] Ignoring superseded response #$requestSeq (latest: $_requestSeq)');
        return;
      }

      _deals = res.deals;
      _totalCount = res.total > 0 ? res.total : _deals.length;
    } catch (e) {
      if (requestedDeptId == _currentDepartmentId) {
        _error = e.toString();
      }
    } finally {
      if (requestedDeptId == _currentDepartmentId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void clearData() {
    _stats = null;
    _deals = [];
    _selectedDeal = null;
    _totalCount = 0;
    _currentPage = 1;
    _isLoading = false;
    _error = null;
    _currentSearch = null;
    _currentOwnerId = null;
    _currentDepartmentId = null;
    _currentIgnorePermissions = null;
    _selectedOwnerId = null;
    _selectedStage = null;
    _selectedPriority = null;
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
      final res = await _repository.getDeals(
        page: _currentPage,
        limit: _limit,
        search: _currentSearch,
        ownerId: _currentOwnerId,
        departmentId: _currentDepartmentId,
        ignorePermissions: _currentIgnorePermissions,
      );

      _deals = res.deals;
      _totalCount = res.total > 0 ? res.total : _deals.length;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createDeal(Map<String, dynamic> dealData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newDeal = await _repository.createDeal(dealData);
      _deals.insert(0, newDeal);
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

  DealModel? _selectedDeal;
  DealModel? get selectedDeal => _selectedDeal;

  Future<bool> updateDeal(String id, Map<String, dynamic> dealData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedDeal = await _repository.updateDeal(id, dealData);
      final index = _deals.indexWhere((d) => d.id.toString() == id.toString());
      if (index != -1) {
        _deals[index] = updatedDeal;
      } else {
        _deals.insert(0, updatedDeal);
      }
      _selectedDeal = updatedDeal;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[DealProvider updateDeal ERROR]: $e');
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteDeal(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _repository.deleteDeal(id);
      if (success) {
        _deals.removeWhere((d) => d.id == id);
        _totalCount = (_totalCount - 1).clamp(0, 999999);
        if (_selectedDeal?.id == id) {
          _selectedDeal = null;
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
