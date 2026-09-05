import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../companies/data/models/company_model.dart';
import '../../../contacts/data/models/contact_model.dart';
import '../../../departments/presentation/providers/department_provider.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  // Tab index mapping:
  // 0: Dashboard, 1: Contacts, 2: Companies, 3: Deals,
  // 4: Tasks, 5: Meetings, 6: Calls, 7: Emails, 8: Notes,
  // 9: Email Engagement, 10: Company-Wise
  int _selectedTab = 0;

  final List<String> _tabs = [
    'Dashboard',
    'Contacts',
    'Companies',
    'Deals',
    'Tasks',
    'Meetings',
    'Calls',
    'Emails',
    'Notes',
    'Email Engagement',
    'Company-Wise',
  ];

  final Map<String, List<Map<String, dynamic>>> _activitiesByType = {};
  final Map<String, Map<String, dynamic>> _activitiesMetaByType = {};
  final Map<String, bool> _isLoadingActivitiesByType = {};
  final Map<String, String?> _errorActivitiesByType = {};

  String _valOrDash(dynamic val) {
    if (val == null) return '-';
    final s = val.toString().trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return '-';
    return s;
  }

  String _formatDateString(dynamic dateStr) {
    if (dateStr == null) return '-';
    final s = dateStr.toString().trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return '-';
    try {
      final dt = DateTime.parse(s);
      final day = dt.day.toString().padLeft(2, '0');
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final month = months[dt.month - 1];
      final year = dt.year;
      final hour = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$day $month $year, $hour:$min';
    } catch (_) {
      return s;
    }
  }

  String? _mapTabToType(String tabName) {
    switch (tabName) {
      case 'Meetings':
        return 'meeting';
      case 'Emails':
      case 'Email Engagement':
        return 'email';
      case 'Notes':
        return 'note';
      case 'Calls':
        return 'call';
      case 'Tasks':
        return 'task';
      default:
        return null;
    }
  }

  void _handleTabTap(int index) {
    setState(() => _selectedTab = index);
    final tabName = _tabs[index];
    final type = _mapTabToType(tabName);
    if (type != null) {
      _fetchActivitiesForType(type);
    }
  }

  void _selectTabByName(String name) {
    final idx = _tabs.indexOf(name);
    if (idx != -1) {
      setState(() => _selectedTab = idx);
      final type = _mapTabToType(name);
      if (type != null) {
        _fetchActivitiesForType(type);
      }
    }
  }

  void _refreshCurrentTabActivityIfNeeded() {
    final currentTabName = _tabs[_selectedTab];
    final type = _mapTabToType(currentTabName);
    if (type != null) {
      _fetchActivitiesForType(type);
    }
  }

  Future<void> _fetchActivitiesForType(String type, {bool isLoadMore = false}) async {
    if (isLoadMore) {
      final meta = _activitiesMetaByType[type];
      final currentTotal = _activitiesByType[type]?.length ?? 0;
      final totalAvailable = meta?['total'] ?? 0;
      if (currentTotal >= totalAvailable && totalAvailable > 0) return;
    }

    final currentPage = isLoadMore ? ((_activitiesMetaByType[type]?['page'] ?? 1) + 1) : 1;

    if (!isLoadMore) {
      setState(() {
        _isLoadingActivitiesByType[type] = true;
        _errorActivitiesByType[type] = null;
      });
    }

    try {
      final api = ApiService();
      String? userId;
      if (_selectedUser != 'All Users' && _users.isNotEmpty) {
        final match = _users.firstWhere(
          (u) {
            final name = '${u['firstName'] ?? u['name'] ?? ''} ${u['lastName'] ?? ''}'.trim();
            return name == _selectedUser || u['id']?.toString() == _selectedUser;
          },
          orElse: () => {},
        );
        if (match.isNotEmpty) {
          userId = match['id']?.toString();
        }
      }

      final currentDeptId = context.read<DepartmentProvider>().selectedDepartmentId;
      final dateRange = _calculateDateRange(_selectedTimeRange);
      final rangeParam = _mapRangeToParam(_selectedTimeRange);

      final queryParams = <String, dynamic>{
        'type': type,
        'range': rangeParam == 'all_time' ? 'all' : rangeParam,
        'page': currentPage,
        'limit': 100,
      };

      if (currentDeptId.isNotEmpty) {
        queryParams['departmentId'] = currentDeptId;
        queryParams['department_id'] = currentDeptId;
      }

      if (userId != null && userId.isNotEmpty && userId != 'all') {
        queryParams['userId'] = userId;
        queryParams['user_id'] = userId;
        queryParams['ownerId'] = userId;
        queryParams['owner_id'] = userId;
      }

      if (dateRange['startDate'] != null) {
        queryParams['startDate'] = dateRange['startDate'];
        queryParams['start_date'] = dateRange['startDate'];
        queryParams['from_date'] = dateRange['startDate'];
        queryParams['created_at_gte'] = dateRange['startDate'];
      }

      if (dateRange['endDate'] != null) {
        queryParams['endDate'] = dateRange['endDate'];
        queryParams['end_date'] = dateRange['endDate'];
        queryParams['to_date'] = dateRange['endDate'];
        queryParams['created_at_lte'] = dateRange['endDate'];
      }

      Response resp;
      try {
        resp = await api.get(ApiConstants.reportsActivities, queryParameters: queryParams);
      } catch (_) {
        resp = await api.get('/activities', queryParameters: queryParams);
      }

      final raw = resp.data;
      List<Map<String, dynamic>> newItems = [];
      Map<String, dynamic> metaMap = {'page': currentPage, 'limit': 100, 'total': 0};

      if (raw is Map<String, dynamic>) {
        if (raw['data'] is List) {
          newItems = (raw['data'] as List).whereType<Map<String, dynamic>>().toList();
        } else if (raw['activities'] is List) {
          newItems = (raw['activities'] as List).whereType<Map<String, dynamic>>().toList();
        }
        if (raw['meta'] is Map<String, dynamic>) {
          metaMap = Map<String, dynamic>.from(raw['meta'] as Map<String, dynamic>);
        } else {
          metaMap['total'] = raw['total'] ?? newItems.length;
        }
      } else if (raw is List) {
        newItems = raw.whereType<Map<String, dynamic>>().toList();
        metaMap['total'] = newItems.length;
      }

      if (mounted) {
        setState(() {
          if (isLoadMore) {
            final existing = _activitiesByType[type] ?? [];
            final existingIds = existing.map((e) => e['id']?.toString()).toSet();
            final filteredNew = newItems.where((item) {
              final id = item['id']?.toString();
              return id == null || !existingIds.contains(id);
            }).toList();
            _activitiesByType[type] = [...existing, ...filteredNew];
          } else {
            _activitiesByType[type] = newItems;
          }
          _activitiesMetaByType[type] = metaMap;
          _isLoadingActivitiesByType[type] = false;
        });
      }
    } catch (e) {
      debugPrint('[Fetch activities type $type error]: $e');
      if (mounted) {
        setState(() {
          _errorActivitiesByType[type] = e.toString();
          _isLoadingActivitiesByType[type] = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _users = [];
  String _selectedUser = 'All Users';
  String _selectedTimeRange = 'All Time';
  DateTime? _startDate;
  DateTime? _endDate;

  bool _isLoading = false;
  Map<String, dynamic>? _reportsAnalyticsData;

  List<ContactModel> _contactsList = [];
  List<CompanyModel> _companiesList = [];
  List<Map<String, dynamic>> _dealsList = [];
  List<Map<String, dynamic>> _activitiesList = [];

  bool _isTabLoading = false;
  String? _lastDepartmentId;

  String _mapRangeToParam(String durationOption) {
    switch (durationOption) {
      case 'Today':
        return 'today';
      case 'Yesterday':
        return 'yesterday';
      case 'This Week':
        return 'this_week';
      case 'Last Week':
        return 'last_week';
      case 'This Month':
        return 'this_month';
      case 'Last Month':
        return 'last_month';
      case 'This Year':
        return 'this_year';
      case 'All Time':
        return 'all_time';
      case 'Custom Range':
        return 'custom';
      default:
        return 'all_time';
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentDeptId = context.watch<DepartmentProvider>().selectedDepartmentId;
    if (_lastDepartmentId != currentDeptId) {
      _lastDepartmentId = currentDeptId;
      _fetchReportsData();
      _fetchTabSpecificData();
      _refreshCurrentTabActivityIfNeeded();
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _fetchReportsData();
    _fetchTabSpecificData();
    _refreshCurrentTabActivityIfNeeded();
  }

  static const List<String> _durationOptions = [
    'Today',
    'Yesterday',
    'This Week',
    'Last Week',
    'This Month',
    'Last Month',
    'This Year',
    'All Time',
    'Custom Range',
  ];

  void _onDurationChanged(String durationOption) {
    final now = DateTime.now();
    DateTime? start;
    DateTime? end;

    switch (durationOption) {
      case 'Today':
        start = DateTime(now.year, now.month, now.day);
        end = DateTime(now.year, now.month, now.day);
        break;
      case 'Yesterday':
        final y = now.subtract(const Duration(days: 1));
        start = DateTime(y.year, y.month, y.day);
        end = DateTime(y.year, y.month, y.day);
        break;
      case 'This Week':
        final sun = now.subtract(Duration(days: now.weekday % 7));
        start = DateTime(sun.year, sun.month, sun.day);
        end = DateTime(now.year, now.month, now.day);
        break;
      case 'Last Week':
        final sunThisWeek = now.subtract(Duration(days: now.weekday % 7));
        final sunLastWeek = sunThisWeek.subtract(const Duration(days: 7));
        final satLastWeek = sunThisWeek.subtract(const Duration(days: 1));
        start = DateTime(sunLastWeek.year, sunLastWeek.month, sunLastWeek.day);
        end = DateTime(satLastWeek.year, satLastWeek.month, satLastWeek.day);
        break;
      case 'This Month':
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month, now.day);
        break;
      case 'Last Month':
        final firstOfThisMonth = DateTime(now.year, now.month, 1);
        final lastOfLastMonth = firstOfThisMonth.subtract(const Duration(days: 1));
        start = DateTime(lastOfLastMonth.year, lastOfLastMonth.month, 1);
        end = DateTime(lastOfLastMonth.year, lastOfLastMonth.month, lastOfLastMonth.day);
        break;
      case 'This Year':
        start = DateTime(now.year, 1, 1);
        end = DateTime(now.year, now.month, now.day);
        break;
      case 'All Time':
        start = null;
        end = null;
        break;
      case 'Custom Range':
        start = _startDate;
        end = _endDate;
        break;
    }

    setState(() {
      _selectedTimeRange = durationOption;
      _startDate = start;
      _endDate = end;
    });

    _fetchReportsData();
    _fetchTabSpecificData();
    _refreshCurrentTabActivityIfNeeded();
  }

  Map<String, String?> _calculateDateRange(String durationOption) {
    if (durationOption == 'All Time') {
      return {'startDate': null, 'endDate': null};
    }

    DateTime? start = _startDate;
    DateTime? end = _endDate;

    if (start == null || end == null || durationOption != 'Custom Range') {
      final now = DateTime.now();
      switch (durationOption) {
        case 'Today':
          start = DateTime(now.year, now.month, now.day);
          end = DateTime(now.year, now.month, now.day);
          break;
        case 'Yesterday':
          final y = now.subtract(const Duration(days: 1));
          start = DateTime(y.year, y.month, y.day);
          end = DateTime(y.year, y.month, y.day);
          break;
        case 'This Week':
          final sun = now.subtract(Duration(days: now.weekday % 7));
          start = DateTime(sun.year, sun.month, sun.day);
          end = DateTime(now.year, now.month, now.day);
          break;
        case 'Last Week':
          final sunThisWeek = now.subtract(Duration(days: now.weekday % 7));
          final sunLastWeek = sunThisWeek.subtract(const Duration(days: 7));
          final satLastWeek = sunThisWeek.subtract(const Duration(days: 1));
          start = DateTime(sunLastWeek.year, sunLastWeek.month, sunLastWeek.day);
          end = DateTime(satLastWeek.year, satLastWeek.month, satLastWeek.day);
          break;
        case 'This Month':
          start = DateTime(now.year, now.month, 1);
          end = DateTime(now.year, now.month, now.day);
          break;
        case 'Last Month':
          final firstOfThisMonth = DateTime(now.year, now.month, 1);
          final lastOfLastMonth = firstOfThisMonth.subtract(const Duration(days: 1));
          start = DateTime(lastOfLastMonth.year, lastOfLastMonth.month, 1);
          end = DateTime(lastOfLastMonth.year, lastOfLastMonth.month, lastOfLastMonth.day);
          break;
        case 'This Year':
          start = DateTime(now.year, 1, 1);
          end = DateTime(now.year, now.month, now.day);
          break;
      }
    }

    String? startStr = start != null
        ? "${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}"
        : null;
    String? endStr = end != null
        ? "${end.year.toString().padLeft(4, '0')}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}"
        : null;

    return {'startDate': startStr, 'endDate': endStr};
  }

  bool _isWithinDateRange(dynamic dateValue) {
    if (_selectedTimeRange == 'All Time') return true;
    if (dateValue == null) return false;

    DateTime? dt;
    if (dateValue is DateTime) {
      dt = dateValue;
    } else {
      final str = dateValue.toString().trim();
      if (str.isEmpty) return false;
      try {
        dt = DateTime.parse(str);
      } catch (_) {
        return true;
      }
    }

    final dateRange = _calculateDateRange(_selectedTimeRange);
    final startStr = dateRange['startDate'];
    final endStr = dateRange['endDate'];

    if (startStr != null) {
      final parts = startStr.split('-');
      if (parts.length == 3) {
        final startDt = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
          0,
          0,
          0,
          0,
        );
        if (dt.isBefore(startDt)) return false;
      }
    }
    if (endStr != null) {
      final parts = endStr.split('-');
      if (parts.length == 3) {
        final endDt = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
          23,
          59,
          59,
          999,
        );
        if (dt.isAfter(endDt)) return false;
      }
    }

    return true;
  }

  bool _isUserMatching(dynamic record) {
    if (_selectedUser == 'All Users') return true;
    if (record == null) return true;

    String? ownerId;
    if (_users.isNotEmpty) {
      final match = _users.firstWhere(
        (u) {
          final name = '${u['firstName'] ?? u['name'] ?? ''} ${u['lastName'] ?? ''}'.trim();
          return name == _selectedUser || u['id']?.toString() == _selectedUser;
        },
        orElse: () => {},
      );
      if (match.isNotEmpty) {
        ownerId = match['id']?.toString();
      }
    }
    if (ownerId == null || ownerId.isEmpty) return true;

    String? recOwner;
    if (record is ContactModel) {
      recOwner = record.ownerId;
    } else if (record is CompanyModel) {
      recOwner = record.ownerId;
    } else if (record is Map) {
      recOwner = (record['ownerId'] ??
              record['owner_id'] ??
              record['userId'] ??
              record['user_id'] ??
              record['createdBy'] ??
              record['created_by'])
          ?.toString();
    }
    if (recOwner == null || recOwner.isEmpty) return true;
    return recOwner.toString() == ownerId;
  }

  Future<void> _fetchTabSpecificData() async {
    setState(() => _isTabLoading = true);
    try {
      final api = ApiService();
      String? userId;
      if (_selectedUser != 'All Users' && _users.isNotEmpty) {
        final match = _users.firstWhere(
          (u) {
            final name = '${u['firstName'] ?? u['name'] ?? ''} ${u['lastName'] ?? ''}'.trim();
            return name == _selectedUser || u['id']?.toString() == _selectedUser;
          },
          orElse: () => {},
        );
        if (match.isNotEmpty) {
          userId = match['id']?.toString();
        }
      }

      final currentDeptId = context.read<DepartmentProvider>().selectedDepartmentId;
      final dateRange = _calculateDateRange(_selectedTimeRange);
      final queryParams = <String, dynamic>{
        'page': 1,
        'limit': 500,
        'range': _mapRangeToParam(_selectedTimeRange),
      };
      if (currentDeptId.isNotEmpty) {
        queryParams['departmentId'] = currentDeptId;
        queryParams['department_id'] = currentDeptId;
      }
      if (userId != null && userId.isNotEmpty) {
        queryParams['userId'] = userId;
        queryParams['user_id'] = userId;
        queryParams['ownerId'] = userId;
        queryParams['owner_id'] = userId;
      }
      if (dateRange['startDate'] != null) {
        queryParams['startDate'] = dateRange['startDate'];
        queryParams['start_date'] = dateRange['startDate'];
        queryParams['from_date'] = dateRange['startDate'];
        queryParams['created_at_gte'] = dateRange['startDate'];
      }
      if (dateRange['endDate'] != null) {
        queryParams['endDate'] = dateRange['endDate'];
        queryParams['end_date'] = dateRange['endDate'];
        queryParams['to_date'] = dateRange['endDate'];
        queryParams['created_at_lte'] = dateRange['endDate'];
      }

      // 1. Fetch Contacts
      try {
        Response resp;
        try {
          resp = await api.get(ApiConstants.reportsContacts, queryParameters: queryParams);
        } catch (_) {
          resp = await api.get('/contacts', queryParameters: queryParams);
        }
        final raw = resp.data;
        List<dynamic> list = [];
        if (raw is List) {
          list = raw;
        } else if (raw is Map<String, dynamic> && raw['data'] is List) {
          list = raw['data'] as List;
        } else if (raw is Map<String, dynamic> && raw['contacts'] is List) {
          list = raw['contacts'] as List;
        }
        _contactsList = list.whereType<Map<String, dynamic>>().map((e) => ContactModel.fromJson(e)).toList();
      } catch (e) {
        debugPrint('[ReportsScreen fetch contacts error]: $e');
      }

      // 2. Fetch Companies
      try {
        Response resp;
        try {
          resp = await api.get(ApiConstants.reportsCompanies, queryParameters: queryParams);
        } catch (_) {
          resp = await api.get('/companies', queryParameters: queryParams);
        }
        final raw = resp.data;
        List<dynamic> list = [];
        if (raw is List) {
          list = raw;
        } else if (raw is Map<String, dynamic> && raw['data'] is List) {
          list = raw['data'] as List;
        } else if (raw is Map<String, dynamic> && raw['companies'] is List) {
          list = raw['companies'] as List;
        }
        _companiesList = list.whereType<Map<String, dynamic>>().map((e) => CompanyModel.fromJson(e)).toList();
      } catch (e) {
        debugPrint('[ReportsScreen fetch companies error]: $e');
      }

      // 3. Fetch Deals
      try {
        Response resp;
        try {
          resp = await api.get(ApiConstants.reportsDeals, queryParameters: queryParams);
        } catch (_) {
          resp = await api.get('/deals', queryParameters: queryParams);
        }
        final raw = resp.data;
        List<dynamic> list = [];
        if (raw is List) {
          list = raw;
        } else if (raw is Map<String, dynamic> && raw['data'] is List) {
          list = raw['data'] as List;
        } else if (raw is Map<String, dynamic> && raw['deals'] is List) {
          list = raw['deals'] as List;
        }
        _dealsList = list.whereType<Map<String, dynamic>>().toList();
      } catch (e) {
        debugPrint('[ReportsScreen fetch deals error]: $e');
      }

      // 4. Fetch Activities
      try {
        Response resp;
        try {
          resp = await api.get(ApiConstants.reportsActivities, queryParameters: queryParams);
        } catch (_) {
          resp = await api.get('/activities', queryParameters: queryParams);
        }
        final raw = resp.data;
        List<dynamic> list = [];
        if (raw is List) {
          list = raw;
        } else if (raw is Map<String, dynamic> && raw['data'] is List) {
          list = raw['data'] as List;
        } else if (raw is Map<String, dynamic> && raw['activities'] is List) {
          list = raw['activities'] as List;
        }
        _activitiesList = list.whereType<Map<String, dynamic>>().toList();
      } catch (e) {
        debugPrint('[ReportsScreen fetch activities error]: $e');
      }
    } finally {
      if (mounted) setState(() => _isTabLoading = false);
    }
  }

  Future<void> _fetchUsers() async {
    try {
      Response resp;
      try {
        resp = await ApiService().get(ApiConstants.reportsUsers, queryParameters: {'page': 1, 'limit': 100});
      } catch (_) {
        resp = await ApiService().get('/users?limit=1000');
      }
      final dynamic raw = resp.data;
      List<Map<String, dynamic>> usersList = [];
      if (raw is List) {
        usersList = raw.whereType<Map<String, dynamic>>().toList();
      } else if (raw is Map<String, dynamic> && raw['data'] is List) {
        usersList = (raw['data'] as List).whereType<Map<String, dynamic>>().toList();
      } else if (raw is Map<String, dynamic> && raw['users'] is List) {
        usersList = (raw['users'] as List).whereType<Map<String, dynamic>>().toList();
      }

      if (mounted && usersList.isNotEmpty) {
        setState(() {
          _users = usersList;
        });
      }
    } catch (e) {
      debugPrint('[ReportsScreen fetch users error]: $e');
    }
  }

  Future<void> _fetchReportsData() async {
    setState(() => _isLoading = true);
    try {
      String? userId;
      if (_selectedUser != 'All Users' && _users.isNotEmpty) {
        final match = _users.firstWhere(
          (u) {
            final name = '${u['firstName'] ?? u['name'] ?? ''} ${u['lastName'] ?? ''}'.trim();
            return name == _selectedUser || u['id']?.toString() == _selectedUser;
          },
          orElse: () => {},
        );
        if (match.isNotEmpty) {
          userId = match['id']?.toString();
        }
      }

      final currentDeptId = context.read<DepartmentProvider>().selectedDepartmentId;
      final dateRange = _calculateDateRange(_selectedTimeRange);
      final queryParams = <String, dynamic>{
        'userId': (userId != null && userId.isNotEmpty) ? userId : 'all',
        'user_id': (userId != null && userId.isNotEmpty) ? userId : 'all',
        'range': _mapRangeToParam(_selectedTimeRange),
        'startDate': dateRange['startDate'] ?? '',
        'endDate': dateRange['endDate'] ?? '',
      };
      if (currentDeptId.isNotEmpty) {
        queryParams['departmentId'] = currentDeptId;
        queryParams['department_id'] = currentDeptId;
      }
      if (dateRange['startDate'] != null) {
        queryParams['start_date'] = dateRange['startDate'];
        queryParams['from_date'] = dateRange['startDate'];
        queryParams['created_at_gte'] = dateRange['startDate'];
      }
      if (dateRange['endDate'] != null) {
        queryParams['end_date'] = dateRange['endDate'];
        queryParams['to_date'] = dateRange['endDate'];
        queryParams['created_at_lte'] = dateRange['endDate'];
      }

      final api = ApiService();
      try {
        final resp = await api.get(ApiConstants.reportsDashboardAnalytics, queryParameters: queryParams);
        final raw = resp.data;
        if (mounted && raw != null) {
          final dataMap = raw is Map<String, dynamic>
              ? (raw['data'] is Map<String, dynamic> ? raw['data'] as Map<String, dynamic> : raw)
              : <String, dynamic>{};
          setState(() {
            _reportsAnalyticsData = Map<String, dynamic>.from(dataMap);
          });
        }
      } catch (e) {
        debugPrint('[GET ${ApiConstants.reportsDashboardAnalytics} error]: $e');
      }
    } catch (e) {
      debugPrint('[ReportsScreen fetch data error]: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    return '$day-$month-$year';
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && mounted) {
      if (isStart && _endDate != null && picked.isAfter(_endDate!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('From Date cannot be after To Date.')),
        );
        return;
      }
      if (!isStart && _startDate != null && picked.isBefore(_startDate!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('To Date cannot be before From Date.')),
        );
        return;
      }

      setState(() {
        _selectedTimeRange = 'Custom Range';
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
      _fetchReportsData();
      _fetchTabSpecificData();
      _refreshCurrentTabActivityIfNeeded();
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersDropdownList = <String>[
      'All Users',
      ..._users
          .map((u) => '${u['firstName'] ?? u['name'] ?? ''} ${u['lastName'] ?? ''}'.trim())
          .where((name) => name.isNotEmpty)
          .toSet(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: AppRefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              _fetchReportsData(),
              _fetchTabSpecificData(),
            ]);
            _refreshCurrentTabActivityIfNeeded();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Detailed Reports Title
                  Text(
                    'Detailed Reports',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2. Filter Controls Row: User, Time Range, Custom Date Range Pickers
                  Wrap(
                    spacing: 8,
                    runSpacing: 10,
                    children: [
                      // Users Filter Dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          value: usersDropdownList.contains(_selectedUser) ? _selectedUser : 'All Users',
                          underline: const SizedBox(),
                          isDense: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 18),
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedUser = val);
                              _fetchReportsData();
                              _fetchTabSpecificData();
                              _refreshCurrentTabActivityIfNeeded();
                            }
                          },
                          items: usersDropdownList
                              .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                              .toList(),
                        ),
                      ),

                      // Time Range Filter Dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          value: _durationOptions.contains(_selectedTimeRange) ? _selectedTimeRange : 'All Time',
                          underline: const SizedBox(),
                          isDense: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 18),
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                          onChanged: (val) {
                            if (val != null) {
                              _onDurationChanged(val);
                            }
                          },
                          items: _durationOptions
                              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                        ),
                      ),

                      // Start Date Picker (dd-mm-yyyy)
                      InkWell(
                        onTap: () => _selectDate(context, true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _startDate != null ? _formatDate(_startDate!) : 'dd-mm-yyyy',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: _startDate != null ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF64748B)),
                            ],
                          ),
                        ),
                      ),

                      // TO Divider
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          'TO',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ),

                      // End Date Picker (dd-mm-yyyy)
                      InkWell(
                        onTap: () => _selectDate(context, false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _endDate != null ? _formatDate(_endDate!) : 'dd-mm-yyyy',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: _endDate != null ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF64748B)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 3. Horizontal Tab Bar Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(_tabs.length, (index) {
                        final isSelected = _selectedTab == index;
                        return InkWell(
                          onTap: () => _handleTabTap(index),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFE6F4F1) : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: isSelected
                                  ? const Border(bottom: BorderSide(color: Color(0xFF00A884), width: 2.5))
                                  : null,
                            ),
                            child: Text(
                              _tabs[index],
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                color: isSelected ? const Color(0xFF00A884) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 18),

                  // 4. Tab Body Content
                  if (_isLoading || _isTabLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00A884)),
                        ),
                      ),
                    )
                  else if (_selectedTab == 0)
                    _buildDashboardGrid()
                  else if (_tabs[_selectedTab] == 'Contacts')
                    _buildContactsList()
                  else if (_tabs[_selectedTab] == 'Companies')
                    _buildCompaniesList()
                  else if (_tabs[_selectedTab] == 'Deals')
                    _buildDealsList()
                  else if (_tabs[_selectedTab] == 'Company-Wise')
                    _buildCompanyWiseList()
                  else
                    _buildActivitiesListForTab(_tabs[_selectedTab]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Dashboard Summary Grid Metrics Cards
  Widget _buildDashboardGrid() {
    final filteredContacts = _contactsList.where((c) => _isWithinDateRange(c.createdAt) && _isUserMatching(c)).toList();
    final filteredCompanies = _companiesList.where((comp) => _isWithinDateRange(comp.createdAt) && _isUserMatching(comp)).toList();
    final filteredDeals = _dealsList.where((d) => _isWithinDateRange(d['createdAt'] ?? d['created_at']) && _isUserMatching(d)).toList();
    final filteredActivities = _activitiesList.where((a) => _isWithinDateRange(a['createdAt'] ?? a['created_at'] ?? a['dueDate'] ?? a['scheduledAt']) && _isUserMatching(a)).toList();

    final filteredTasks = filteredActivities.where((a) => (a['type'] ?? a['activityType'] ?? '').toString().toLowerCase().contains('task')).toList();
    final filteredMeetings = filteredActivities.where((a) => (a['type'] ?? a['activityType'] ?? '').toString().toLowerCase().contains('meeting')).toList();
    final filteredCalls = filteredActivities.where((a) => (a['type'] ?? a['activityType'] ?? '').toString().toLowerCase().contains('call')).toList();
    final filteredEmails = filteredActivities.where((a) => (a['type'] ?? a['activityType'] ?? '').toString().toLowerCase().contains('email')).toList();
    final filteredNotes = filteredActivities.where((a) => (a['type'] ?? a['activityType'] ?? '').toString().toLowerCase().contains('note')).toList();

    final map = _reportsAnalyticsData ?? {};

    int parseVal(String key, int fallback) {
      final v = map[key] ?? map['${key}Count'] ?? map['total${key.substring(0, 1).toUpperCase()}${key.substring(1)}'];
      if (v != null) {
        return int.tryParse(v.toString()) ?? fallback;
      }
      return fallback;
    }

    final contactsCount = parseVal('contacts', filteredContacts.length);
    final companiesCount = parseVal('companies', filteredCompanies.length);
    final dealsCount = parseVal('deals', filteredDeals.length);
    final tasksCompletedCount = parseVal('tasks', filteredTasks.length);
    final meetingsHeldCount = parseVal('meetings', filteredMeetings.length);
    final callsMadeCount = parseVal('calls', filteredCalls.length);
    final emailsSentCount = parseVal('emails', filteredEmails.length);
    final notesCreatedCount = parseVal('notes', filteredNotes.length);

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // 1. CONTACTS ADDED -> Contacts
        _buildMetricCard(
          icon: Icons.people_outline_rounded,
          iconBg: const Color(0xFFEFF6FF),
          iconColor: const Color(0xFF3B82F6),
          title: 'CONTACTS ADDED',
          count: contactsCount,
          onTap: () => _selectTabByName('Contacts'),
        ),

        // 2. COMPANIES ADDED -> Companies
        _buildMetricCard(
          icon: Icons.business_outlined,
          iconBg: const Color(0xFFEEF2FF),
          iconColor: const Color(0xFF6366F1),
          title: 'COMPANIES ADDED',
          count: companiesCount,
          onTap: () => _selectTabByName('Companies'),
        ),

        // 3. DEALS ADDED -> Deals
        _buildMetricCard(
          icon: Icons.trending_up_rounded,
          iconBg: const Color(0xFFECFDF5),
          iconColor: const Color(0xFF10B981),
          title: 'DEALS ADDED',
          count: dealsCount,
          onTap: () => _selectTabByName('Deals'),
        ),

        // 4. TASKS COMPLETED -> Tasks
        _buildMetricCard(
          icon: Icons.check_box_outlined,
          iconBg: const Color(0xFFF0FDF4),
          iconColor: const Color(0xFF22C55E),
          title: 'TASKS COMPLETED',
          count: tasksCompletedCount,
          onTap: () => _selectTabByName('Tasks'),
        ),

        // 5. MEETINGS HELD -> Meetings
        _buildMetricCard(
          icon: Icons.calendar_today_outlined,
          iconBg: const Color(0xFFFFF1F2),
          iconColor: const Color(0xFFF43F5E),
          title: 'MEETINGS HELD',
          count: meetingsHeldCount,
          onTap: () => _selectTabByName('Meetings'),
        ),

        // 6. CALLS MADE -> Calls
        _buildMetricCard(
          icon: Icons.phone_in_talk_outlined,
          iconBg: const Color(0xFFF0FDFA),
          iconColor: const Color(0xFF14B8A6),
          title: 'CALLS MADE',
          count: callsMadeCount,
          onTap: () => _selectTabByName('Calls'),
        ),

        // 7. EMAILS SENT -> Emails
        _buildMetricCard(
          icon: Icons.email_outlined,
          iconBg: const Color(0xFFFDF4FF),
          iconColor: const Color(0xFFD946EF),
          title: 'EMAILS SENT',
          count: emailsSentCount,
          onTap: () => _selectTabByName('Emails'),
        ),

        // 8. NOTES CREATED -> Notes
        _buildMetricCard(
          icon: Icons.description_outlined,
          iconBg: const Color(0xFFFEFCE8),
          iconColor: const Color(0xFFEAB308),
          title: 'NOTES CREATED',
          count: notesCreatedCount,
          onTap: () => _selectTabByName('Notes'),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required int count,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF64748B),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    count.toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// TAB 1: CONTACTS LIST VIEW
  Widget _buildContactsList() {
    final filtered = _contactsList.where((c) => _isWithinDateRange(c.createdAt) && _isUserMatching(c)).toList();
    if (filtered.isEmpty) return _buildEmptyTabState('No contacts found');

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final c = filtered[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.name,
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
              ),
              const SizedBox(height: 6),
              _buildReportDetailRow('LAST NAME', c.lastName ?? '--'),
              _buildReportDetailRow('EMAIL', c.email.isNotEmpty ? c.email : '--'),
              _buildReportDetailRow('PHONE', c.phone ?? '--'),
              _buildReportDetailRow('JOB TITLE', c.jobTitle ?? '--'),
              _buildReportDetailRow('LIFECYCLE STAGE', c.lifecycleStage ?? 'Added'),
              _buildReportDetailRow('LEAD STATUS', c.leadStatus ?? '--'),
              _buildReportDetailRow('OWNER NAME', c.ownerName ?? 'Admin User'),
              _buildReportDetailRow('COMPANY NAME', c.companyName ?? '--'),
            ],
          ),
        );
      },
    );
  }

  /// TAB 2: COMPANIES LIST VIEW
  Widget _buildCompaniesList() {
    final filtered = _companiesList.where((comp) => _isWithinDateRange(comp.createdAt) && _isUserMatching(comp)).toList();
    if (filtered.isEmpty) return _buildEmptyTabState('No companies found');

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final comp = filtered[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                comp.name,
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
              ),
              const SizedBox(height: 6),
              _buildReportDetailRow('DOMAIN', comp.domain ?? '--'),
              _buildReportDetailRow('INDUSTRY', comp.industryName ?? '--'),
              _buildReportDetailRow('CITY', comp.city ?? '--'),
              _buildReportDetailRow('STATE', comp.state ?? '--'),
              _buildReportDetailRow('COUNTRY', comp.country ?? '--'),
              _buildReportDetailRow('EMPLOYEE COUNT', comp.companySize ?? '--'),
              _buildReportDetailRow('ANNUAL REVENUE', comp.annualRevenue != null ? '\$${comp.annualRevenue}' : '--'),
              _buildReportDetailRow('CREATED AT', comp.createdAt ?? 'Recently'),
              _buildReportDetailRow('OWNER NAME', 'Admin User'),
            ],
          ),
        );
      },
    );
  }



  /// TAB 4: DEALS LIST VIEW
  Widget _buildDealsList() {
    final filtered = _dealsList.where((d) => _isWithinDateRange(d['createdAt'] ?? d['created_at']) && _isUserMatching(d)).toList();
    if (filtered.isEmpty) return _buildEmptyTabState('No deals found');

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final d = filtered[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (d['title'] ?? d['name'] ?? 'Deal').toString(),
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
              ),
              const SizedBox(height: 6),
              _buildReportDetailRow('STAGE', d['stage']?.toString() ?? 'Qualification'),
              _buildReportDetailRow('VALUE', d['value'] != null ? '\$${d['value']}' : '--'),
              _buildReportDetailRow('COMPANY', d['companyName']?.toString() ?? '--'),
              _buildReportDetailRow('CONTACT', d['contactName']?.toString() ?? '--'),
              _buildReportDetailRow('OWNER', d['ownerName']?.toString() ?? 'Admin User'),
            ],
          ),
        );
      },
    );
  }

  /// TABS 5 to 10: ACTIVITIES LIST VIEW (Tasks, Meetings, Calls, Emails, Notes, Email Engagement)
  Widget _buildActivitiesListForTab(String tabName) {
    final type = _mapTabToType(tabName);

    if (type != null) {
      final isLoading = _isLoadingActivitiesByType[type] ?? false;
      final error = _errorActivitiesByType[type];
      final items = _activitiesByType[type] ?? [];
      final meta = _activitiesMetaByType[type] ?? {};
      final total = meta['total'] ?? items.length;

      if (isLoading && items.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00A884)),
            ),
          ),
        );
      }

      if (error != null && items.isEmpty) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          alignment: Alignment.center,
          child: Column(
            children: [
              const Icon(Icons.error_outline_rounded, size: 36, color: Color(0xFFEF4444)),
              const SizedBox(height: 10),
              Text(
                'Failed to load $tabName details.',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
              ),
              const SizedBox(height: 6),
              Text(
                error,
                style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () => _fetchActivitiesForType(type),
                icon: const Icon(Icons.refresh, size: 16),
                label: Text('Retry', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A884),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        );
      }

      if (items.isEmpty) {
        return _buildEmptyTabState('No $tabName records found');
      }

      final canLoadMore = items.length < total;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$tabName Records ($total)',
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF334155)),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00A884)),
                  ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final act = items[index];
              return _buildActivityCardForType(act, type);
            },
          ),
          if (canLoadMore) ...[
            const SizedBox(height: 16),
            Center(
              child: OutlinedButton.icon(
                onPressed: isLoading ? null : () => _fetchActivitiesForType(type, isLoadMore: true),
                icon: isLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00A884)),
                      )
                    : const Icon(Icons.expand_more, size: 18),
                label: Text(
                  isLoading ? 'Loading...' : 'Load More (${items.length}/$total)',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF00A884)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF00A884)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ],
      );
    }

    return _buildEmptyTabState('No $tabName records found');
  }

  Widget _buildActivityCardForType(Map<String, dynamic> act, String type) {
    final normType = type.toLowerCase();
    if (normType == 'note') return _buildNoteCard(act);
    if (normType == 'call') return _buildCallCard(act);
    if (normType == 'email') return _buildEmailCard(act);
    if (normType == 'meeting') return _buildMeetingCard(act);
    return _buildCallCard(act);
  }

  Widget _buildNoteCard(Map<String, dynamic> act) {
    final title = _valOrDash(act['title'] ?? act['subject']);
    final author = _valOrDash(act['author'] ?? act['assignedTo'] ?? act['sentBy'] ?? act['ownerName']);
    final date = _formatDateString(act['date'] ?? act['createdAt']);
    final contact = _valOrDash(act['associatedContact'] ?? act['contactName'] ?? act['contact']);
    final company = _valOrDash(act['associatedCompany'] ?? act['companyName'] ?? act['company']);
    final deal = _valOrDash(act['associatedDeal'] ?? act['dealName'] ?? act['deal']);
    final description = act['description']?.toString().trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEFCE8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.description_outlined, size: 18, color: Color(0xFFEAB308)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title != '-' ? title : 'Note Details',
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          _buildReportDetailRow('AUTHOR', author),
          _buildReportDetailRow('DATE', date),
          _buildReportDetailRow('CONTACT', contact),
          _buildReportDetailRow('COMPANY', company),
          _buildReportDetailRow('DEAL', deal),
          if (description != null && description.isNotEmpty && description != 'null') ...[
            const SizedBox(height: 4),
            _buildReportDetailRow('DESCRIPTION', description),
          ],
        ],
      ),
    );
  }

  Widget _buildCallCard(Map<String, dynamic> act) {
    final subject = _valOrDash(act['subject'] ?? act['title']);
    final activityType = _valOrDash(act['activityType'] ?? act['type']);
    final status = _valOrDash(act['status']);
    final priority = _valOrDash(act['priority']);
    final outcome = _valOrDash(act['outcome']);
    final duration = act['duration'] != null ? '${act['duration']} min' : '-';
    final dueDate = _formatDateString(act['dueDate']);
    final completedAt = _formatDateString(act['completedAt']);
    final createdAt = _formatDateString(act['createdAt'] ?? act['date']);
    final assignedTo = _valOrDash(act['assignedTo'] ?? act['author'] ?? act['ownerName']);
    final contact = _valOrDash(act['associatedContact'] ?? act['contactName'] ?? act['contact']);
    final company = _valOrDash(act['associatedCompany'] ?? act['companyName'] ?? act['company']);
    final deal = _valOrDash(act['associatedDeal'] ?? act['dealName'] ?? act['deal']);
    final description = act['description']?.toString().trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.phone_in_talk_outlined, size: 18, color: Color(0xFF14B8A6)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  subject != '-' ? subject : 'Call Details',
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          _buildReportDetailRow('ACTIVITY TYPE', activityType),
          _buildReportDetailRow('STATUS', status),
          _buildReportDetailRow('PRIORITY', priority),
          _buildReportDetailRow('OUTCOME', outcome),
          _buildReportDetailRow('DURATION', duration),
          _buildReportDetailRow('ASSIGNED TO', assignedTo),
          _buildReportDetailRow('CONTACT', contact),
          _buildReportDetailRow('COMPANY', company),
          _buildReportDetailRow('DEAL', deal),
          _buildReportDetailRow('DUE DATE', dueDate),
          _buildReportDetailRow('COMPLETED AT', completedAt),
          _buildReportDetailRow('CREATED AT', createdAt),
          if (description != null && description.isNotEmpty && description != 'null') ...[
            const SizedBox(height: 4),
            _buildReportDetailRow('DESCRIPTION', description),
          ],
        ],
      ),
    );
  }

  Widget _buildEmailCard(Map<String, dynamic> act) {
    final subject = _valOrDash(act['subject'] ?? act['title']);
    final sentBy = _valOrDash(act['sentBy'] ?? act['author'] ?? act['assignedTo'] ?? act['ownerName']);
    final sentDate = _formatDateString(act['sentDate'] ?? act['date'] ?? act['createdAt']);
    final contact = _valOrDash(act['associatedContact'] ?? act['contactName'] ?? act['contact']);
    final company = _valOrDash(act['associatedCompany'] ?? act['companyName'] ?? act['company']);
    final deal = _valOrDash(act['associatedDeal'] ?? act['dealName'] ?? act['deal']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF4FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.email_outlined, size: 18, color: Color(0xFFD946EF)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  subject != '-' ? subject : 'Email Details',
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          _buildReportDetailRow('SENT BY', sentBy),
          _buildReportDetailRow('SENT DATE', sentDate),
          _buildReportDetailRow('CONTACT', contact),
          _buildReportDetailRow('COMPANY', company),
          _buildReportDetailRow('DEAL', deal),
        ],
      ),
    );
  }

  Widget _buildMeetingCard(Map<String, dynamic> act) {
    final subject = _valOrDash(act['subject'] ?? act['title']);
    final activityType = _valOrDash(act['activityType'] ?? act['type']);
    final status = _valOrDash(act['status']);
    final priority = _valOrDash(act['priority']);
    final outcome = _valOrDash(act['outcome']);
    final duration = act['duration'] != null ? '${act['duration']} min' : '-';
    final dueDate = _formatDateString(act['dueDate']);
    final completedAt = _formatDateString(act['completedAt']);
    final createdAt = _formatDateString(act['createdAt'] ?? act['date']);
    final assignedTo = _valOrDash(act['assignedTo'] ?? act['author'] ?? act['ownerName']);
    final contact = _valOrDash(act['associatedContact'] ?? act['contactName'] ?? act['contact']);
    final company = _valOrDash(act['associatedCompany'] ?? act['companyName'] ?? act['company']);
    final deal = _valOrDash(act['associatedDeal'] ?? act['dealName'] ?? act['deal']);
    final description = act['description']?.toString().trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFFF43F5E)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  subject != '-' ? subject : 'Meeting Details',
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          _buildReportDetailRow('ACTIVITY TYPE', activityType),
          _buildReportDetailRow('STATUS', status),
          _buildReportDetailRow('PRIORITY', priority),
          _buildReportDetailRow('OUTCOME', outcome),
          _buildReportDetailRow('DURATION', duration),
          _buildReportDetailRow('ASSIGNED TO', assignedTo),
          _buildReportDetailRow('CONTACT', contact),
          _buildReportDetailRow('COMPANY', company),
          _buildReportDetailRow('DEAL', deal),
          _buildReportDetailRow('DUE DATE', dueDate),
          _buildReportDetailRow('COMPLETED AT', completedAt),
          _buildReportDetailRow('CREATED AT', createdAt),
          if (description != null && description.isNotEmpty && description != 'null') ...[
            const SizedBox(height: 4),
            _buildReportDetailRow('DESCRIPTION', description),
          ],
        ],
      ),
    );
  }

  /// TAB 11: COMPANY-WISE LIST VIEW
  Widget _buildCompanyWiseList() {
    final filtered = _companiesList.where((comp) => _isWithinDateRange(comp.createdAt) && _isUserMatching(comp)).toList();
    if (filtered.isEmpty) return _buildEmptyTabState('No company-wise records found');

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final comp = filtered[index];
        final compContacts = _contactsList.where((c) => c.companyId == comp.id || c.companyName == comp.name).length;
        final compDeals = _dealsList.where((d) => d['companyId'] == comp.id || d['company_id'] == comp.id || d['companyName'] == comp.name).length;
        final compActivities = _activitiesList.where((a) => a['companyId'] == comp.id || a['company_id'] == comp.id || a['companyName'] == comp.name).length;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                comp.name,
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
              ),
              const SizedBox(height: 6),
              _buildReportDetailRow('DOMAIN', comp.domain ?? '--'),
              _buildReportDetailRow('INDUSTRY', comp.industryName ?? '--'),
              _buildReportDetailRow('TOTAL CONTACTS', '$compContacts'),
              _buildReportDetailRow('TOTAL DEALS', '$compDeals'),
              _buildReportDetailRow('TOTAL ACTIVITIES', '$compActivities'),
              _buildReportDetailRow('CREATED AT', comp.createdAt ?? 'Recently'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReportDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF94A3B8),
                letterSpacing: 0.3,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTabState(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 36, color: Color(0xFF94A3B8)),
          const SizedBox(height: 10),
          Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
