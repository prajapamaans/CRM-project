import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/navigation/route_names.dart';
import '../../../../core/navigation/route_paths.dart';
import '../../../../core/widgets/action_pill_button.dart';
import '../../../../core/widgets/stat_card.dart';
import '../../../../core/widgets/work_summary_card.dart';
import '../../../../core/repositories/master_data_repository.dart';
import '../../../../core/providers/master_data_provider.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../contacts/data/models/contact_model.dart';
import '../../../contacts/data/models/contact_lifecycle_count_model.dart';
import '../../../contacts/presentation/providers/contact_provider.dart';
import '../../../companies/presentation/providers/company_provider.dart';
import '../../../deals/data/models/deal_model.dart';
import '../../../deals/presentation/providers/deal_provider.dart';
import '../../../navigation/presentation/providers/navigation_provider.dart';
import '../../../departments/presentation/providers/department_provider.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/models/bingo_summary_model.dart';
import '../../../../core/utils/department_scope.dart';
import '../../../../core/utils/follow_up_task_request.dart';
import '../../../../core/utils/task_activity_history.dart';
import '../../data/models/activity_stats_model.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/activity_leaderboard_card.dart';
import '../widgets/contact_count_card.dart';
import '../widgets/follow_up_task_dialog.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedPillIndex = 0; // 0 = Team, 1 = My work
  int _selectedTimeFilter = 1; // 0: 7 Days, 1: 30 Days, 2: 90 Days, 3: All time
  String? _lastDepartmentId;
  Future<List<Map<String, dynamic>>>? _meetingsBookedFuture;
  bool _isGeneratingBingoAi = false;
  DateTime _customSelectedDate = DateTime.now();

  String _formatDateSubtitle(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    final weekdayStr = weekdays[date.weekday - 1];
    final monthStr = months[date.month - 1];
    return '$weekdayStr, $monthStr ${date.day}, ${date.year}';
  }

  Future<void> _onCustomDateSearchTap() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _customSelectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF00A884),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || !mounted) return;

    setState(() {
      _customSelectedDate = picked;
    });

    // The chosen day is fetched from the backend rather than looked for in
    // what is already on screen: the card shows that day's tasks, and only
    // that day's, however far back it is.
    final ownerId = _selectedPillIndex == 1 ? context.read<AuthProvider>().currentUser?.id : null;
    final deptId = context.read<DepartmentProvider>().selectedDepartmentId;
    await context.read<DashboardProvider>().fetchTasksForDate(
          picked,
          ownerId: ownerId,
          departmentId: deptId,
        );
  }

  /// The department the user is working in, whichever of them it is.
  ///
  /// Read from the picker when they have chosen, and otherwise from their own
  /// account — never from a constant, so a follow-up completed in Australia is
  /// never filed under APAC because nothing had been picked yet.
  String _activeDepartmentId() {
    final departments = context.read<DepartmentProvider>();
    final user = context.read<AuthProvider>().currentUser;
    return resolveActiveDepartmentId(
      selected: departments.selectedDepartmentIdOrNull,
      userDepartmentId: user?.departmentId,
      assignedDepartmentId: departments.assignedDepartmentId,
    );
  }

  /// Reloads the task lists behind the three work cards, for the department
  /// and the owner filter that are selected right now.
  Future<void> _refreshDashboardTasks() async {
    if (!mounted) return;
    final ownerId =
        _selectedPillIndex == 1 ? context.read<AuthProvider>().currentUser?.id : null;
    final departmentId = context.read<DepartmentProvider>().selectedDepartmentId;
    await context.read<DashboardProvider>().fetchDashboardTasks(
          ownerId: ownerId,
          departmentId: departmentId,
        );
  }

  void _showTaskMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        backgroundColor: isError ? Colors.red : const Color(0xFF00A884),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  /// The Dashboard's task checkbox.
  ///
  /// Completing a task offers a follow-up straight afterwards; this is the only
  /// screen that does so, which is why the offer lives here and not in the card
  /// or in the provider. Unticking a completed task is just an update — there
  /// is nothing to follow up on — and a completion the server refused shows the
  /// error and stops, leaving the checkbox as it was.
  Future<void> _onToggleTaskStatus(
    Map<String, dynamic> task,
    String newStatus,
  ) async {
    final taskId = activityId(task);
    if (taskId == null) return;

    final dashboard = context.read<DashboardProvider>();
    final departmentId = _activeDepartmentId();

    late final Map<String, dynamic> completed;
    try {
      completed = await dashboard.setTaskStatus(
        taskId,
        newStatus,
        departmentId: departmentId,
      );
    } catch (e) {
      _showTaskMessage(
        newStatus == 'completed'
            ? 'The task could not be completed: ${_taskErrorText(e)}'
            : 'The task could not be updated: ${_taskErrorText(e)}',
        isError: true,
      );
      return;
    }

    if (newStatus != 'completed') {
      await _refreshDashboardTasks();
      return;
    }
    if (!mounted) return;

    final choice = await FollowUpTaskDialog.show(
      context,
      taskTitle: taskTitle(completed) ?? taskTitle(task) ?? '',
      completedAt: taskCompletedAt(completed) ?? DateTime.now(),
    );

    Map<String, dynamic>? followUpTask;
    if (choice != null) {
      try {
        followUpTask = await dashboard.createFollowUpTask(
          original: completed,
          scheduledAt: choice.scheduledAt,
          departmentId: departmentId,
          selectedDepartmentId: _activeDepartmentId(),
        );
        _showTaskMessage('Follow-up task created.');
      } catch (e) {
        _showTaskMessage(
          'The task was completed, but the follow-up could not be created: '
          '${_taskErrorText(e)}',
          isError: true,
        );
      }
    } else {
      _showTaskMessage('Task completed.');
    }

    String? resolveAssociatedId(String objectType) {
      for (final item in [followUpTask, completed, task]) {
        if (item == null) continue;
        final direct = item['${objectType}Id'] ?? item['${objectType}_id'];
        if (direct != null && direct.toString().isNotEmpty) return direct.toString();
        final obj = item[objectType];
        if (obj is Map && obj['id'] != null) return obj['id'].toString();

        final assoc = item['associations'];
        if (assoc is List) {
          for (final a in assoc) {
            if (a is Map && a['objectType'] == objectType && a['objectId'] != null) {
              return a['objectId'].toString();
            }
          }
        } else if (assoc is Map) {
          final listKey = objectType == 'company'
              ? 'Companies'
              : (objectType == 'contact' ? 'Contacts' : 'Deals');
          if (assoc[listKey] is List && (assoc[listKey] as List).isNotEmpty) {
            final first = (assoc[listKey] as List).first;
            if (first is Map) {
              return (first['id'] ?? first['_id'] ?? first['objectId'])?.toString();
            }
          }
        }
      }
      return null;
    }

    final companyId = resolveAssociatedId('company');
    final contactId = resolveAssociatedId('contact');
    final dealId = resolveAssociatedId('deal');
    final targetActId = (followUpTask?['id'] ?? followUpTask?['_id'] ?? completed['id'] ?? completed['_id'] ?? taskId)?.toString();

    if (mounted) {
      if (companyId != null && companyId.isNotEmpty) {
        context.pushNamed(
          RouteNames.companyDetails,
          pathParameters: {RoutePaths.idParam: companyId},
          queryParameters: RoutePaths.recordActivityQuery(targetActId),
        );
      } else if (contactId != null && contactId.isNotEmpty) {
        context.pushNamed(
          RouteNames.contactDetails,
          pathParameters: {RoutePaths.idParam: contactId},
          queryParameters: RoutePaths.recordActivityQuery(targetActId),
        );
      } else if (dealId != null && dealId.isNotEmpty) {
        context.pushNamed(
          RouteNames.dealDetails,
          pathParameters: {RoutePaths.idParam: dealId},
          queryParameters: RoutePaths.recordActivityQuery(targetActId),
        );
      } else if (targetActId != null && targetActId.isNotEmpty) {
        context.pushNamed(
          RouteNames.taskDetails,
          pathParameters: {RoutePaths.idParam: targetActId},
        );
      }
    }

    await _refreshDashboardTasks();
  }

  static String _taskErrorText(Object error) {
    if (error is StateError) return error.message;
    return error.toString();
  }

  void _onTaskTap(Map<String, dynamic> act) async {
    final taskId = (act['id'] ?? act['_id'])?.toString();
    if (taskId == null || taskId.isEmpty) return;

    String? compId = (act['companyId'] ?? act['company_id'] ?? (act['company'] is Map ? act['company']['id'] : null))?.toString();
    String? contactId = (act['contactId'] ?? act['contact_id'] ?? (act['contact'] is Map ? act['contact']['id'] : null))?.toString();
    String? dealId = (act['dealId'] ?? act['deal_id'] ?? (act['deal'] is Map ? act['deal']['id'] : null))?.toString();

    if (compId != null && compId.isNotEmpty) {
      await context.pushNamed(
        RouteNames.companyDetails,
        pathParameters: {RoutePaths.idParam: compId},
        queryParameters: RoutePaths.recordActivityQuery(taskId),
      );
    } else if (contactId != null && contactId.isNotEmpty) {
      await context.pushNamed(
        RouteNames.contactDetails,
        pathParameters: {RoutePaths.idParam: contactId},
        queryParameters: RoutePaths.recordActivityQuery(taskId),
      );
    } else if (dealId != null && dealId.isNotEmpty) {
      await context.pushNamed(
        RouteNames.dealDetails,
        pathParameters: {RoutePaths.idParam: dealId},
        queryParameters: RoutePaths.recordActivityQuery(taskId),
      );
    } else {
      await context.pushNamed<bool>(
        RouteNames.taskDetails,
        pathParameters: {RoutePaths.idParam: taskId},
      );
    }

    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final ownerId = _selectedPillIndex == 1 ? auth.currentUser?.id : null;
    final deptId = context.read<DepartmentProvider>().selectedDepartmentId;
    context.read<DashboardProvider>().fetchDashboardTasks(ownerId: ownerId, departmentId: deptId);
  }

  Map<String, String?> _getDashboardTimeFilterRange() {
    final now = DateTime.now();
    DateTime? start;
    DateTime? end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (_selectedTimeFilter) {
      case 0: // 7 Days
        start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
        break;
      case 1: // 30 Days
        start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));
        break;
      case 2: // 90 Days
        start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 90));
        break;
      case 3: // All time
      default:
        start = null;
        end = null;
        break;
    }

    final startStr = start != null
        ? "${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}"
        : null;
    final endStr = end != null
        ? "${end.year.toString().padLeft(4, '0')}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}"
        : null;

    return {'startDate': startStr, 'endDate': endStr};
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final departments = context.watch<DepartmentProvider>();

    // Mid-switch the selected id has already changed but the access token it
    // depends on has not been swapped yet — and the API reads the department
    // from that token. Fetching now would answer with the department being
    // left. Wait for the switch to settle.
    if (departments.isSwitchingDepartment) return;

    final deptId = departments.selectedDepartmentId;
    if (_lastDepartmentId == deptId) return;

    final isFirstBuild = _lastDepartmentId == null;
    final prevDeptId = _lastDepartmentId;
    _lastDepartmentId = deptId;

    debugPrint('==================================================');
    debugPrint('[DASHBOARD SCREEN DEPARTMENT CHANGE DETECTED]');
    debugPrint('Previous Department ID: ${prevDeptId ?? 'FIRST BUILD'}');
    debugPrint('Selected Department Name: ${departments.selectedDepartmentName}');
    debugPrint('Selected Department ID: $deptId');
    debugPrint('==================================================');

    _meetingsBookedFuture =
        MasterDataRepositoryImpl().getActivities(type: 'meeting', departmentId: deptId);

    // initState already loads the first department. Every change after that
    // reloads here, so the Dashboard follows the department in both
    // directions and however many times it is switched — and does so with the
    // owner and time filters the user currently has selected, which the
    // app-wide reload does not know about.
    if (!isFirstBuild) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadDashboard();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      final master = context.read<MasterDataProvider>();
      final currentUserId = auth.currentUser?.id;
      final deptId = context.read<DepartmentProvider>().selectedDepartmentId;
      final range = _getDashboardTimeFilterRange();
      
      final teamMembers = await auth.fetchTeamMembers();
      await master.fetchAllMasterData(
        currentUserId: currentUserId,
        departmentId: deptId,
      );
      final reportUsers = master.reportsUsers;

      if (mounted) {
        final ownerId = _selectedPillIndex == 1 ? currentUserId : null;
        context.read<ContactProvider>().setSegmentScope(ownerId: ownerId, departmentId: deptId);
        context.read<CompanyProvider>().setSegmentScope(ownerId: ownerId, departmentId: deptId);
        context.read<DealProvider>().setSegmentScope(ownerId: ownerId, departmentId: deptId);

        context.read<DashboardProvider>().loadDashboardData(
          ownerId: ownerId,
          departmentId: deptId,
          departmentName: context.read<DepartmentProvider>().selectedDepartmentName,
          startDate: range['startDate'],
          endDate: range['endDate'],
          subtitleLabel: _performanceSubtitleLabel,
          teamMembers: teamMembers,
          customTaskDate: _customSelectedDate,
          reportUsers: reportUsers,
        );
      }
    });
  }

  /// Loads every Dashboard section for the department that is selected right
  /// now, with the owner and time filters the user has on screen.
  ///
  /// The one place the Dashboard asks for its data, so the department can only
  /// be read from one source and every section is asked for the same one.
  Future<void> _loadDashboard() {
    final auth = context.read<AuthProvider>();
    final master = context.read<MasterDataProvider>();
    final departments = context.read<DepartmentProvider>();
    final range = _getDashboardTimeFilterRange();
    final ownerId = _selectedPillIndex == 1 ? auth.currentUser?.id : null;
    final deptId = departments.selectedDepartmentId;

    context.read<ContactProvider>().setSegmentScope(ownerId: ownerId, departmentId: deptId);
    context.read<CompanyProvider>().setSegmentScope(ownerId: ownerId, departmentId: deptId);
    context.read<DealProvider>().setSegmentScope(ownerId: ownerId, departmentId: deptId);

    return context.read<DashboardProvider>().loadDashboardData(
          ownerId: ownerId,
          departmentId: deptId,
          departmentName: departments.selectedDepartmentName,
          startDate: range['startDate'],
          endDate: range['endDate'],
          subtitleLabel: _performanceSubtitleLabel,
          teamMembers: auth.teamMembers,
          customTaskDate: _customSelectedDate,
          reportUsers: master.reportsUsers,
        );
  }

  void _onTogglePill(int index) {
    setState(() {
      _selectedPillIndex = index;
    });
    _loadDashboard();
  }

  DateTime? get _performanceCutoffDate {
    final now = DateTime.now();
    switch (_selectedTimeFilter) {
      case 0:
        return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
      case 1:
        return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));
      case 2:
        return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 90));
      case 3:
      default:
        return null;
    }
  }

  String get _performanceSubtitleLabel {
    switch (_selectedTimeFilter) {
      case 0:
        return 'LAST 7 DAYS';
      case 1:
        return 'LAST 30 DAYS';
      case 2:
        return 'LAST 90 DAYS';
      case 3:
      default:
        return 'ALL TIME';
    }
  }

  void _navTo(String routeName, int tabIndex) {
    context.read<NavigationProvider>().selectScreen(tabIndex);
    context.goNamed(routeName);
  }

  void _onTimeFilterChanged(int index) {
    setState(() {
      _selectedTimeFilter = index;
    });
    _loadDashboard();
  }

  Future<void> _handleAskBingoTap() async {
    if (_isGeneratingBingoAi) return;

    final auth = context.read<AuthProvider>();
    final userId = auth.currentUser?.id ?? 'me';

    setState(() {
      _isGeneratingBingoAi = true;
    });

    // Show Bingo AI Modal
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return FutureBuilder<BingoSummaryResponse>(
              future: ApiService().getBingoSummary(
                recordType: 'dashboard',
                recordId: userId,
              ),
              builder: (context, snapshot) {
                return Container(
                  height: MediaQuery.of(context).size.height * 0.7,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3E8FF),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFD8B4FE)),
                                ),
                                child: const Icon(
                                  Icons.auto_awesome_rounded,
                                  color: Color(0xFF7C3AED),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Bingo AI Assistant',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                  Text(
                                    'CRM Workspace Analysis',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 16),

                      // Content State
                      Expanded(
                        child: snapshot.connectionState == ConnectionState.waiting
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const CircularProgressIndicator(color: Color(0xFF7C3AED)),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Bingo AI is analyzing your CRM data...',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : snapshot.hasError
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.error_outline_rounded,
                                          color: Color(0xFFEF4444),
                                          size: 40,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Failed to generate AI analysis',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF1E293B),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          snapshot.error.toString(),
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF7C3AED),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                          onPressed: () {
                                            setModalState(() {});
                                          },
                                          icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
                                          label: Text(
                                            'Retry',
                                            style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : SingleChildScrollView(
                                    physics: const BouncingScrollPhysics(),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                          ),
                                          child: Text(
                                            snapshot.data?.data.summary.isNotEmpty == true
                                                ? snapshot.data!.data.summary
                                                : 'Bingo AI has compiled key data from your workspace. Review active leads, pending tasks, and deals to stay on track!',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              height: 1.5,
                                              color: const Color(0xFF334155),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        if (snapshot.data?.data.activities.isNotEmpty == true) ...[
                                          Text(
                                            'Key Recommended Activities',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF1E293B),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          ...snapshot.data!.data.activities.map(
                                            (act) => Container(
                                              margin: const EdgeInsets.only(bottom: 8),
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.task_alt_rounded,
                                                    color: Color(0xFF00A884),
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      act.title ?? act.description ?? act.type,
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 12,
                                                        color: const Color(0xFF1E293B),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00A884),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            context.read<NavigationProvider>().selectScreen(5);
                          },
                          icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 18),
                          label: Text(
                            'Open Full Bingo AI Assistant',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    ).whenComplete(() {
      if (mounted) {
        setState(() {
          _isGeneratingBingoAi = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 800;
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser;
    final dashboardProvider = context.watch<DashboardProvider>();
    final contactProvider = context.watch<ContactProvider>();
    final companyProvider = context.watch<CompanyProvider>();
    final dealProvider = context.watch<DealProvider>();
    final deptProvider = context.watch<DepartmentProvider>();
    final stats = dashboardProvider.stats;
    final contactsList = contactProvider.contacts;
    final dealsList = dealProvider.deals;
    final isSwitching = deptProvider.isSwitchingDepartment;

    final reportsData = dashboardProvider.reportsDashboardData;
    final Map<String, dynamic>? dataObj = reportsData != null
        ? (reportsData['data'] is Map<String, dynamic> ? reportsData['data'] as Map<String, dynamic> : reportsData)
        : null;

    int displayContactsCount = contactProvider.totalCount;
    int displayCompaniesCount = companyProvider.totalCount;
    int displayDealsCount = dealProvider.totalCount;
    int displayTasksCount = stats?.tasks != null && stats!.tasks > 0
        ? stats.tasks
        : (stats?.pendingTasks ?? 0);

    if (dataObj != null) {
      final dynamic rawContacts = dataObj['totalContactsOwned'] ?? dataObj['totalContacts'] ?? dataObj['contactsCount'];
      if (rawContacts is num) displayContactsCount = rawContacts.toInt();

      final dynamic rawCompanies = dataObj['totalCompaniesOwned'] ?? dataObj['totalCompanies'] ?? dataObj['companiesCount'];
      if (rawCompanies is num) displayCompaniesCount = rawCompanies.toInt();

      final dynamic rawDeals = dataObj['totalDealsOwned'] ?? dataObj['totalDeals'] ?? dataObj['dealsCount'];
      if (rawDeals is num) displayDealsCount = rawDeals.toInt();

      final dynamic rawTasks = dataObj['totalTasksOwned'] ?? dataObj['totalTasks'] ?? dataObj['tasksCount'];
      if (rawTasks is num) displayTasksCount = rawTasks.toInt();
    }

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
          // Refreshing keeps what the user has selected — the time filter, the
          // My Work / Team pill and the custom date. Calling the provider
          // directly here dropped all three, so a pull-to-refresh silently
          // reset the Dashboard to its defaults.
          onRefresh: _loadDashboard,
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

                if (isSwitching || (dashboardProvider.isLoadingStats && stats == null))
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFF00A884)),
                    ),
                  )
                else ...[
                  // 2. Stat Cards Section (4 Boxes - 2 Boxes per Line: Company, Contact, Deal, Task)
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              label: 'Companies',
                              value: '$displayCompaniesCount',
                              icon: Icons.domain_rounded,
                              iconBgColor: const Color(0xFFE0F2FE),
                              iconColor: const Color(0xFF0284C7),
                              onTap: () => _navTo(RouteNames.companies, 2),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: StatCard(
                              label: 'Contacts',
                              value: '$displayContactsCount',
                              icon: Icons.people_alt_rounded,
                              iconBgColor: const Color(0xFFE6F4F1),
                              iconColor: const Color(0xFF00A884),
                              onTap: () => _navTo(RouteNames.contacts, 1),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              label: 'Deals',
                              value: '$displayDealsCount',
                              icon: Icons.monetization_on_rounded,
                              iconBgColor: const Color(0xFFFEF3C7),
                              iconColor: const Color(0xFFD97706),
                              onTap: () => _navTo(RouteNames.deals, 3),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: StatCard(
                              label: 'Tasks',
                              value: '$displayTasksCount',
                              icon: Icons.task_alt_rounded,
                              iconBgColor: const Color(0xFFF3E8FF),
                              iconColor: const Color(0xFF7C3AED),
                              onTap: () => _navTo(RouteNames.tasks, 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // 3. Work Summary Cards (Today's Work, Yesterday's Work, Custom Date Search)
                  Builder(
                    builder: (context) {
                      final today = DateTime.now();
                      final yesterday = today.subtract(const Duration(days: 1));

                      final todayGroup = dashboardProvider.getTasksForDate(today);
                      final yesterdayGroup = dashboardProvider.getTasksForDate(yesterday);
                      final customGroup = dashboardProvider.getTasksForDate(_customSelectedDate);

                      void navigateToTasks() {
                        _navTo(RouteNames.tasks, 12);
                      }

                      final todayCard = WorkSummaryCard(
                        title: "Today's Work",
                        dateString: _formatDateSubtitle(today),
                        taskGroup: todayGroup,
                        onViewAllTap: navigateToTasks,
                        onToggleTaskStatus: _onToggleTaskStatus,
                        onTaskTap: _onTaskTap,
                      );

                      final yesterdayCard = WorkSummaryCard(
                        title: "Yesterday's Work",
                        dateString: _formatDateSubtitle(yesterday),
                        taskGroup: yesterdayGroup,
                        onViewAllTap: navigateToTasks,
                        onToggleTaskStatus: _onToggleTaskStatus,
                        onTaskTap: _onTaskTap,
                      );

                      final customCard = WorkSummaryCard(
                        title: "Custom Date Search",
                        dateString: _formatDateSubtitle(_customSelectedDate),
                        taskGroup: customGroup,
                        showFilterButton: true,
                        onFilterTap: _onCustomDateSearchTap,
                        onViewAllTap: navigateToTasks,
                        onToggleTaskStatus: _onToggleTaskStatus,
                        onTaskTap: _onTaskTap,
                      );

                      if (isDesktop) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: todayCard),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(child: yesterdayCard),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(child: customCard),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            todayCard,
                            const SizedBox(height: AppSpacing.lg),
                            yesterdayCard,
                            const SizedBox(height: AppSpacing.lg),
                            customCard,
                          ],
                        );
                      }
                    },
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
                            final deptProvider = context.read<DepartmentProvider>();
                            context.read<DashboardProvider>().loadDashboardData(
                              departmentId: deptProvider.selectedDepartmentId,
                              departmentName: deptProvider.selectedDepartmentName,
                            );
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
                    subtitle: _performanceSubtitleLabel,
                    onTap: () => _navTo(RouteNames.contacts, 1),
                    child: _buildLifecycleFunnelTable(contactsList),
                  ),

                  const SizedBox(height: 16),

                  // Card 2: Team activity totals -> Reports Screen
                  _buildDashboardCard(
                    title: 'Team activity totals',
                    subtitle: _performanceSubtitleLabel,
                    onTap: () => _navTo(RouteNames.reports, 4),
                    child: _buildTeamActivityTotalsGrid(stats),
                  ),

                  const SizedBox(height: 16),

                  // Card 3: Deal stage overview -> Deals Screen
                  _buildDashboardCard(
                    title: 'Deal stage overview',
                    subtitle: _performanceSubtitleLabel,
                    onTap: () => _navTo(RouteNames.deals, 3),
                    child: _buildDealsByStageContent(dealsList),
                  ),

                  const SizedBox(height: 16),

                  // Card 4: Deals in sales pipeline stages by owner -> Deals Screen
                  _buildDashboardCard(
                    title: 'Deals in sales pipeline stages by ...',
                    subtitle: _performanceSubtitleLabel,
                    onTap: () => _navTo(RouteNames.deals, 3),
                    child: _buildDealsByOwnerContent(dealsList),
                  ),

                  const SizedBox(height: 16),

                  // Card 5: Contact created totals by first conversion -> Contacts Screen
                  _buildDashboardCard(
                    title: 'Contact created totals by first co...',
                    subtitle: _performanceSubtitleLabel,
                    onTap: () => _navTo(RouteNames.contacts, 1),
                    child: _buildFirstConversionContent(contactsList),
                  ),

                  const SizedBox(height: 16),

                  // Card 6: Call and meeting totals by rep -> Calls Screen
                  _buildDashboardCard(
                    title: 'Call and meeting totals by rep',
                    subtitle: _performanceSubtitleLabel,
                    onTap: () => _navTo(RouteNames.calls, 9),
                    child: _buildCallAndMeetingTotalsByRepContent(),
                  ),

                  const SizedBox(height: 16),

                  // Card 7: Email sent, opened, and click totals -> Emails Screen
                  _buildDashboardCard(
                    title: 'Email sent, opened, and click tot...',
                    subtitle: _performanceSubtitleLabel,
                    onTap: () => _navTo(RouteNames.emails, 10),
                    child: _buildEmailTotalsGrid(stats),
                  ),

                  const SizedBox(height: 16),

                  // Card 8: Meetings booked with reps by owner -> Meetings Screen
                  _buildDashboardCard(
                    title: 'Meetings booked with reps by ow...',
                    subtitle: _performanceSubtitleLabel,
                    onTap: () => _navTo(RouteNames.meetings, 7),
                    child: _buildMeetingsBookedTable(),
                  ),

                  const SizedBox(height: 16),

                  // Card 9: Activity of recently created contacts -> Contacts Screen
                  _buildDashboardCard(
                    title: 'Activity of recently created cont...',
                    subtitle: _performanceSubtitleLabel,
                    onTap: () => _navTo(RouteNames.contacts, 1),
                    child: _buildRecentlyCreatedContactsTable(contactsList),
                  ),

                  const SizedBox(height: 16),

                  // Card 10: Deals by last modified date -> Deals Screen
                  _buildDashboardCard(
                    title: 'Deals by last modified date',
                    subtitle: _performanceSubtitleLabel,
                    onTap: () => _navTo(RouteNames.deals, 3),
                    child: _buildDealsByLastModifiedTable(dealsList),
                  ),

                  const SizedBox(height: 16),

                  // Card 11: Activity Leaderboard by Rep
                  ActivityLeaderboardCard(
                    items: dashboardProvider.activityLeaderboard,
                    isLoading: dashboardProvider.isLoadingLeaderboard,
                    subtitleLabel: dashboardProvider.leaderboardSubtitleLabel,
                    onRefresh: () async {
                      final deptId = context.read<DepartmentProvider>().selectedDepartmentId;
                      final reportUsers = context.read<MasterDataProvider>().reportsUsers;
                      final teamMembers = await context.read<AuthProvider>().fetchTeamMembers();
                      final range = _getDashboardTimeFilterRange();
                      if (!mounted) return;
                      dashboardProvider.fetchActivityLeaderboard(
                        startDate: range['startDate'],
                        endDate: range['endDate'],
                        subtitleLabel: _performanceSubtitleLabel,
                        departmentId: deptId,
                        teamMembers: teamMembers,
                        reportUsers: reportUsers,
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // Card 12: (Count) Contacts by Owner (LAST 30 DAYS)
                  ContactCountCard(
                    items: dashboardProvider.contactOwnerCounts,
                    isLoading: dashboardProvider.isLoadingContactCounts,
                    onRefresh: () async {
                      final deptId = context.read<DepartmentProvider>().selectedDepartmentId;
                      final teamMembers = await context.read<AuthProvider>().fetchTeamMembers();
                      dashboardProvider.fetchContactOwnerCounts(
                        departmentId: deptId,
                        teamMembers: teamMembers,
                      );
                    },
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
            onTap: _handleAskBingoTap,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeFilterPill(int index, String label) {
    final bool isSelected = _selectedTimeFilter == index;
    return GestureDetector(
      onTap: () => _onTimeFilterChanged(index),
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
    final deptId = context.watch<DepartmentProvider>().selectedDepartmentId;
    _meetingsBookedFuture ??= MasterDataRepositoryImpl().getActivities(type: 'meeting', departmentId: deptId);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _meetingsBookedFuture,
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
    final cutoff = _performanceCutoffDate;
    final filteredContacts = cutoff == null
        ? contacts
        : contacts.where((c) {
            if (c.createdAt == null || c.createdAt!.trim().isEmpty) return true;
            final dt = DateTime.tryParse(c.createdAt!.trim());
            if (dt == null) return true;
            return dt.isAfter(cutoff);
          }).toList();

    final masterStages = context.watch<MasterDataProvider>().contactLifecycleStages;
    final summary = ContactLifecycleAnalyzer.analyze(
      contacts: filteredContacts,
      masterStages: masterStages,
    );

    final List<Map<String, dynamic>> funnelRows = [
      {
        'name': 'All created contacts',
        'count': summary.totalContacts,
      },
      ...summary.stageCounts.map((sc) => {
            'name': sc.stageName,
            'count': sc.count,
          }),
    ];

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
          ...List.generate(funnelRows.length, (index) {
            final row = funnelRows[index];
            final name = row['name'] as String;
            final count = row['count'] as int;
            final isZero = count == 0;

            String fromPrevStr = '-';
            if (index == 0) {
              fromPrevStr = filteredContacts.isNotEmpty ? '100%' : '-';
            } else {
              final prevCount = funnelRows[index - 1]['count'] as int;
              if (prevCount > 0 && count > 0) {
                final pct = ((count / prevCount) * 100).round();
                fromPrevStr = '$pct%';
              } else if (count > 0) {
                fromPrevStr = '100%';
              }
            }

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                children: [
                  SizedBox(width: 145, child: Text(name, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF334155)))),
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
                      fromPrevStr,
                      style: GoogleFonts.poppins(fontSize: 11, color: isZero || fromPrevStr == '-' ? const Color(0xFF94A3B8) : const Color(0xFF00BDA5)),
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
                      widthFactor: count > 0 ? (count / (count > 20 ? count : 20)).clamp(0.05, 1.0) : 0.05,
                      child: Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: count > 10
                              ? const Color(0xFF00A884)
                              : count > 0
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFFCBD5E1),
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
    final dashboardProvider = context.watch<DashboardProvider>();
    final items = dashboardProvider.callAndMeetingTotals;
    final stats = dashboardProvider.stats;

    if (dashboardProvider.isLoadingCallAndMeeting) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00A884)),
          ),
        ),
      );
    }

    if (items.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: const Color(0xFFF8FAFC),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'REPRESENTATIVE',
                    style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF475569), letterSpacing: 0.5),
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    'CALLS',
                    textAlign: TextAlign.end,
                    style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF475569), letterSpacing: 0.5),
                  ),
                ),
                SizedBox(
                  width: 75,
                  child: Text(
                    'MEETINGS',
                    textAlign: TextAlign.end,
                    style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF475569), letterSpacing: 0.5),
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    'TOTAL',
                    textAlign: TextAlign.end,
                    style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF475569), letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          ...items.map((item) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.repName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w500, color: const Color(0xFF334155)),
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      '${item.callCount}',
                      textAlign: TextAlign.end,
                      style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF475569)),
                    ),
                  ),
                  SizedBox(
                    width: 75,
                    child: Text(
                      '${item.meetingCount}',
                      textAlign: TextAlign.end,
                      style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF475569)),
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      '${item.totalCount}',
                      textAlign: TextAlign.end,
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F766E)),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      );
    }

    // Fallback using real activity stats if available
    if (stats != null && ((stats.calls > 0) || (stats.meetings > 0))) {
      return Row(
        children: [
          Expanded(child: _buildMetricTile('CALLS', '${stats.calls}', '', const Color(0xFF0F766E))),
          const SizedBox(width: 12),
          Expanded(child: _buildMetricTile('MEETINGS', '${stats.meetings}', '', const Color(0xFF7C3AED))),
        ],
      );
    }

    return _buildEmptyState('No call or meeting data in this time frame');
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
