import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:crmproject/core/widgets/app_refresh_indicator.dart';
import '../../../../core/repositories/master_data_repository.dart';
import '../../../../core/utils/activity_utils.dart';
import '../../../../core/utils/list_scroll_utils.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../departments/presentation/providers/department_provider.dart';
import '../../../navigation/presentation/providers/navigation_provider.dart';
import '../widgets/log_call_modal.dart';
import '../../../companies/data/models/company_model.dart';
import '../../../companies/presentation/screens/company_details_screen.dart';
import '../../../contacts/data/models/contact_model.dart';
import '../../../contacts/presentation/screens/contact_details_screen.dart';
import '../../../deals/data/models/deal_model.dart';
import '../../../deals/presentation/screens/deal_details_screen.dart';
import '../../../../core/widgets/search_and_filter_bar.dart';
import '../../../contacts/presentation/providers/contact_provider.dart';
import '../widgets/call_inline_filter_section.dart';
import 'call_details_screen.dart';

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
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

  Future<void> _loadCalls() async {
    if (!mounted) return;
    setState(() {
      _isLoadingCalls = true;
    });
    try {
      final repository = MasterDataRepositoryImpl();
      final deptId = context.read<DepartmentProvider>().selectedDepartmentId;
      final activities = await repository.getActivities(type: 'call', page: 1, limit: 25, departmentId: deptId);
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

      final filteredCalls = _calls.where((c) {
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

        // 3. Status filter
        if (_selectedStatusFilter != null && _selectedStatusFilter != 'All statuses') {
          final status = (c.outcome + ' ' + (act['status'] ?? '')).toLowerCase();
          if (!status.contains(_selectedStatusFilter!.toLowerCase())) {
            return false;
          }
        }

        // 4. Create Date filter
        if (_selectedCreateDate != null && _selectedCreateDate != 'All time') {
          final timeStr = (act['scheduledAt'] ?? act['scheduled_at'] ?? act['createdAt'] ?? c.startTime).toString();
          if (timeStr.isNotEmpty) {
            try {
              final itemDt = DateTime.parse(timeStr).toLocal();
              final now = DateTime.now();
              if (_selectedCreateDate == 'Today') {
                if (itemDt.year != now.year || itemDt.month != now.month || itemDt.day != now.day) return false;
              } else if (_selectedCreateDate == 'Yesterday') {
                final yest = now.subtract(const Duration(days: 1));
                if (itemDt.year != yest.year || itemDt.month != yest.month || itemDt.day != yest.day) return false;
              } else if (_selectedCreateDate == 'This week') {
                final weekStart = now.subtract(Duration(days: now.weekday - 1));
                if (itemDt.isBefore(DateTime(weekStart.year, weekStart.month, weekStart.day))) return false;
              } else if (_selectedCreateDate == 'This month') {
                if (itemDt.year != now.year || itemDt.month != now.month) return false;
              } else if (_selectedCreateDate == 'This year') {
                if (itemDt.year != now.year) return false;
              }
            } catch (_) {}
          }
        }

        // 5. Outcome filter
        if (_selectedOutcomeFilter != null && _selectedOutcomeFilter!.isNotEmpty) {
          if (!c.outcome.toLowerCase().contains(_selectedOutcomeFilter!.toLowerCase())) return false;
        }

        // 6. Search query
        if (_searchQuery.isEmpty) return true;
        return c.title.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();

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
                      onSearchChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim();
                        });
                      },
                      onSegmentChanged: (index) {
                        setState(() {
                          _selectedTab = index;
                        });
                      },
                      currentSort: _currentSort,
                      onSortChanged: (ContactSortOption option) {
                        setState(() {
                          _currentSort = option;
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
                    ),

                    if (_isFilterExpanded)
                      CallInlineFilterSection(
                        selectedOwnerId: _selectedOwnerId,
                        selectedCreateDate: _selectedCreateDate,
                        selectedStatus: _selectedStatusFilter,
                        onOwnerChanged: (val) {
                          setState(() {
                            _selectedOwnerId = val;
                          });
                        },
                        onCreateDateChanged: (val) {
                          setState(() {
                            _selectedCreateDate = val;
                          });
                        },
                        onStatusChanged: (val) {
                          setState(() {
                            _selectedStatusFilter = val;
                          });
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
        String? compName = (act['companyName'] ?? act['company_name'] ?? (act['company'] is Map ? act['company']['name'] : null))?.toString();

        String? contactId = (act['contactId'] ?? act['contact_id'] ?? (act['contact'] is Map ? act['contact']['id'] : null) ?? call.contactId)?.toString();
        String? contactName = (act['contactName'] ?? act['contact_name'] ?? (act['contact'] is Map ? act['contact']['firstName'] ?? act['contact']['name'] : null))?.toString();

        String? dealId = (act['dealId'] ?? act['deal_id'] ?? (act['deal'] is Map ? act['deal']['id'] : null) ?? call.dealId)?.toString();
        String? dealName = (act['dealName'] ?? act['deal_name'] ?? (act['deal'] is Map ? act['deal']['title'] : null))?.toString();

        if (act['associations'] is Map) {
          final assocMap = act['associations'] as Map;
          if ((compId == null || compId.isEmpty) && assocMap['Companies'] is List && (assocMap['Companies'] as List).isNotEmpty) {
            final firstComp = (assocMap['Companies'] as List).first;
            if (firstComp is Map) {
              compId = (firstComp['id'] ?? firstComp['_id'] ?? firstComp['objectId'])?.toString();
              compName = (firstComp['name'] ?? firstComp['title'])?.toString();
            }
          }
          if ((contactId == null || contactId.isEmpty) && assocMap['Contacts'] is List && (assocMap['Contacts'] as List).isNotEmpty) {
            final firstContact = (assocMap['Contacts'] as List).first;
            if (firstContact is Map) {
              contactId = (firstContact['id'] ?? firstContact['_id'] ?? firstContact['objectId'])?.toString();
              contactName = (firstContact['name'] ?? firstContact['title'])?.toString();
            }
          }
          if ((dealId == null || dealId.isEmpty) && assocMap['Deals'] is List && (assocMap['Deals'] as List).isNotEmpty) {
            final firstDeal = (assocMap['Deals'] as List).first;
            if (firstDeal is Map) {
              dealId = (firstDeal['id'] ?? firstDeal['_id'] ?? firstDeal['objectId'])?.toString();
              dealName = (firstDeal['name'] ?? firstDeal['title'])?.toString();
            }
          }
        } else if (act['associations'] is List) {
          for (final assoc in (act['associations'] as List)) {
            if (assoc is Map) {
              final id = (assoc['objectId'] ?? assoc['id'] ?? assoc['_id'])?.toString();
              final type = (assoc['objectType'] ?? assoc['type'])?.toString().toLowerCase();
              final name = (assoc['name'] ?? assoc['title'])?.toString();
              if (id != null && id.isNotEmpty) {
                if ((type == 'company' || type == 'companies') && (compId == null || compId.isEmpty)) {
                  compId = id;
                  compName = name;
                } else if ((type == 'contact' || type == 'contacts') && (contactId == null || contactId.isEmpty)) {
                  contactId = id;
                  contactName = name;
                } else if ((type == 'deal' || type == 'deals') && (dealId == null || dealId.isEmpty)) {
                  dealId = id;
                  dealName = name;
                }
              }
            }
          }
        }

        if (compId != null && compId.isNotEmpty) {
          final companyModel = CompanyModel(
            id: compId,
            name: compName ?? 'Company',
          );
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CompanyDetailsScreen(company: companyModel, initialTabIndex: 1, highlightActivityId: call.id),
            ),
          );
          _loadCalls();
        } else if (contactId != null && contactId.isNotEmpty) {
          final contactModel = ContactModel(
            id: contactId,
            firstName: contactName ?? 'Contact',
            email: '',
          );
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ContactDetailsScreen(contact: contactModel, initialTabIndex: 1, highlightActivityId: call.id),
            ),
          );
          _loadCalls();
        } else if (dealId != null && dealId.isNotEmpty) {
          final dealModel = DealModel(
            id: dealId,
            title: dealName ?? 'Deal',
            amount: 0.0,
            stage: '',
            probability: 0,
          );
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DealDetailsScreen(deal: dealModel, initialTabIndex: 1, highlightActivityId: call.id),
            ),
          );
          _loadCalls();
        } else {
          final refreshed = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => CallDetailsScreen(call: call),
            ),
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
