import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/navigation/app_router.dart';
import '../../../../theme/app_theme.dart';
import '../../../../core/widgets/bottom_nav_bar.dart';
import '../../../../core/widgets/desktop_header.dart';
import '../../../../core/widgets/sidebar_drawer.dart';
import '../../../activities/presentation/screens/bingo_ai_screen.dart';
import '../../../activities/presentation/screens/calendar_screen.dart';
import '../../../activities/presentation/screens/calls_screen.dart';
import '../../../activities/presentation/screens/documents_screen.dart';
import '../../../activities/presentation/screens/emails_screen.dart';
import '../../../activities/presentation/screens/meeting_scheduler_screen.dart';
import '../../../activities/presentation/screens/meetings_screen.dart';
import '../../../activities/presentation/screens/quarter_view_screen.dart';
import '../../../activities/presentation/screens/reports_screen.dart';
import '../../../activities/presentation/screens/tasks_screen.dart';
import '../../../activities/presentation/screens/templates_screen.dart';
import '../../../companies/presentation/screens/companies_screen.dart';
import '../../../contacts/presentation/screens/contacts_screen.dart';
import '../../../dashboard/presentation/screens/dashboard_screen.dart';
import '../../../deals/presentation/screens/deals_screen.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../activities/presentation/screens/master_dropdowns_screen.dart';
import '../../../authentication/presentation/screens/user_management_screen.dart';
import '../../../departments/presentation/providers/department_provider.dart';
import '../../../departments/data/models/department_model.dart';
import '../../../departments/presentation/screens/departments_screen.dart';
import '../providers/navigation_provider.dart';

class MainLayoutScreen extends StatefulWidget {
  /// The routed screen to show in the body. Supplied by the shell route in
  /// [AppRouter]; when null the screen falls back to the index-driven list,
  /// which keeps the layout usable on its own (e.g. in widget tests).
  final Widget? child;

  const MainLayoutScreen({super.key, this.child});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  bool _isSidebarCollapsed = false;
  bool _isFullScreenMenu = false;

  final List<Widget> _screens = const [
    DashboardScreen(),          // 0
    ContactsScreen(),           // 1
    CompaniesScreen(),          // 2
    DealsScreen(),              // 3
    ReportsScreen(),            // 4 Reports
    BingoAiScreen(),            // 5
    NotificationsScreen(),      // 6
    MeetingsScreen(),           // 7
    MeetingSchedulerScreen(),   // 8
    CallsScreen(),              // 9
    EmailsScreen(),             // 10
    TasksScreen(),              // 11 (was Sequences)
    TasksScreen(),              // 12
    CalendarScreen(),           // 13
    QuarterViewScreen(),        // 14
    DocumentsScreen(),          // 15
    TemplatesScreen(),          // 16
    UserManagementScreen(),     // 17
    MasterDropdownsScreen(),    // 18
    DepartmentsScreen(),        // 19
  ];

  final List<String> _tabTitles = const [
    'Dashboard',
    'Contacts',
    'Companies',
    'Deals',
    'Reports',
    'Bingo AI',
    'Notifications',
    'Meetings',
    'Meeting Scheduler',
    'Calls',
    'Emails',
    'Tasks',
    'Tasks',
    'Calendar',
    'Quarter View',
    'Documents',
    'Templates',
    'User Management',
    'Master Dropdowns',
    'Departments Configuration',
  ];

  /// Switches main tab. Under the router this is a `go`, which replaces the
  /// current tab rather than stacking a second copy of it; without the router
  /// it falls back to the index the layout was already using.
  void _goToTab(BuildContext context, NavigationProvider navProvider, int index) {
    final location = AppRouter.locationForTab(index);
    if (widget.child != null && location != null) {
      if (GoRouterState.of(context).uri.path == location) return;
      context.go(location);
      return;
    }
    navProvider.selectScreen(index);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 800;
    final deptProvider = context.watch<DepartmentProvider>();

    // Under the router the current location decides the tab; the provider is
    // still what the sidebar and bottom bar read, so keep the two in step.
    final routedChild = widget.child;
    if (routedChild != null) {
      final location = GoRouterState.of(context).uri.path;
      final routedIndex = AppRouter.tabIndexForLocation(location);
      final navProvider = context.read<NavigationProvider>();
      if (navProvider.selectedIndex != routedIndex) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) navProvider.syncSelectedIndex(routedIndex);
        });
      }
    }

    return Consumer<NavigationProvider>(
      builder: (context, navProvider, child) {
        final int activeIndex = routedChild != null
            ? AppRouter.tabIndexForLocation(GoRouterState.of(context).uri.path)
            : (navProvider.selectedIndex >= 0 &&
                    navProvider.selectedIndex < _screens.length
                ? navProvider.selectedIndex
                : 0);

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          drawer: !isDesktop
              ? Drawer(
                  width: MediaQuery.of(context).size.width * 0.72,
                  child: SidebarDrawer(
                    selectedIndex: activeIndex,
                    isFullScreen: false,
                    onToggleFullScreen: () {},
                    onItemSelected: (index) {
                      _goToTab(context, navProvider, index);
                      Navigator.of(context).pop();
                    },
                    onClose: () => Navigator.of(context).pop(),
                  ),
                )
              : null,
          appBar: AppBar(
            titleSpacing: 0,
            leading: Builder(
              builder: (context) {
                return IconButton(
                  icon: const Icon(
                    Icons.menu_rounded,
                    color: Color(0xFF1E293B),
                    size: 24,
                  ),
                  onPressed: () {
                    if (isDesktop) {
                      setState(() {
                        _isSidebarCollapsed = !_isSidebarCollapsed;
                      });
                    } else {
                      Scaffold.of(context).openDrawer();
                    }
                  },
                  tooltip: 'Menu',
                );
              },
            ),
            title: Text(
              _tabTitles[activeIndex],
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            actions: [
              // Department Selector Pill (Only visible & enabled for Super Admin)
              if (deptProvider.canSwitchDepartment)
                PopupMenuButton<DepartmentModel>(
                  onSelected: (DepartmentModel dept) async {
                    final messenger = ScaffoldMessenger.of(context);
                    final switched = await deptProvider.changeDepartment(
                      context,
                      dept.id,
                      dept.name,
                    );
                    // A refused switch leaves the previous department in
                    // force. Say so — silently staying put looks like the
                    // switch worked and the data is simply wrong.
                    if (!switched) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            deptProvider.error ??
                                'Could not switch to ${dept.name}.',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
                  },
                  offset: const Offset(0, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  itemBuilder: (context) => deptProvider.availableDepartments
                      .map(
                        (dept) => PopupMenuItem<DepartmentModel>(
                          value: dept,
                          child: Row(
                            children: [
                              Icon(
                                Icons.apartment_rounded,
                                size: 16,
                                color: dept.id == deptProvider.selectedDepartmentId
                                    ? const Color(0xFF00A884)
                                    : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                dept.dropdownName,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: dept.id == deptProvider.selectedDepartmentId
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: dept.id == deptProvider.selectedDepartmentId
                                      ? const Color(0xFF00A884)
                                      : const Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.apartment_rounded,
                          size: 18,
                          color: Color(0xFF00A884),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          deptProvider.dropdownSelectedDepartmentName,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                )
              else
                // Read-only department indicator for Admin & User
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.apartment_rounded,
                        size: 18,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        deptProvider.dropdownSelectedDepartmentName,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: () {
                  _goToTab(context, navProvider, 6);
                },
                icon: Stack(
                  children: [
                    const Icon(
                      Icons.notifications_none_rounded,
                      color: Color(0xFF1E293B),
                      size: 24,
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 9,
                          minHeight: 9,
                        ),
                      ),
                    ),
                  ],
                ),
                tooltip: 'Notifications',
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Stack(
            children: [
              Row(
                children: [
                  if (isDesktop && !_isSidebarCollapsed && !_isFullScreenMenu)
                    SidebarDrawer(
                      selectedIndex: activeIndex,
                      isFullScreen: false,
                      onToggleFullScreen: () {
                        setState(() {
                          _isFullScreenMenu = true;
                        });
                      },
                      onItemSelected: (index) {
                        _goToTab(context, navProvider, index);
                      },
                    ),
                  Expanded(
                    child: Column(
                      children: [
                        if (isDesktop) const DesktopHeader(),
                        Expanded(
                          child: routedChild ?? _screens[activeIndex],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_isFullScreenMenu)
                Positioned.fill(
                  child: SidebarDrawer(
                    selectedIndex: activeIndex,
                    isFullScreen: true,
                    onToggleFullScreen: () {
                      setState(() {
                        _isFullScreenMenu = false;
                      });
                    },
                    onItemSelected: (index) {
                      _goToTab(context, navProvider, index);
                      setState(() {
                        _isFullScreenMenu = false;
                      });
                    },
                    onClose: () {
                      setState(() {
                        _isFullScreenMenu = false;
                      });
                    },
                  ),
                ),
              // Department switching modal loader overlay
              if (deptProvider.isSwitchingDepartment)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.35),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 16,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFF00A884),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              'Switching department data...',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: !isDesktop
              ? CustomBottomNavBar(
                  currentIndex: activeIndex,
                  onTap: (index) {
                    _goToTab(context, navProvider, index);
                  },
                )
              : null,
        );
      },
    );
  }
}
