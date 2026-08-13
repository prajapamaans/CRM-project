import 'package:flutter/material.dart';
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

  // Filter properties
  String? _selectedOwnerId;
  String? _selectedStage;
  String? _selectedPriority;
  String? _selectedCreateDate;
  String? _selectedStaleDays;

  // Sorting
  ContactSortOption _sortOption = ContactSortOption.mostRecent;

  DealStatsModel? get stats => _stats;

  List<DealModel> get deals {
    List<DealModel> filtered = List.from(_deals);

    // Apply Owner filter
    if (_selectedOwnerId != null && _selectedOwnerId!.isNotEmpty && _selectedOwnerId != 'all') {
      filtered = filtered.where((d) => d.ownerId == _selectedOwnerId).toList();
    }

    // Apply Deal Stage filter
    if (_selectedStage != null &&
        _selectedStage!.isNotEmpty &&
        _selectedStage != 'all stages' &&
        _selectedStage != 'Select a stage') {
      filtered = filtered.where((d) {
        final s = d.stage.toLowerCase();
        final sel = _selectedStage!.toLowerCase();
        if (sel == 'won') return s.contains('won');
        if (sel == 'lost') return s.contains('lost');
        if (sel == 'rfp/rfq') return s.contains('rfp') || s.contains('rfq');
        return s == sel;
      }).toList();
    }

    // Apply Stale Days filter
    if (_selectedStaleDays != null &&
        _selectedStaleDays!.isNotEmpty &&
        _selectedStaleDays != 'All deals' &&
        _selectedStaleDays != 'all') {
      final days = int.tryParse(_selectedStaleDays!.replaceAll(RegExp(r'[^\d]'), ''));
      if (days != null) {
        final now = DateTime.now();
        filtered = filtered.where((d) {
          final dt = DateTime.tryParse(d.createdAt ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          return now.difference(dt).inDays >= days;
        }).toList();
      }
    }

    // Apply Priority filter
    if (_selectedPriority != null &&
        _selectedPriority!.isNotEmpty &&
        _selectedPriority != 'Select a priority' &&
        _selectedPriority != 'all') {
      filtered = filtered.where((d) {
        final prio = (d.priority ?? '').toLowerCase();
        return prio == _selectedPriority!.toLowerCase();
      }).toList();
    }

    // Apply Sorting
    switch (_sortOption) {
      case ContactSortOption.aToZ:
        filtered.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case ContactSortOption.zToA:
        filtered.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
        break;
      case ContactSortOption.mostRecent:
        filtered.sort((a, b) {
          final dateA = DateTime.tryParse(a.createdAt ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dateB = DateTime.tryParse(b.createdAt ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          return dateB.compareTo(dateA);
        });
        break;
    }

    return filtered;
  }

  String? get selectedStage => _selectedStage;
  String? get selectedOwnerId => _selectedOwnerId;
  String? get selectedPriority => _selectedPriority;
  String? get selectedCreateDate => _selectedCreateDate;
  String? get selectedStaleDays => _selectedStaleDays;
  ContactSortOption get sortOption => _sortOption;

  bool get isFilterActive =>
      (_selectedOwnerId != null && _selectedOwnerId!.isNotEmpty && _selectedOwnerId != 'all') ||
      (_selectedStage != null &&
          _selectedStage!.isNotEmpty &&
          _selectedStage != 'all stages' &&
          _selectedStage != 'Select a stage') ||
      (_selectedStaleDays != null &&
          _selectedStaleDays!.isNotEmpty &&
          _selectedStaleDays != 'All deals' &&
          _selectedStaleDays != 'all') ||
      (_selectedPriority != null &&
          _selectedPriority!.isNotEmpty &&
          _selectedPriority != 'Select a priority' &&
          _selectedPriority != 'all') ||
      (_selectedCreateDate != null && _selectedCreateDate!.isNotEmpty);

  int get totalCount => isFilterActive ? deals.length : _totalCount;
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

  void setOwnerFilter(String? ownerId) {
    _selectedOwnerId = ownerId;
    notifyListeners();
  }

  void setStageFilter(String? stage) {
    _selectedStage = stage;
    notifyListeners();
  }

  void setStaleDaysFilter(String? days) {
    _selectedStaleDays = days;
    notifyListeners();
  }

  void setPriorityFilter(String? priority) {
    _selectedPriority = priority;
    notifyListeners();
  }

  void setCreateDateFilter(String? date) {
    _selectedCreateDate = date;
    notifyListeners();
  }

  void clearAllFilters() {
    _selectedOwnerId = null;
    _selectedStage = null;
    _selectedPriority = null;
    _selectedCreateDate = null;
    _selectedStaleDays = null;
    _sortOption = ContactSortOption.mostRecent;
    notifyListeners();
  }

  Future<void> fetchDealStats() async {
    try {
      _stats = await _repository.getDealStats();
      notifyListeners();
    } catch (e) {
      debugPrint('[DealProvider fetchDealStats error]: $e');
    }
  }

  Future<void> fetchDeals({
    String? search,
    String? ownerId,
    bool? ignorePermissions,
    bool refresh = true,
  }) async {
    if (refresh) {
      _currentPage = 1;
      _isLoading = true;
      _error = null;
      if (search != null) _currentSearch = search;
      _currentOwnerId = ownerId;
      _currentIgnorePermissions = ignorePermissions;
      notifyListeners();
    }

    try {
      final res = await _repository.getDeals(
        page: _currentPage,
        limit: _limit,
        search: _currentSearch,
        ownerId: _currentOwnerId,
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
}
