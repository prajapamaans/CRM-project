/// Every route path in the application, in one place.
///
/// Child paths are relative — go_router joins them onto the parent, so
/// [contacts] + [details] resolves to `/contacts/details/:id`.
class RoutePaths {
  RoutePaths._();

  /// Shared child segment for every detail screen: `details/:id`.
  static const details = 'details/:id';

  /// Path parameter carrying the record id.
  static const idParam = 'id';

  // Authentication tree.
  static const splash = '/';
  static const login = '/login';
  static const dataLoader = '/loading';

  // Main application tree.
  static const dashboard = '/dashboard';

  static const contacts = '/contacts';
  static const companies = '/companies';
  static const deals = '/deals';

  /// Activities is the parent of the four activity lists.
  static const activities = '/activities';
  static const tasks = 'tasks';
  static const calls = 'calls';
  static const meetings = 'meetings';
  static const emails = 'emails';

  // Remaining main-tree screens.
  static const reports = '/reports';
  static const bingoAi = '/bingo-ai';
  static const notifications = '/notifications';
  static const meetingScheduler = '/meeting-scheduler';
  static const calendar = '/calendar';
  static const quarterView = '/quarter-view';
  static const documents = '/documents';
  static const templates = '/templates';
  static const userManagement = '/user-management';
  static const masterDropdowns = '/master-dropdowns';
  static const departments = '/departments';

  /// Absolute location of an activity list, e.g. `/activities/tasks`.
  static String activityList(String segment) => '$activities/$segment';

  /// Query for opening a record's details on its Activities tab with
  /// [activityId] highlighted. Both are optional extras, so a missing id simply
  /// opens the tab.
  static Map<String, String> recordActivityQuery(String? activityId) {
    final id = activityId?.trim();
    return {
      'tab': '1',
      if (id != null && id.isNotEmpty) 'activityId': id,
    };
  }
}
