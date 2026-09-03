import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/utils/activity_task_fields.dart';
import '../../../../core/utils/activity_utils.dart';
import '../../../../core/utils/follow_up_schedule.dart';

/// Renders the structured details card inside an expanded task activity item
/// matching the exact design:
/// - Due date (Date box & Time box) and Reminder
/// - Type and Priority
/// - Queue and Assigned to
/// - Description / Notes text
/// - Footer: Add comment & Associations
class TaskActivityCardDetails extends StatelessWidget {
  final Map<String, dynamic> activity;
  final VoidCallback? onAddComment;
  final VoidCallback? onManageAssociations;

  const TaskActivityCardDetails({
    super.key,
    required this.activity,
    this.onAddComment,
    this.onManageAssociations,
  });

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return const Color(0xFFEF4444);
      case 'medium':
        return const Color(0xFFF97316);
      case 'low':
        return const Color(0xFF3B82F6);
      case 'none':
      default:
        return const Color(0xFFCBD5E1);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Extract Due Date & Time
    final rawDate = activity['scheduledAt'] ??
        activity['dueDate'] ??
        activity['due_date'] ??
        activity['scheduled_at'] ??
        activity['createdAt'];
    final dt = parseActivityDateTimeOrNull(rawDate)?.toLocal() ?? DateTime.now();

    final dayStr = dt.day.toString().padLeft(2, '0');
    final monthStr = dt.month.toString().padLeft(2, '0');
    final dateBoxText = '$dayStr/$monthStr/${dt.year}';
    final timeBoxText = formatTimeOfDay(dt);

    // 2. Extract Reminder
    final reminderText = (activity['reminderText'] ??
            activity['reminderType'] ??
            activity['reminder'] ??
            '30 minutes before')
        .toString();

    // 3. Extract Type
    final rawType = (activity['taskType'] ??
            activity['type'] ??
            activity['activity_type'] ??
            'To-do')
        .toString();
    final typeText = rawType.toLowerCase() == 'task' ? 'To-do' : (rawType.isEmpty ? 'To-do' : rawType);

    // 4. Extract Priority
    final priorityText = (activity['priority'] ?? 'None').toString();

    // 5. Extract Queue
    final rawQueue = activity['queue']?.toString();
    final queueText = (rawQueue == null || rawQueue.trim().isEmpty) ? 'None' : rawQueue;

    // 6. Extract Assigned to
    final assignedToText = activityAssigneeLabel(activity) ??
        activity['ownerName'] ??
        activity['assignedTo'] ??
        'Admin User';

    // 7. Extract Description
    final rawNotes = activity['description'] ?? activity['notes'] ?? activity['content'] ?? '';
    final descriptionText = parseActivityDescription(rawNotes);

    // 8. Associations Count
    int associationsCount = 1;
    final assoc = activity['associations'];
    if (assoc is Map) {
      int sum = 0;
      for (final key in ['Companies', 'Contacts', 'Deals']) {
        if (assoc[key] is List) sum += (assoc[key] as List).length;
      }
      if (sum > 0) associationsCount = sum;
    } else if (assoc is List) {
      if (assoc.isNotEmpty) associationsCount = assoc.length;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Divider(color: Color(0xFFE2E8F0), height: 1),
        const SizedBox(height: 14),

        // Section 1: Due date & Reminder
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Due date (Date Box & Time Box)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Due date',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              dateBoxText,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF334155),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              timeBoxText,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF334155),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Reminder
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reminder',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          reminderText,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF00A884),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF00A884),
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),
        const Divider(color: Color(0xFFF1F5F9), height: 1),
        const SizedBox(height: 14),

        // Section 2: Type & Priority
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Type',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          typeText,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF00A884),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF00A884),
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Priority
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Priority',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getPriorityColor(priorityText),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          priorityText,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF00A884),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF00A884),
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Section 3: Queue & Assigned to
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Queue
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Queue',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    queueText,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Assigned to
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assigned to',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          assignedToText,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF00A884),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF00A884),
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        // Section 4: Description Text
        if (descriptionText.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            descriptionText.trim(),
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF334155),
              height: 1.4,
            ),
          ),
        ],

        const SizedBox(height: 14),
        const Divider(color: Color(0xFFE2E8F0), height: 1),
        const SizedBox(height: 10),

        // Section 5: Footer (Add comment & Associations)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: InkWell(
                onTap: onAddComment,
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 15,
                      color: Color(0xFF00A884),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Add comment',
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF00A884),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: InkWell(
                onTap: onManageAssociations,
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        '$associationsCount association${associationsCount > 1 ? 's' : ''}',
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF00A884),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: Color(0xFF00A884),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
