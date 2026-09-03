import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/navigation/route_names.dart';
import '../../../../core/navigation/route_paths.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:crmproject/core/widgets/app_refresh_indicator.dart';

import '../../../../core/repositories/master_data_repository.dart';
import '../../../../core/utils/department_aware_state.dart';
import '../../../../core/utils/filter_query_utils.dart';
import '../../../../core/utils/list_scroll_utils.dart';
import '../../../../core/widgets/search_and_filter_bar.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../contacts/presentation/providers/contact_provider.dart';
import '../../../departments/presentation/providers/department_provider.dart';
import '../../../navigation/presentation/providers/navigation_provider.dart';
import '../widgets/email_inline_filter_section.dart';

class EmailsScreen extends StatefulWidget {
  const EmailsScreen({super.key});

  @override
  State<EmailsScreen> createState() => _EmailsScreenState();
}

class _EmailsScreenState extends State<EmailsScreen> with DepartmentAwareState {
  final ScrollController _scrollController = ScrollController();

  int _selectedTab = 0; // 0: All emails, 1: My emails
  String _searchQuery = '';
  ContactSortOption _currentSort = ContactSortOption.mostRecent;
  bool _isFilterExpanded = false;

  String? _selectedOwnerId;
  String? _selectedCreateDate;
  String? _selectedStatusFilter;

  final List<Map<String, dynamic>> _emails = [];
  
  int _currentPage = 1;
  static const int _pageSize = 25;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  String? _errorMessage;

  /// Id of the email the user selected. Held by id so the highlight survives a
  /// reload of the list.
  String? _selectedEmailId;

  /// Marks the selected row so it can be scrolled to once it is built.
  final GlobalKey _selectedTileKey = GlobalKey();

  /// Activity requested by another screen, applied once the list has loaded.
  String? _pendingFocusId;
  String? _appliedFocusId;
  bool _hasLoadedOnce = false;

  /// Extra pages to pull while looking for a requested email, so an activity
  /// that is not on the first page can still be reached.
  static const int _maxFocusPageFetches = 5;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchEmails(reset: true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // This screen keeps its own list, so it has to notice a department switch
    // itself. It previously loaded once in initState and never reacted, which
    // left the previous department's emails on screen indefinitely.
    watchDepartmentChanges((_) {
      setState(() {
        _emails.clear();
        _selectedEmailId = null;
        _currentPage = 1;
        _hasMoreData = true;
      });
      _fetchEmails(reset: true);
    });

    // An email opened from elsewhere in the app (e.g. a notification).
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

  String? _emailId(Map<String, dynamic> email) =>
      (email['id'] ?? email['_id'])?.toString();

  /// Highlights the requested email and brings it into view. Does nothing until
  /// the list has loaded — [_fetchEmails] calls back in once it has.
  Future<void> _applyPendingFocus() async {
    final id = _pendingFocusId;
    if (id == null || !_hasLoadedOnce || _isLoading) return;

    _pendingFocusId = null;

    // The list is paginated, so keep pulling pages until the email shows up.
    var fetches = 0;
    while (mounted &&
        !_emails.any((e) => _emailId(e) == id) &&
        _hasMoreData &&
        fetches < _maxFocusPageFetches) {
      fetches++;
      await _fetchEmails(reset: false);
    }

    // Not in this list (deleted, filtered out, or too far back): leave the
    // screen as it is rather than scrolling somewhere arbitrary.
    if (!mounted || !_emails.any((e) => _emailId(e) == id)) return;

    setState(() => _selectedEmailId = id);
    await ensureListItemVisible(
      controller: _scrollController,
      itemKey: _selectedTileKey,
    );
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && !_isLoadingMore && _hasMoreData) {
        _fetchEmails(reset: false);
      }
    }
  }

  String get _sortApiField {
    switch (_currentSort) {
      case ContactSortOption.aToZ:
      case ContactSortOption.zToA:
        return 'title';
      case ContactSortOption.mostRecent:
        return 'scheduled_at';
    }
  }

  String get _sortApiOrder {
    switch (_currentSort) {
      case ContactSortOption.aToZ:
        return 'asc';
      case ContactSortOption.zToA:
      case ContactSortOption.mostRecent:
        return 'desc';
    }
  }

  /// The Owner pill's value as an `ownerId` query value.
  String? get _ownerQuery => FilterValue.orNull(_selectedOwnerId);

  /// The Status pill's value as a `status` query value, when the chosen label
  /// is one of the four the endpoint accepts. Anything else stays an
  /// in-memory match against the record's own status field.
  String? get _statusQuery => FilterValue.activityStatus(_selectedStatusFilter);

  String? get _createdDateRangeQuery => FilterDateRange.toQueryValue(_selectedCreateDate);

  Future<void> _fetchEmails({bool reset = false}) async {
    if (!mounted) return;

    if (reset) {
      setState(() {
        _currentPage = 1;
        _hasMoreData = true;
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      if (_isLoadingMore || !_hasMoreData) return;
      setState(() {
        _isLoadingMore = true;
      });
    }

    final pageToFetch = reset ? 1 : _currentPage;

    debugPrint('==================================================');
    debugPrint('Email API Request:');
    debugPrint('GET /api/activities');
    debugPrint('type=email');
    debugPrint('page=$pageToFetch');
    debugPrint('limit=$_pageSize');
    debugPrint('sort=$_sortApiField');
    debugPrint('order=$_sortApiOrder');
    if (_searchQuery.isNotEmpty) debugPrint('search=$_searchQuery');
    debugPrint('==================================================');

    try {
      final repository = MasterDataRepositoryImpl();
      final deptId = context.read<DepartmentProvider>().selectedDepartmentId;

      debugPrint('[EmailsScreen] filters → owner=${_ownerQuery ?? '-'} '
          'status=${_statusQuery ?? '-'} '
          'createdDateRange=${_createdDateRangeQuery ?? '-'} '
          'search=${_searchQuery.isEmpty ? '-' : _searchQuery}');

      final items = await repository.getActivities(
        type: 'email',
        page: pageToFetch,
        limit: _pageSize,
        sort: _sortApiField,
        order: _sortApiOrder,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        departmentId: deptId,
        ownerId: _ownerQuery,
        status: _statusQuery,
        createdDateRange: _createdDateRangeQuery,
      );

      debugPrint('[Emails Received]: ${items.length}');

      // Strict filter: only items with type == 'email'
      final emailItems = items.where((item) {
        final type = (item['type'] ?? item['activity_type'])?.toString().toLowerCase();
        return type == 'email';
      }).toList();

      if (!mounted) return;

      setState(() {
        if (reset) {
          _emails.clear();
        }

        // Deduplicate by ID
        final existingIds = _emails.map((e) => (e['id'] ?? e['_id'])?.toString()).toSet();
        for (final item in emailItems) {
          final id = (item['id'] ?? item['_id'])?.toString();
          if (id == null || !existingIds.contains(id)) {
            _emails.add(item);
            if (id != null) existingIds.add(id);
          }
        }

        _currentPage = pageToFetch + 1;
        _hasMoreData = items.length >= _pageSize;
        _isLoading = false;
        _isLoadingMore = false;
        _hasLoadedOnce = true;
      });

      // The list is populated now, so an activity requested by another screen
      // (including one requested before this load started) can be located.
      if (reset) _applyPendingFocus();
    } catch (e) {
      debugPrint('[Fetch Emails ERROR]: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load emails. Tap to retry.';
        _isLoading = false;
        _isLoadingMore = false;
        _hasLoadedOnce = true;
      });
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.trim();
    });
    _fetchEmails(reset: true);
  }

  String _formatEmailDateTime(String raw) {
    if (raw.isEmpty) return '--';
    try {
      final dt = DateTime.parse(raw).toLocal();
      int hour = dt.hour;
      final ampm = hour >= 12 ? 'PM' : 'AM';
      hour = hour % 12;
      if (hour == 0) hour = 12;
      final hourStr = hour.toString().padLeft(2, '0');
      final minStr = dt.minute.toString().padLeft(2, '0');
      final dateStr = '${dt.month}/${dt.day}/${dt.year}';
      return '$hourStr:$minStr $ampm  $dateStr';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final currentUserName = auth.currentUser?.fullName ?? 'Admin User';
    final currentUserId = auth.currentUser?.id ?? '';

    final isFilterActive = (_selectedOwnerId != null && _selectedOwnerId != 'all') ||
        (_selectedCreateDate != null && _selectedCreateDate != 'All time') ||
        (_selectedStatusFilter != null && _selectedStatusFilter != 'All statuses');

    var filteredEmails = _emails.where((e) {
      // 1. Tab filter (All vs Mine)
      if (_selectedTab == 1) {
        final ownerId = (e['ownerId'] ?? e['owner_id'] ?? e['owner']?['id'])?.toString();
        final ownerName = (e['ownerName'] ?? e['owner']?['name'] ?? e['assignedTo'])?.toString();
        final matchesOwner = (ownerId != null && ownerId == currentUserId) ||
            (ownerName != null && ownerName == currentUserName);
        if (!matchesOwner) return false;
      }

      // 2. Owner filter
      if (_selectedOwnerId != null && _selectedOwnerId != 'all') {
        final ownerId = (e['ownerId'] ?? e['owner_id'] ?? e['owner']?['id'])?.toString();
        if (ownerId != _selectedOwnerId) return false;
      }

      return true;
    }).toList();

    // Status and create date are re-checked here as well as being sent to the
    // API. They go through narrowInMemory so a value the app and the API spell
    // differently cannot empty the screen — the rows are shown and the
    // mismatch is logged instead.
    String? createdOf(Map<String, dynamic> e) =>
        (e['createdAt'] ?? e['created_at'] ?? e['scheduledAt'] ?? e['scheduled_at'])?.toString();

    if (FilterValue.orNull(_selectedStatusFilter) != null) {
      filteredEmails = narrowInMemory(
        rows: filteredEmails,
        filter: 'Status',
        selection: _selectedStatusFilter,
        test: (e) =>
            FilterValue.matchesSlug(_selectedStatusFilter, e['status']?.toString()) ||
            FilterValue.matchesSlug(_selectedStatusFilter, e['state']?.toString()),
        storedValue: (e) => (e['status'] ?? e['state'])?.toString(),
      );
    }

    if (!FilterDateRange.isUnset(_selectedCreateDate)) {
      filteredEmails = narrowInMemory(
        rows: filteredEmails,
        filter: 'Create date',
        selection: _selectedCreateDate,
        test: (e) => FilterDateRange.matches(_selectedCreateDate, createdOf(e)),
        storedValue: createdOf,
      );
    }

    // Client-side sort fallback
    if (_currentSort == ContactSortOption.aToZ) {
      filteredEmails.sort((a, b) {
        final t1 = (a['title'] ?? a['subject'] ?? '').toString().toLowerCase();
        final t2 = (b['title'] ?? b['subject'] ?? '').toString().toLowerCase();
        return t1.compareTo(t2);
      });
    } else if (_currentSort == ContactSortOption.zToA) {
      filteredEmails.sort((a, b) {
        final t1 = (a['title'] ?? a['subject'] ?? '').toString().toLowerCase();
        final t2 = (b['title'] ?? b['subject'] ?? '').toString().toLowerCase();
        return t2.compareTo(t1);
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Header Row: Email Icon + Title
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Row(
                children: [
                  const Icon(
                    Icons.email_outlined,
                    color: Color(0xFF00A884),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Emails',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
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
                    searchHint: 'Search emails...',
                    allLabel: 'All Emails',
                    mineLabel: 'Mine Emails',
                    onSearchChanged: _onSearchChanged,
                    onSegmentChanged: (index) {
                      setState(() {
                        _selectedTab = index;
                      });
                    },
                    isFilterActive: isFilterActive,
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
                        _searchQuery = '';
                      });
                      _fetchEmails(reset: true);
                    },
                  ),

                  // Email Inline Filter Section matching Company and Contact screens (Email owner, Create date, Status)
                  if (_isFilterExpanded)
                    EmailInlineFilterSection(
                      selectedOwnerId: _selectedOwnerId,
                      selectedCreateDate: _selectedCreateDate,
                      selectedStatus: _selectedStatusFilter,
                      // Each change replaces just that filter and reissues the
                      // request from page 1, so the others stay applied.
                      onOwnerChanged: (val) {
                        setState(() {
                          _selectedOwnerId = val;
                        });
                        _fetchEmails(reset: true);
                      },
                      onCreateDateChanged: (val) {
                        setState(() {
                          _selectedCreateDate = val;
                        });
                        _fetchEmails(reset: true);
                      },
                      onStatusChanged: (val) {
                        setState(() {
                          _selectedStatusFilter = val;
                        });
                        _fetchEmails(reset: true);
                      },
                    ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // 3. Main Content List Area
            Expanded(
              child: AppRefreshIndicator(
                onRefresh: () async {
                  await _fetchEmails(reset: true);
                },
                child: _buildMainContent(filteredEmails),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(List<Map<String, dynamic>> filteredEmails) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00A884)),
        ),
      );
    }

    if (_errorMessage != null && _emails.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _fetchEmails(reset: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A884),
              ),
              child: Text('Retry', style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (filteredEmails.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.email_outlined, size: 48, color: Color(0xFF94A3B8)),
                const SizedBox(height: 12),
                Text(
                  'No emails found',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.all(16),
      itemCount: filteredEmails.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == filteredEmails.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00A884)),
              ),
            ),
          );
        }
        return _buildEmailTile(filteredEmails[index]);
      },
    );
  }

  Widget _buildEmailTile(Map<String, dynamic> act) {
    final title = (act['title'] ?? act['subject'] ?? 'Email').toString();
    final startTime = (act['scheduledAt'] ?? act['scheduled_at'] ?? act['createdAt'] ?? '').toString();
    final ownerName = (act['ownerName'] ?? act['owner']?['name'] ?? act['assignedTo'] ?? 'Admin User').toString();

    final id = _emailId(act);
    final bool isSelected = id != null && id == _selectedEmailId;

    return Container(
      // The key rides along with the selection so the selected row can always
      // be scrolled to, however it got selected.
      key: isSelected ? _selectedTileKey : null,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFE6F4F1) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? const Color(0xFF00A884) : const Color(0xFFE2E8F0),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: () async {
          // Mark this email as the selected one before opening its details.
          setState(() => _selectedEmailId = id);
          _onEmailTileTap(act);
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.email_outlined,
                  color: Color(0xFF8B5CF6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F766E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatEmailDateTime(startTime),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Logged by: $ownerName',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFCBD5E1),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onEmailTileTap(Map<String, dynamic> act) async {

    String? compId = (act['companyId'] ?? act['company_id'] ?? (act['company'] is Map ? act['company']['id'] : null))?.toString();

    String? contactId = (act['contactId'] ?? act['contact_id'] ?? (act['contact'] is Map ? act['contact']['id'] : null))?.toString();

    String? dealId = (act['dealId'] ?? act['deal_id'] ?? (act['deal'] is Map ? act['deal']['id'] : null))?.toString();

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
        queryParameters: RoutePaths.recordActivityQuery((act['id'] ?? act['_id'])?.toString()),
      );
      _fetchEmails(reset: true);
    } else if (contactId != null && contactId.isNotEmpty) {
      await context.pushNamed(
        RouteNames.contactDetails,
        pathParameters: {RoutePaths.idParam: contactId},
        queryParameters: RoutePaths.recordActivityQuery((act['id'] ?? act['_id'])?.toString()),
      );
      _fetchEmails(reset: true);
    } else if (dealId != null && dealId.isNotEmpty) {
      await context.pushNamed(
        RouteNames.dealDetails,
        pathParameters: {RoutePaths.idParam: dealId},
        queryParameters: RoutePaths.recordActivityQuery((act['id'] ?? act['_id'])?.toString()),
      );
      _fetchEmails(reset: true);
    } else {
      // /activities/emails/details/:id
      final emailId = (act['id'] ?? act['_id'])?.toString();
      if (emailId == null || emailId.isEmpty) return;
      await context.pushNamed(
        RouteNames.emailDetails,
        pathParameters: {RoutePaths.idParam: emailId},
      );
      _fetchEmails(reset: true);
    }
  }

  void _showSortMenu(BuildContext context) async {
    final selected = await showMenu<ContactSortOption>(
      context: context,
      position: const RelativeRect.fromLTRB(200, 100, 16, 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 6,
      items: [
        PopupMenuItem<ContactSortOption>(
          enabled: false,
          height: 32,
          child: Text(
            'SORT BY',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF94A3B8),
              letterSpacing: 0.8,
            ),
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<ContactSortOption>(
          value: ContactSortOption.aToZ,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('A to Z', style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: _currentSort == ContactSortOption.aToZ ? FontWeight.w600 : FontWeight.w400)),
              if (_currentSort == ContactSortOption.aToZ) const Icon(Icons.check_rounded, color: Color(0xFF00A884), size: 18),
            ],
          ),
        ),
        PopupMenuItem<ContactSortOption>(
          value: ContactSortOption.zToA,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Z to A', style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: _currentSort == ContactSortOption.zToA ? FontWeight.w600 : FontWeight.w400)),
              if (_currentSort == ContactSortOption.zToA) const Icon(Icons.check_rounded, color: Color(0xFF00A884), size: 18),
            ],
          ),
        ),
        PopupMenuItem<ContactSortOption>(
          value: ContactSortOption.mostRecent,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Most recent', style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: _currentSort == ContactSortOption.mostRecent ? FontWeight.w600 : FontWeight.w400)),
              if (_currentSort == ContactSortOption.mostRecent) const Icon(Icons.check_rounded, color: Color(0xFF00A884), size: 18),
            ],
          ),
        ),
      ],
    );

    if (selected != null) {
      setState(() {
        _currentSort = selected;
      });
      _fetchEmails(reset: true);
    }
  }
}
