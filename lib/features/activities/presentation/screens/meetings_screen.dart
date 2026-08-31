import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/navigation/route_names.dart';
import '../../../../core/navigation/route_paths.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:crmproject/core/widgets/app_refresh_indicator.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/providers/master_data_provider.dart';
import '../../../../core/repositories/master_data_repository.dart';
import '../../../../core/utils/activity_utils.dart';
import '../../../../core/utils/list_scroll_utils.dart';
import '../../../../core/utils/meeting_booking_source.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../companies/presentation/providers/company_provider.dart';
import '../../../contacts/presentation/providers/contact_provider.dart';
import '../../../deals/presentation/providers/deal_provider.dart';
import '../../../departments/presentation/providers/department_provider.dart';
import '../../../navigation/presentation/providers/navigation_provider.dart';
import '../widgets/log_meeting_modal.dart';

class MeetingsScreen extends StatefulWidget {
  const MeetingsScreen({super.key});

  @override
  State<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends State<MeetingsScreen> {
  int _selectedTab = 0; // 0: All meetings, 1: My meetings
  String _currentHeaderMode = 'log'; // 'log' or 'create'
  String _searchQuery = '';
  final List<MeetingModel> _meetings = [];
  bool _isLoadingMeetings = false;
  String? _lastDepartmentId;

  /// Id of the meeting the user selected. Held by id so the highlight survives
  /// a reload of the list.
  String? _selectedMeetingId;

  /// Marks the selected row so it can be scrolled to once it is built.
  final GlobalKey _selectedTileKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  /// Activity requested by another screen, applied once the list has loaded.
  String? _pendingFocusId;
  String? _appliedFocusId;
  bool _hasLoadedOnce = false;

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

    // A meeting opened from elsewhere in the app (e.g. a notification).
    final requested = context.watch<NavigationProvider>().focusedActivityId;
    if (requested != null && requested != _appliedFocusId) {
      _appliedFocusId = requested;
      _pendingFocusId = requested;
      // Off the build phase: applying the focus calls setState.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyPendingFocus();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Highlights the requested meeting and brings it into view. Does nothing
  /// until the list has loaded — [_loadMeetings] calls back in once it has.
  Future<void> _applyPendingFocus() async {
    final id = _pendingFocusId;
    if (id == null || !_hasLoadedOnce || _isLoadingMeetings) return;

    _pendingFocusId = null;

    // Not in this list (deleted, filtered out, or a different type): leave the
    // screen as it is rather than scrolling somewhere arbitrary.
    if (!_meetings.any((m) => m.id == id)) return;
    if (!mounted) return;

    setState(() => _selectedMeetingId = id);
    await ensureListItemVisible(
      controller: _scrollController,
      itemKey: _selectedTileKey,
    );
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

  /// The booking source the currently selected header mode lists.
  String get _expectedBookingSource =>
      _currentHeaderMode == 'create' ? BookingSource.directBooking : BookingSource.manual;

  /// Renders a stored outcome (or, for a meeting that has not happened yet,
  /// its status) as the label the status filter matches on.
  String _outcomeLabel(Map<String, dynamic> item) {
    final rawOutcome = (item['outcome'] ?? '').toString().trim();
    final rawStatus = (item['status'] ?? '').toString().trim();
    final raw = rawOutcome.isNotEmpty
        ? rawOutcome
        : (rawStatus.isNotEmpty ? rawStatus : 'Scheduled');

    switch (raw.toLowerCase()) {
      case 'scheduled':
        return 'Scheduled';
      case 'completed':
        return 'Completed';
      case 'rescheduled':
        return 'Rescheduled';
      case 'pending':
        return 'Pending';
      case 'no_show':
        return 'No show';
      case 'canceled':
      case 'cancelled':
        return 'Cancelled';
      default:
        return raw[0].toUpperCase() + raw.substring(1);
    }
  }

  /// Loads the meetings for the current header mode.
  ///
  /// [ensureVisible] is a meeting that was just saved: it is kept at the top of
  /// the list when the reload has not picked it up yet (indexing lag, or a
  /// backend that ignores the `bookingSource` filter and pages it out).
  Future<void> _loadMeetings({MeetingModel? ensureVisible}) async {
    if (!mounted) return;
    setState(() {
      _isLoadingMeetings = true;
    });

    final expectedSource = _expectedBookingSource;
    final isCreateMode = expectedSource == BookingSource.directBooking;
    final deptId = context.read<DepartmentProvider>().selectedDepartmentId;

    List<MeetingModel>? loadedMeetings;
    try {
      await MeetingBookingSourceStore.ensureLoaded();
      final repository = MasterDataRepositoryImpl();
      final activities = await repository.getActivities(
        type: 'meeting',
        bookingSource: expectedSource,
        page: 1,
        limit: 25,
        // Booked meetings are read newest-first so one created a moment ago
        // sits on the first page instead of behind 25 older rows.
        sort: isCreateMode ? 'createdAt' : null,
        order: isCreateMode ? 'desc' : 'asc',
        departmentId: deptId,
      );

      // The `bookingSource` query parameter is only honoured by backends that
      // know the field, so the split is enforced here as well — otherwise a
      // booked meeting would show up in the Log Meeting list and vice versa.
      //
      // Meetings booked before the app started tagging them carry no
      // bookingSource at all; those are recognised by their missing outcome,
      // but only when this page proves outcomes are being returned.
      final inferFromOutcome = canInferBookingSourceFromOutcome(activities);
      final scoped = activities
          .where((item) =>
              resolveBookingSource(item, inferFromOutcome: inferFromOutcome) == expectedSource)
          .toList();
      debugPrint(
        '[_loadMeetings]: mode=$_currentHeaderMode bookingSource=$expectedSource '
        'returned=${activities.length} kept=${scoped.length} '
        'inferFromOutcome=$inferFromOutcome',
      );
      if (!inferFromOutcome && activities.isNotEmpty) {
        debugPrint(
          '[_loadMeetings]: no meeting in this page carries an `outcome` field '
          '— it looks absent from the list response, so untagged meetings are '
          'left in the Log Meeting list.',
        );
      }

      loadedMeetings = scoped.map((item) {
        final title = item['title'] as String? ?? item['subject'] as String? ?? 'Meeting';

        final outcomeLabel = _outcomeLabel(item);

        final id = item['id']?.toString() ?? item['_id']?.toString();
        // The API stores these as durationMinutes (int) and scheduledAt (ISO).
        final durationMinutes = parseDurationMinutes(
          item['durationMinutes'] ?? item['duration_minutes'] ?? item['duration'],
        );
        final duration = durationMinutes != null ? formatDurationLabel(durationMinutes) : '15 Minutes';
        final scheduledAt = parseActivityDateTimeOrNull(
          item['scheduledAt'] ?? item['scheduled_at'] ?? item['startTime'] ?? item['start_time'],
        );
        final startTime = scheduledAt != null ? formatActivityDateTimeInput(scheduledAt) : '';
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
          bookingSource: expectedSource,
          rawMap: item,
        );
      }).toList();
    } catch (e) {
      debugPrint('[_loadMeetings ERROR]: $e');
    } finally {
      if (mounted) {
        setState(() {
          // The header mode may have been switched while this load was in
          // flight; those results belong to the other list, so drop them.
          if (loadedMeetings != null && expectedSource == _expectedBookingSource) {
            _meetings
              ..clear()
              ..addAll(loadedMeetings);

            if (ensureVisible != null &&
                ensureVisible.bookingSource == expectedSource &&
                !_meetings.any((m) => m.id != null && m.id == ensureVisible.id)) {
              debugPrint(
                '[_loadMeetings]: reload did not return the meeting just saved '
                '(${ensureVisible.id}) — keeping it at the top of the list.',
              );
              _meetings.insert(0, ensureVisible);
            }
          }
          _isLoadingMeetings = false;
          _hasLoadedOnce = true;
        });
        // The list is populated now, so an activity requested by another screen
        // (including one requested before this load started) can be located.
        _applyPendingFocus();
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
      ownersSet.add(auth.currentUser!.fullName);
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

  /// When a meeting was created, for the "Most recent" sort. Ids are UUIDs, so
  /// ordering by id says nothing about age.
  DateTime _createdAt(MeetingModel m) {
    final raw = m.rawMap?['createdAt'] ?? m.rawMap?['created_at'];
    return parseActivityDateTimeOrNull(raw) ??
        parseActivityDateTimeOrNull(m.startTime) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// The tab, search and filter-bar selections. The booking-source split is not
  /// checked here — [_loadMeetings] only ever puts one source into [_meetings].
  bool _passesFilters(MeetingModel m, String currentUserName) {
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
  }

  /// Reloads the list a meeting was just saved into and brings that meeting
  /// into view. A filter left over from before the save (a status, an owner, a
  /// search term) would hide a brand new row, so those are cleared when — and
  /// only when — they would swallow it.
  Future<void> _showSavedMeeting(MeetingModel saved) async {
    if (!mounted) return;
    final currentUserName = context.read<AuthProvider>().currentUser?.fullName ?? 'Admin User';
    if (!_passesFilters(saved, currentUserName)) {
      setState(() {
        _selectedTab = 0;
        _searchQuery = '';
        _selectedOwner = 'All owners';
        _selectedDateRange = 'All time';
        _selectedStatus = 'All statuses';
      });
    }

    setState(() {
      _selectedMeetingId = saved.id;
      // Shown straight away; the reload below replaces it with the stored row.
      if (saved.bookingSource == _expectedBookingSource &&
          !_meetings.any((m) => m.id != null && m.id == saved.id)) {
        _meetings.insert(0, saved);
      }
    });

    _pendingFocusId = saved.id;
    await _loadMeetings(ensureVisible: saved);
  }

  @override
  Widget build(BuildContext context) {
    try {
      final auth = context.watch<AuthProvider>();
      final currentUserName = auth.currentUser?.fullName ?? 'Admin User';
      final myMeetingsCount = _meetings.where((m) => (m.assignedTo ?? 'Admin User') == currentUserName).length;

      final filteredMeetings =
          _meetings.where((m) => _passesFilters(m, currentUserName)).toList();

      // Apply Sorting:
      if (_selectedSort == 'title_asc') {
        filteredMeetings.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      } else if (_selectedSort == 'title_desc') {
        filteredMeetings.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
      } else if (_selectedSort == 'created_oldest') {
        filteredMeetings.sort((a, b) => _createdAt(a).compareTo(_createdAt(b)));
      } else if (_selectedSort == 'created_newest') {
        filteredMeetings.sort((a, b) => _createdAt(b).compareTo(_createdAt(a)));
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

                  // Title Dropdown Menu: "Log Meetings ▾" / "Create Meeting ▾"
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (_currentHeaderMode != value) {
                            setState(() {
                              _currentHeaderMode = value;
                              // The other mode's rows must not linger while the
                              // new list loads.
                              _meetings.clear();
                              _selectedMeetingId = null;
                            });
                            _loadMeetings();
                          }
                        },
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        itemBuilder: (ctx) => [
                          PopupMenuItem<String>(
                            value: 'log',
                            child: Row(
                              children: [
                                const Icon(Icons.history_rounded, size: 18, color: Color(0xFF0F766E)),
                                const SizedBox(width: 10),
                                Text(
                                  'Log Meetings',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'create',
                            child: Row(
                              children: [
                                const Icon(Icons.add_circle_outline_rounded, size: 18, color: Color(0xFF0F766E)),
                                const SizedBox(width: 10),
                                Text(
                                  'Create Meeting',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _currentHeaderMode == 'create' ? 'Create Meeting' : 'Log Meetings',
                              style: GoogleFonts.poppins(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Color(0xFF1E293B),
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Right Action Button
                  ElevatedButton.icon(
                    onPressed: () async {
                      final isCreate = _currentHeaderMode == 'create';
                      final newMeeting = await LogMeetingModal.show(
                        context,
                        isCreateMode: isCreate,
                        titleOverride: isCreate ? 'Create Meeting' : 'Log Meeting',
                      );
                      if (newMeeting != null) {
                        await _showSavedMeeting(newMeeting);
                      }
                    },
                    icon: const Icon(Icons.add, size: 16, color: Colors.white),
                    label: Text(
                      _currentHeaderMode == 'create' ? 'Create' : 'Log Meeting',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A884),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
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
                                      _loadMeetings();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFFCA5A5)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.close_rounded, size: 14, color: Color(0xFFEF4444)),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Clear',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFFEF4444),
                                            ),
                                          ),
                                        ],
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
                                              _currentHeaderMode == 'create'
                                                  ? 'No meetings created yet. Click "Create" to add one.'
                                                  : 'No meetings found. Click "Log Meeting" to add one.',
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
                                      controller: _scrollController,
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
    final bool isSelected = meeting.id != null && meeting.id == _selectedMeetingId;

    return InkWell(
      // The key rides along with the selection so the selected row can always
      // be scrolled to, however it got selected.
      key: isSelected ? _selectedTileKey : null,
      onTap: () async {
        // Mark this meeting as the selected one before opening its details.
        setState(() => _selectedMeetingId = meeting.id);

        // 1. If meeting was created from / associated with Contact, open Contact Details
        if (meeting.contactId != null && meeting.contactId!.isNotEmpty) {
          context.pushNamed(
            RouteNames.contactDetails,
            pathParameters: {RoutePaths.idParam: meeting.contactId!},
            queryParameters: RoutePaths.recordActivityQuery(meeting.id),
          );
        }
        // 2. If meeting was created from / associated with Company, open Company Details
        else if (meeting.companyId != null && meeting.companyId!.isNotEmpty) {
          context.pushNamed(
            RouteNames.companyDetails,
            pathParameters: {RoutePaths.idParam: meeting.companyId!},
            queryParameters: RoutePaths.recordActivityQuery(meeting.id),
          );
        }
        // 3. If meeting was created from / associated with Deal, open Deal Details
        else if (meeting.dealId != null && meeting.dealId!.isNotEmpty) {
          context.pushNamed(
            RouteNames.dealDetails,
            pathParameters: {RoutePaths.idParam: meeting.dealId!},
            queryParameters: RoutePaths.recordActivityQuery(meeting.id),
          );
        }
        // 4. Standalone / Unassigned meeting created on Meetings screen -> Open MeetingDetailsScreen
        else {
          // /activities/meetings/details/:id
          final meetingId = meeting.id;
          if (meetingId == null || meetingId.isEmpty) return;
          final refresh = await context.pushNamed<bool>(
            RouteNames.meetingDetails,
            pathParameters: {RoutePaths.idParam: meetingId},
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
          color: isSelected ? const Color(0xFFE6F4F1) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF00A884) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
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
