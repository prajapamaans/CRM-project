import 'package:flutter_test/flutter_test.dart';

import 'package:crmproject/core/navigation/app_router.dart';
import 'package:crmproject/core/navigation/route_names.dart';
import 'package:crmproject/core/navigation/route_paths.dart';

void main() {
  group('the route tree', () {
    test('nests every detail route under its list route', () {
      // Parent → child, as paths.
      expect(RoutePaths.contacts, '/contacts');
      expect(RoutePaths.companies, '/companies');
      expect(RoutePaths.deals, '/deals');
      expect(RoutePaths.activities, '/activities');

      expect(RoutePaths.activityList(RoutePaths.tasks), '/activities/tasks');
      expect(RoutePaths.activityList(RoutePaths.calls), '/activities/calls');
      expect(RoutePaths.activityList(RoutePaths.meetings), '/activities/meetings');
      expect(RoutePaths.activityList(RoutePaths.emails), '/activities/emails');

      // Every detail screen is addressed by id, never by a model.
      expect(RoutePaths.details, 'details/:id');
      expect(RoutePaths.idParam, 'id');
    });

    test('gives each tab a location', () {
      expect(AppRouter.locationForTab(0), RoutePaths.dashboard);
      expect(AppRouter.locationForTab(1), RoutePaths.contacts);
      expect(AppRouter.locationForTab(2), RoutePaths.companies);
      expect(AppRouter.locationForTab(3), RoutePaths.deals);
      expect(AppRouter.locationForTab(7), '/activities/meetings');
      expect(AppRouter.locationForTab(9), '/activities/calls');
      expect(AppRouter.locationForTab(10), '/activities/emails');
      expect(AppRouter.locationForTab(12), '/activities/tasks');
      expect(AppRouter.locationForTab(99), isNull);
    });

    test('maps a location back to the tab that owns it', () {
      expect(AppRouter.tabIndexForLocation('/dashboard'), 0);
      expect(AppRouter.tabIndexForLocation('/contacts'), 1);
      // A detail route still belongs to its parent tab.
      expect(AppRouter.tabIndexForLocation('/contacts/details/abc'), 1);
      expect(AppRouter.tabIndexForLocation('/companies/details/abc'), 2);
      expect(AppRouter.tabIndexForLocation('/deals/details/abc'), 3);
      expect(AppRouter.tabIndexForLocation('/activities/calls'), 9);
      expect(AppRouter.tabIndexForLocation('/activities/calls/details/abc'), 9);
      expect(AppRouter.tabIndexForLocation('/activities/meetings/details/abc'), 7);
      expect(AppRouter.tabIndexForLocation('/activities/emails/details/abc'), 10);
      // Unknown locations fall back to Dashboard rather than throwing.
      expect(AppRouter.tabIndexForLocation('/nope'), 0);
    });

    test('every tab index maps to a route name', () {
      for (final entry in AppRouter.tabRouteNames.entries) {
        expect(AppRouter.locationForTab(entry.key), isNotNull,
            reason: 'tab ${entry.key} (${entry.value}) has no location');
      }
    });
  });

  group('the record-activity query', () {
    test('opens the Activities tab and highlights the activity', () {
      expect(RoutePaths.recordActivityQuery('act-1'), {
        'tab': '1',
        'activityId': 'act-1',
      });
    });

    test('omits a missing activity id', () {
      expect(RoutePaths.recordActivityQuery(null), {'tab': '1'});
      expect(RoutePaths.recordActivityQuery(''), {'tab': '1'});
      expect(RoutePaths.recordActivityQuery('   '), {'tab': '1'});
    });
  });

  group('route names', () {
    test('are unique', () {
      const names = [
        RouteNames.splash,
        RouteNames.login,
        RouteNames.dataLoader,
        RouteNames.dashboard,
        RouteNames.contacts,
        RouteNames.contactDetails,
        RouteNames.companies,
        RouteNames.companyDetails,
        RouteNames.deals,
        RouteNames.dealDetails,
        RouteNames.activities,
        RouteNames.tasks,
        RouteNames.taskDetails,
        RouteNames.calls,
        RouteNames.callDetails,
        RouteNames.meetings,
        RouteNames.meetingDetails,
        RouteNames.emails,
        RouteNames.emailDetails,
      ];
      expect(names.toSet().length, names.length);
    });
  });
}
