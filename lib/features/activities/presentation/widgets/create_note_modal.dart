import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/widgets/record_association_sheet.dart';
import 'follow_up_task_section.dart';

class CreateNoteModal extends StatefulWidget {
  final Map<String, dynamic>? noteToEdit;
  final String? contactId;
  final String? companyId;
  final String? dealId;
  final String associatedRecordName;

  const CreateNoteModal({
    super.key,
    this.noteToEdit,
    this.contactId,
    this.companyId,
    this.dealId,
    this.associatedRecordName = 'xyzzzz',
  });

  static Future<bool?> show(
    BuildContext context, {
    Map<String, dynamic>? noteToEdit,
    String? contactId,
    String? companyId,
    String? dealId,
    String associatedRecordName = 'xyzzzz',
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateNoteModal(
        noteToEdit: noteToEdit,
        contactId: contactId,
        companyId: companyId,
        dealId: dealId,
        associatedRecordName: associatedRecordName,
      ),
    );
  }

  @override
  State<CreateNoteModal> createState() => _CreateNoteModalState();
}

class _CreateNoteModalState extends State<CreateNoteModal> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  bool _createFollowUpTask = false;
  bool _isSubmitting = false;

  // Active formatting state toggles
  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderline = false;
  String _activeHeading = 'T'; // 'T', 'H1', 'H2'
  bool _isBullet = false;
  bool _isNumbered = false;

  // Associations state
  late Map<String, List<Map<String, String>>> _associations;

  // Undo/Redo state stack
  final List<String> _undoHistory = [];
  final List<String> _redoHistory = [];
  bool _isProgrammaticChange = false;
  Timer? _undoDebounceTimer;

  @override
  void initState() {
    super.initState();
    _associations = {
      'Companies': widget.companyId != null ? [{'id': widget.companyId!, 'name': widget.associatedRecordName}] : [],
      'Contacts': widget.contactId != null ? [{'id': widget.contactId!, 'name': widget.associatedRecordName}] : widget.companyId == null && widget.dealId == null ? [{'id': '1', 'name': widget.associatedRecordName}] : [],
      'Deals': widget.dealId != null ? [{'id': widget.dealId!, 'name': widget.associatedRecordName}] : [],
    };

    if (widget.noteToEdit != null) {
      _titleController.text = (widget.noteToEdit!['title'] ?? widget.noteToEdit!['subject'] ?? '').toString();
      _contentController.text = (widget.noteToEdit!['notes'] ?? widget.noteToEdit!['content'] ?? widget.noteToEdit!['description'] ?? '').toString();
    }

    _undoHistory.add(_contentController.text);
    _contentController.addListener(_onContentChanged);
  }

  void _onContentChanged() {
    if (_isProgrammaticChange) return;
    final currentText = _contentController.text;
    
    // Check if user hit space, newline, or a punctuation mark
    final bool isWordBoundary = currentText.endsWith(' ') || currentText.endsWith('\n') || currentText.endsWith('.') || currentText.endsWith(',');

    _undoDebounceTimer?.cancel();
    if (isWordBoundary) {
      _saveUndoCheckpoint(currentText);
    } else {
      _undoDebounceTimer = Timer(const Duration(milliseconds: 500), () {
        _saveUndoCheckpoint(currentText);
      });
    }
  }

  void _saveUndoCheckpoint(String text) {
    if (_undoHistory.isEmpty || _undoHistory.last != text) {
      if (_undoHistory.length > 200) {
        _undoHistory.removeAt(0);
      }
      _undoHistory.add(text);
      _redoHistory.clear();
      setState(() {});
    }
  }

  void _undo() {
    if (_undoHistory.length > 1) {
      _isProgrammaticChange = true;
      final current = _undoHistory.removeLast();
      _redoHistory.add(current);
      final previous = _undoHistory.last;
      _contentController.value = TextEditingValue(
        text: previous,
        selection: TextSelection.collapsed(offset: previous.length),
      );
      _isProgrammaticChange = false;
      setState(() {});
    }
  }

  void _redo() {
    if (_redoHistory.isNotEmpty) {
      _isProgrammaticChange = true;
      final next = _redoHistory.removeLast();
      _undoHistory.add(next);
      _contentController.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
      _isProgrammaticChange = false;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _undoDebounceTimer?.cancel();
    _contentController.removeListener(_onContentChanged);
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  int get _totalAssociations {
    return _associations['Companies']!.length +
        _associations['Contacts']!.length +
        _associations['Deals']!.length;
  }

  String get _displayForName {
    if (_associations['Contacts']!.isNotEmpty) {
      return _associations['Contacts']!.first['name']!;
    }
    if (_associations['Companies']!.isNotEmpty) {
      return _associations['Companies']!.first['name']!;
    }
    if (_associations['Deals']!.isNotEmpty) {
      return _associations['Deals']!.first['name']!;
    }
    return widget.associatedRecordName;
  }

  void _applyFormatPrefix(String prefix, String suffix) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    if (selection.isValid && !selection.isCollapsed) {
      final selectedText = text.substring(selection.start, selection.end);
      final newText = text.replaceRange(selection.start, selection.end, '$prefix$selectedText$suffix');
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + prefix.length + selectedText.length + suffix.length),
      );
    } else {
      final cursor = selection.start >= 0 ? selection.start : text.length;
      final newText = text.replaceRange(cursor, cursor, '$prefix$suffix');
      _contentController.value = TextEditingValue(
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

  Future<void> _submitNote() async {
    final title = _titleController.text.trim();
    final body = _contentController.text.trim();

    if (title.isEmpty && body.isEmpty) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final api = ApiService();
      String? selectedCompanyId;
      if (_associations['Companies'] != null && _associations['Companies']!.isNotEmpty) {
        selectedCompanyId = _associations['Companies']!.first['id'];
      } else if (widget.companyId != null && widget.companyId!.isNotEmpty) {
        selectedCompanyId = widget.companyId;
      } else {
        selectedCompanyId = widget.noteToEdit?['companyId'] ?? widget.noteToEdit?['company_id'];
      }

      String? selectedContactId;
      if (_associations['Contacts'] != null && _associations['Contacts']!.isNotEmpty) {
        selectedContactId = _associations['Contacts']!.first['id'];
      } else if (widget.contactId != null && widget.contactId!.isNotEmpty) {
        selectedContactId = widget.contactId;
      } else {
        selectedContactId = widget.noteToEdit?['contactId'] ?? widget.noteToEdit?['contact_id'];
      }

      String? selectedDealId;
      if (_associations['Deals'] != null && _associations['Deals']!.isNotEmpty) {
        selectedDealId = _associations['Deals']!.first['id'];
      } else if (widget.dealId != null && widget.dealId!.isNotEmpty) {
        selectedDealId = widget.dealId;
      } else {
        selectedDealId = widget.noteToEdit?['dealId'] ?? widget.noteToEdit?['deal_id'];
      }

      final companyIds = _associations['Companies']?.map((e) => e['id']).whereType<String>().toList() ?? [];
      if (selectedCompanyId != null && selectedCompanyId.isNotEmpty && !companyIds.contains(selectedCompanyId)) {
        companyIds.add(selectedCompanyId);
      }

      final contactIds = _associations['Contacts']?.map((e) => e['id']).whereType<String>().toList() ?? [];
      if (selectedContactId != null && selectedContactId.isNotEmpty && !contactIds.contains(selectedContactId)) {
        contactIds.add(selectedContactId);
      }

      final dealIds = _associations['Deals']?.map((e) => e['id']).whereType<String>().toList() ?? [];
      if (selectedDealId != null && selectedDealId.isNotEmpty && !dealIds.contains(selectedDealId)) {
        dealIds.add(selectedDealId);
      }

      final List<Map<String, String>> assocList = [];
      for (final id in companyIds) {
        assocList.add({'objectId': id, 'objectType': 'company'});
      }
      for (final id in contactIds) {
        assocList.add({'objectId': id, 'objectType': 'contact'});
      }
      for (final id in dealIds) {
        assocList.add({'objectId': id, 'objectType': 'deal'});
      }

      final payload = {
        'title': title.isNotEmpty ? title : 'Note',
        'type': 'note',
        'notes': body,
        'activityDate': DateTime.now().toIso8601String(),
        'associations': _associations,
        'associationsList': assocList,
        'associations_list': assocList,
        'companyIds': companyIds,
        'company_ids': companyIds,
        'contactIds': contactIds,
        'contact_ids': contactIds,
        'dealIds': dealIds,
        'deal_ids': dealIds,
        if (selectedContactId != null && selectedContactId.isNotEmpty) ...{
          'contactId': selectedContactId,
          'contact_id': selectedContactId,
        },
        if (selectedCompanyId != null && selectedCompanyId.isNotEmpty) ...{
          'companyId': selectedCompanyId,
          'company_id': selectedCompanyId,
        },
        if (selectedDealId != null && selectedDealId.isNotEmpty) ...{
          'dealId': selectedDealId,
          'deal_id': selectedDealId,
        },
      };

      final noteId = widget.noteToEdit?['id'] ?? widget.noteToEdit?['_id'];
      if (noteId != null && noteId.toString().isNotEmpty) {
        try {
          await api.put('${ApiConstants.activities}/$noteId', data: payload);
        } catch (_) {
          await api.patch('${ApiConstants.activities}/$noteId', data: payload);
        }
      } else {
        await api.post(ApiConstants.activities, data: payload);
      }

      if (_createFollowUpTask) {
        try {
          final taskPayload = {
            'title': 'Follow-up: ${title.isNotEmpty ? title : "Note"}',
            'subject': 'Follow-up: ${title.isNotEmpty ? title : "Note"}',
            'type': 'task',
            'status': 'PENDING',
            'priority': 'Medium',
            'notes': body,
            'description': body,
            'activityDate': DateTime.now().toIso8601String(),
            'dueDate': 'Today',
            if (selectedContactId != null && selectedContactId.isNotEmpty) ...{
              'contactId': selectedContactId,
              'contact_id': selectedContactId,
            },
            if (selectedCompanyId != null && selectedCompanyId.isNotEmpty) ...{
              'companyId': selectedCompanyId,
              'company_id': selectedCompanyId,
            },
            if (selectedDealId != null && selectedDealId.isNotEmpty) ...{
              'dealId': selectedDealId,
              'deal_id': selectedDealId,
            },
          };
          try {
            await api.post(ApiConstants.activities, data: taskPayload);
          } catch (_) {}
          try {
            await api.post('/tasks', data: taskPayload);
          } catch (_) {}
        } catch (e) {
          debugPrint('[Create Follow-up Task Error]: $e');
        }
      }
    } catch (_) {}

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Column(
          children: [
            // 1. Dark Top Bar matching Image 1
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF475569),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Note',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _titleController.clear();
                            _contentController.clear();
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Note form data refreshed'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                        tooltip: 'Refresh Form Data',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 2. Dynamic For Record Tag Row (Matching Image 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Text(
                    'For',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Text(
                      _displayForName,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 3. Note Title Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: TextField(
                controller: _titleController,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1E293B),
                ),
                decoration: InputDecoration(
                  hintText: 'Note title',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 16,
                    color: const Color(0xFF94A3B8),
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // 4. Dynamic Formatting Toolbar (B, I, U, H1, H2, T, Bullet, Numbering, File Attach, Undo, Redo)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: const Color(0xFFF8FAFC),
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
                      onTap: _undoHistory.length > 1 ? _undo : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Icon(
                          Icons.undo_rounded,
                          size: 24,
                          color: _undoHistory.length > 1 ? const Color(0xFF00A884) : const Color(0xFFCBD5E1),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: _redoHistory.isNotEmpty ? _redo : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Icon(
                          Icons.redo_rounded,
                          size: 24,
                          color: _redoHistory.isNotEmpty ? const Color(0xFF00A884) : const Color(0xFFCBD5E1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // 5. Dynamic Note Content Field
            Expanded(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Container(
                    color: const Color(0xFFF8FAFC),
                    constraints: const BoxConstraints(minHeight: 180),
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _contentController,
                      maxLines: null,
                      style: _getContentStyle(),
                      decoration: InputDecoration(
                        hintText: 'Start typing to leave a note...',
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 14,
                          color: const Color(0xFF94A3B8),
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 6. Dynamic Associated Record Link Row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: Colors.white,
                    child: InkWell(
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
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF00A884),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Color(0xFF00A884),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),

                  // 7. Follow-up Task Row
                  FollowUpTaskSection(
                    initialChecked: _createFollowUpTask,
                    onCheckedChanged: (val) {
                      setState(() {
                        _createFollowUpTask = val;
                      });
                    },
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),

                  // 8. Footer Action Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitNote,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00A884),
                            disabledBackgroundColor: const Color(0xFFCBD5E1),
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: Text(
                            'Create note',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            const Icon(Icons.check, color: Color(0xFF00A884), size: 18),
                            const SizedBox(width: 4),
                            Text(
                              'Draft saved',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(width: 14),
                            InkWell(
                              onTap: () {
                                _titleController.clear();
                                _contentController.clear();
                              },
                              child: const Icon(Icons.delete_outline, color: Color(0xFF64748B), size: 20),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 160),
                ],
              ),
            ),
          ],
        ),
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
}
