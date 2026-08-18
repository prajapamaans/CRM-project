import 'package:flutter/material.dart';
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

  // Filter properties
  String? _selectedOwnerId;
  String? _selectedLifecycleStage;
  String? _selectedLeadStatus;
  String? _selectedCreateDate;

  // Sorting
  ContactSortOption _sortOption = ContactSortOption.mostRecent;

  List<ContactModel> get contacts {
    List<ContactModel> filtered = List.from(_contacts);

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

  ContactModel? get selectedContact => _selectedContact;
  String? get selectedStage => _selectedLifecycleStage;
  String? get selectedOwnerId => _selectedOwnerId;
  String? get selectedLeadStatus => _selectedLeadStatus;
  String? get selectedCreateDate => _selectedCreateDate;
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
      (_selectedCreateDate != null && _selectedCreateDate!.isNotEmpty);

  int get totalCount => isFilterActive ? contacts.length : _totalCount;
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

  void clearAllFilters() {
    _selectedOwnerId = null;
    _selectedLifecycleStage = null;
    _selectedLeadStatus = null;
    _selectedCreateDate = null;
    _sortOption = ContactSortOption.mostRecent;
    notifyListeners();
  }

  String? _currentDepartmentId;
  String? get currentDepartmentId => _currentDepartmentId;

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
      final res = await _repository.getContacts(
        page: _currentPage.toString(),
        limit: _limit.toString(),
        search: _currentSearch,
        ownerId: _currentOwnerId,
        departmentId: _currentDepartmentId,
        ignorePermissions: _currentIgnorePermissions,
      );

      // Race condition guard: ignore stale response if department changed while waiting
      if (requestedDeptId != _currentDepartmentId) {
        debugPrint('[ContactProvider] Ignoring stale response for department: $requestedDeptId (active: $_currentDepartmentId)');
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
      if (requestedDeptId == _currentDepartmentId) {
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
        ownerId: _currentOwnerId,
        departmentId: _currentDepartmentId,
        ignorePermissions: _currentIgnorePermissions,
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

  Future<void> loadMoreContacts() async {
    if (_hasMore && !_isLoadingMore && !_isLoading) {
      _currentPage++;
      await fetchContacts(
        search: _currentSearch,
        ownerId: _currentOwnerId,
        departmentId: _currentDepartmentId,
        ignorePermissions: _currentIgnorePermissions,
        refresh: false,
      );
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
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteContact(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _repository.deleteContact(id);
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
