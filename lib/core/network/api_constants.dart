/// Centralized API constants including base URLs, endpoints, and timeouts.
class ApiConstants {
  ApiConstants._();

  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://192.168.250.2:8050/api',
  );
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);

  // Authentication Endpoints
  static const String emailDetails = '/auth/email-details';
  static const String login = '/auth/login';
  static const String me = '/auth/me';
  static const String refreshToken = '/auth/refresh';
  static const String team = '/auth/team';
  static const String switchDepartment = '/auth/switch-department';

  // Core CRM Endpoints
  static const String departments = '/departments';
  static const String contacts = '/contacts';
  static const String companies = '/companies';
  static const String deals = '/deals';
  static const String dealsStats = '/deals/stats';
  static const String dealsStages = '/deals/stages';
  static const String activities = '/activities';
  static const String dashboard = '/dashboard';
  static const String activitiesStats = '/activities/stats';
  static const String activitiesDashboardUnified = '/activities/dashboard-unified';
  static const String activitiesUnifiedTimeline = '/activities/unified-timeline';
  static const String notifications = '/activities/notifications';

  // Master Data & Configuration Endpoints
  static const String lifecycleStages = '/lifecycle-stages';
  static const String masterDropdowns = '/master-dropdowns';
  static const String mspOptions = '/msp-options';
  static const String emailTemplates = '/email-templates';
  static const String emailTemplatesList = '/email-templates/list';
  static const String meetingSchedulers = '/meeting-schedulers';
  static const String sequences = '/sequences';
  static String sequenceById(String id) => '/sequences/$id';
  static String sequenceEnrollments(String id) => '/sequences/$id/enrollments';
  static String sequenceLogs(String id) => '/sequences/$id/logs';
  static String sequencePerformance(String id) => '/sequences/$id/performance';
  static String masterDropdownByKey(String key) => '/master-dropdowns/key/$key';

  // Report & Dashboard Endpoints
  static const String reportsScope = '/reports/scope';
  static const String reportsUsers = '/reports/users';
  static const String reportsDashboards = '/reports/dashboards';
  static const String reportsDashboardsDefault = '/reports/dashboards/default';
  // AI & Assistant Endpoints
  static const String assistantSummarize = '/assistant/summarize';
}
