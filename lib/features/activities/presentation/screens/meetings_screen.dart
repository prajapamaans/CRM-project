import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:crmproject/core/widgets/app_refresh_indicator.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/providers/master_data_provider.dart';
import '../../../../core/repositories/master_data_repository.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../companies/data/models/company_model.dart';
import '../../../companies/presentation/providers/company_provider.dart';
import '../../../companies/presentation/screens/company_details_screen.dart';
import '../../../contacts/data/models/contact_model.dart';
import '../../../contacts/presentation/providers/contact_provider.dart';
import '../../../contacts/presentation/screens/contact_details_screen.dart';
import '../../../deals/data/models/deal_model.dart';
import '../../../deals/presentation/providers/deal_provider.dart';
import '../../../deals/presentation/screens/deal_details_screen.dart';
import '../../../departments/presentation/providers/department_provider.dart';
import '../widgets/log_meeting_modal.dart';
import 'meeting_details_screen.dart';

class MeetingsScreen extends StatefulWidget {
  const MeetingsScreen({super.key});

  @override
  State<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends State<MeetingsScreen> {
  int _selectedTab = 0; // 0: All meetings, 1: My meetings
  String _searchQuery = '';
  final List<MeetingModel> _meetings = [];
  bool _isLoadingMeetings = false;
  String? _lastDepartmentId;

  // Filter & Sort State
  bool _showFilterBar = false;
  String _selectedSort = 'created_newest';
  String _selectedOwner = 'All owners';
  String _selectedDateRange = 'All time';
  String _selectedStatus = 'All statuses';
  List<Map<String, dynamic>> _apiUsers = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentDeptId = context.watch<DepartmentProvider>().selectedDepartmentId;
    if (_lastDepartmentId != currentDeptId) {
      _lastDepartmentId = currentDeptId;
      _loadMeetings();
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final currentUserId = auth.currentUser?.id ?? '311fee58-ba54-42b9-8795-f3ba19255b20';
      final deptId = context.read<DepartmentProvider>().selectedDepartmentId;

      auth.fetchUserProfile();
      auth.fetchTeamMembers();

      context.read<MasterDataProvider>().fetchAllMasterData(currentUserId: currentUserId, departmentId: deptId);
      context.read<CompanyProvider>().fetchCompanies(ignorePermissions: true, departmentId: deptId);
      context.read<ContactProvider>().fetchContacts(ignorePermissions: true, departmentId: deptId);
      context.read<DealProvider>().fetchDeals(ignorePermissions: true, departmentId: deptId);

      _loadMeetings();
    });
  }

  Future<void> _fetchUsers() async {
    try {
      final resp = await ApiService().get('/users');
      final raw = resp.data;
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
          _apiUsers = usersList;
        });
      }
    } catch (e) {
      debugPrint('[MeetingsScreen _fetchUsers error]: $e');
    }
  }

  Future<void> _loadMeetings() async {
    if (!mounted) return;
    setState(() {
      _isLoadingMeetings = true;
    });
    try {
      final repository = MasterDataRepositoryImpl();
      final deptId = context.read<DepartmentProvider>().selectedDepartmentId;
      final activities = await repository.getActivities(type: 'meeting', departmentId: deptId);
      final loadedMeetings = activities.map((item) {
        final title = item['title'] as String? ?? item['subject'] as String? ?? 'Meeting';
        
        final rawOutcome = item['outcome'] as String? ?? 'Scheduled';
        String outcomeLabel = rawOutcome;
        if (rawOutcome.toLowerCase() == 'scheduled') outcomeLabel = 'Scheduled';
        else if (rawOutcome.toLowerCase() == 'completed') outcomeLabel = 'Completed';
        else if (rawOutcome.toLowerCase() == 'rescheduled') outcomeLabel = 'Rescheduled';
        else if (rawOutcome.toLowerCase() == 'no_show') outcomeLabel = 'No show';
        else if (rawOutcome.toLowerCase() == 'canceled') outcomeLabel = 'Canceled';
        else if (rawOutcome.isNotEmpty) {
          outcomeLabel = rawOutcome[0].toUpperCase() + rawOutcome.substring(1);
        }

        final id = item['id']?.toString() ?? item['_id']?.toString();
        final duration = item['duration'] as String? ?? '15 Minutes';
        final startTime = item['startTime'] as String? ?? item['start_time'] as String? ?? '';
        final notes = item['notes'] as String? ?? item['description'] as String? ?? '';
        final assignedTo = item['ownerName'] as String? ?? 'Admin User';

        String? parsedContactId = (item['contactId'] ?? item['contact_id'] ?? item['contact']?['id'])?.toString();
        String? parsedCompanyId = (item['companyId'] ?? item['company_id'] ?? item['company']?['id'])?.toString();
        String? parsedDealId = (item['dealId'] ?? item['deal_id'] ?? item['deal']?['id'])?.toString();

        if (item['associations'] is List) {
          for (final assoc in item['associations']) {
            if (assoc is Map) {
              final objType = (assoc['objectType'] ?? assoc['type'])?.toString().toLowerCase();
              final objId = (assoc['objectId'] ?? assoc['id'])?.toString();
              if (objId != null && objId.isNotEmpty) {
                if (objType == 'contact' && (parsedContactId == null || parsedContactId.isEmpty)) parsedContactId = objId;
                if (objType == 'company' && (parsedCompanyId == null || parsedCompanyId.isEmpty)) parsedCompanyId = objId;
                if (objType == 'deal' && (parsedDealId == null || parsedDealId.isEmpty)) parsedDealId = objId;
              }
            }
          }
        }

        return MeetingModel(
          id: id,
          title: title,
          outcome: outcomeLabel,
          duration: duration,
          startTime: startTime,
          notes: notes,
          assignedTo: assignedTo,
          contactId: parsedContactId,
          companyId: parsedCompanyId,
          dealId: parsedDealId,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _meetings.clear();
          _meetings.addAll(loadedMeetings);
        });
      }
    } catch (e) {
      debugPrint('[_loadMeetings ERROR]: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMeetings = false;
        });
      }
    }
  }

  String _formatDateTime(String raw) {
    if (raw.isEmpty) return '--  2026-08-05';
    try {
      if (raw.contains('T')) {
        final dt = DateTime.parse(raw);
        final hour = dt.hour.toString().padLeft(2, '0');
        final min = dt.minute.toString().padLeft(2, '0');
        final y = dt.year.toString();
        final m = dt.month.toString().padLeft(2, '0');
        final d = dt.day.toString().padLeft(2, '0');
        return '$hour:$min  $y-$m-$d';
      }
      final parts = raw.split(' ');
      if (parts.length >= 2) {
        final datePart = parts[0];
        final timePart = parts[1];
        final ampmPart = parts.length > 2 ? ' ${parts[2]}' : '';
        String formattedDate = '2026-08-05';
        final dateSubparts = datePart.split('/');
        if (dateSubparts.length == 3) {
          formattedDate = '${dateSubparts[2]}-${dateSubparts[1].padLeft(2, '0')}-${dateSubparts[0].padLeft(2, '0')}';
        }
        return '$timePart$ampmPart  $formattedDate';
      }
    } catch (_) {}
    return raw;
  }

  DateTime? _parseMeetingDate(String raw) {
    if (raw.isEmpty) return null;
    try {
      if (raw.contains('T')) return DateTime.parse(raw);
      final parts = raw.split(' ');
      if (parts.isNotEmpty) {
        final dateSubparts = parts[0].split('/');
        if (dateSubparts.length == 3) {
          return DateTime(
            int.parse(dateSubparts[2]),
            int.parse(dateSubparts[0]),
            int.parse(dateSubparts[1]),
          );
        }
      }
    } catch (_) {}
    return null;
  }

  void _showOwnerMenu(BuildContext context, TapDownDetails details) async {
    final position = RelativeRect.fromLTRB(
      details.globalPosition.dx - 10,
      details.globalPosition.dy + 10,
      details.globalPosition.dx + 240,
      details.globalPosition.dy + 350,
    );

    final ownersSet = <String>{'All owners'};
    final auth = context.read<AuthProvider>();
    if (auth.currentUser?.fullName != null) {
      ownersSet.add(auth.currentUser!.fullName!);
    }
    ownersSet.add('Admin User');
    for (final u in _apiUsers) {
      final fn = u['firstName'] ?? u['first_name'] ?? '';
      final ln = u['lastName'] ?? u['last_name'] ?? '';
      final name = '$fn $ln'.trim();
      if (name.isNotEmpty) ownersSet.add(name);
      else if (u['name'] != null && u['name'].toString().isNotEmpty) ownersSet.add(u['name'].toString());
    }

    final selected = await showMenu<String>(
      context: context,
      position: position,
      constraints: const BoxConstraints(maxHeight: 320, minWidth: 220, maxWidth: 260),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 6,
      items: [
        PopupMenuItem<String>(
          enabled: false,
          height: 36,
          child: Text(
            'FILTER BY OWNER',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF475569),
              letterSpacing: 0.6,
            ),
          ),
        ),
        const PopupMenuDivider(height: 1),
        ...ownersSet.map((o) {
          final isSelected = _selectedOwner == o;
          return PopupMenuItem<String>(
            value: o,
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    o,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ),
                if (isSelected) const Icon(Icons.check_rounded, size: 18, color: Color(0xFF334155)),
              ],
            ),
          );
        }),
      ],
    );

    if (selected != null) {
      setState(() => _selectedOwner = selected);
    }
  }

  void _showDateMenu(BuildContext context, TapDownDetails details) async {
    final position = RelativeRect.fromLTRB(
      details.globalPosition.dx - 10,
      details.globalPosition.dy + 10,
      details.globalPosition.dx + 240,
      details.globalPosition.dy + 350,
    );

    final options = [
      'All time',
      'Today',
      'Yesterday',
      'This week',
      'Last week',
      'This month',
      'Last month',
      'This year',
      'CUSTOM RANGE',
    ];

    final selected = await showMenu<String>(
      context: context,
      position: position,
      constraints: const BoxConstraints(maxHeight: 340, minWidth: 220, maxWidth: 260),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 6,
      items: [
        PopupMenuItem<String>(
          enabled: false,
          height: 36,
          child: Text(
            'FILTER BY DATE',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF475569),
              letterSpacing: 0.6,
            ),
          ),
        ),
        const PopupMenuDivider(height: 1),
        ...options.map((opt) {
          final isSelected = _selectedDateRange == opt;
          return PopupMenuItem<String>(
            value: opt,
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    opt,
                    style: GoogleFonts.poppins(
                      fontSize: opt == 'CUSTOM RANGE' ? 12 : 13,
                      fontWeight: opt == 'CUSTOM RANGE' ? FontWeight.w700 : (isSelected ? FontWeight.w600 : FontWeight.w400),
                      color: opt == 'CUSTOM RANGE' ? const Color(0xFF64748B) : const Color(0xFF1E293B),
                    ),
                  ),
                ),
                if (isSelected) const Icon(Icons.check_rounded, size: 18, color: Color(0xFF334155)),
              ],
            ),
          );
        }),
      ],
    );

    if (selected == 'CUSTOM RANGE') {
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
      );
      if (range != null) {
        setState(() {
          _selectedDateRange = '${range.start.month}/${range.start.day} - ${range.end.month}/${range.end.day}';
        });
      }
    } else if (selected != null) {
      setState(() => _selectedDateRange = selected);
    }
  }

  void _showStatusMenu(BuildContext context, TapDownDetails details) async {
    final position = RelativeRect.fromLTRB(
      details.globalPosition.dx - 10,
      details.globalPosition.dy + 10,
      details.globalPosition.dx + 220,
      details.globalPosition.dy + 300,
    );

    final statuses = ['All statuses', 'Scheduled', 'Completed', 'Cancelled', 'Pending'];

    final selected = await showMenu<String>(
      context: context,
      position: position,
      constraints: const BoxConstraints(maxHeight: 280, minWidth: 200, maxWidth: 240),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 6,
      items: [
        PopupMenuItem<String>(
          enabled: false,
          height: 36,
          child: Text(
            'FILTER BY STATUS',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF475569),
              letterSpacing: 0.6,
            ),
          ),
        ),
        const PopupMenuDivider(height: 1),
        ...statuses.map((st) {
          final isSelected = _selectedStatus == st;
          return PopupMenuItem<String>(
            value: st,
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    st,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ),
                if (isSelected) const Icon(Icons.check_rounded, size: 18, color: Color(0xFF334155)),
              ],
            ),
          );
        }),
      ],
    );

    if (selected != null) {
      setState(() => _selectedStatus = selected);
    }
  }

  void _showSortMenu(BuildContext context, Offset offset) async {
    final position = RelativeRect.fromLTRB(
      offset.dx - 100,
      offset.dy + 10,
      offset.dx + 180,
      offset.dy + 250,
    );

    final selected = await showMenu<String>(
      context: context,
      position: position,
      constraints: const BoxConstraints(maxHeight: 240, minWidth: 200, maxWidth: 240),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 6,
      items: [
        PopupMenuItem<String>(
          enabled: false,
          height: 36,
          child: Text(
            'SORT BY',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF475569),
              letterSpacing: 0.6,
            ),
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'title_asc',
          height: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('A to Z', style: GoogleFonts.poppins(fontSize: 13, fontWeight: _selectedSort == 'title_asc' ? FontWeight.w600 : FontWeight.w400, color: const Color(0xFF1E293B))),
              if (_selectedSort == 'title_asc') const Icon(Icons.check_rounded, size: 18, color: Color(0xFF00A884)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'title_desc',
          height: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Z to A', style: GoogleFonts.poppins(fontSize: 13, fontWeight: _selectedSort == 'title_desc' ? FontWeight.w600 : FontWeight.w400, color: const Color(0xFF1E293B))),
              if (_selectedSort == 'title_desc') const Icon(Icons.check_rounded, size: 18, color: Color(0xFF00A884)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'created_newest',
          height: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Most recent', style: GoogleFonts.poppins(fontSize: 13, fontWeight: _selectedSort == 'created_newest' ? FontWeight.w600 : FontWeight.w400, color: const Color(0xFF1E293B))),
              if (_selectedSort == 'created_newest') const Icon(Icons.check_rounded, size: 18, color: Color(0xFF00A884)),
            ],
          ),
        ),
      ],
    );

    if (selected != null) {
      setState(() => _selectedSort = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      final auth = context.watch<AuthProvider>();
      final currentUserName = auth.currentUser?.fullName ?? 'Admin User';
      final myMeetingsCount = _meetings.where((m) => (m.assignedTo ?? 'Admin User') == currentUserName).length;

      final filteredMeetings = _meetings.where((m) {
        if (_selectedTab == 1 && (m.assignedTo ?? 'Admin User') != currentUserName) return false;
        if (_searchQuery.isNotEmpty && !m.title.toLowerCase().contains(_searchQuery.toLowerCase())) return false;

        // 1. Owner Filter
        if (_selectedOwner != 'All owners') {
          if ((m.assignedTo ?? '').toLowerCase() != _selectedOwner.toLowerCase()) {
            return false;
          }
        }

        // 2. Status Filter
        if (_selectedStatus != 'All statuses') {
          if (m.outcome.toLowerCase() != _selectedStatus.toLowerCase()) {
            return false;
          }
        }

        // 3. Date Range Filter
        if (_selectedDateRange != 'All time') {
          final meetingDt = _parseMeetingDate(m.startTime);
          if (meetingDt != null) {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            if (_selectedDateRange == 'Today') {
              if (meetingDt.isBefore(today) || meetingDt.isAfter(today.add(const Duration(days: 1)))) return false;
            } else if (_selectedDateRange == 'Yesterday') {
              final yest = today.subtract(const Duration(days: 1));
              if (meetingDt.isBefore(yest) || meetingDt.isAfter(today)) return false;
            } else if (_selectedDateRange == 'This week') {
              final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
              if (meetingDt.isBefore(startOfWeek)) return false;
            } else if (_selectedDateRange == 'Last week') {
              final startOfLastWeek = today.subtract(Duration(days: today.weekday - 1 + 7));
              final endOfLastWeek = startOfLastWeek.add(const Duration(days: 7));
              if (meetingDt.isBefore(startOfLastWeek) || meetingDt.isAfter(endOfLastWeek)) return false;
            } else if (_selectedDateRange == 'This month') {
              final startOfMonth = DateTime(now.year, now.month, 1);
              if (meetingDt.isBefore(startOfMonth)) return false;
            } else if (_selectedDateRange == 'Last month') {
              final startOfLastMonth = DateTime(now.year, now.month - 1, 1);
              final endOfLastMonth = DateTime(now.year, now.month, 1);
              if (meetingDt.isBefore(startOfLastMonth) || meetingDt.isAfter(endOfLastMonth)) return false;
            } else if (_selectedDateRange == 'This year') {
              final startOfYear = DateTime(now.year, 1, 1);
              if (meetingDt.isBefore(startOfYear)) return false;
            }
          }
        }

        return true;
      }).toList();

      // Apply Sorting:
      if (_selectedSort == 'title_asc') {
        filteredMeetings.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      } else if (_selectedSort == 'title_desc') {
        filteredMeetings.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
      } else if (_selectedSort == 'created_oldest') {
        filteredMeetings.sort((a, b) => (a.id ?? '').compareTo(b.id ?? ''));
      } else if (_selectedSort == 'created_newest') {
        filteredMeetings.sort((a, b) => (b.id ?? '').compareTo(a.id ?? ''));
      } else if (_selectedSort == 'time_newest') {
        filteredMeetings.sort((a, b) => b.startTime.compareTo(a.startTime));
      } else if (_selectedSort == 'time_oldest') {
        filteredMeetings.sort((a, b) => a.startTime.compareTo(b.startTime));
      }

      return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Header Row: Camera Icon + Meetings Title + "+ Meeting" Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Row(
                children: [
                  const Icon(
                    Icons.videocam_outlined,
                    color: Color(0xFF0F766E),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Meetings',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const Spacer(),

                  // + Meeting Button
                  ElevatedButton.icon(
                    onPressed: () async {
                      final newMeeting = await LogMeetingModal.show(context);
                      if (newMeeting != null) {
                        _loadMeetings();
                      }
                    },
                    icon: const Icon(Icons.add, size: 18, color: Colors.white),
                    label: Text(
                      'Meeting',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A884),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Sub-header Segmented Pill: "All meetings" | "My meetings" + 3 Dots Action Menu
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        _buildTabButton('All meetings', 0, _meetings.length),
                        _buildTabButton('My meetings', 1, myMeetingsCount),
                      ],
                    ),
                  ),

                  // 3 Dots Menu containing Filters, Sort, Import, Export
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'filters') {
                        setState(() {
                          _showFilterBar = !_showFilterBar;
                        });
                      } else if (value == 'sort') {
                        final RenderBox? button = context.findRenderObject() as RenderBox?;
                        final offset = button != null ? button.localToGlobal(Offset.zero) : const Offset(200, 200);
                        _showSortMenu(context, offset);
                      } else {
                        debugPrint('[MeetingsScreen Action]: Selected $value');
                      }
                    },
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Icon(
                        Icons.more_horiz_rounded,
                        size: 18,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    itemBuilder: (BuildContext context) => [
                      PopupMenuItem<String>(
                        value: 'filters',
                        child: Row(
                          children: [
                            const Icon(Icons.tune_rounded, size: 18, color: Color(0xFF64748B)),
                            const SizedBox(width: 10),
                            Text(
                              'Filters',
                              style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF334155)),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'sort',
                        child: Row(
                          children: [
                            const Icon(Icons.swap_vert_rounded, size: 18, color: Color(0xFF64748B)),
                            const SizedBox(width: 10),
                            Text(
                              'Sort',
                              style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF334155)),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'import',
                        child: Row(
                          children: [
                            const Icon(Icons.file_upload_outlined, size: 18, color: Color(0xFF64748B)),
                            const SizedBox(width: 10),
                            Text(
                              'Import',
                              style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF334155)),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'export',
                        child: Row(
                          children: [
                            const Icon(Icons.file_download_outlined, size: 18, color: Color(0xFF64748B)),
                            const SizedBox(width: 10),
                            Text(
                              'Export',
                              style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF334155)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // 3. Search and Action Filter Container Card
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      // Search Field
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: TextField(
                            textAlignVertical: TextAlignVertical.center,
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val;
                              });
                            },
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: const Color(0xFF1E293B),
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Search',
                              hintStyle: GoogleFonts.poppins(
                                fontSize: 13,
                                color: const Color(0xFF94A3B8),
                              ),
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: Color(0xFF94A3B8),
                                size: 20,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ),

                      // Filter Bar Options (Meeting owner v | Create date v | Status v) matching Image 1
                      if (_showFilterBar) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                InkWell(
                                  onTapDown: (details) => _showOwnerMenu(context, details),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                    child: Row(
                                      children: [
                                        Text(
                                          _selectedOwner == 'All owners' ? 'Meeting owner' : 'Meeting owner: $_selectedOwner',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF00A884),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF00A884)),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                InkWell(
                                  onTapDown: (details) => _showDateMenu(context, details),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                    child: Row(
                                      children: [
                                        Text(
                                          _selectedDateRange == 'All time' ? 'Create date' : 'Create date: $_selectedDateRange',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF00A884),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF00A884)),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                InkWell(
                                  onTapDown: (details) => _showStatusMenu(context, details),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                    child: Row(
                                      children: [
                                        Text(
                                          _selectedStatus == 'All statuses' ? 'Status' : 'Status: $_selectedStatus',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF00A884),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF00A884)),
                                      ],
                                    ),
                                  ),
                                ),
                                if (_selectedOwner != 'All owners' || _selectedDateRange != 'All time' || _selectedStatus != 'All statuses') ...[
                                  const SizedBox(width: 16),
                                  InkWell(
                                    onTap: () {
                                      setState(() {
                                        _selectedOwner = 'All owners';
                                        _selectedDateRange = 'All time';
                                        _selectedStatus = 'All statuses';
                                      });
                                    },
                                    child: Text(
                                      'Reset filters',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      const SizedBox(height: 8),

                      const Divider(height: 1, color: Color(0xFFF1F5F9)),

                      // Main List Content or Empty State
                      Expanded(
                        child: AppRefreshIndicator(
                          onRefresh: () async {
                            await _loadMeetings();
                          },
                          child: _isLoadingMeetings && _meetings.isEmpty
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF0F766E),
                                  ),
                                )
                              : filteredMeetings.isEmpty
                                  ? ListView(
                                      physics: const AlwaysScrollableScrollPhysics(
                                          parent: BouncingScrollPhysics()),
                                      children: [
                                        const SizedBox(height: 120),
                                        Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(24),
                                            child: Text(
                                              'No meetings found. Click "Create meeting" to add one.',
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.poppins(
                                                fontSize: 13.5,
                                                color: const Color(0xFF64748B),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : ListView.builder(
                                      physics: const AlwaysScrollableScrollPhysics(
                                          parent: BouncingScrollPhysics()),
                                      padding: const EdgeInsets.all(14),
                                      itemCount: filteredMeetings.length,
                                      itemBuilder: (context, index) {
                                        final m = filteredMeetings[index];
                                        return _buildMeetingTile(m);
                                      },
                                    ),
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              filteredMeetings.isEmpty 
                                  ? '0-0 of 0' 
                                  : '1-${filteredMeetings.length} of ${filteredMeetings.length}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF334155),
                              ),
                            ),
                            Row(
                              children: [
                                TextButton.icon(
                                  onPressed: null,
                                  icon: const Icon(Icons.chevron_left_rounded, size: 16),
                                  label: Text(
                                    'Prev',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF94A3B8),
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '1/1',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: null,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Next',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right_rounded, size: 16),
                                    ],
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF94A3B8),
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      );
    } catch (e, stack) {
      debugPrint('[MeetingsScreen Build Crash]: $e\n$stack');
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: SelectableText(
                'Crash: $e\n\nStack:\n$stack',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          ),
        ),
      );
    }
  }

  Widget _buildTabButton(String label, int index, int count) {
    final bool isSelected = _selectedTab == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected
                    ? const Color(0xFF0F766E)
                    : const Color(0xFF64748B),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingTile(MeetingModel meeting) {
    return InkWell(
      onTap: () async {
        // 1. If meeting was created from / associated with Contact, open Contact Details
        if (meeting.contactId != null && meeting.contactId!.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ContactDetailsScreen(
                contact: ContactModel(
                  id: meeting.contactId!,
                  email: '',
                  firstName: '',
                  lastName: '',
                ),
              ),
            ),
          );
        }
        // 2. If meeting was created from / associated with Company, open Company Details
        else if (meeting.companyId != null && meeting.companyId!.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CompanyDetailsScreen(
                company: CompanyModel(
                  id: meeting.companyId!,
                  name: '',
                ),
              ),
            ),
          );
        }
        // 3. If meeting was created from / associated with Deal, open Deal Details
        else if (meeting.dealId != null && meeting.dealId!.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DealDetailsScreen(
                deal: DealModel(
                  id: meeting.dealId!,
                  title: '',
                  amount: 0.0,
                  stage: '',
                  probability: 0,
                ),
              ),
            ),
          );
        }
        // 4. Standalone / Unassigned meeting created on Meetings screen -> Open MeetingDetailsScreen
        else {
          final refresh = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => MeetingDetailsScreen(meeting: meeting),
            ),
          );

          if (refresh == true) {
            _loadMeetings();
          }
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFE6F4F1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.videocam_outlined,
                color: Color(0xFF0F766E),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meeting.title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F766E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDateTime(meeting.startTime),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Assigned: ${meeting.assignedTo ?? 'Admin User'}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFCBD5E1),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
