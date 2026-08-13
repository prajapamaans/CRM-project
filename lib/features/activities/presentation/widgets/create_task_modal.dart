import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/models/master_dropdown_model.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/repositories/master_data_repository.dart';
import '../../../../core/widgets/record_association_sheet.dart';

class TaskModel {
  final String? id;
  final String title;
  final String dueDate;
  final String priority;
  final String status;
  final String assignedTo;
  final String notes;
  final String? taskType;
  final String? queue;
  final String? activityDateText;
  final String? reminderText;
  final Map<String, dynamic>? rawMap;

  TaskModel({
    this.id,
    required this.title,
    required this.dueDate,
    required this.priority,
    required this.status,
    required this.assignedTo,
    this.notes = '',
    this.taskType = 'To-do',
    this.queue = 'None',
    this.activityDateText = 'In 3 business days (Tuesday)',
    this.reminderText = 'No reminder',
    this.rawMap,
  });
}

class CreateTaskModal extends StatefulWidget {
  final TaskModel? taskToEdit;
  final String? contactId;
  final String? companyId;
  final String? dealId;
  final String associatedRecordName;

  const CreateTaskModal({
    super.key,
    this.taskToEdit,
    this.contactId,
    this.companyId,
    this.dealId,
    this.associatedRecordName = 'xyzzzz',
  });

  static Future<TaskModel?> show(
    BuildContext context, {
    TaskModel? taskToEdit,
    String? contactId,
    String? companyId,
    String? dealId,
    String associatedRecordName = 'xyzzzz',
  }) {
    return showModalBottomSheet<TaskModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateTaskModal(
        taskToEdit: taskToEdit,
        contactId: contactId,
        companyId: companyId,
        dealId: dealId,
        associatedRecordName: associatedRecordName,
      ),
    );
  }

  @override
  State<CreateTaskModal> createState() => _CreateTaskModalState();
}

class _CreateTaskModalState extends State<CreateTaskModal> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;

  String _activityDateText = 'In 3 business days (Tuesday)';
  String _timeText = '8:00 AM';
  String _reminderText = 'No reminder';

  String _selectedTaskType = 'To-do';
  String _selectedPriority = 'None';
  String _selectedQueue = 'None';
  String _selectedAssignee = 'Select ...';

  bool _isSubmitting = false;

  // Associations state
  late Map<String, List<Map<String, String>>> _associations;

  int get _totalAssociations {
    return _associations['Companies']!.length +
        _associations['Contacts']!.length +
        _associations['Deals']!.length;
  }

  // Active formatting state toggles
  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderline = false;
  String _activeHeading = 'T';
  bool _isBullet = false;
  bool _isNumbered = false;

  void _applyFormatPrefix(String prefix, String suffix) {
    final text = _notesController.text;
    final selection = _notesController.selection;
    if (selection.isValid && !selection.isCollapsed) {
      final selectedText = text.substring(selection.start, selection.end);
      final newText = text.replaceRange(selection.start, selection.end, '$prefix$selectedText$suffix');
      _notesController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + prefix.length + selectedText.length + suffix.length),
      );
    } else {
      final cursor = selection.start >= 0 ? selection.start : text.length;
      final newText = text.replaceRange(cursor, cursor, '$prefix$suffix');
      _notesController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: cursor + prefix.length),
      );
    }
  }

  TextStyle _getContentStyle() {
    double fontSize = 14.0;
    FontWeight fontWeight = _isBold ? FontWeight.bold : FontWeight.normal;
    FontStyle fontStyle = _isItalic ? FontStyle.italic : FontStyle.normal;
    TextDecoration decoration = _isUnderline ? TextDecoration.underline : TextDecoration.none;

    if (_activeHeading == 'H1') {
      fontSize = 20.0;
      fontWeight = FontWeight.bold;
    } else if (_activeHeading == 'H2') {
      fontSize = 17.0;
      fontWeight = FontWeight.bold;
    }

    return GoogleFonts.poppins(
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      decoration: decoration,
      color: const Color(0xFF334155),
    );
  }

  List<MasterDropdownOptionModel> _apiPriorities = [];
  List<Map<String, dynamic>> _apiUsers = [];

  final List<String> _taskTypes = const ['To-do', 'Call', 'Email'];
  final List<String> _queues = const [
    'None',
    'Day 7 reminder',
    'follow-up 1',
    'follow up 2',
    'New Outreach',
  ];
  final List<String> _reminders = const ['No reminder', 'At time of task', '15 mins before', '1 hour before', '1 day before'];

  @override
  void initState() {
    super.initState();
    _associations = {
      'Companies': widget.companyId != null ? [{'id': widget.companyId!, 'name': widget.associatedRecordName}] : [],
      'Contacts': widget.contactId != null ? [{'id': widget.contactId!, 'name': widget.associatedRecordName}] : widget.companyId == null && widget.dealId == null ? [{'id': '1', 'name': widget.associatedRecordName}] : [],
      'Deals': widget.dealId != null ? [{'id': widget.dealId!, 'name': widget.associatedRecordName}] : [],
    };
    final editTask = widget.taskToEdit;
    _titleController = TextEditingController(text: editTask?.title ?? '');
    _notesController = TextEditingController(text: editTask?.notes ?? '');

    if (editTask != null) {
      if (editTask.priority.isNotEmpty) _selectedPriority = editTask.priority;
      if (editTask.assignedTo.isNotEmpty && editTask.assignedTo != 'Admin User') {
        _selectedAssignee = editTask.assignedTo;
      }
      if (editTask.taskType != null && editTask.taskType!.isNotEmpty) {
        _selectedTaskType = editTask.taskType!;
      }
      if (editTask.queue != null && editTask.queue!.isNotEmpty) {
        _selectedQueue = editTask.queue!;
      }
      if (editTask.activityDateText != null && editTask.activityDateText!.isNotEmpty) {
        _activityDateText = editTask.activityDateText!;
      }
      if (editTask.reminderText != null && editTask.reminderText!.isNotEmpty) {
        _reminderText = editTask.reminderText!;
      }
    }

    _loadMasterData();
  }

  Future<void> _loadMasterData() async {
    try {
      final repo = MasterDataRepositoryImpl();
      await repo.getMasterDropdownByKey('task_status', includeInactive: false);
      final priorities = await repo.getMasterDropdownByKey('task_priority', includeInactive: false);
      
      List<Map<String, dynamic>> usersList = [];
      try {
        final resp = await ApiService().get('/users');
        final raw = resp.data;
        if (raw is List) {
          usersList = raw.whereType<Map<String, dynamic>>().toList();
        } else if (raw is Map<String, dynamic> && raw['data'] is List) {
          usersList = (raw['data'] as List).whereType<Map<String, dynamic>>().toList();
        }
      } catch (e) {
        debugPrint('[FETCH /users IN TASK MODAL ERROR]: $e');
      }

      if (mounted) {
        setState(() {
          _apiPriorities = priorities;
          _apiUsers = usersList;

          if (widget.taskToEdit == null && priorities.isNotEmpty) {
            final defaultP = priorities.firstWhere((p) => p.isDefault, orElse: () => priorities.first);
            _selectedPriority = defaultP.label;
          }
        });
      }
    } catch (e) {
      debugPrint('[TaskModal _loadMasterData Error]: $e');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.taskToEdit != null;
    final prioritiesList = _apiPriorities.isNotEmpty
        ? _apiPriorities.map((p) => p.label).toList()
        : const ['None', 'Low', 'Medium', 'High'];

    if (!prioritiesList.contains(_selectedPriority) && prioritiesList.isNotEmpty) {
      prioritiesList.add(_selectedPriority);
    }

    final usersDisplayList = _apiUsers.isNotEmpty
        ? _apiUsers.map((u) {
            final first = u['firstName'] as String? ?? u['first_name'] as String? ?? '';
            final last = u['lastName'] as String? ?? u['last_name'] as String? ?? '';
            final name = '$first $last'.trim();
            return name.isNotEmpty ? name : u['email'] as String? ?? 'User';
          }).toList()
        : const ['Admin User', 'Abhishek Puranik', 'Select ...'];

    if (!usersDisplayList.contains(_selectedAssignee)) {
      usersDisplayList.add(_selectedAssignee);
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        children: [
          // 1. Dark Top Header matching 2nd Image
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF475569), // Dark steel grey as image 2
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isEditing ? 'Task' : 'Task',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // 2. Form Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Enter task name... textfield container
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF5FB6AD), width: 1.5),
                  ),
                  child: TextField(
                    controller: _titleController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Enter task name...',
                      hintStyle: GoogleFonts.poppins(
                        color: const Color(0xFF94A3B8),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                    ),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                // Activity date label
                Text(
                  'Activity date',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),

                // Activity date & time pickers row
                Row(
                  children: [
                    PopupMenuButton<String>(
                      onSelected: (val) {
                        setState(() {
                          _activityDateText = val;
                        });
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _activityDateText,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF00A884),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Color(0xFF00A884),
                            size: 18,
                          ),
                        ],
                      ),
                      itemBuilder: (context) => [
                        'In 3 business days (Tuesday)',
                        'Today',
                        'Tomorrow',
                        'Next week',
                      ]
                          .map((d) => PopupMenuItem(
                                value: d,
                                child: Text(d, style: GoogleFonts.poppins(fontSize: 13)),
                              ))
                          .toList(),
                    ),
                    const SizedBox(width: 12),
                    PopupMenuButton<String>(
                      onSelected: (val) {
                        setState(() {
                          _timeText = val;
                        });
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 16,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _timeText,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Color(0xFF94A3B8),
                            size: 18,
                          ),
                        ],
                      ),
                      itemBuilder: (context) => ['8:00 AM', '9:00 AM', '10:00 AM', '12:00 PM', '2:00 PM', '5:00 PM']
                          .map((t) => PopupMenuItem(
                                value: t,
                                child: Text(t, style: GoogleFonts.poppins(fontSize: 13)),
                              ))
                          .toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Send reminder label
                Text(
                  'Send reminder',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),

                // Send reminder dropdown
                PopupMenuButton<String>(
                  onSelected: (val) {
                    setState(() {
                      _reminderText = val;
                    });
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _reminderText,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF00A884),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF00A884),
                        size: 18,
                      ),
                    ],
                  ),
                  itemBuilder: (context) => _reminders
                      .map((r) => PopupMenuItem(
                            value: r,
                            child: Text(r, style: GoogleFonts.poppins(fontSize: 13)),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 4),

                // 4 Columns: Task Type, Priority, Queue, Activity assigned to
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Task Type
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Task Type',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          PopupMenuButton<String>(
                            onSelected: (val) => setState(() => _selectedTaskType = val),
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _selectedTaskType,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF00A884),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Color(0xFF00A884),
                                  size: 16,
                                ),
                              ],
                            ),
                            itemBuilder: (context) => _taskTypes
                                .map((t) => PopupMenuItem(
                                      value: t,
                                      child: Text(t, style: GoogleFonts.poppins(fontSize: 12.5)),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),

                    // Priority
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Priority',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          PopupMenuButton<String>(
                            onSelected: (val) => setState(() => _selectedPriority = val),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF99ACC2),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _selectedPriority,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF00A884),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Color(0xFF00A884),
                                  size: 16,
                                ),
                              ],
                            ),
                            itemBuilder: (context) => prioritiesList
                                .map((p) => PopupMenuItem(
                                      value: p,
                                      child: Text(p, style: GoogleFonts.poppins(fontSize: 12.5)),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),

                    // Queue
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Queue',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          PopupMenuButton<String>(
                            onSelected: (val) => setState(() => _selectedQueue = val),
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _selectedQueue,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF00A884),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Color(0xFF00A884),
                                  size: 16,
                                ),
                              ],
                            ),
                            itemBuilder: (context) => _queues
                                .map((q) => PopupMenuItem(
                                      value: q,
                                      child: Text(q, style: GoogleFonts.poppins(fontSize: 12.5)),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),

                    // Activity assigned to
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Activity assigned to',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          PopupMenuButton<String>(
                            onSelected: (val) => setState(() => _selectedAssignee = val),
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _selectedAssignee,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF00A884),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Color(0xFF00A884),
                                  size: 16,
                                ),
                              ],
                            ),
                            itemBuilder: (context) => usersDisplayList
                                .map((u) => PopupMenuItem(
                                      value: u,
                                      child: Text(u, style: GoogleFonts.poppins(fontSize: 12.5)),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Rich Toolbar & Notes Card
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      // Toolbar Row (same spacing as Note form)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFormatIconButton('B', isActive: _isBold, isBold: true, onTap: () {
                                setState(() => _isBold = !_isBold);
                              }),
                              _buildFormatIconButton('I', isActive: _isItalic, isItalic: true, onTap: () {
                                setState(() => _isItalic = !_isItalic);
                              }),
                              _buildFormatIconButton('U', isActive: _isUnderline, isUnderline: true, onTap: () {
                                setState(() => _isUnderline = !_isUnderline);
                              }),
                              const SizedBox(width: 10),
                              const SizedBox(height: 24, child: VerticalDivider(color: Color(0xFFCBD5E1), width: 1)),
                              const SizedBox(width: 10),
                              _buildHeadingOption('H1'),
                              _buildHeadingOption('H2'),
                              _buildHeadingOption('T'),
                              const SizedBox(width: 10),
                              const SizedBox(height: 24, child: VerticalDivider(color: Color(0xFFCBD5E1), width: 1)),
                              const SizedBox(width: 10),
                              InkWell(
                                onTap: () {
                                  setState(() => _isBullet = !_isBullet);
                                  _applyFormatPrefix('• ', '');
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  child: Icon(Icons.format_list_bulleted, size: 24, color: _isBullet ? const Color(0xFF00A884) : const Color(0xFF64748B)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () {
                                  setState(() => _isNumbered = !_isNumbered);
                                  _applyFormatPrefix('1. ', '');
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  child: Icon(Icons.format_list_numbered, size: 24, color: _isNumbered ? const Color(0xFF00A884) : const Color(0xFF64748B)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('File attachment added', style: GoogleFonts.poppins(fontSize: 13)),
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  child: Icon(Icons.attach_file_rounded, size: 24, color: Color(0xFF64748B)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const SizedBox(height: 24, child: VerticalDivider(color: Color(0xFFCBD5E1), width: 1)),
                              const SizedBox(width: 10),
                              InkWell(
                                onTap: () {
                                  if (_notesController.text.isNotEmpty) {
                                    _notesController.clear();
                                  }
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  child: Icon(Icons.undo_rounded, size: 24, color: Color(0xFF64748B)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                child: Icon(Icons.redo_rounded, size: 24, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),

                      // Notes Input Field
                      Container(
                        constraints: const BoxConstraints(minHeight: 100),
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: _notesController,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          decoration: InputDecoration(
                            hintText: 'Notes...',
                            hintStyle: GoogleFonts.poppins(
                              color: const Color(0xFF94A3B8),
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                          ),
                          style: _getContentStyle(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. Footer Bar with Create button & Associated with 0 records
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: _titleController.text.trim().isNotEmpty && !_isSubmitting
                      ? _handleSubmit
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF70D1C4), // Teal background matching image 2
                    disabledBackgroundColor: const Color(0xFFA5E3DB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          isEditing ? 'Save' : 'Create',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
                InkWell(
                  onTap: () async {
                    final result = await RecordAssociationSheet.show(
                      context,
                      initialAssociations: _associations,
                    );
                    if (result != null) {
                      setState(() {
                        _associations = result;
                      });
                    }
                  },
                  child: Row(
                    children: [
                      Text(
                        'Associated with $_totalAssociations record${_totalAssociations > 1 ? 's' : ''}',
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF00A884),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF00A884),
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatIconButton(String label, {required bool isActive, bool isBold = false, bool isItalic = false, bool isUnderline = false, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
            decoration: isUnderline ? TextDecoration.underline : TextDecoration.none,
            color: isActive ? const Color(0xFF00A884) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildHeadingOption(String type) {
    final isSelected = _activeHeading == type;
    if (type == 'T') {
      return InkWell(
        onTap: () => setState(() => _activeHeading = 'T'),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFCCFBF1) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'T',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isSelected ? const Color(0xFF0F766E) : const Color(0xFF64748B),
            ),
          ),
        ),
      );
    }

    return InkWell(
      onTap: () => setState(() => _activeHeading = type),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          type,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isSelected ? const Color(0xFF00A884) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _isSubmitting = true;
    });

    final taskData = {
      'title': _titleController.text.trim(),
      'type': 'task',
      'taskType': _selectedTaskType,
      'priority': _selectedPriority,
      'queue': _selectedQueue,
      'assignedTo': _selectedAssignee,
      'notes': _notesController.text.trim(),
      'status': widget.taskToEdit?.status ?? 'PENDING',
      if (widget.contactId != null) 'contactId': widget.contactId,
      if (widget.companyId != null) 'companyId': widget.companyId,
      if (widget.dealId != null) 'dealId': widget.dealId,
    };

    final isEditing = widget.taskToEdit != null &&
        widget.taskToEdit!.id != null &&
        widget.taskToEdit!.id!.isNotEmpty;

    try {
      if (isEditing) {
        await ApiService().put(
          '${ApiConstants.activities}/${widget.taskToEdit!.id}',
          data: taskData,
        );
      } else {
        await ApiService().post(ApiConstants.activities, data: taskData);
      }
    } catch (e) {
      debugPrint('[CREATE/EDIT TASK ERROR]: $e');
    }

    final updatedTask = TaskModel(
      id: widget.taskToEdit?.id,
      title: _titleController.text.trim(),
      dueDate: widget.taskToEdit?.dueDate ?? '8/15/2026',
      priority: _selectedPriority,
      status: widget.taskToEdit?.status ?? 'PENDING',
      assignedTo: _selectedAssignee != 'Select ...' ? _selectedAssignee : 'Admin User',
      notes: _notesController.text.trim(),
      taskType: _selectedTaskType,
      queue: _selectedQueue,
      activityDateText: _activityDateText,
      reminderText: _reminderText,
    );

    if (mounted) {
      Navigator.of(context).pop(updatedTask);
    }
  }
}
