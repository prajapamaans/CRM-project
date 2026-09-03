import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../companies/data/models/company_model.dart';
import '../../../contacts/data/models/contact_model.dart';
import '../../../dashboard/data/datasource/remote/dashboard_remote_datasource.dart';
import '../../../dashboard/data/models/activity_stats_model.dart';
import '../../../departments/presentation/providers/department_provider.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _selectedTab = 0; // 0: Dashboard, 1: Contacts, 2: Companies, 3: Users, 4: Deals, 5: Tasks, 6: Meetings, 7: Calls, 8: Emails, 9: Notes, 10: Email Engagement

  final List<String> _tabs = [
    'Dashboard',
    'Contacts',
    'Companies',
    'Users',
    'Deals',
    'Tasks',
    'Meetings',
    'Calls',
    'Emails',
    'Notes',
    'Email Engagement'
  ];

  void _handleTabTap(int index) {
    setState(() => _selectedTab = index);
  }

  List<Map<String, dynamic>> _users = [];
  String _selectedUser = 'All Users';
  String _selectedTimeRange = 'All Time';
  DateTime? _startDate;
  DateTime? _endDate;

  bool _isLoading = false;
  ActivityStatsModel? _stats;
  Map<String, dynamic>? _reportsAnalyticsData;

  List<ContactModel> _contactsList = [];
  List<CompanyModel> _companiesList = [];
  List<Map<String, dynamic>> _dealsList = [];
  List<Map<String, dynamic>> _activitiesList = [];

  bool _isTabLoading = false;
  String? _lastDepartmentId;

  String _mapRangeToParam(String durationOption) {
    switch (durationOption) {
      case 'Today': return 'today';
      case 'Yesterday': return 'yesterday';
      case 'This Week': return 'this_week';
      case 'Last Week': return 'last_week';
      case 'This Month': return 'this_month';
      case 'Last Month': return 'last_month';
      case 'This Year': return 'this_year';
      case 'All Time': return 'all_time';
      case 'Custom Range': return 'custom';
      default: return 'all_time';
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
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _fetchReportsData();
    _fetchTabSpecificData();
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
  }

  Map<String, String?> _calculateDateRange(String durationOption) {
    if (durationOption == 'All Time') {
      return {'startDate': null, 'endDate': null};
    }

    DateTime? start = _startDate;
    DateTime? end = _endDate;

    if (start == null || end == null) {
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
        return true; // Keep if unparseable string
      }
    }

    final dateRange = _calculateDateRange(_selectedTimeRange);
    final startStr = dateRange['startDate'];
    final endStr = dateRange['endDate'];

    if (startStr != null) {
      final startDt = DateTime.parse(startStr);
      if (dt.isBefore(startDt)) return false;
    }
    if (endStr != null) {
      final endParts = endStr.split('-');
      if (endParts.length == 3) {
        final endDt = DateTime(
          int.parse(endParts[0]),
          int.parse(endParts[1]),
          int.parse(endParts[2]),
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

    final recOwner = record is ContactModel
        ? record.ownerId
        : record is CompanyModel
            ? record.ownerId
            : (record is Map ? (record['ownerId'] ?? record['owner_id'] ?? record['userId'] ?? record['createdBy']) : null);
    if (recOwner == null) return true;
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

      final dateRange = _calculateDateRange(_selectedTimeRange);
      final queryParams = <String, dynamic>{
        'page': 1,
        'limit': 100,
        'range': _mapRangeToParam(_selectedTimeRange),
      };
      if (userId != null && userId.isNotEmpty) queryParams['userId'] = userId;
      if (dateRange['startDate'] != null) queryParams['startDate'] = dateRange['startDate'];
      if (dateRange['endDate'] != null) queryParams['endDate'] = dateRange['endDate'];
      
      // 1. Fetch Contacts (GET /api/reports/contacts)
      try {
        Response resp;
        try {
          resp = await api.get(ApiConstants.reportsContacts, queryParameters: queryParams);
        } catch (_) {
          resp = await api.get('/contacts', queryParameters: {...queryParams, 'range': 'all'});
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

      // 2. Fetch Companies (GET /api/reports/companies)
      try {
        Response resp;
        try {
          resp = await api.get(ApiConstants.reportsCompanies, queryParameters: queryParams);
        } catch (_) {
          resp = await api.get('/companies', queryParameters: {...queryParams, 'range': 'all'});
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

      // 3. Fetch Deals (GET /api/reports/deals)
      try {
        Response resp;
        try {
          resp = await api.get(ApiConstants.reportsDeals, queryParameters: queryParams);
        } catch (_) {
          resp = await api.get('/deals', queryParameters: {...queryParams, 'page': 1, 'limit': 50});
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

      // 4. Fetch Activities (GET /api/reports/activities)
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

      final dateRange = _calculateDateRange(_selectedTimeRange);
      final queryParams = <String, dynamic>{
        'range': _mapRangeToParam(_selectedTimeRange),
      };
      if (userId != null && userId.isNotEmpty) queryParams['userId'] = userId;
      if (dateRange['startDate'] != null) queryParams['startDate'] = dateRange['startDate'];
      if (dateRange['endDate'] != null) queryParams['endDate'] = dateRange['endDate'];

      final api = ApiService();
      try {
        final resp = await api.get(ApiConstants.reportsDashboardAnalytics, queryParameters: queryParams);
        final raw = resp.data;
        if (mounted && raw is Map<String, dynamic>) {
          setState(() {
            _reportsAnalyticsData = raw;
          });
        }
      } catch (e) {
        debugPrint('[GET ${ApiConstants.reportsDashboardAnalytics} fallback]: $e');
        final ds = DashboardRemoteDataSourceImpl();
        final statsResult = await ds.getActivityStats(
          ownerId: userId,
          startDate: dateRange['startDate'],
          endDate: dateRange['endDate'],
        );
        if (mounted) {
          setState(() {
            _stats = statsResult;
          });
        }
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
                  color: Colors.black.withOpacity(0.03),
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
                              _startDate != null
                                  ? _formatDate(_startDate!)
                                  : 'dd-mm-yyyy',
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
                              _endDate != null
                                  ? _formatDate(_endDate!)
                                  : 'dd-mm-yyyy',
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

                // 3. Tab Bar Row (Image 1 & 2): Dashboard, Contacts, Companies, Users, Deals, Tasks, Meetings, Calls, Emails, Notes, Email Engagement
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

                // 4. Tab Body View
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
                else if (_selectedTab == 1)
                  _buildContactsList()
                else if (_selectedTab == 2)
                  _buildCompaniesList()
                else if (_selectedTab == 3)
                  _buildUsersList()
                else if (_selectedTab == 4)
                  _buildDealsList()
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

  /// Grid view corresponding to Image 1: Detailed Reports Metrics Cards
  Widget _buildDashboardGrid() {
    final filteredContacts = _contactsList.where((c) => _isWithinDateRange(c.createdAt) && _isUserMatching(c)).toList();
    final filteredCompanies = _companiesList.where((comp) => _isWithinDateRange(comp.createdAt) && _isUserMatching(comp)).toList();
    final filteredDeals = _dealsList.where((d) => _isWithinDateRange(d['createdAt'] ?? d['created_at']) && _isUserMatching(d)).toList();
    final filteredActivities = _activitiesList.where((a) => _isWithinDateRange(a['createdAt'] ?? a['created_at'] ?? a['dueDate']) && _isUserMatching(a)).toList();

    final map = _reportsAnalyticsData ?? {};
    final rawData = map['data'] is Map<String, dynamic> ? map['data'] as Map<String, dynamic> : map;

    final contactsCount = rawData['totalContacts'] ?? rawData['contactsCount'] ?? rawData['contacts'] ?? _stats?.totalContacts ?? filteredContacts.length;
    final companiesCount = rawData['totalCompanies'] ?? rawData['companiesCount'] ?? rawData['companies'] ?? _stats?.totalCompanies ?? filteredCompanies.length;
    final dealsCount = rawData['totalDeals'] ?? rawData['dealsCount'] ?? rawData['deals'] ?? _stats?.totalDeals ?? filteredDeals.length;
    final tasksCompletedCount = rawData['completedTasks'] ?? rawData['tasksCompleted'] ?? rawData['completed'] ?? rawData['tasks'] ?? _stats?.completed ?? filteredActivities.where((a) => (a['type'] ?? '').toString().toLowerCase().contains('task')).length;
    final emailsSentCount = rawData['emailsSent'] ?? rawData['emails'] ?? _stats?.emails ?? filteredActivities.where((a) => (a['type'] ?? '').toString().toLowerCase().contains('email')).length;
    final meetingsHeldCount = rawData['meetingsHeld'] ?? rawData['meetings'] ?? _stats?.meetings ?? filteredActivities.where((a) => (a['type'] ?? '').toString().toLowerCase().contains('meeting')).length;
    final callsMadeCount = rawData['callsMade'] ?? rawData['calls'] ?? _stats?.calls ?? filteredActivities.where((a) => (a['type'] ?? '').toString().toLowerCase().contains('call')).length;
    final notesCreatedCount = rawData['notesCreated'] ?? rawData['notes'] ?? _stats?.notes ?? filteredActivities.where((a) => (a['type'] ?? '').toString().toLowerCase().contains('note')).length;

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // 1. CONTACTS ADDED -> Tab 1 (Contacts)
        _buildMetricCard(
          icon: Icons.people_outline_rounded,
          iconBg: const Color(0xFFEFF6FF),
          iconColor: const Color(0xFF3B82F6),
          title: 'CONTACTS ADDED',
          count: contactsCount,
          onTap: () => setState(() => _selectedTab = 1),
        ),

        // 2. COMPANIES ADDED -> Tab 2 (Companies)
        _buildMetricCard(
          icon: Icons.business_outlined,
          iconBg: const Color(0xFFEEF2FF),
          iconColor: const Color(0xFF6366F1),
          title: 'COMPANIES ADDED',
          count: companiesCount,
          onTap: () => setState(() => _selectedTab = 2),
        ),

        // 3. DEALS ADDED -> Tab 4 (Deals)
        _buildMetricCard(
          icon: Icons.trending_up_rounded,
          iconBg: const Color(0xFFECFDF5),
          iconColor: const Color(0xFF10B981),
          title: 'DEALS ADDED',
          count: dealsCount,
          onTap: () => setState(() => _selectedTab = 4),
        ),

        // 4. TASKS COMPLETED -> Tab 5 (Tasks)
        _buildMetricCard(
          icon: Icons.check_box_outlined,
          iconBg: const Color(0xFFF0FDF4),
          iconColor: const Color(0xFF22C55E),
          title: 'TASKS COMPLETED',
          count: tasksCompletedCount,
          onTap: () => setState(() => _selectedTab = 5),
        ),

        // 5. EMAILS SENT -> Tab 8 (Emails)
        _buildMetricCard(
          icon: Icons.email_outlined,
          iconBg: const Color(0xFFFDF4FF),
          iconColor: const Color(0xFFD946EF),
          title: 'EMAILS SENT',
          count: emailsSentCount,
          onTap: () => setState(() => _selectedTab = 8),
        ),

        // 6. MEETINGS HELD -> Tab 6 (Meetings)
        _buildMetricCard(
          icon: Icons.calendar_today_outlined,
          iconBg: const Color(0xFFFFF1F2),
          iconColor: const Color(0xFFF43F5E),
          title: 'MEETINGS HELD',
          count: meetingsHeldCount,
          onTap: () => setState(() => _selectedTab = 6),
        ),

        // 7. CALLS MADE -> Tab 7 (Calls)
        _buildMetricCard(
          icon: Icons.phone_in_talk_outlined,
          iconBg: const Color(0xFFF0FDFA),
          iconColor: const Color(0xFF14B8A6),
          title: 'CALLS MADE',
          count: callsMadeCount,
          onTap: () => setState(() => _selectedTab = 7),
        ),

        // 8. NOTES CREATED -> Tab 9 (Notes)
        _buildMetricCard(
          icon: Icons.description_outlined,
          iconBg: const Color(0xFFFEFCE8),
          iconColor: const Color(0xFFEAB308),
          title: 'NOTES CREATED',
          count: notesCreatedCount,
          onTap: () => setState(() => _selectedTab = 9),
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
              color: Colors.black.withOpacity(0.02),
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

  /// --------------------------------------------------------------------------
  /// TAB 1: CONTACTS LIST VIEW
  /// --------------------------------------------------------------------------
  Widget _buildContactsList() {
    final filtered = _contactsList.where((c) => _isWithinDateRange(c.createdAt) && _isUserMatching(c)).toList();
    if (filtered.isEmpty) return _buildEmptyTabState('No contacts found');

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
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

  /// --------------------------------------------------------------------------
  /// TAB 2: COMPANIES LIST VIEW
  /// --------------------------------------------------------------------------
  Widget _buildCompaniesList() {
    final filtered = _companiesList.where((comp) => _isWithinDateRange(comp.createdAt) && _isUserMatching(comp)).toList();
    if (filtered.isEmpty) return _buildEmptyTabState('No companies found');

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
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

  /// --------------------------------------------------------------------------
  /// TAB 3: USERS LIST VIEW
  /// --------------------------------------------------------------------------
  Widget _buildUsersList() {
    if (_users.isEmpty) return _buildEmptyTabState('No users found');

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final u = _users[index];
        final name = '${u['firstName'] ?? u['name'] ?? ''} ${u['lastName'] ?? ''}'.trim();
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
                name.isNotEmpty ? name : 'User',
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
              ),
              const SizedBox(height: 6),
              _buildReportDetailRow('EMAIL', u['email']?.toString() ?? '--'),
              _buildReportDetailRow('ROLE', u['role']?.toString() ?? 'Member'),
              _buildReportDetailRow('DEPARTMENT', u['department']?.toString() ?? 'Sales'),
            ],
          ),
        );
      },
    );
  }

  /// --------------------------------------------------------------------------
  /// TAB 4: DEALS LIST VIEW
  /// --------------------------------------------------------------------------
  Widget _buildDealsList() {
    final filtered = _dealsList.where((d) => _isWithinDateRange(d['createdAt'] ?? d['created_at']) && _isUserMatching(d)).toList();
    if (filtered.isEmpty) return _buildEmptyTabState('No deals found');

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
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

  /// --------------------------------------------------------------------------
  /// TABS 5+: ACTIVITIES LIST VIEW (Tasks, Meetings, Calls, Emails, Notes, Engagement)
  /// --------------------------------------------------------------------------
  Widget _buildActivitiesListForTab(String tabName) {
    final filtered = _activitiesList.where((a) {
      if (!_isWithinDateRange(a['createdAt'] ?? a['created_at'] ?? a['dueDate'])) return false;
      if (!_isUserMatching(a)) return false;
      final type = (a['type'] ?? a['activityType'] ?? '').toString().toLowerCase();
      if (tabName == 'Tasks') return type.contains('task');
      if (tabName == 'Meetings') return type.contains('meeting');
      if (tabName == 'Calls') return type.contains('call');
      if (tabName == 'Emails' || tabName == 'Email Engagement') return type.contains('email');
      if (tabName == 'Notes') return type.contains('note');
      return true;
    }).toList();

    if (filtered.isEmpty) return _buildEmptyTabState('No $tabName records found');

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final act = filtered[index];
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
                (act['title'] ?? act['subject'] ?? tabName).toString(),
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
              ),
              const SizedBox(height: 6),
              _buildReportDetailRow('TYPE', (act['type'] ?? tabName).toString()),
              _buildReportDetailRow('STATUS', (act['status'] ?? 'Completed').toString()),
              _buildReportDetailRow('CONTACT', (act['contactName'] ?? act['contact'] ?? '--').toString()),
              _buildReportDetailRow('COMPANY', (act['companyName'] ?? act['company'] ?? '--').toString()),
              _buildReportDetailRow('DUE DATE', (act['dueDate'] ?? act['createdAt'] ?? 'Recently').toString()),
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
