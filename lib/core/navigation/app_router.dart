import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/activities/presentation/screens/bingo_ai_screen.dart';
import '../../features/activities/presentation/screens/calendar_screen.dart';
import '../../features/activities/presentation/screens/call_details_screen.dart';
import '../../features/activities/presentation/screens/calls_screen.dart';
import '../../features/activities/presentation/screens/documents_screen.dart';
import '../../features/activities/presentation/screens/email_details_screen.dart';
import '../../features/activities/presentation/screens/emails_screen.dart';
import '../../features/activities/presentation/screens/master_dropdowns_screen.dart';
import '../../features/activities/presentation/screens/meeting_details_screen.dart';
import '../../features/activities/presentation/screens/meeting_scheduler_screen.dart';
import '../../features/activities/presentation/screens/meetings_screen.dart';
import '../../features/activities/presentation/screens/quarter_view_screen.dart';
import '../../features/activities/presentation/screens/reports_screen.dart';
import '../../features/activities/presentation/screens/task_details_screen.dart';
import '../../features/activities/presentation/screens/tasks_screen.dart';
import '../../features/activities/presentation/screens/templates_screen.dart';
import '../../features/authentication/presentation/providers/auth_provider.dart';
import '../../features/authentication/presentation/screens/login_screen.dart';
import '../../features/authentication/presentation/screens/user_management_screen.dart';
import '../../features/companies/presentation/screens/companies_screen.dart';
import '../../features/companies/presentation/screens/company_details_screen.dart';
import '../../features/contacts/presentation/screens/contact_details_screen.dart';
import '../../features/contacts/presentation/screens/contacts_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/deals/presentation/screens/deal_details_screen.dart';
import '../../features/deals/presentation/screens/deals_screen.dart';
import '../../features/departments/presentation/screens/departments_screen.dart';
import '../../features/navigation/presentation/screens/initial_data_loader_screen.dart';
import '../../features/navigation/presentation/screens/main_layout_screen.dart';
import '../../features/navigation/presentation/screens/splash_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import 'route_names.dart';
import 'route_paths.dart';
import 'route_not_found_screen.dart';

/// The single navigation tree for the application.
///
/// ```
/// /                      splash
/// /login                 login
/// /loading               post-login data loader
/// [shell]                MainLayoutScreen chrome (app bar, sidebar, bottom nav)
///   /dashboard
///   /contacts            -> /contacts/details/:id
///   /companies           -> /companies/details/:id
///   /deals               -> /deals/details/:id
///   /activities          -> /activities/tasks    -> /activities/tasks/details/:id
///                        -> /activities/calls    -> /activities/calls/details/:id
///                        -> /activities/meetings -> /activities/meetings/details/:id
///                        -> /activities/emails   -> /activities/emails/details/:id
///   …plus the remaining sidebar screens
/// ```
///
/// Detail routes are declared as children of their list route — so the paths
/// nest and Back returns to the list — but are attached to the root navigator
/// so they cover the shell chrome, matching the previous full-screen pushes.
class AppRouter {
  AppRouter._();

  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');
  static final GlobalKey<NavigatorState> shellNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'shell');

  /// Routes reachable without a session.
  static const Set<String> _publicPaths = {
    RoutePaths.splash,
    RoutePaths.login,
  };

  /// Tab index used by the sidebar and bottom bar → route name.
  ///
  /// The indexes are the ones [MainLayoutScreen] and `NavigationProvider`
  /// already use, so every existing `selectScreen(index)` caller keeps working.
  static const Map<int, String> tabRouteNames = {
    0: RouteNames.dashboard,
    1: RouteNames.contacts,
    2: RouteNames.companies,
    3: RouteNames.deals,
    4: RouteNames.reports,
    5: RouteNames.bingoAi,
    6: RouteNames.notifications,
    7: RouteNames.meetings,
    8: RouteNames.meetingScheduler,
    9: RouteNames.calls,
    10: RouteNames.emails,
    11: RouteNames.tasks,
    12: RouteNames.tasks,
    13: RouteNames.calendar,
    14: RouteNames.quarterView,
    15: RouteNames.documents,
    16: RouteNames.templates,
    17: RouteNames.userManagement,
    18: RouteNames.masterDropdowns,
    19: RouteNames.departments,
  };

  /// Absolute location per tab index, for driving the shell from a tab tap.
  static const Map<int, String> _tabLocations = {
    0: RoutePaths.dashboard,
    1: RoutePaths.contacts,
    2: RoutePaths.companies,
    3: RoutePaths.deals,
    4: RoutePaths.reports,
    5: RoutePaths.bingoAi,
    6: RoutePaths.notifications,
    7: '${RoutePaths.activities}/${RoutePaths.meetings}',
    8: RoutePaths.meetingScheduler,
    9: '${RoutePaths.activities}/${RoutePaths.calls}',
    10: '${RoutePaths.activities}/${RoutePaths.emails}',
    11: '${RoutePaths.activities}/${RoutePaths.tasks}',
    12: '${RoutePaths.activities}/${RoutePaths.tasks}',
    13: RoutePaths.calendar,
    14: RoutePaths.quarterView,
    15: RoutePaths.documents,
    16: RoutePaths.templates,
    17: RoutePaths.userManagement,
    18: RoutePaths.masterDropdowns,
    19: RoutePaths.departments,
  };

  /// Location for [tabIndex], or null when the index is unknown.
  static String? locationForTab(int tabIndex) => _tabLocations[tabIndex];

  /// The tab index a location belongs to, so the sidebar and bottom bar can
  /// highlight the right entry. Falls back to Dashboard.
  static int tabIndexForLocation(String location) {
    var best = 0;
    var bestLength = 0;
    _tabLocations.forEach((index, path) {
      if ((location == path || location.startsWith('$path/')) &&
          path.length > bestLength) {
        best = index;
        bestLength = path.length;
      }
    });
    return best;
  }

  /// Builds the router. [authProvider] drives the redirect and is listened to,
  /// so logging in or out re-evaluates the current location immediately.
  static GoRouter create(AuthProvider authProvider) {
    return GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: RoutePaths.splash,
      refreshListenable: authProvider,
      errorBuilder: (context, state) =>
          RouteNotFoundScreen(location: state.uri.toString()),
      redirect: (context, state) {
        final location = state.uri.path;
        final isPublic = _publicPaths.contains(location);

        // The splash screen decides where to go once it has restored the
        // session, so never redirect away from it.
        if (location == RoutePaths.splash) return null;

        // While a session is being restored or a login is in flight, leave the
        // user where they are rather than bouncing them around.
        if (authProvider.isLoading) return null;

        if (!authProvider.isAuthenticated && !isPublic) {
          return RoutePaths.login;
        }
        if (authProvider.isAuthenticated && location == RoutePaths.login) {
          return RoutePaths.dashboard;
        }
        return null;
      },
      routes: [
        // ── Authentication tree ──────────────────────────────────────────
        GoRoute(
          path: RoutePaths.splash,
          name: RouteNames.splash,
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: RoutePaths.login,
          name: RouteNames.login,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: RoutePaths.dataLoader,
          name: RouteNames.dataLoader,
          builder: (context, state) => const InitialDataLoaderScreen(),
        ),

        // ── Main application tree ────────────────────────────────────────
        ShellRoute(
          navigatorKey: shellNavigatorKey,
          builder: (context, state, child) => MainLayoutScreen(child: child),
          routes: [
            GoRoute(
              path: RoutePaths.dashboard,
              name: RouteNames.dashboard,
              builder: (context, state) => const DashboardScreen(),
            ),

            // Contacts → Contact details
            GoRoute(
              path: RoutePaths.contacts,
              name: RouteNames.contacts,
              builder: (context, state) => const ContactsScreen(),
              routes: [
                GoRoute(
                  path: RoutePaths.details,
                  name: RouteNames.contactDetails,
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) => ContactDetailsScreen(
                    contactId: state.pathParameters[RoutePaths.idParam],
                    initialTabIndex: _tabIndexOf(state),
                    highlightActivityId: state.uri.queryParameters['activityId'],
                  ),
                ),
              ],
            ),

            // Companies → Company details
            GoRoute(
              path: RoutePaths.companies,
              name: RouteNames.companies,
              builder: (context, state) => const CompaniesScreen(),
              routes: [
                GoRoute(
                  path: RoutePaths.details,
                  name: RouteNames.companyDetails,
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) => CompanyDetailsScreen(
                    companyId: state.pathParameters[RoutePaths.idParam],
                    initialTabIndex: _tabIndexOf(state),
                    highlightActivityId: state.uri.queryParameters['activityId'],
                  ),
                ),
              ],
            ),

            // Deals → Deal details
            GoRoute(
              path: RoutePaths.deals,
              name: RouteNames.deals,
              builder: (context, state) => const DealsScreen(),
              routes: [
                GoRoute(
                  path: RoutePaths.details,
                  name: RouteNames.dealDetails,
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) => DealDetailsScreen(
                    dealId: state.pathParameters[RoutePaths.idParam],
                    initialTabIndex: _tabIndexOf(state),
                    highlightActivityId: state.uri.queryParameters['activityId'],
                  ),
                ),
              ],
            ),

            // Activities → Tasks / Calls / Meetings / Emails → details
            GoRoute(
              path: RoutePaths.activities,
              name: RouteNames.activities,
              // Activities is a grouping node; land on its first child.
              redirect: (context, state) =>
                  state.uri.path == RoutePaths.activities
                      ? RoutePaths.activityList(RoutePaths.tasks)
                      : null,
              builder: (context, state) => const TasksScreen(),
              routes: [
                GoRoute(
                  path: RoutePaths.tasks,
                  name: RouteNames.tasks,
                  builder: (context, state) => const TasksScreen(),
                  routes: [
                    GoRoute(
                      path: RoutePaths.details,
                      name: RouteNames.taskDetails,
                      parentNavigatorKey: rootNavigatorKey,
                      builder: (context, state) => TaskDetailsScreen(
                        taskId: state.pathParameters[RoutePaths.idParam],
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: RoutePaths.calls,
                  name: RouteNames.calls,
                  builder: (context, state) => const CallsScreen(),
                  routes: [
                    GoRoute(
                      path: RoutePaths.details,
                      name: RouteNames.callDetails,
                      parentNavigatorKey: rootNavigatorKey,
                      builder: (context, state) => CallDetailsScreen(
                        callId: state.pathParameters[RoutePaths.idParam],
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: RoutePaths.meetings,
                  name: RouteNames.meetings,
                  builder: (context, state) => const MeetingsScreen(),
                  routes: [
                    GoRoute(
                      path: RoutePaths.details,
                      name: RouteNames.meetingDetails,
                      parentNavigatorKey: rootNavigatorKey,
                      builder: (context, state) => MeetingDetailsScreen(
                        meetingId: state.pathParameters[RoutePaths.idParam],
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: RoutePaths.emails,
                  name: RouteNames.emails,
                  builder: (context, state) => const EmailsScreen(),
                  routes: [
                    GoRoute(
                      path: RoutePaths.details,
                      name: RouteNames.emailDetails,
                      parentNavigatorKey: rootNavigatorKey,
                      builder: (context, state) => EmailDetailsScreen(
                        emailId: state.pathParameters[RoutePaths.idParam],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Remaining sidebar screens — leaves of the main tree.
            GoRoute(
              path: RoutePaths.reports,
              name: RouteNames.reports,
              builder: (context, state) => const ReportsScreen(),
            ),
            GoRoute(
              path: RoutePaths.bingoAi,
              name: RouteNames.bingoAi,
              builder: (context, state) => const BingoAiScreen(),
            ),
            GoRoute(
              path: RoutePaths.notifications,
              name: RouteNames.notifications,
              builder: (context, state) => const NotificationsScreen(),
            ),
            GoRoute(
              path: RoutePaths.meetingScheduler,
              name: RouteNames.meetingScheduler,
              builder: (context, state) => const MeetingSchedulerScreen(),
            ),
            GoRoute(
              path: RoutePaths.calendar,
              name: RouteNames.calendar,
              builder: (context, state) => const CalendarScreen(),
            ),
            GoRoute(
              path: RoutePaths.quarterView,
              name: RouteNames.quarterView,
              builder: (context, state) => const QuarterViewScreen(),
            ),
            GoRoute(
              path: RoutePaths.documents,
              name: RouteNames.documents,
              builder: (context, state) => const DocumentsScreen(),
            ),
            GoRoute(
              path: RoutePaths.templates,
              name: RouteNames.templates,
              builder: (context, state) => const TemplatesScreen(),
            ),
            GoRoute(
              path: RoutePaths.userManagement,
              name: RouteNames.userManagement,
              builder: (context, state) => const UserManagementScreen(),
            ),
            GoRoute(
              path: RoutePaths.masterDropdowns,
              name: RouteNames.masterDropdowns,
              builder: (context, state) => const MasterDropdownsScreen(),
            ),
            GoRoute(
              path: RoutePaths.departments,
              name: RouteNames.departments,
              builder: (context, state) => const DepartmentsScreen(),
            ),
          ],
        ),
      ],
    );
  }

  /// `?tab=1` opens a record's details on its Activities tab. Anything
  /// unparseable falls back to the first tab rather than throwing.
  static int _tabIndexOf(GoRouterState state) =>
      int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0;
}
