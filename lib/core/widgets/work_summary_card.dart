import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../features/dashboard/presentation/providers/dashboard_provider.dart';
import 'empty_state.dart';

class WorkSummaryCard extends StatelessWidget {
  final String title;
  final String dateString;
  final TaskWorkGroup taskGroup;
  final bool showFilterButton;
  final VoidCallback? onFilterTap;
  final VoidCallback? onViewAllTap;

  /// Ticking or unticking a task. The whole row is handed over, not just its
  /// id: what happens next — on the Dashboard, the offer of a follow-up —
  /// needs the task's owner, priority and linked records, and re-reading them
  /// from a list that is about to be refreshed would be racing itself.
  final void Function(Map<String, dynamic> task, String newStatus)?
      onToggleTaskStatus;
  final void Function(Map<String, dynamic> taskMap)? onTaskTap;

  const WorkSummaryCard({
    super.key,
    this.title = "Today's Work",
    this.dateString = 'Thursday, July 30th',
    required this.taskGroup,
    this.showFilterButton = false,
    this.onFilterTap,
    this.onViewAllTap,
    this.onToggleTaskStatus,
    this.onTaskTap,
  });

  @override
  Widget build(BuildContext context) {
    final pendingCount = taskGroup.pendingCount;
    final completedCount = taskGroup.completedCount;
    final progressPercent = taskGroup.progressPercent;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 1),
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
          // 1. Top Header Section inside Card
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.headingMedium.copyWith(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        dateString,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    if (onViewAllTap != null)
                      InkWell(
                        onTap: onViewAllTap,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              Text(
                                'View all',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.primaryTeal,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 16,
                                color: AppColors.primaryTeal,
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (showFilterButton) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: onFilterTap,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: const Icon(
                            Icons.calendar_month_rounded,
                            size: 16,
                            color: AppColors.primaryTeal,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    // Dynamic Progress Indicator badge
                    () {
                      final Color barColor = progressPercent == 100
                          ? const Color(0xFF00A884)
                          : progressPercent > 50
                              ? const Color(0xFF0F766E)
                              : progressPercent > 0
                                  ? const Color(0xFF3B82F6)
                                  : const Color(0xFF94A3B8);
                      return Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: barColor.withValues(alpha: 0.12),
                          border: Border.all(
                            color: barColor,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$progressPercent%',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: barColor,
                            ),
                          ),
                        ),
                      );
                    }(),
                  ],
                ),
              ],
            ),
          ),

          // Linear Progress Bar matching completion ratio
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: taskGroup.totalCount > 0
                    ? (completedCount / taskGroup.totalCount).clamp(0.0, 1.0)
                    : 0.0,
                minHeight: 5,
                backgroundColor: const Color(0xFFF1F5F9),
                valueColor: AlwaysStoppedAnimation<Color>(
                  progressPercent == 100
                      ? const Color(0xFF00A884)
                      : progressPercent > 50
                          ? const Color(0xFF0F766E)
                          : progressPercent > 0
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFFCBD5E1),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          const Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFFF3F4F6),
          ),

          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2. Pending Work Section Header
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'PENDING WORK ($pendingCount)',
                      style: AppTextStyles.labelSmall.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF4B5563),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Pending Tasks List or Empty State
                if (taskGroup.pendingTasks.isEmpty)
                  const EmptyStateCard(
                    title: 'All caught up',
                    description: 'No pending tasks for this period',
                    icon: Icons.check_rounded,
                    isDashed: true,
                    borderRadius: 12.0,
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.xl,
                    ),
                  )
                else
                  Column(
                    children: taskGroup.pendingTasks.map((task) {
                      return _buildTaskRow(
                        context: context,
                        task: task,
                        isCompleted: false,
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 16),

                // 3. Completed Work Section Header
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryTeal,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'COMPLETED WORK ($completedCount)',
                      style: AppTextStyles.labelSmall.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF4B5563),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Completed Tasks List or Empty State
                if (taskGroup.completedTasks.isEmpty)
                  const EmptyStateCard(
                    title: 'No work completed yet',
                    isDashed: true,
                    borderRadius: 12.0,
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.lg,
                    ),
                  )
                else
                  Column(
                    children: taskGroup.completedTasks.map((task) {
                      return _buildTaskRow(
                        context: context,
                        task: task,
                        isCompleted: true,
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskRow({
    required BuildContext context,
    required Map<String, dynamic> task,
    required bool isCompleted,
  }) {
    final taskId = (task['id'] ?? task['_id'])?.toString() ?? '';
    final title = task['title'] as String? ??
        task['subject'] as String? ??
        task['notes'] as String? ??
        'Untitled Task';

    final priority = (task['priority'] as String? ?? '').trim();
    final companyName = (task['companyName'] ?? task['company']?['name'])?.toString();
    final contactName = (task['recipientName'] ?? task['contact']?['fullName'] ?? task['contact']?['name'])?.toString();
    final dealName = (task['dealName'] ?? task['deal']?['name'])?.toString();

    final String? assocName = companyName ?? contactName ?? dealName;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCompleted ? const Color(0xFFF8FAFC) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCompleted ? const Color(0xFFE2E8F0) : const Color(0xFFCBD5E1),
        ),
      ),
      child: InkWell(
        onTap: () {
          if (onTaskTap != null) {
            onTaskTap!(task);
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Square Checkbox toggle
              GestureDetector(
                onTap: () {
                  if (taskId.isNotEmpty && onToggleTaskStatus != null) {
                    onToggleTaskStatus!(task, isCompleted ? 'pending' : 'completed');
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Icon(
                    isCompleted
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 20,
                    color: isCompleted
                        ? const Color(0xFF00A884)
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ),
              // Task Title & Assoc
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isCompleted
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF1E293B),
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                    if (assocName != null && assocName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        assocName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (priority.isNotEmpty) ...[
                const SizedBox(width: 8),
                _buildPriorityBadge(priority),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color bg = const Color(0xFFF1F5F9);
    Color fg = const Color(0xFF64748B);

    switch (priority.toLowerCase()) {
      case 'high':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFEF4444);
        break;
      case 'medium':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        break;
      case 'low':
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0284C7);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        priority.toUpperCase(),
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }
}
