import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/action_pill_button.dart';
import '../../../../core/widgets/stat_card.dart';
import '../../../../core/widgets/work_summary_card.dart';
import '../../../../core/repositories/master_data_repository.dart';
import '../../../../core/providers/master_data_provider.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../contacts/data/models/contact_model.dart';
import '../../../contacts/presentation/providers/contact_provider.dart';
import '../../../deals/data/models/deal_model.dart';
import '../../../deals/presentation/providers/deal_provider.dart';
import '../../../navigation/presentation/providers/navigation_provider.dart';
import '../../data/models/activity_stats_model.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedPillIndex = 0; // 0 = Team, 1 = My work
  int _selectedTimeFilter = 1; // 0: 7 Days, 1: 30 Days, 2: 90 Days, 3: All time

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final currentUserId = auth.currentUser?.id;
      
      context.read<DashboardProvider>().loadDashboardData(
        ownerId: _selectedPillIndex == 1 ? currentUserId : null,
      );
      context.read<ContactProvider>().fetchContacts();
      context.read<DealProvider>().fetchDeals();
      context.read<MasterDataProvider>().fetchAllMasterData(
        currentUserId: currentUserId,
        departmentId: auth.currentUser?.departmentId,
      );
      auth.fetchTeamMembers();
    });
  }

  void _onTogglePill(int index) {
    setState(() {
      _selectedPillIndex = index;
    });
    final auth = context.read<AuthProvider>();
    final ownerId = index == 1 ? auth.currentUser?.id : null;
    context.read<DashboardProvider>().loadDashboardData(ownerId: ownerId);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 800;
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser;
    final dashboardProvider = context.watch<DashboardProvider>();
    final contactProvider = context.watch<ContactProvider>();
    final dealProvider = context.watch<DealProvider>();
    final stats = dashboardProvider.stats;
    final contactsList = contactProvider.contacts;
    final dealsList = dealProvider.deals;

    // Check if logged in user is Admin / Super Admin
    final bool isAdmin = currentUser == null ||
        (currentUser.role != null &&
            (currentUser.role == 'super_admin' ||
                currentUser.role == 'admin' ||
                currentUser.role == 'administrator' ||
                currentUser.role!.toLowerCase().contains('admin')));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            final ownerId = _selectedPillIndex == 1 ? currentUser?.id : null;
            await Future.wait([
              context.read<DashboardProvider>().loadDashboardData(ownerId: ownerId),
              context.read<MasterDataProvider>().fetchAllMasterData(
                currentUserId: currentUser?.id,
                departmentId: currentUser?.departmentId,
              ),
              context.read<AuthProvider>().fetchTeamMembers(),
              context.read<ContactProvider>().fetchContacts(),
              context.read<DealProvider>().fetchDeals(),
            ]);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: EdgeInsets.all(isDesktop ? AppSpacing.lg : AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==========================================
                // SECTION A: ORIGINAL DASHBOARD CONTENT
                // ==========================================
                
                // 1. Workspace Overview Greeting & Action Pills
                if (isDesktop)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildGreetingHeader(),
                      _buildActionPillsRow(),
                    ],
                  )
                else ...[
                  _buildGreetingHeader(),
                  const SizedBox(height: AppSpacing.md),
                  _buildActionPillsRow(),
                ],

                const SizedBox(height: AppSpacing.lg),

                if (dashboardProvider.isLoadingStats && stats == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFF00A884)),
                    ),
                  )
                else ...[
                  // 2. Stat Cards Section (TOTAL CONTACTS, TOTAL COMPANIES, TOTAL DEALS)
                  if (isDesktop)
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            label: 'TOTAL CONTACTS',
                            value: '${stats?.totalContacts ?? 0}',
                            badgeText: 'Contacts',
                            badgeBgColor: const Color(0xFFE6F4F1),
                            badgeTextColor: const Color(0xFF0F766E),
                            onTap: () {
                              context.read<NavigationProvider>().selectScreen(1); // Contacts
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: StatCard(
                            label: 'TOTAL COMPANIES',
                            value: '${stats?.totalCompanies ?? 0}',
                            badgeText: 'Companies',
                            badgeBgColor: const Color(0xFFE6F4F1),
                            badgeTextColor: const Color(0xFF0F766E),
                            onTap: () {
                              context.read<NavigationProvider>().selectScreen(2); // Companies
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: StatCard(
                            label: 'TOTAL DEALS',
                            value: '${stats?.totalDeals ?? 0}',
                            badgeText: 'Active',
                            badgeBgColor: const Color(0xFFE6F4F1),
                            badgeTextColor: const Color(0xFF0F766E),
                            onTap: () {
                              context.read<NavigationProvider>().selectScreen(3); // Deals
                            },
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        StatCard(
                          label: 'TOTAL CONTACTS',
                          value: '${stats?.totalContacts ?? 0}',
                          badgeText: 'Contacts',
                          badgeBgColor: const Color(0xFFE6F4F1),
                          badgeTextColor: const Color(0xFF0F766E),
                          onTap: () {
                            context.read<NavigationProvider>().selectScreen(1); // Contacts
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        StatCard(
                          label: 'TOTAL COMPANIES',
                          value: '${stats?.totalCompanies ?? 0}',
                          badgeText: 'Companies',
                          badgeBgColor: const Color(0xFFE6F4F1),
                          badgeTextColor: const Color(0xFF0F766E),
                          onTap: () {
                            context.read<NavigationProvider>().selectScreen(2); // Companies
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        StatCard(
                          label: 'TOTAL DEALS',
                          value: '${stats?.totalDeals ?? 0}',
                          badgeText: 'Active',
                          badgeBgColor: const Color(0xFFE6F4F1),
                          badgeTextColor: const Color(0xFF0F766E),
                          onTap: () {
                            context.read<NavigationProvider>().selectScreen(3); // Deals
                          },
                        ),
                      ],
                    ),

                  const SizedBox(height: AppSpacing.lg),

                  // 3. Work Summary Cards (Today's Work, Yesterday's Work, Custom Date Search)
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: WorkSummaryCard(
                            title: "Today's Work",
                            dateString: "Today",
                            pendingCount: stats?.pendingTasks ?? 0,
                            completedCount: stats?.completed ?? 0,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: WorkSummaryCard(
                            title: "Yesterday's Work",
                            dateString: "Yesterday",
                            pendingCount: 0,
                            completedCount: 0,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: WorkSummaryCard(
                            title: "Custom Date Search",
                            dateString: "Filter Range",
                            pendingCount: 0,
                            completedCount: 0,
                            showFilterButton: true,
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        WorkSummaryCard(
                          title: "Today's Work",
                          dateString: "Today",
                          pendingCount: stats?.pendingTasks ?? 0,
                          completedCount: stats?.completed ?? 0,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        WorkSummaryCard(
                          title: "Yesterday's Work",
                          dateString: "Yesterday",
                          pendingCount: 0,
                          completedCount: 0,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        WorkSummaryCard(
                          title: "Custom Date Search",
                          dateString: "Filter Range",
                          pendingCount: 0,
                          completedCount: 0,
                          showFilterButton: true,
                        ),
                      ],
                    ),
                ],

                // ==========================================
                // SECTION B: ADMIN PERFORMANCE REPORTING
                // ==========================================
                if (isAdmin) ...[
                  const SizedBox(height: 32),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 24),

                  // 1. Performance Title Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F4F1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.grid_view_rounded,
                          color: Color(0xFF00A884),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Performance',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Color(0xFF64748B),
                                  size: 20,
                                ),
                              ],
                            ),
                            Text(
                              'Default performance dashboard with key metrics and insights',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 2. Filter Pills & Control Buttons Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildTimeFilterPill(0, '7 Days'),
                        _buildTimeFilterPill(1, '30 Days'),
                        _buildTimeFilterPill(2, '90 Days'),
                        _buildTimeFilterPill(3, 'All time'),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(
                                'Auto: 5 min',
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            context.read<DashboardProvider>().loadDashboardData();
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF475569)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF00A884)),
                          label: Text(
                            'Create',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF00A884),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF00A884)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Card 1: Contact lifecycle stage funnel -> Contacts Screen
                  _buildDashboardCard(
                    title: 'Contact lifecycle stage funnel',
                    subtitle: 'LAST 90 DAYS',
                    onTap: () => context.read<NavigationProvider>().selectScreen(1),
                    child: _buildLifecycleFunnelTable(contactsList),
                  ),

                  const SizedBox(height: 16),

                  // Card 2: Team activity totals -> Reports Screen
                  _buildDashboardCard(
                    title: 'Team activity totals',
                    subtitle: 'LAST 30 DAYS',
                    onTap: () => context.read<NavigationProvider>().selectScreen(4),
                    child: _buildTeamActivityTotalsGrid(stats),
                  ),

                  const SizedBox(height: 16),

                  // Card 3: Deal stage overview -> Deals Screen
                  _buildDashboardCard(
                    title: 'Deal stage overview',
                    subtitle: 'ALL TIME',
                    onTap: () => context.read<NavigationProvider>().selectScreen(3),
                    child: _buildDealsByStageContent(dealsList),
                  ),

                  const SizedBox(height: 16),

                  // Card 4: Deals in sales pipeline stages by owner -> Deals Screen
                  _buildDashboardCard(
                    title: 'Deals in sales pipeline stages by ...',
                    subtitle: 'ALL TIME',
                    onTap: () => context.read<NavigationProvider>().selectScreen(3),
                    child: _buildDealsByOwnerContent(dealsList),
                  ),

                  const SizedBox(height: 16),

                  // Card 5: Contact created totals by first conversion -> Contacts Screen
                  _buildDashboardCard(
                    title: 'Contact created totals by first co...',
                    subtitle: 'LAST 30 DAYS',
                    onTap: () => context.read<NavigationProvider>().selectScreen(1),
                    child: _buildFirstConversionContent(contactsList),
                  ),

                  const SizedBox(height: 16),

                  // Card 6: Call and meeting totals by rep -> Calls Screen
                  _buildDashboardCard(
                    title: 'Call and meeting totals by rep',
                    subtitle: 'LAST 30 DAYS',
                    onTap: () => context.read<NavigationProvider>().selectScreen(9),
                    child: _buildCallAndMeetingTotalsByRepContent(),
                  ),

                  const SizedBox(height: 16),

                  // Card 7: Email sent, opened, and click totals -> Emails Screen
                  _buildDashboardCard(
                    title: 'Email sent, opened, and click tot...',
                    subtitle: 'LAST 30 DAYS',
                    onTap: () => context.read<NavigationProvider>().selectScreen(10),
                    child: _buildEmailTotalsGrid(stats),
                  ),

                  const SizedBox(height: 16),

                  // Card 8: Meetings booked with reps by owner -> Meetings Screen
                  _buildDashboardCard(
                    title: 'Meetings booked with reps by ow...',
                    subtitle: 'LAST 30 DAYS',
                    onTap: () => context.read<NavigationProvider>().selectScreen(7),
                    child: _buildMeetingsBookedTable(),
                  ),

                  const SizedBox(height: 16),

                  // Card 9: Activity of recently created contacts -> Contacts Screen
                  _buildDashboardCard(
                    title: 'Activity of recently created cont...',
                    subtitle: 'LAST 30 DAYS',
                    onTap: () => context.read<NavigationProvider>().selectScreen(1),
                    child: _buildRecentlyCreatedContactsTable(contactsList),
                  ),

                  const SizedBox(height: 16),

                  // Card 10: Deals by last modified date -> Deals Screen
                  _buildDashboardCard(
                    title: 'Deals by last modified date',
                    subtitle: 'ALL TIME',
                    onTap: () => context.read<NavigationProvider>().selectScreen(3),
                    child: _buildDealsByLastModifiedTable(dealsList),
                  ),
                ],

                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGreetingHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Workspace Overview',
          style: AppTextStyles.headingMedium.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Here is your personal work summary and CRM activity statistics.',
          style: AppTextStyles.bodyMedium.copyWith(
            fontSize: 13.5,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildActionPillsRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // Segment box for Team & My work
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                ActionPillButton(
                  label: 'Team',
                  icon: Icons.groups_outlined,
                  isSelected: _selectedPillIndex == 0,
                  onTap: () => _onTogglePill(0),
                ),
                ActionPillButton(
                  label: 'My work',
                  icon: Icons.person_outline_rounded,
                  isSelected: _selectedPillIndex == 1,
                  onTap: () => _onTogglePill(1),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm + 4),
          ActionPillButton(
            label: 'Ask Bingo',
            icon: Icons.auto_awesome_rounded,
            isHighlighted: true,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Ask Bingo AI Assistant clicked!'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimeFilterPill(int index, String label) {
    final bool isSelected = _selectedTimeFilter == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTimeFilter = index;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00A884) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF00A884) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required String subtitle,
    required Widget child,
    VoidCallback? onTap,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00A884).withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F766E),
                          ),
                        ),
                      ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF64748B)),
                        SizedBox(width: 8),
                        Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF64748B)),
                        SizedBox(width: 8),
                        Icon(Icons.alt_route_rounded, size: 16, color: Color(0xFF64748B)),
                        SizedBox(width: 8),
                        Icon(Icons.tune_rounded, size: 16, color: Color(0xFF64748B)),
                        SizedBox(width: 8),
                        Icon(Icons.more_vert_rounded, size: 16, color: Color(0xFF64748B)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF475569),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Padding(
            padding: const EdgeInsets.all(14),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
        ),
      ),
    );
  }

  Widget _buildMeetingsBookedTable() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: MasterDataRepositoryImpl().getActivities(type: 'meeting'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00A884)),
              ),
            ),
          );
        }

        final meetings = snapshot.data ?? [];
        if (meetings.isEmpty) {
          return _buildEmptyState('No meetings booked yet');
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                color: const Color(0xFFF8FAFC),
                child: Row(
                  children: [
                    SizedBox(width: 140, child: Text('MEETING TITLE', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF475569)))),
                    SizedBox(width: 110, child: Text('OWNER', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF475569)))),
                    SizedBox(width: 90, child: Text('STATUS', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF475569)))),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              ...meetings.take(5).map((m) {
                final title = (m['title'] ?? m['subject'] ?? 'Meeting').toString();
                final owner = (m['ownerName'] ?? m['owner'] ?? 'Admin User').toString();
                final status = (m['outcome'] ?? m['status'] ?? 'Scheduled').toString();

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 140,
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF00A884),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 110,
                        child: Text(
                          owner,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF475569)),
                        ),
                      ),
                      SizedBox(
                        width: 90,
                        child: Text(
                          status,
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentlyCreatedContactsTable(List<ContactModel> contacts) {
    if (contacts.isEmpty) {
      return _buildEmptyState('No contacts created yet');
    }

    final recentContacts = contacts.take(5).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: const Color(0xFFF8FAFC),
            child: Row(
              children: [
                SizedBox(width: 140, child: Text('CONTACT', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF475569)))),
                SizedBox(width: 110, child: Text('OWNER', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF475569)))),
                SizedBox(width: 100, child: Text('CREATE DATE', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF475569)))),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          ...recentContacts.map((c) {
            final fullName = '${c.firstName ?? ''} ${c.lastName ?? ''}'.trim();
            final displayName = fullName.isNotEmpty ? fullName : (c.name.isNotEmpty ? c.name : 'Unnamed');
            final owner = c.ownerName ?? 'Admin User';
            const dateStr = 'Recently';

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(
                      displayName,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF00A884),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 110,
                    child: Text(
                      owner,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF475569)),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: Text(
                      dateStr,
                      style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDealsByLastModifiedTable(List<DealModel> deals) {
    if (deals.isEmpty) {
      return _buildEmptyState('No deals available');
    }

    final recentDeals = deals.take(5).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: const Color(0xFFF8FAFC),
            child: Row(
              children: [
                SizedBox(width: 140, child: Text('DEAL NAME', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF475569)))),
                SizedBox(width: 140, child: Text('STAGE', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF475569)))),
                SizedBox(width: 90, child: Text('AMOUNT', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF475569)))),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          ...recentDeals.map((d) {
            final name = d.title.isNotEmpty ? d.title : 'Deal';
            final stage = d.stage.isNotEmpty ? d.stage : 'Prospect';
            final amount = '\$${d.amount.toStringAsFixed(0)}';

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF00A884),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: Text(
                      stage,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF475569)),
                    ),
                  ),
                  SizedBox(
                    width: 90,
                    child: Text(
                      amount,
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLifecycleFunnelTable(List<ContactModel> contacts) {
    final defaultStages = [
      'All created contacts',
      'Added',
      'Subscriber',
      'Lead',
      'Marketing Qualified Lead',
      'Sales Qualified Lead',
      'Opportunity',
      'Customer',
      'Evangelist',
      'Other',
    ];

    final Map<String, int> countsByStage = {};
    for (final s in defaultStages) {
      countsByStage[s] = 0;
    }
    countsByStage['All created contacts'] = contacts.length;

    for (final c in contacts) {
      final stage = c.lifecycleStage ?? 'Added';
      countsByStage[stage] = (countsByStage[stage] ?? 0) + 1;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: const Color(0xFFF8FAFC),
            child: Row(
              children: [
                SizedBox(width: 145, child: Text('STAGE', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF475569)))),
                SizedBox(width: 75, child: Text('CONTACTS', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF475569)))),
                SizedBox(width: 90, child: Text('FROM PREV', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF475569)))),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          ...countsByStage.entries.map((entry) {
            final count = entry.value;
            final isZero = count == 0;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                children: [
                  SizedBox(width: 145, child: Text(entry.key, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF334155)))),
                  SizedBox(
                    width: 75,
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: isZero ? const Color(0xFFF1F5F9) : const Color(0xFF00BDA5),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('$count', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: isZero ? const Color(0xFF94A3B8) : const Color(0xFF0F766E))),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 90,
                    child: Text(
                      isZero ? '-' : '100%',
                      style: GoogleFonts.poppins(fontSize: 11, color: isZero ? const Color(0xFF94A3B8) : const Color(0xFF00BDA5)),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDealsByStageContent(List<DealModel> deals) {
    if (deals.isEmpty) {
      return _buildEmptyState('No deals data recorded yet');
    }

    final Map<String, int> countsByStage = {};
    for (final d in deals) {
      final stage = d.stage;
      countsByStage[stage] = (countsByStage[stage] ?? 0) + 1;
    }

    final maxCount = countsByStage.values.fold<int>(1, (max, e) => e > max ? e : max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...countsByStage.entries.map((entry) {
          final double percentage = (entry.value / maxCount).clamp(0.05, 1.0);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 85,
                  child: Text(
                    entry.key,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(fontSize: 10.5, color: const Color(0xFF475569)),
                  ),
                ),
                Expanded(
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: percentage,
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00A884),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${entry.value}',
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDealsByOwnerContent(List<DealModel> deals) {
    if (deals.isEmpty) {
      return _buildEmptyState('No deals data recorded yet');
    }

    final Map<String, int> countsByOwner = {};
    for (final d in deals) {
      final owner = d.ownerName ?? 'Admin';
      countsByOwner[owner] = (countsByOwner[owner] ?? 0) + 1;
    }

    final maxCount = countsByOwner.values.fold<int>(1, (max, e) => e > max ? e : max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...countsByOwner.entries.map((entry) {
          final double percentage = (entry.value / maxCount).clamp(0.05, 1.0);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 75,
                  child: Text(
                    entry.key,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(fontSize: 10.5, color: const Color(0xFF475569)),
                  ),
                ),
                Expanded(
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: percentage,
                        child: Container(
                          height: 14,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00BDA5),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${entry.value}',
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFirstConversionContent(List<ContactModel> contacts) {
    final count = contacts.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  '(No conversion)',
                  style: GoogleFonts.poppins(fontSize: 10.5, color: const Color(0xFF475569)),
                ),
              ),
              Expanded(
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: count > 0 ? 1.0 : 0.05,
                      child: Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$count',
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCallAndMeetingTotalsByRepContent() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          const Icon(Icons.highlight_off_rounded, size: 36, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 8),
          Text(
            'No data in this time frame. Try a wider date range or a different department.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailTotalsGrid(ActivityStatsModel? stats) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMetricTile('SENT', '${stats?.emails ?? 0}', '', const Color(0xFF64748B)),
          const SizedBox(width: 20),
          _buildMetricTile('OPENED', '0', '', const Color(0xFF64748B)),
          const SizedBox(width: 20),
          _buildMetricTile('CLICKED', '0', '', const Color(0xFF64748B)),
          const SizedBox(width: 20),
          _buildMetricTile('REPLIED', '0', '', const Color(0xFF64748B)),
          const SizedBox(width: 20),
          _buildMetricTile('OPEN RATE %', '0%', '', const Color(0xFF64748B)),
        ],
      ),
    );
  }

  Widget _buildTeamActivityTotalsGrid(ActivityStatsModel? stats) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildMetricTile('CALL', '${stats?.calls ?? 0}', '', const Color(0xFF64748B))),
            Expanded(child: _buildMetricTile('EMAIL SENT TO CONTACT', '${stats?.emails ?? 0}', '', const Color(0xFF64748B))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildMetricTile('MEETING', '${stats?.meetings ?? 0}', '', const Color(0xFF64748B))),
            Expanded(child: _buildMetricTile('NOTE', '${stats?.notes ?? 0}', '', const Color(0xFF64748B))),
          ],
        ),
        const SizedBox(height: 12),
        Center(
          child: SizedBox(
            width: 180,
            child: _buildMetricTile('TASK', '${stats?.tasks ?? 0}', '', const Color(0xFF64748B)),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile(String label, String value, String changeText, Color changeColor) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF00A884)),
        ),
        if (changeText.isNotEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                changeText,
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: changeColor),
              ),
            ],
          ),
      ],
    );
  }
}
