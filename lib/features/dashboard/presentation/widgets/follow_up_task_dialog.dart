import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/utils/follow_up_schedule.dart';

/// What the user settled on in the follow-up popup: the instant the follow-up
/// task is due.
class FollowUpTaskChoice {
  final DateTime scheduledAt;

  const FollowUpTaskChoice(this.scheduledAt);
}

/// Offered right after a task is completed from the Dashboard: create the next
/// task in the same thread, or don't.
///
/// Returns the chosen date and time, or null when the user picked "Not now" or
/// dismissed it — in which case the completion stands on its own and nothing
/// further is created.
class FollowUpTaskDialog extends StatefulWidget {
  /// The task that was just completed, named in the popup as the user named it.
  final String taskTitle;

  /// The moment the task was completed. The offered dates are measured from
  /// here, so "in 3 business days" is three business days from the completion.
  final DateTime completedAt;

  const FollowUpTaskDialog({
    super.key,
    required this.taskTitle,
    required this.completedAt,
  });

  static Future<FollowUpTaskChoice?> show(
    BuildContext context, {
    required String taskTitle,
    required DateTime completedAt,
  }) {
    return showDialog<FollowUpTaskChoice>(
      context: context,
      barrierDismissible: true,
      builder: (context) => FollowUpTaskDialog(
        taskTitle: taskTitle,
        completedAt: completedAt,
      ),
    );
  }

  @override
  State<FollowUpTaskDialog> createState() => _FollowUpTaskDialogState();
}

class _FollowUpTaskDialogState extends State<FollowUpTaskDialog> {
  static const Color _teal = Color(0xFF00A884);
  static const Color _ink = Color(0xFF1E293B);
  static const Color _body = Color(0xFF475569);
  static const Color _muted = Color(0xFF64748B);
  static const Color _selectedRow = Color(0xFFF1F5F9);

  final GlobalKey _dateKey = GlobalKey();
  final GlobalKey _timeKey = GlobalKey();

  /// The day the follow-up lands on, and the reference day the offered labels
  /// are worked out from. Both are set once from the completion.
  late DateTime _basis;
  late DateTime _selectedDate;
  late String _selectedTime;

  @override
  void initState() {
    super.initState();
    _basis = startOfDay(widget.completedAt);
    _selectedDate = defaultFollowUpDate(from: _basis);
    _selectedTime = formatTimeLabel(8, 0, padHour: true);
  }

  Future<T?> _showOptionsMenu<T>({
    required GlobalKey anchor,
    required List<({T value, String label})> options,
    required T selected,
    double width = 260,
    double maxHeight = 360,
  }) {
    final renderBox = anchor.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return Future<T?>.value(null);

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    return showMenu<T>(
      context: context,
      constraints: BoxConstraints(maxHeight: maxHeight, minWidth: width),
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height,
        offset.dx + width,
        offset.dy + size.height + maxHeight,
      ),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      items: options.map((option) {
        final isSelected = option.value == selected;
        return PopupMenuItem<T>(
          value: option.value,
          height: 40,
          padding: EdgeInsets.zero,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isSelected ? _selectedRow : Colors.transparent,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    option.label,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ),
                if (isSelected) const Icon(Icons.check, color: _teal, size: 16),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _pickDate() async {
    final options = followUpDateOptions(from: _basis);

    final picked = await _showOptionsMenu<String>(
      anchor: _dateKey,
      options: [
        for (final option in options) (value: option.label, label: option.label),
      ],
      selected: followUpDateLabel(_selectedDate, from: _basis),
      width: 260,
      maxHeight: 400,
    );
    if (picked == null || !mounted) return;

    final option = options.firstWhere((o) => o.label == picked);
    if (!option.isCustom) {
      setState(() => _selectedDate = option.date!);
      return;
    }

    final custom = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: _basis,
      lastDate: DateTime(_basis.year + 5, _basis.month, _basis.day),
    );
    if (custom == null || !mounted) return;
    setState(() => _selectedDate = startOfDay(custom));
  }

  Future<void> _pickTime() async {
    final options = followUpTimeOptions(padHour: true);

    final picked = await _showOptionsMenu<String>(
      anchor: _timeKey,
      options: [
        for (final label in options) (value: label, label: label),
        (value: _customTimeSentinel, label: 'Custom time…'),
      ],
      selected: _selectedTime,
      width: 200,
      maxHeight: 320,
    );
    if (picked == null || !mounted) return;

    if (picked != _customTimeSentinel) {
      setState(() => _selectedTime = picked);
      return;
    }

    final parsed = parseTimeLabel(_selectedTime);
    final custom = await showTimePicker(
      context: context,
      initialTime: parsed == null
          ? TimeOfDay.now()
          : TimeOfDay(hour: parsed.hour, minute: parsed.minute),
    );
    if (custom == null || !mounted) return;
    setState(() {
      _selectedTime = formatTimeLabel(custom.hour, custom.minute, padHour: true);
    });
  }

  static const String _customTimeSentinel = '__custom_time__';

  void _createTask() {
    Navigator.of(context).pop(
      FollowUpTaskChoice(combineDateAndTime(_selectedDate, _selectedTime)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.taskTitle.trim();

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create a follow up task?',
                style: GoogleFonts.poppins(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title.isEmpty
                    ? "We'll create a task for you to follow up on this task"
                    : 'We\'ll create a task for you to follow up on "$title"',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  height: 1.45,
                  color: _body,
                ),
              ),
              const SizedBox(height: 18),
              // Side by side where there is room; stacked when there is not.
              LayoutBuilder(
                builder: (context, constraints) {
                  final dateField = _SelectorField(
                    fieldKey: _dateKey,
                    label: 'Due date',
                    value: followUpDateLabel(_selectedDate, from: _basis),
                    onTap: _pickDate,
                  );
                  final timeField = _SelectorField(
                    fieldKey: _timeKey,
                    label: 'Time',
                    value: _selectedTime,
                    onTap: _pickTime,
                  );

                  if (constraints.maxWidth < 320) {
                    return Column(
                      children: [
                        dateField,
                        const SizedBox(height: 10),
                        timeField,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: dateField),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: timeField),
                    ],
                  );
                },
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: _muted,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      'Not now',
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _createTask,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _teal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Create task',
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A bordered field that opens a menu — the date and the time both read this
/// way, matching the pickers on the task form.
class _SelectorField extends StatelessWidget {
  final GlobalKey fieldKey;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _SelectorField({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          key: fieldKey,
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
