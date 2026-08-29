import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:crmproject/core/widgets/app_refresh_indicator.dart';
import 'package:crmproject/core/utils/activity_utils.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/widgets/record_loading_scaffold.dart';
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

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    if (task != null) {
      _task = task;
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
      final res = await ApiService().get('${ApiConstants.activities}/$id');
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
          rawMap: item,
        );
        _isLoadingById = false;
      });
    } catch (e) {
      debugPrint('[TaskDetailsScreen load error]: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingById = false;
        _loadError = 'This task could not be loaded.';
      });
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
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) setState(() {});
        },
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
                    _buildDetailRow('Task Type', _task.taskType ?? 'To-do'),
                    const SizedBox(height: 10),
                    _buildDetailRow('Queue', _task.queue ?? 'None'),
                    const SizedBox(height: 10),
                    _buildDetailRow('Activity Date', _task.activityDateText ?? 'In 3 business days'),
                    const SizedBox(height: 10),
                    _buildDetailRow('Reminder', _task.reminderText ?? 'No reminder'),
                  ],
                ),
              ),
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

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            color: const Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}
