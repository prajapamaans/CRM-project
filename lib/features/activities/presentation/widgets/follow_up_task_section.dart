import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FollowUpTaskSection extends StatefulWidget {
  final bool initialChecked;
  final String initialType;
  final String? initialDateLabel;
  final String initialTime;
  final ValueChanged<bool>? onCheckedChanged;
  final ValueChanged<String>? onTypeChanged;
  final ValueChanged<String>? onDateChanged;
  final ValueChanged<String>? onTimeChanged;

  const FollowUpTaskSection({
    super.key,
    this.initialChecked = false,
    this.initialType = 'To-do',
    this.initialDateLabel,
    this.initialTime = '8:00 AM',
    this.onCheckedChanged,
    this.onTypeChanged,
    this.onDateChanged,
    this.onTimeChanged,
  });

  @override
  State<FollowUpTaskSection> createState() => _FollowUpTaskSectionState();
}

class _FollowUpTaskSectionState extends State<FollowUpTaskSection> {
  late bool _isChecked;
  late String _selectedType;
  late String _selectedDateLabel;
  late String _selectedTime;

  final GlobalKey _typeKey = GlobalKey();
  final GlobalKey _dateKey = GlobalKey();
  final GlobalKey _timeKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _isChecked = widget.initialChecked;
    _selectedType = widget.initialType;
    _selectedTime = widget.initialTime;

    final defaultDates = _generateDynamicDateOptions();
    if (widget.initialDateLabel != null && widget.initialDateLabel!.isNotEmpty) {
      _selectedDateLabel = widget.initialDateLabel!;
    } else {
      // Default to "In 3 business days" option if available, or first option
      if (defaultDates.length > 3) {
        _selectedDateLabel = defaultDates[3]['label']!;
      } else {
        _selectedDateLabel = defaultDates.first['label']!;
      }
    }
  }

  static List<Map<String, String>> _generateDynamicDateOptions() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime addBusinessDays(DateTime start, int days) {
      DateTime current = start;
      int added = 0;
      while (added < days) {
        current = current.add(const Duration(days: 1));
        if (current.weekday != DateTime.saturday && current.weekday != DateTime.sunday) {
          added++;
        }
      }
      return current;
    }

    final in2Biz = addBusinessDays(today, 2);
    final in3Biz = addBusinessDays(today, 3);
    final in1Week = today.add(const Duration(days: 7));
    final in2Weeks = today.add(const Duration(days: 14));

    DateTime addMonths(DateTime start, int months) {
      int year = start.year;
      int month = start.month + months;
      while (month > 12) {
        month -= 12;
        year += 1;
      }
      int day = start.day;
      int daysInTargetMonth = DateUtils.getDaysInMonth(year, month);
      if (day > daysInTargetMonth) day = daysInTargetMonth;
      return DateTime(year, month, day);
    }

    final in1Month = addMonths(today, 1);
    final in3Months = addMonths(today, 3);
    final in6Months = addMonths(today, 6);

    String weekdayName(int weekday) {
      const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return names[weekday - 1];
    }

    String monthAbbr(int month) {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return months[month - 1];
    }

    return [
      {'label': 'Today', 'value': 'Today'},
      {'label': 'Tomorrow', 'value': 'Tomorrow'},
      {'label': 'In 2 business days (${weekdayName(in2Biz.weekday)})', 'value': 'In 2 business days (${weekdayName(in2Biz.weekday)})'},
      {'label': 'In 3 business days (${weekdayName(in3Biz.weekday)})', 'value': 'In 3 business days (${weekdayName(in3Biz.weekday)})'},
      {'label': 'In 1 week (${monthAbbr(in1Week.month)} ${in1Week.day})', 'value': 'In 1 week (${monthAbbr(in1Week.month)} ${in1Week.day})'},
      {'label': 'In 2 weeks (${monthAbbr(in2Weeks.month)} ${in2Weeks.day})', 'value': 'In 2 weeks (${monthAbbr(in2Weeks.month)} ${in2Weeks.day})'},
      {'label': 'In 1 month (${monthAbbr(in1Month.month)} ${in1Month.day})', 'value': 'In 1 month (${monthAbbr(in1Month.month)} ${in1Month.day})'},
      {'label': 'In 3 months (${monthAbbr(in3Months.month)} ${in3Months.day})', 'value': 'In 3 months (${monthAbbr(in3Months.month)} ${in3Months.day})'},
      {'label': 'In 6 months (${monthAbbr(in6Months.month)} ${in6Months.day})', 'value': 'In 6 months (${monthAbbr(in6Months.month)} ${in6Months.day})'},
      {'label': 'Custom Date', 'value': 'Custom Date'},
    ];
  }

  static List<String> _generateDynamicTimeOptions() {
    List<String> times = [];
    for (int hour = 0; hour < 24; hour++) {
      for (int minute = 0; minute < 60; minute += 15) {
        final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
        final period = hour < 12 ? 'AM' : 'PM';
        final m = minute.toString().padLeft(2, '0');
        times.add('$h:$m $period');
      }
    }
    return times;
  }

  void _showTypeMenu() async {
    final RenderBox renderBox = _typeKey.currentContext!.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final types = ['Call', 'Email', 'To-do'];

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height,
        offset.dx + 180,
        offset.dy + size.height + 200,
      ),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      items: types.map((t) {
        final isSelected = t == _selectedType;
        return PopupMenuItem<String>(
          value: t,
          height: 40,
          padding: EdgeInsets.zero,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isSelected ? const Color(0xFFF1F5F9) : Colors.transparent,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: const Color(0xFF334155),
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check,
                    color: Color(0xFF00A884),
                    size: 16,
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );

    if (selected != null) {
      setState(() {
        _selectedType = selected;
      });
      widget.onTypeChanged?.call(selected);
    }
  }

  void _showDateMenu() async {
    final RenderBox renderBox = _dateKey.currentContext!.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final options = _generateDynamicDateOptions();

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height,
        offset.dx + 260,
        offset.dy + size.height + 400,
      ),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      items: options.map((opt) {
        final label = opt['label']!;
        final isSelected = label == _selectedDateLabel;
        return PopupMenuItem<String>(
          value: label,
          height: 40,
          padding: EdgeInsets.zero,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isSelected ? const Color(0xFFF1F5F9) : Colors.transparent,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check,
                    color: Color(0xFF00A884),
                    size: 16,
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );

    if (selected != null) {
      if (selected == 'Custom Date') {
        if (!mounted) return;
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
        );
        if (picked != null) {
          String formatted = '${picked.day}/${picked.month}/${picked.year}';
          setState(() {
            _selectedDateLabel = formatted;
          });
          widget.onDateChanged?.call(formatted);
        }
      } else {
        setState(() {
          _selectedDateLabel = selected;
        });
        widget.onDateChanged?.call(selected);
      }
    }
  }

  void _showTimeMenu() async {
    final RenderBox renderBox = _timeKey.currentContext!.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final timeOptions = _generateDynamicTimeOptions();

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height,
        offset.dx + 200,
        offset.dy + size.height + 350,
      ),
      elevation: 6,
      constraints: const BoxConstraints(maxHeight: 320),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      items: [
        ...timeOptions.map((t) {
          final isSelected = t == _selectedTime;
          return PopupMenuItem<String>(
            value: t,
            height: 38,
            padding: EdgeInsets.zero,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isSelected ? const Color(0xFFF1F5F9) : Colors.transparent,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    t,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check,
                      color: Color(0xFF00A884),
                      size: 16,
                    ),
                ],
              ),
            ),
          );
        }),
        PopupMenuItem<String>(
          value: 'Custom Time...',
          height: 38,
          padding: EdgeInsets.zero,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Custom Time...',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF00A884),
              ),
            ),
          ),
        ),
      ],
    );

    if (selected != null) {
      if (selected == 'Custom Time...') {
        if (!mounted) return;
        final pickedTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
        );
        if (pickedTime != null) {
          final hour = pickedTime.hourOfPeriod == 0 ? 12 : pickedTime.hourOfPeriod;
          final period = pickedTime.period == DayPeriod.am ? 'AM' : 'PM';
          final minute = pickedTime.minute.toString().padLeft(2, '0');
          final timeStr = '$hour:$minute $period';
          setState(() {
            _selectedTime = timeStr;
          });
          widget.onTimeChanged?.call(timeStr);
        }
      } else {
        setState(() {
          _selectedTime = selected;
        });
        widget.onTimeChanged?.call(selected);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Checkbox(
            value: _isChecked,
            onChanged: (val) {
              final newChecked = val ?? false;
              setState(() {
                _isChecked = newChecked;
              });
              widget.onCheckedChanged?.call(newChecked);
            },
            activeColor: const Color(0xFF00A884),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Create a ',
                  style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF475569)),
                ),
                InkWell(
                  key: _typeKey,
                  onTap: _showTypeMenu,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '$_selectedType ⌄ ',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF00A884),
                      ),
                    ),
                  ),
                ),
                Text(
                  'task to follow up ',
                  style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF475569)),
                ),
                InkWell(
                  key: _dateKey,
                  onTap: _showDateMenu,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '$_selectedDateLabel ⌄ ',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF00A884),
                      ),
                    ),
                  ),
                ),
                Text(
                  'at ',
                  style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF475569)),
                ),
                InkWell(
                  key: _timeKey,
                  onTap: _showTimeMenu,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '$_selectedTime ⌄',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF00A884),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
