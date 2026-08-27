import 'package:flutter/material.dart';
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

  // Filter properties
  String? _selectedOwnerId;
  String? _selectedLifecycleStage;
  String? _selectedLeadStatus;
  String? _selectedCreateDate;
  String? _selectedMsp;

  // Sorting
  ContactSortOption _sortOption = ContactSortOption.mostRecent;

  List<CompanyModel> get companies {
    List<CompanyModel> filtered = List.from(_companies);

    // Apply Owner filter
    if (_selectedOwnerId != null && _selectedOwnerId!.isNotEmpty && _selectedOwnerId != 'all') {
      filtered = filtered.where((c) => c.ownerId == _selectedOwnerId).toList();
    }

    // Apply Lifecycle Stage filter
    if (_selectedLifecycleStage != null &&
        _selectedLifecycleStage!.isNotEmpty &&
        _selectedLifecycleStage != 'all stages' &&
        _selectedLifecycleStage != 'Select a stage') {
      filtered = filtered.where((c) {
        final stage = (c.lifecycleStage ?? '').toLowerCase();
        return stage == _selectedLifecycleStage!.toLowerCase();
      }).toList();
    }

    // Apply Lead Status filter
    if (_selectedLeadStatus != null &&
        _selectedLeadStatus!.isNotEmpty &&
        _selectedLeadStatus != 'Select a status' &&
        _selectedLeadStatus != 'all') {
      filtered = filtered.where((c) {
        final status = (c.leadStatus ?? '').toLowerCase();
        return status == _selectedLeadStatus!.toLowerCase();
      }).toList();
    }

    // Apply MSP filter
    if (_selectedMsp != null &&
        _selectedMsp!.isNotEmpty &&
        _selectedMsp != 'All MSPs' &&
        _selectedMsp != 'all') {
      filtered = filtered.where((c) {
        final msp = (c.msp ?? '').toLowerCase();
        return msp.contains(_selectedMsp!.toLowerCase());
      }).toList();
    }

    // Apply Sorting
    switch (_sortOption) {
      case ContactSortOption.aToZ:
        filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case ContactSortOption.zToA:
        filtered.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
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

  CompanyModel? get selectedCompany => _selectedCompany;
  String? get selectedStage => _selectedLifecycleStage;
  String? get selectedOwnerId => _selectedOwnerId;
  String? get selectedLeadStatus => _selectedLeadStatus;
  String? get selectedCreateDate => _selectedCreateDate;
  String? get selectedMsp => _selectedMsp;
  ContactSortOption get sortOption => _sortOption;

  bool get isFilterActive =>
      (_selectedOwnerId != null && _selectedOwnerId!.isNotEmpty && _selectedOwnerId != 'all') ||
      (_selectedLifecycleStage != null &&
          _selectedLifecycleStage!.isNotEmpty &&
          _selectedLifecycleStage != 'all stages' &&
          _selectedLifecycleStage != 'Select a stage') ||
      (_selectedLeadStatus != null &&
          _selectedLeadStatus!.isNotEmpty &&
          _selectedLeadStatus != 'Select a status' &&
          _selectedLeadStatus != 'all') ||
      (_selectedMsp != null &&
          _selectedMsp!.isNotEmpty &&
          _selectedMsp != 'All MSPs' &&
          _selectedMsp != 'all') ||
      (_selectedCreateDate != null && _selectedCreateDate!.isNotEmpty);

  int get totalCount => isFilterActive ? companies.length : _totalCount;
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

  void setOwnerFilter(String? ownerId) {
    _selectedOwnerId = ownerId;
    notifyListeners();
  }

  void setLifecycleStageFilter(String? stage) {
    _selectedLifecycleStage = stage;
    notifyListeners();
  }

  void setLeadStatusFilter(String? status) {
    _selectedLeadStatus = status;
    notifyListeners();
  }

  void setCreateDateFilter(String? date) {
    _selectedCreateDate = date;
    notifyListeners();
  }

  void setMspFilter(String? msp) {
    _selectedMsp = msp;
    notifyListeners();
  }

  void clearAllFilters() {
    _selectedOwnerId = null;
    _selectedLifecycleStage = null;
    _selectedLeadStatus = null;
    _selectedCreateDate = null;
    _sortOption = ContactSortOption.mostRecent;
    notifyListeners();
  }

  void setStageFilter(String? stage) {
    _selectedLifecycleStage = stage;
    notifyListeners();
  }

  String? _currentDepartmentId;
  String? get currentDepartmentId => _currentDepartmentId;

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

    if (refresh) {
      _currentPage = 1;
      _isLoading = true;
      _error = null;
      if (search != null) _currentSearch = search;
      _currentOwnerId = ownerId;
      _currentIgnorePermissions = ignorePermissions;
      notifyListeners();
    } else {
      if (_isLoadingMore || !_hasMore) return;
      _isLoadingMore = true;
      notifyListeners();
    }

    try {
      final res = await _repository.getCompanies(
        page: _currentPage.toString(),
        limit: _limit.toString(),
        search: _currentSearch,
        ownerId: _currentOwnerId,
        departmentId: _currentDepartmentId,
        ignorePermissions: _currentIgnorePermissions,
      );

      // Race condition guard: ignore stale response if department changed while waiting
      if (requestedDeptId != _currentDepartmentId) {
        debugPrint('[CompanyProvider] Ignoring stale response for department: $requestedDeptId (active: $_currentDepartmentId)');
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
        ownerId: _currentOwnerId,
        departmentId: _currentDepartmentId,
        ignorePermissions: _currentIgnorePermissions,
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

  Future<void> loadMoreCompanies() async {
    if (_hasMore && !_isLoadingMore && !_isLoading) {
      _currentPage++;
      await fetchCompanies(
        search: _currentSearch,
        ownerId: _currentOwnerId,
        departmentId: _currentDepartmentId,
        ignorePermissions: _currentIgnorePermissions,
        refresh: false,
      );
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
