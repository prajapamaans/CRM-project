import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:crmproject/core/widgets/app_refresh_indicator.dart';
import 'package:crmproject/core/utils/activity_utils.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/storage/follow_up_link_storage.dart';
import '../../../../core/utils/activity_task_fields.dart';
import '../../../../core/utils/department_scope.dart';
import '../../../../core/utils/follow_up_schedule.dart';
import '../../../../core/utils/follow_up_task_request.dart';
import '../../../../core/utils/task_activity_history.dart';
import '../../../../core/widgets/record_loading_scaffold.dart';
import '../../../departments/presentation/providers/department_provider.dart';
import '../widgets/create_task_modal.dart';

class TaskDetailsScreen extends StatefulWidget {
  final TaskModel? task;

  /// Id of the task to load when opened by route
  /// (`/activities/tasks/details/:id`) rather than handed a loaded model.
  final String? taskId;

  const TaskDetailsScreen({super.key, this.task, this.taskId});

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  late TaskModel _task;
  bool _isLoadingById = false;
  String? _loadError;

  /// The task the thread started from, and the follow-ups that came out of it.
  /// Both are rows straight from the API; the history is read off them.
  Map<String, dynamic>? _threadRoot;
  List<Map<String, dynamic>> _threadFollowUps = [];
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    if (task != null) {
      _task = task;
      _loadHistory();
    } else {
      // Placeholder while the record is fetched; build shows a spinner until
      // the real task arrives, so this is never rendered.
      _task = TaskModel(
        title: '',
        dueDate: '',
        priority: '',
        status: '',
        assignedTo: '',
      );
      _isLoadingById = true;
      _loadTaskById();
    }
  }

  /// Loads the task behind the `:id` path parameter.
  Future<void> _loadTaskById() async {
    final id = widget.taskId?.trim();
    if (id == null || id.isEmpty) {
      setState(() {
        _isLoadingById = false;
        _loadError = 'No task was specified.';
      });
      return;
    }

    try {
      final res = await ApiService().get(
        '${ApiConstants.activities}/$id',
        queryParameters: departmentQuery(_departmentId()),
      );
      final raw = res.data;
      final data = raw is Map && raw['data'] is Map ? raw['data'] : raw;
      if (data is! Map) throw Exception('Unexpected response');

      final item = Map<String, dynamic>.from(data);
      if (!mounted) return;
      setState(() {
        _task = TaskModel(
          id: (item['id'] ?? item['_id'])?.toString(),
          title: (item['title'] ?? item['subject'] ?? 'Untitled Activity').toString(),
          dueDate: (item['scheduledAt'] ?? item['dueDate'] ?? item['createdAt'] ?? '').toString(),
          priority: (item['priority'] ?? 'None').toString(),
          status: (item['status'] ?? 'pending').toString(),
          assignedTo: (item['ownerName'] ?? item['assignedTo'] ?? 'Admin User').toString(),
          notes: (item['description'] ?? item['notes'] ?? '').toString(),
          taskType: (item['type'] ?? 'task').toString(),
          queue: item['queue']?.toString() ?? 'None',
          rawMap: item,
        );
        _isLoadingById = false;
      });
      _loadHistory();
    } catch (e) {
      debugPrint('[TaskDetailsScreen load error]: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingById = false;
        _loadError = 'This task could not be loaded.';
      });
    }
  }

  /// The task's own row, as the API returned it.
  Map<String, dynamic> get _row {
    final raw = _task.rawMap;
    if (raw != null && raw.isNotEmpty) return raw;
    // Opened from a list that only kept the display fields.
    return {
      'id': ?_task.id,
      'title': _task.title,
      'status': _task.status,
      'priority': _task.priority,
      'scheduledAt': _task.dueDate,
      'type': ?_task.taskType,
    };
  }

  /// Loads the thread this task sits in: the task it follows up on, if any,
  /// all the way back to the first one, and every follow-up that came out of
  /// it. Each is fetched from `GET /api/activities/:id`, so the history is
  /// built out of the tasks the backend actually holds.
  ///
  /// Only the link between a task and its follow-up is held on the device —
  /// the activities API has no parent field to read it back from, beyond the
  /// tag written when the follow-up was created.
  Future<void> _loadHistory() async {
    final id = activityId(_row);
    if (id == null) return;

    setState(() => _isLoadingHistory = true);

    try {
      final root = await _findThreadRoot(id, _task.rawMap);
      final rootId = activityId(root) ?? id;
      final followUps = await _collectFollowUps(rootId);

      if (!mounted) return;
      setState(() {
        _threadRoot = root;
        _threadFollowUps = followUps;
        _isLoadingHistory = false;
      });
    } catch (e) {
      debugPrint('[TaskDetailsScreen history load error]: $e');
      if (!mounted) return;
      setState(() => _isLoadingHistory = false);
    }
  }

  /// Walks up the follow-up chain to the task it began with.
  Future<Map<String, dynamic>> _findThreadRoot(
    String startId,
    Map<String, dynamic>? startRow,
  ) async {
    var currentId = startId;
    var current = startRow ?? await _fetchActivity(startId) ?? _row;
    final seen = <String>{currentId};

    // Bounded: a chain longer than this is a loop, not a history.
    for (var depth = 0; depth < 20; depth++) {
      final parentId = followUpParentIdFromTags(current) ??
          await FollowUpLinkStorage.originalIdFor(currentId);
      if (parentId == null || !seen.add(parentId)) break;

      final parent = await _fetchActivity(parentId);
      if (parent == null) break;

      currentId = parentId;
      current = parent;
    }

    return current;
  }

  /// Every follow-up under [rootId], depth first, each one fetched.
  Future<List<Map<String, dynamic>>> _collectFollowUps(String rootId) async {
    final collected = <Map<String, dynamic>>[];
    final seen = <String>{rootId};
    final queue = <String>[rootId];

    while (queue.isNotEmpty && collected.length < 20) {
      final parentId = queue.removeAt(0);
      for (final childId in await FollowUpLinkStorage.followUpIdsFor(parentId)) {
        if (!seen.add(childId)) continue;
        final child = await _fetchActivity(childId);
        if (child == null) continue;
        collected.add(child);
        queue.add(childId);
      }
    }

    return collected;
  }

  /// The department this screen is reading in, so the history is fetched from
  /// the same department the task itself was listed from.
  String _departmentId() {
    if (!mounted) return '';
    final departments = context.read<DepartmentProvider>();
    return resolveActiveDepartmentId(
      selected: departments.selectedDepartmentIdOrNull,
      assignedDepartmentId: departments.assignedDepartmentId,
    );
  }

  /// One activity, or null when it cannot be read — a task that was deleted
  /// leaves the rest of the history intact rather than emptying it.
  Future<Map<String, dynamic>?> _fetchActivity(String id) async {
    try {
      final res = await ApiService().get(
        '${ApiConstants.activities}/$id',
        queryParameters: departmentQuery(_departmentId()),
      );
      final raw = res.data;
      final data = raw is Map && raw['data'] is Map ? raw['data'] : raw;
      return data is Map ? Map<String, dynamic>.from(data) : null;
    } catch (e) {
      debugPrint('[TaskDetailsScreen activity $id not loaded]: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingById || _loadError != null) {
      return RecordLoadingScaffold(title: 'Task Details', error: _loadError);
    }

    final rawNotes = _task.notes.isNotEmpty
        ? _task.notes
        : (_task.rawMap?['description']?.toString() ?? _task.rawMap?['notes']?.toString() ?? '');
    final descriptionText = parseActivityDescription(rawNotes);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.of(context).pop(true),
        ),
        title: Text(
          'Task Details',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF00A884)),
            onPressed: () async {
              final updated = await CreateTaskModal.show(
                context,
                taskToEdit: _task,
              );
              if (updated != null) {
                setState(() {
                  _task = updated;
                });
              }
            },
            tooltip: 'Edit Task',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AppRefreshIndicator(
        onRefresh: _loadHistory,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Task Title Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _task.status.toLowerCase() == 'completed'
                                ? const Color(0xFFE6F4F1)
                                : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _task.status.toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _task.status.toLowerCase() == 'completed'
                                  ? const Color(0xFF00BDA5)
                                  : const Color(0xFFFFC254),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _task.title,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Text(
                          'Due: ${_task.dueDate}',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Text(
                          'Assigned to: ${_task.assignedTo}',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Additional Info Details Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Task Information',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const Divider(height: 24, color: Color(0xFFE2E8F0)),
                    // Only what the task itself records. A line the row has no
                    // value for is left out rather than filled with a default
                    // the user never chose.
                    ..._buildInformationRows(),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _buildActivityHistoryCard(),
              const SizedBox(height: 16),

              // Description / Notes Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Description & Notes',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      descriptionText.isNotEmpty ? descriptionText : 'No description provided.',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The lines the task actually carries a value for.
  List<Widget> _buildInformationRows() {
    final row = _row;

    String? text(dynamic value) {
      final trimmed = value?.toString().trim();
      if (trimmed == null || trimmed.isEmpty || trimmed == 'null') return null;
      return trimmed;
    }

    String? titleCase(String? value) {
      if (value == null || value.isEmpty) return null;
      return value[0].toUpperCase() + value.substring(1);
    }

    final completedAt = taskCompletedAt(row);

    final entries = <(String, String?)>[
      ('Type', titleCase(text(row['type']) ?? _task.taskType)),
      ('Status', titleCase(text(row['status']) ?? _task.status)),
      ('Assigned to', activityAssigneeLabel(row)),
      ('Due date', activityDueLabel(row)),
      ('Priority', titleCase(text(row['priority']))),
      ('Queue', text(row['queue']) ?? text(_task.queue) ?? 'None'),
      ('Reminder', text(row['reminderType']) ?? text(_task.reminderText)),
      ('Association', activityRelatedRecordLabel(row)),
      ('Completed', completedAt == null ? null : _formatStamp(completedAt)),
    ];

    final rows = <Widget>[];
    for (final (label, value) in entries) {
      if (value == null || value.isEmpty) continue;
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 10));
      rows.add(_buildDetailRow(label, value));
    }

    if (rows.isEmpty) {
      rows.add(Text(
        'This task carries no further details.',
        style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF64748B)),
      ));
    }
    return rows;
  }

  /// `Sep 1, 2026 at 4:20 PM GMT+05:30` — the timestamp as it was recorded,
  /// shown in the reader's own timezone.
  static String _formatStamp(DateTime moment) {
    final local = moment.isUtc ? moment.toLocal() : moment;
    final offset = local.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');

    return '${monthAbbr(local)} ${local.day}, ${local.year} at '
        '${formatTimeOfDay(local)} GMT$sign$hours:$minutes';
  }

  /// What happened to this task, and to the follow-ups that came out of it.
  Widget _buildActivityHistoryCard() {
    final root = _threadRoot ?? _row;
    final entries = buildTaskActivityHistory(root, followUps: _threadFollowUps);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Activity History',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(width: 8),
              if (_isLoadingHistory)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Color(0xFF00A884),
                  ),
                ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFE2E8F0)),
          if (entries.isEmpty)
            Text(
              _isLoadingHistory
                  ? 'Loading history…'
                  : 'This task carries no dated history yet.',
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                color: const Color(0xFF64748B),
              ),
            )
          else
            for (var i = 0; i < entries.length; i++)
              _buildHistoryEntry(entries[i], isLast: i == entries.length - 1),
        ],
      ),
    );
  }

  Widget _buildHistoryEntry(TaskHistoryEntry entry, {required bool isLast}) {
    final isFollowUp = entry.kind == TaskHistoryKind.followUpCreated ||
        entry.kind == TaskHistoryKind.followUpCompleted;
    final isDone = entry.kind == TaskHistoryKind.completed ||
        entry.kind == TaskHistoryKind.followUpCompleted;

    final dotColor = isDone
        ? const Color(0xFF00A884)
        : isFollowUp
            ? const Color(0xFF7C3AED)
            : const Color(0xFF94A3B8);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 1.5, color: const Color(0xFFE2E8F0)),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  if (entry.detail != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      entry.detail!,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    _formatStamp(entry.at),
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }
}
