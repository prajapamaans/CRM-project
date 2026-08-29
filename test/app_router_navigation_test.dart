import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crmproject/core/navigation/route_names.dart';
import 'package:crmproject/core/navigation/route_not_found_screen.dart';
import 'package:crmproject/core/navigation/route_paths.dart';

/// A stand-in tree with the same shape as [AppRouter]: a shell holding the
/// list routes, each with an id-addressed detail child on the root navigator.
/// It exercises the routing rules without booting every real screen.
class _Harness {
  _Harness({required this.isAuthenticated});

  bool isAuthenticated;
  final rootKey = GlobalKey<NavigatorState>();

  late final GoRouter router = GoRouter(
    navigatorKey: rootKey,
    initialLocation: RoutePaths.login,
    errorBuilder: (context, state) =>
        RouteNotFoundScreen(location: state.uri.toString()),
    redirect: (context, state) {
      final location = state.uri.path;
      final isPublic = location == RoutePaths.login || location == RoutePaths.splash;
      if (!isAuthenticated && !isPublic) return RoutePaths.login;
      if (isAuthenticated && location == RoutePaths.login) return RoutePaths.dashboard;
      return null;
    },
    routes: [
      GoRoute(
        path: RoutePaths.login,
        name: RouteNames.login,
        builder: (_, __) => const Text('LOGIN'),
      ),
      ShellRoute(
        builder: (_, __, child) => Scaffold(body: child),
        routes: [
          GoRoute(
            path: RoutePaths.dashboard,
            name: RouteNames.dashboard,
            builder: (_, __) => const Text('DASHBOARD'),
          ),
          GoRoute(
            path: RoutePaths.contacts,
            name: RouteNames.contacts,
            builder: (_, __) => const Text('CONTACTS'),
            routes: [
              GoRoute(
                path: RoutePaths.details,
                name: RouteNames.contactDetails,
                parentNavigatorKey: rootKey,
                builder: (_, state) => Scaffold(
                  body: Text('CONTACT ${state.pathParameters[RoutePaths.idParam]}'),
                ),
              ),
            ],
          ),
          GoRoute(
            path: RoutePaths.activities,
            name: RouteNames.activities,
            redirect: (_, state) => state.uri.path == RoutePaths.activities
                ? RoutePaths.activityList(RoutePaths.tasks)
                : null,
            builder: (_, __) => const Text('ACTIVITIES'),
            routes: [
              GoRoute(
                path: RoutePaths.tasks,
                name: RouteNames.tasks,
                builder: (_, __) => const Text('TASKS'),
                routes: [
                  GoRoute(
                    path: RoutePaths.details,
                    name: RouteNames.taskDetails,
                    parentNavigatorKey: rootKey,
                    builder: (_, state) => Scaffold(
                      body: Text('TASK ${state.pathParameters[RoutePaths.idParam]}'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );

  Widget get app => MaterialApp.router(routerConfig: router);
  String get location =>
      router.routerDelegate.currentConfiguration.last.matchedLocation;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('authentication tree', () {
    testWidgets('an unauthenticated user is sent to login', (tester) async {
      final h = _Harness(isAuthenticated: false);
      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();

      h.router.goNamed(RouteNames.dashboard);
      await tester.pumpAndSettle();

      expect(find.text('LOGIN'), findsOneWidget);
      expect(h.location, RoutePaths.login);
    });

    testWidgets('an authenticated user lands on the dashboard', (tester) async {
      final h = _Harness(isAuthenticated: true);
      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();

      expect(find.text('DASHBOARD'), findsOneWidget);
      expect(h.location, RoutePaths.dashboard);
    });

    testWidgets('login does not stay under the dashboard', (tester) async {
      final h = _Harness(isAuthenticated: false);
      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();
      expect(find.text('LOGIN'), findsOneWidget);

      // Sign in, then `go` to the dashboard the way LoginScreen does.
      h.isAuthenticated = true;
      h.router.goNamed(RouteNames.dashboard);
      await tester.pumpAndSettle();
      expect(find.text('DASHBOARD'), findsOneWidget);

      // Back must not reveal login again.
      expect(h.router.canPop(), isFalse);
    });

    testWidgets('after logout the dashboard is not reachable by Back',
        (tester) async {
      final h = _Harness(isAuthenticated: true);
      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();

      h.isAuthenticated = false;
      h.router.goNamed(RouteNames.login);
      await tester.pumpAndSettle();

      expect(find.text('LOGIN'), findsOneWidget);
      expect(h.router.canPop(), isFalse);
    });
  });

  group('parent → child navigation', () {
    testWidgets('a contact opens by id and Back returns to the list',
        (tester) async {
      final h = _Harness(isAuthenticated: true);
      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();

      h.router.goNamed(RouteNames.contacts);
      await tester.pumpAndSettle();
      expect(find.text('CONTACTS'), findsOneWidget);

      h.router.pushNamed(
        RouteNames.contactDetails,
        pathParameters: {RoutePaths.idParam: 'c-123'},
      );
      await tester.pumpAndSettle();

      // The id in the path is the one that was asked for.
      expect(find.text('CONTACT c-123'), findsOneWidget);
      expect(h.location, '/contacts/details/c-123');

      h.router.pop();
      await tester.pumpAndSettle();
      expect(find.text('CONTACTS'), findsOneWidget);
    });

    testWidgets('a task opens under activities and Back returns to tasks',
        (tester) async {
      final h = _Harness(isAuthenticated: true);
      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();

      h.router.goNamed(RouteNames.tasks);
      await tester.pumpAndSettle();
      expect(find.text('TASKS'), findsOneWidget);

      h.router.pushNamed(
        RouteNames.taskDetails,
        pathParameters: {RoutePaths.idParam: '123'},
      );
      await tester.pumpAndSettle();

      expect(find.text('TASK 123'), findsOneWidget);
      expect(h.location, '/activities/tasks/details/123');

      h.router.pop();
      await tester.pumpAndSettle();
      expect(find.text('TASKS'), findsOneWidget);
    });

    testWidgets('opening two different records shows the second, not the first',
        (tester) async {
      final h = _Harness(isAuthenticated: true);
      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();

      h.router.pushNamed(
        RouteNames.taskDetails,
        pathParameters: {RoutePaths.idParam: '111'},
      );
      await tester.pumpAndSettle();
      expect(find.text('TASK 111'), findsOneWidget);

      h.router.pop();
      await tester.pumpAndSettle();

      h.router.pushNamed(
        RouteNames.taskDetails,
        pathParameters: {RoutePaths.idParam: '222'},
      );
      await tester.pumpAndSettle();

      expect(find.text('TASK 222'), findsOneWidget);
      expect(find.text('TASK 111'), findsNothing);
    });
  });

  group('grouping and error routes', () {
    testWidgets('/activities lands on its first child', (tester) async {
      final h = _Harness(isAuthenticated: true);
      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();

      h.router.go(RoutePaths.activities);
      await tester.pumpAndSettle();

      expect(h.location, '/activities/tasks');
      expect(find.text('TASKS'), findsOneWidget);
    });

    testWidgets('an unknown route shows the not-found screen', (tester) async {
      final h = _Harness(isAuthenticated: true);
      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();

      h.router.go('/does-not-exist');
      await tester.pumpAndSettle();

      expect(find.byType(RouteNotFoundScreen), findsOneWidget);
      expect(find.text('Page not found'), findsOneWidget);
    });
  });
}
