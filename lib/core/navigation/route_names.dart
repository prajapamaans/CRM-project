/// Every route name in the application, in one place.
///
/// Navigate with these rather than hardcoding strings:
/// `context.goNamed(RouteNames.dashboard)`.
class RouteNames {
  RouteNames._();

  // Authentication tree — outside the protected application.
  static const splash = 'splash';
  static const login = 'login';
  static const dataLoader = 'dataLoader';

  // Main application tree.
  static const dashboard = 'dashboard';

  static const contacts = 'contacts';
  static const contactDetails = 'contactDetails';

  static const companies = 'companies';
  static const companyDetails = 'companyDetails';

  static const deals = 'deals';
  static const dealDetails = 'dealDetails';

  static const activities = 'activities';

  static const tasks = 'tasks';
  static const taskDetails = 'taskDetails';

  static const calls = 'calls';
  static const callDetails = 'callDetails';

  static const meetings = 'meetings';
  static const meetingDetails = 'meetingDetails';

  static const emails = 'emails';
  static const emailDetails = 'emailDetails';

  // Remaining main-tree screens reachable from the sidebar / more menu.
  static const reports = 'reports';
  static const bingoAi = 'bingoAi';
  static const notifications = 'notifications';
  static const meetingScheduler = 'meetingScheduler';
  static const calendar = 'calendar';
  static const quarterView = 'quarterView';
  static const documents = 'documents';
  static const templates = 'templates';
  static const userManagement = 'userManagement';
  static const masterDropdowns = 'masterDropdowns';
  static const departments = 'departments';
}
