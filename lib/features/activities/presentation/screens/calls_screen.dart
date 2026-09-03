import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/navigation/route_names.dart';
import '../../../../core/navigation/route_paths.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:crmproject/core/widgets/app_refresh_indicator.dart';
import '../../../../core/repositories/master_data_repository.dart';
import '../../../../core/utils/department_aware_state.dart';
import '../../../../core/utils/activity_utils.dart';
import '../../../../core/utils/filter_query_utils.dart';
import '../../../../core/utils/list_scroll_utils.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../departments/presentation/providers/department_provider.dart';
import '../../../navigation/presentation/providers/navigation_provider.dart';
import '../widgets/log_call_modal.dart';
import '../../../../core/widgets/search_and_filter_bar.dart';
import '../../../contacts/presentation/providers/contact_provider.dart';
import '../widgets/call_inline_filter_section.dart';

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> with DepartmentAwareState {
  int _selectedTab = 0; // 0: All calls, 1: My calls
  String _searchQuery = '';
  ContactSortOption _currentSort = ContactSortOption.mostRecent;
  bool _isFilterExpanded = false;
  String? _selectedOutcomeFilter;
  String? _selectedOwnerId;
  String? _selectedCreateDate;
  String? _selectedStatusFilter;
  final List<CallModel> _calls = [];
  bool _isLoadingCalls = false;

  /// Id of the call the user selected. Held by id so the highlight survives a
  /// reload of the list.
  String? _selectedCallId;

  /// Marks the selected row so it can be scrolled to once it is built.
  final GlobalKey _selectedTileKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  /// Activity requested by another screen, applied once the list has loaded.
  String? _pendingFocusId;
  String? _appliedFocusId;
  bool _hasLoadedOnce = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCalls();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // This screen keeps its own list, so it has to notice a department switch
    // itself. It previously loaded once in initState and never reacted, which
    // left the previous department's calls on screen indefinitely.
    watchDepartmentChanges((_) {
      setState(() {
        _calls.clear();
        _selectedCallId = null;
      });
      _loadCalls();
    });

    // A call opened from elsewhere in the app (e.g. a notification).
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

  /// Highlights the requested call and brings it into view. Does nothing until
  /// the list has loaded — [_loadCalls] calls back in once it has.
  Future<void> _applyPendingFocus() async {
    final id = _pendingFocusId;
    if (id == null || !_hasLoadedOnce || _isLoadingCalls) return;

    _pendingFocusId = null;

    // Not in this list (deleted, filtered out, or a different type): leave the
    // screen as it is rather than scrolling somewhere arbitrary.
    if (!_calls.any((c) => c.id == id)) return;
    if (!mounted) return;

    setState(() => _selectedCallId = id);
    await ensureListItemVisible(
      controller: _scrollController,
      itemKey: _selectedTileKey,
    );
  }

  /// The Owner pill's value as an `ownerId` query value.
  String? get _ownerQuery => FilterValue.orNull(_selectedOwnerId);

  /// The Status pill's value as a `status` query value. The pill also offers
  /// outcomes (`Scheduled`, `Logged`) which the endpoint has no parameter for;
  /// those return null here and stay an in-memory match.
  String? get _statusQuery => FilterValue.activityStatus(_selectedStatusFilter);

  String? get _createdDateRangeQuery => FilterDateRange.toQueryValue(_selectedCreateDate);

  Future<void> _loadCalls() async {
    if (!mounted) return;
    setState(() {
      _isLoadingCalls = true;
    });
    try {
      final repository = MasterDataRepositoryImpl();
      final deptId = context.read<DepartmentProvider>().selectedDepartmentId;
      debugPrint('[CallsScreen] filters → owner=${_ownerQuery ?? '-'} '
          'status=${_statusQuery ?? '-'} '
          'createdDateRange=${_createdDateRangeQuery ?? '-'} '
          'outcome=${_selectedOutcomeFilter ?? '-'} search=${_searchQuery.isEmpty ? '-' : _searchQuery}');
      final activities = await repository.getActivities(
        type: 'call',
        page: 1,
        limit: 25,
        departmentId: deptId,
        ownerId: _ownerQuery,
        status: _statusQuery,
        createdDateRange: _createdDateRangeQuery,
        sort: 'created_at',
        order: 'desc',
      );
      final loadedCalls = activities.map((item) {
        final title = item['title'] as String? ?? item['subject'] as String? ?? 'Call';
        
        final rawOutcome = item['outcome'] as String? ?? 'Scheduled';
        String outcomeLabel = rawOutcome;
        if (rawOutcome.toLowerCase() == 'scheduled') outcomeLabel = 'Scheduled';
        else if (rawOutcome.toLowerCase() == 'completed') outcomeLabel = 'Completed';
        else if (rawOutcome.toLowerCase() == 'rescheduled') outcomeLabel = 'Rescheduled';
        else if (rawOutcome.toLowerCase() == 'no_show') outcomeLabel = 'No show';
        else if (rawOutcome.toLowerCase() == 'canceled') outcomeLabel = 'Canceled';
        else if (rawOutcome.toLowerCase() == 'connected') outcomeLabel = 'Connected';
        else if (rawOutcome.toLowerCase() == 'busy') outcomeLabel = 'Busy';
        else if (rawOutcome.toLowerCase() == 'left message') outcomeLabel = 'Left Message';
        else if (rawOutcome.toLowerCase() == 'no answer') outcomeLabel = 'No Answer';
        else if (rawOutcome.toLowerCase() == 'wrong number') outcomeLabel = 'Wrong Number';
        else if (rawOutcome.isNotEmpty) {
          outcomeLabel = rawOutcome[0].toUpperCase() + rawOutcome.substring(1);
        }

        final id = item['id']?.toString() ?? item['_id']?.toString() ?? item['activityId']?.toString();
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
        final priority = item['priority'] as String? ?? 'Medium';
        final status = item['status'] as String? ?? 'PENDING';
        final type = item['type'] as String? ?? 'call';

        return CallModel(
          id: id,
          title: title,
          outcome: outcomeLabel,
          duration: duration,
          startTime: startTime,
          notes: notes,
          assignedTo: assignedTo,
          priority: priority,
          status: status,
          type: type,
          rawMap: item,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _calls.clear();
          _calls.addAll(loadedCalls);
        });
      }
    } catch (e) {
      debugPrint('[_loadCalls ERROR]: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCalls = false;
          _hasLoadedOnce = true;
        });
        // The list is populated now, so an activity requested by another screen
        // (including one requested before this load started) can be located.
        _applyPendingFocus();
      }
    }
  }

  String _formatCallDateTime(String raw) {
    if (raw.isEmpty) return '--';
    try {
      DateTime? dt;
      if (raw.contains('T')) {
        dt = DateTime.parse(raw);
      } else {
        dt = DateTime.tryParse(raw);
        if (dt == null) {
          final parts = raw.split(' ');
          if (parts.length >= 2) {
            final dateParts = parts[0].split('/');
            final timeParts = parts[1].split(':');
            if (dateParts.length == 3 && timeParts.length >= 2) {
              final day = int.parse(dateParts[0]);
              final month = int.parse(dateParts[1]);
              final year = int.parse(dateParts[2]);
              final hour = int.parse(timeParts[0]);
              final minute = int.parse(timeParts[1]);
              dt = DateTime(year, month, day, hour, minute);
            }
          }
        }
      }

      if (dt != null) {
        int hour = dt.hour;
        final ampm = hour >= 12 ? 'PM' : 'AM';
        hour = hour % 12;
        if (hour == 0) hour = 12;
        final hourStr = hour.toString().padLeft(2, '0');
        final minStr = dt.minute.toString().padLeft(2, '0');
        final dateStr = '${dt.month}/${dt.day}/${dt.year}';
        return '$hourStr:$minStr $ampm  $dateStr';
      }
    } catch (_) {}
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    try {
      final auth = context.watch<AuthProvider>();
      final currentUserName = auth.currentUser?.fullName ?? 'Admin User';

      var filteredCalls = _calls.where((c) {
        final act = c.rawMap ?? {};

        // 1. My Calls tab filter
        if (_selectedTab == 1 && (c.assignedTo ?? 'Admin User') != currentUserName) return false;

        // 2. Owner filter
        if (_selectedOwnerId != null && _selectedOwnerId != 'all') {
          final ownerId = (act['ownerId'] ?? act['owner_id'] ?? '').toString();
          final ownerName = (act['creatorName'] ?? act['ownerName'] ?? c.assignedTo ?? '').toString().toLowerCase();
          if (ownerId != _selectedOwnerId && !ownerName.contains(_selectedOwnerId!.toLowerCase())) {
            return false;
          }
        }

        // 3. Search query
        if (_searchQuery.isEmpty) return true;
        return c.title.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();

      // Status, create date and outcome are re-checked here as well as being
      // sent to the API. They go through narrowInMemory so a value the app and
      // the API spell differently cannot empty the screen — the rows are shown
      // and the mismatch is logged instead.
      String? createdOf(CallModel c) =>
          (c.rawMap?['createdAt'] ?? c.rawMap?['created_at'] ?? c.rawMap?['scheduledAt'] ?? c.rawMap?['scheduled_at'] ?? c.startTime)
              ?.toString();

      if (FilterValue.orNull(_selectedStatusFilter) != null) {
        filteredCalls = narrowInMemory(
          rows: filteredCalls,
          filter: 'Status',
          selection: _selectedStatusFilter,
          // The pill lists both statuses and outcomes, so both are tried.
          test: (c) =>
              FilterValue.matchesSlug(_selectedStatusFilter, c.rawMap?['status']?.toString()) ||
              FilterValue.matchesSlug(_selectedStatusFilter, c.outcome),
          storedValue: (c) => c.rawMap?['status']?.toString() ?? c.outcome,
        );
      }

      if (!FilterDateRange.isUnset(_selectedCreateDate)) {
        filteredCalls = narrowInMemory(
          rows: filteredCalls,
          filter: 'Create date',
          selection: _selectedCreateDate,
          test: (c) => FilterDateRange.matches(_selectedCreateDate, createdOf(c)),
          storedValue: createdOf,
        );
      }

      if (_selectedOutcomeFilter != null && _selectedOutcomeFilter!.isNotEmpty) {
        filteredCalls = narrowInMemory(
          rows: filteredCalls,
          filter: 'Outcome',
          selection: _selectedOutcomeFilter,
          test: (c) => c.outcome.toLowerCase().contains(_selectedOutcomeFilter!.toLowerCase()),
          storedValue: (c) => c.outcome,
        );
      }

      if (_currentSort == ContactSortOption.aToZ) {
        filteredCalls.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      } else if (_currentSort == ContactSortOption.zToA) {
        filteredCalls.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
      }

      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Column(
            children: [
              // 1. Top Header Row: Call Icon + Calls Title + "+ Call" Button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.white,
                child: Row(
                  children: [
                    const Icon(
                      Icons.phone_outlined,
                      color: Color(0xFF00A884),
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Calls',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const Spacer(),

                    // + Call Button
                    ElevatedButton.icon(
                      onPressed: () async {
                        final newCall = await LogCallModal.show(context);
                        if (newCall != null) {
                          _loadCalls();
                        }
                      },
                      icon: const Icon(Icons.add, size: 18, color: Colors.white),
                      label: Text(
                        'Call',
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

              // 2. Search & 3-Dot Filter/Sort Bar Section
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  children: [
                    SearchAndFilterBar(
                      searchHint: 'Search calls...',
                      allLabel: 'All Calls',
                      mineLabel: 'Mine Calls',
                      onSearchChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim();
                        });
                      },
                      onRefreshTap: _loadCalls,
                      onSegmentChanged: (index) {
                        setState(() {
                          _selectedTab = index;
                        });
                      },
                      isFilterActive: (_selectedOwnerId != null && _selectedOwnerId != 'all') ||
                          (_selectedCreateDate != null && _selectedCreateDate != 'All time') ||
                          (_selectedStatusFilter != null && _selectedStatusFilter != 'All statuses') ||
                          (_selectedOutcomeFilter != null && _selectedOutcomeFilter!.isNotEmpty),
                      isFilterExpanded: _isFilterExpanded,
                      onToggleFilterExpanded: () {
                        setState(() {
                          _isFilterExpanded = !_isFilterExpanded;
                        });
                      },
                      onClearTap: () {
                        setState(() {
                          _selectedOwnerId = null;
                          _selectedCreateDate = null;
                          _selectedStatusFilter = null;
                          _selectedOutcomeFilter = null;
                          _searchQuery = '';
                        });
                        _loadCalls();
                      },
                    ),

                    if (_isFilterExpanded)
                      CallInlineFilterSection(
                        selectedOwnerId: _selectedOwnerId,
                        selectedCreateDate: _selectedCreateDate,
                        selectedStatus: _selectedStatusFilter,
                        // Each change replaces just that filter and reissues
                        // the request, so the others stay applied.
                        onOwnerChanged: (val) {
                          setState(() {
                            _selectedOwnerId = val;
                          });
                          _loadCalls();
                        },
                        onCreateDateChanged: (val) {
                          setState(() {
                            _selectedCreateDate = val;
                          });
                          _loadCalls();
                        },
                        onStatusChanged: (val) {
                          setState(() {
                            _selectedStatusFilter = val;
                          });
                          _loadCalls();
                        },
                      ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // 3. Calls List Container Card
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
                        // Main List Content or Empty State
                        Expanded(
                          child: AppRefreshIndicator(
                            onRefresh: () async {
                              await _loadCalls();
                            },
                            child: _isLoadingCalls && _calls.isEmpty
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF00A884),
                                    ),
                                  )
                                : filteredCalls.isEmpty
                                    ? ListView(
                                        physics: const AlwaysScrollableScrollPhysics(
                                            parent: BouncingScrollPhysics()),
                                        children: [
                                          const SizedBox(height: 120),
                                          Center(
                                            child: Padding(
                                              padding: const EdgeInsets.all(24),
                                              child: Text(
                                                'No call logs found. Click "+ Call" to add one.',
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
                                        itemCount: filteredCalls.length,
                                        itemBuilder: (context, index) {
                                          final c = filteredCalls[index];
                                          return _buildCallTile(c);
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
                                filteredCalls.isEmpty 
                                    ? '0-0 of 0' 
                                    : '1-${filteredCalls.length} of ${filteredCalls.length}',
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
      debugPrint('[CallsScreen Build Crash]: $e\n$stack');
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





  Widget _buildCallTile(CallModel call) {
    final bool isSelected = call.id != null && call.id == _selectedCallId;

    return InkWell(
      // The key rides along with the selection so the selected row can always
      // be scrolled to, however it got selected.
      key: isSelected ? _selectedTileKey : null,
      onTap: () async {
        // Mark this call as the selected one before opening its details.
        setState(() => _selectedCallId = call.id);

        final act = call.rawMap ?? {};

        String? compId = (act['companyId'] ?? act['company_id'] ?? (act['company'] is Map ? act['company']['id'] : null) ?? call.companyId)?.toString();

        String? contactId = (act['contactId'] ?? act['contact_id'] ?? (act['contact'] is Map ? act['contact']['id'] : null) ?? call.contactId)?.toString();

        String? dealId = (act['dealId'] ?? act['deal_id'] ?? (act['deal'] is Map ? act['deal']['id'] : null) ?? call.dealId)?.toString();

        if (act['associations'] is Map) {
          final assocMap = act['associations'] as Map;
          if ((compId == null || compId.isEmpty) && assocMap['Companies'] is List && (assocMap['Companies'] as List).isNotEmpty) {
            final firstComp = (assocMap['Companies'] as List).first;
            if (firstComp is Map) {
              compId = (firstComp['id'] ?? firstComp['_id'] ?? firstComp['objectId'])?.toString();
            }
          }
          if ((contactId == null || contactId.isEmpty) && assocMap['Contacts'] is List && (assocMap['Contacts'] as List).isNotEmpty) {
            final firstContact = (assocMap['Contacts'] as List).first;
            if (firstContact is Map) {
              contactId = (firstContact['id'] ?? firstContact['_id'] ?? firstContact['objectId'])?.toString();
            }
          }
          if ((dealId == null || dealId.isEmpty) && assocMap['Deals'] is List && (assocMap['Deals'] as List).isNotEmpty) {
            final firstDeal = (assocMap['Deals'] as List).first;
            if (firstDeal is Map) {
              dealId = (firstDeal['id'] ?? firstDeal['_id'] ?? firstDeal['objectId'])?.toString();
            }
          }
        } else if (act['associations'] is List) {
          for (final assoc in (act['associations'] as List)) {
            if (assoc is Map) {
              final id = (assoc['objectId'] ?? assoc['id'] ?? assoc['_id'])?.toString();
              final type = (assoc['objectType'] ?? assoc['type'])?.toString().toLowerCase();
              if (id != null && id.isNotEmpty) {
                if ((type == 'company' || type == 'companies') && (compId == null || compId.isEmpty)) {
                  compId = id;
                } else if ((type == 'contact' || type == 'contacts') && (contactId == null || contactId.isEmpty)) {
                  contactId = id;
                } else if ((type == 'deal' || type == 'deals') && (dealId == null || dealId.isEmpty)) {
                  dealId = id;
                }
              }
            }
          }
        }

        if (compId != null && compId.isNotEmpty) {
          await context.pushNamed(
              RouteNames.companyDetails,
              pathParameters: {RoutePaths.idParam: compId},
              queryParameters: RoutePaths.recordActivityQuery(call.id),
            );
          _loadCalls();
        } else if (contactId != null && contactId.isNotEmpty) {
          await context.pushNamed(
              RouteNames.contactDetails,
              pathParameters: {RoutePaths.idParam: contactId},
              queryParameters: RoutePaths.recordActivityQuery(call.id),
            );
          _loadCalls();
        } else if (dealId != null && dealId.isNotEmpty) {
          await context.pushNamed(
              RouteNames.dealDetails,
              pathParameters: {RoutePaths.idParam: dealId},
              queryParameters: RoutePaths.recordActivityQuery(call.id),
            );
          _loadCalls();
        } else {
          // /activities/calls/details/:id
          final callId = call.id;
          if (callId == null || callId.isEmpty) return;
          final refreshed = await context.pushNamed<bool>(
            RouteNames.callDetails,
            pathParameters: {RoutePaths.idParam: callId},
          );
          if (refreshed == true) {
            _loadCalls();
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
              Icons.phone_outlined,
              color: Color(0xFF00A884),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  call.title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F766E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatCallDateTime(call.startTime),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Logged by: ${call.assignedTo ?? 'Admin User'}',
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
