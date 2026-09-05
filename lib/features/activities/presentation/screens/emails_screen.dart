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
import '../../../../core/utils/activity_delete.dart';

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
  final Set<String> _selectedForDelete = {};
  bool _isDeleting = false;
  
  int _currentPage = 1;
  int _totalCount = 0;
  static const int _pageSize = 25;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  String? _errorMessage;

  String _formatCount(int count) {
    return count.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  int get _totalPages {
    if (_totalCount <= 0) return 1;
    return (_totalCount / _pageSize).ceil();
  }

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

    watchDepartmentChanges((_) {
      setState(() {
        _emails.clear();
        _selectedEmailId = null;
        _selectedForDelete.clear();
        _currentPage = 1;
        _totalCount = 0;
        _hasMoreData = true;
      });
      _fetchEmails(reset: true);
    });

    final requested = context.watch<NavigationProvider>().focusedActivityId;
    if (requested != null && requested != _appliedFocusId) {
      _appliedFocusId = requested;
      _pendingFocusId = requested;
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

  Future<void> _applyPendingFocus() async {
    final id = _pendingFocusId;
    if (id == null || !_hasLoadedOnce || _isLoading) return;

    _pendingFocusId = null;

    var fetches = 0;
    while (mounted &&
        !_emails.any((e) => _emailId(e) == id) &&
        _hasMoreData &&
        fetches < _maxFocusPageFetches) {
      fetches++;
      await _fetchEmails(reset: false);
    }

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

  String? get _ownerQuery => FilterValue.orNull(_selectedOwnerId);

  String? get _statusQuery => FilterValue.activityStatus(_selectedStatusFilter);

  String? get _createdDateRangeQuery => FilterDateRange.toQueryValue(_selectedCreateDate);

  Future<void> _fetchEmails({bool reset = false, int? page}) async {
    if (!mounted) return;

    final pageToFetch = page ?? (reset ? 1 : _currentPage);

    if (reset || page != null) {
      setState(() {
        _currentPage = pageToFetch;
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

      final resMap = await repository.getActivitiesWithMeta(
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

      final items = (resMap['data'] as List).whereType<Map<String, dynamic>>().toList();
      final total = (resMap['total'] as int?) ?? items.length;

      final emailItems = items.where((item) {
        final type = (item['type'] ?? item['activity_type'])?.toString().toLowerCase();
        return type == 'email';
      }).toList();

      if (!mounted) return;

      setState(() {
        _emails.clear();
        _emails.addAll(emailItems);
        _totalCount = total;
        _currentPage = pageToFetch;
        _hasMoreData = pageToFetch < ((total / _pageSize).ceil());
        _isLoading = false;
        _isLoadingMore = false;
        _hasLoadedOnce = true;
      });

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

  Future<void> _confirmAndDeleteSelectedEmails() async {
    final targets = _emails.where((e) {
      final id = _emailId(e);
      return id != null && _selectedForDelete.contains(id);
    }).toList();
    if (targets.isEmpty || _isDeleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          targets.length == 1 ? 'Delete email' : 'Delete ${targets.length} emails',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          targets.length == 1
              ? 'Are you sure you want to delete this email log? This action cannot be undone.'
              : 'Are you sure you want to delete these ${targets.length} email logs? This action cannot be undone.',
          style: GoogleFonts.poppins(fontSize: 13.5, color: const Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);

    final targetIds = targets.map((e) => _emailId(e)).whereType<String>().toList();
    final result = await deleteActivities(targetIds);
    if (!mounted) return;

    setState(() {
      _isDeleting = false;
      _selectedForDelete.removeWhere((id) => result.deleted.contains(id));
    });

    if (result.deleted.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.deleted.length == 1
                ? 'Email deleted successfully'
                : '${result.deleted.length} emails deleted successfully',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          backgroundColor: const Color(0xFF00A884),
        ),
      );
      _fetchEmails(reset: true);
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
    } else if (_currentSort == ContactSortOption.mostRecent) {
      filteredEmails.sort((a, b) {
        final d1Str = (a['scheduledAt'] ?? a['scheduled_at'] ?? a['createdAt'] ?? a['created_at'] ?? '').toString();
        final d2Str = (b['scheduledAt'] ?? b['scheduled_at'] ?? b['createdAt'] ?? b['created_at'] ?? '').toString();
        final d1 = DateTime.tryParse(d1Str) ?? DateTime(1970);
        final d2 = DateTime.tryParse(d2Str) ?? DateTime(1970);
        return d2.compareTo(d1);
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
                  const Spacer(),
                  if (_selectedForDelete.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: _isDeleting ? null : _confirmAndDeleteSelectedEmails,
                      icon: _isDeleting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.white),
                      label: Text(
                        'Delete (${_selectedForDelete.length})',
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                    countText: _isLoading && _emails.isEmpty
                        ? '...'
                        : _formatCount(_totalCount > 0 ? _totalCount : filteredEmails.length),
                    currentSort: _currentSort,
                    onSortChanged: (sort) {
                      setState(() {
                        _currentSort = sort;
                      });
                      _fetchEmails(reset: true);
                    },
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

            // 4. Pagination Footer Bar
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    filteredEmails.isEmpty 
                        ? '0-0 of 0' 
                        : '${((_currentPage - 1) * _pageSize) + 1}-${((_currentPage - 1) * _pageSize) + filteredEmails.length} of ${_formatCount(_totalCount > 0 ? _totalCount : filteredEmails.length)}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: _currentPage > 1 && !_isLoading
                            ? () {
                                _fetchEmails(page: _currentPage - 1);
                              }
                            : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF334155),
                          disabledForegroundColor: const Color(0xFFCBD5E1),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: Text(
                          'Previous',
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$_currentPage/$_totalPages',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: _currentPage < _totalPages && !_isLoading
                            ? () {
                                _fetchEmails(page: _currentPage + 1);
                              }
                            : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF334155),
                          disabledForegroundColor: const Color(0xFFCBD5E1),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: Text(
                          'Next',
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
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
    final startTime = (act['scheduledAt'] ?? act['scheduled_at'] ?? act['completedAt'] ?? act['completed_at'] ?? act['createdAt'] ?? act['created_at'] ?? '').toString();
    
    String ownerName = (act['creatorName'] ?? act['ownerName'] ?? act['owner']?['name'])?.toString() ?? '';
    if (ownerName.isEmpty && act['creatorFirstName'] != null) {
      ownerName = '${act['creatorFirstName']} ${act['creatorLastName'] ?? ''}'.trim();
    }
    if (ownerName.isEmpty && act['assignees'] is List && (act['assignees'] as List).isNotEmpty) {
      final firstAssignee = (act['assignees'] as List).first;
      if (firstAssignee is Map) {
        ownerName = '${firstAssignee['firstName'] ?? ''} ${firstAssignee['lastName'] ?? ''}'.trim();
        if (ownerName.isEmpty) ownerName = firstAssignee['email']?.toString() ?? '';
      }
    }
    if (ownerName.isEmpty) {
      ownerName = (act['assignedTo'] ?? 'Admin User').toString();
    }

    final recipientName = (act['recipientName'] ?? act['recipient_name'])?.toString();
    final companyName = (act['companyName'] ?? act['company_name'])?.toString();
    final status = (act['status'] ?? '').toString();

    Widget? statusChip;
    if (status.isNotEmpty) {
      final isCompleted = status.toLowerCase() == 'completed';
      final isPending = status.toLowerCase() == 'pending';
      final bgColor = isCompleted
          ? const Color(0xFFDCFCE7)
          : (isPending ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9));
      final textColor = isCompleted
          ? const Color(0xFF166534)
          : (isPending ? const Color(0xFF92400E) : const Color(0xFF475569));
      final label = status[0].toUpperCase() + status.substring(1);

      statusChip = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      );
    }

    final id = _emailId(act);
    final bool isSelected = id != null && id == _selectedEmailId;
    final bool isChecked = id != null && _selectedForDelete.contains(id);

    return Container(
      key: isSelected ? _selectedTileKey : null,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isChecked
            ? const Color(0xFFFEF2F2)
            : (isSelected ? const Color(0xFFE6F4F1) : Colors.white),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isChecked
              ? const Color(0xFFFCA5A5)
              : (isSelected ? const Color(0xFF00A884) : const Color(0xFFE2E8F0)),
          width: isChecked || isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: () async {
          setState(() => _selectedEmailId = id);
          _onEmailTileTap(act);
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            children: [
              Transform.scale(
                scale: 0.9,
                child: Checkbox(
                  value: isChecked,
                  activeColor: const Color(0xFFEF4444),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onChanged: (bool? val) {
                    if (id == null || id.isEmpty) return;
                    setState(() {
                      if (val == true) {
                        _selectedForDelete.add(id);
                      } else {
                        _selectedForDelete.remove(id);
                      }
                    });
                  },
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.email_outlined,
                  color: Color(0xFF8B5CF6),
                  size: 19,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0F766E),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (statusChip != null) ...[
                          const SizedBox(width: 8),
                          statusChip,
                        ],
                      ],
                    ),
                    if (recipientName != null && recipientName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'To: $recipientName${companyName != null && companyName.isNotEmpty ? ' ($companyName)' : ''}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF334155),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ] else if (companyName != null && companyName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Company: $companyName',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF334155),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
}
