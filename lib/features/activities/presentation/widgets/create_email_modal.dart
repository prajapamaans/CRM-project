import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/widgets/record_association_sheet.dart';

class CreateEmailModal extends StatefulWidget {
  final String? contactId;
  final String? companyId;
  final String? dealId;
  final String associatedRecordName;
  final String fromEmail;

  const CreateEmailModal({
    super.key,
    this.contactId,
    this.companyId,
    this.dealId,
    this.associatedRecordName = 'xyzzzz',
    this.fromEmail = 'dev@apideltech.com',
  });

  static Future<bool?> show(
    BuildContext context, {
    String? contactId,
    String? companyId,
    String? dealId,
    String associatedRecordName = 'xyzzzz',
    String fromEmail = 'dev@apideltech.com',
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateEmailModal(
        contactId: contactId,
        companyId: companyId,
        dealId: dealId,
        associatedRecordName: associatedRecordName,
        fromEmail: fromEmail,
      ),
    );
  }

  @override
  State<CreateEmailModal> createState() => _CreateEmailModalState();
}

class _CreateEmailModalState extends State<CreateEmailModal> {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  bool _createFollowUpTask = false;
  bool _isSubmitting = false;

  // Active formatting state toggles
  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderline = false;
  String _activeHeading = 'T';

  // Associations state
  late Map<String, List<Map<String, String>>> _associations;

  @override
  void initState() {
    super.initState();
    _associations = {
      'Companies': widget.companyId != null ? [{'id': widget.companyId!, 'name': widget.associatedRecordName}] : [],
      'Contacts': widget.contactId != null ? [{'id': widget.contactId!, 'name': widget.associatedRecordName}] : widget.companyId == null && widget.dealId == null ? [{'id': '1', 'name': widget.associatedRecordName}] : [],
      'Deals': widget.dealId != null ? [{'id': widget.dealId!, 'name': widget.associatedRecordName}] : [],
    };
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  int get _totalAssociations {
    return _associations['Companies']!.length +
        _associations['Contacts']!.length +
        _associations['Deals']!.length;
  }

  String get _displayToName {
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
    final text = _bodyController.text;
    final selection = _bodyController.selection;
    if (selection.isValid && !selection.isCollapsed) {
      final selectedText = text.substring(selection.start, selection.end);
      final newText = text.replaceRange(selection.start, selection.end, '$prefix$selectedText$suffix');
      _bodyController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + prefix.length + selectedText.length + suffix.length),
      );
    } else {
      final cursor = selection.start >= 0 ? selection.start : text.length;
      final newText = text.replaceRange(cursor, cursor, '$prefix$suffix');
      _bodyController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: cursor + prefix.length),
      );
    }
  }

  TextStyle _getBodyStyle() {
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

  Widget _buildHeadingOption(String type) {
    final isSelected = _activeHeading == type;
    return InkWell(
      onTap: () => setState(() => _activeHeading = type),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFCCFBF1) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          type,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isSelected ? const Color(0xFF0F766E) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Future<void> _submitEmail() async {
    final subject = _subjectController.text.trim();
    final body = _bodyController.text.trim();

    if (subject.isEmpty && body.isEmpty) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final api = ApiService();
      final payload = {
        'title': subject.isNotEmpty ? subject : 'Email Activity',
        'type': 'email',
        'notes': body,
        'activityDate': DateTime.now().toIso8601String(),
        if (widget.contactId != null) 'contactId': widget.contactId,
        if (widget.companyId != null) 'companyId': widget.companyId,
        if (widget.dealId != null) 'dealId': widget.dealId,
      };

      await api.post(ApiConstants.activities, data: payload);
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
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Column(
          children: [
            // 1. Dark Top Bar matching Image 2
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
                    'Email',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.open_in_full_rounded, color: Colors.white, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 14),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // 2. Templates Header Row matching Image 2
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Templates',
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF00A884),
                    ),
                  ),
                  Text(
                    'Type / in the message to insert a template',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),

            // 3. From Field
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(
                      'From',
                      style: GoogleFonts.poppins(fontSize: 13.5, color: const Color(0xFF64748B)),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      widget.fromEmail,
                      style: GoogleFonts.poppins(fontSize: 13.5, color: const Color(0xFF1E293B)),
                    ),
                  ),
                  Text(
                    'Cc  Bcc',
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF00A884),
                    ),
                  ),
                ],
              ),
            ),

            // 4. To Field matching Image 2 (Dynamic with chip)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(
                      'To',
                      style: GoogleFonts.poppins(fontSize: 13.5, color: const Color(0xFF64748B)),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _displayToName,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.close, size: 14, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Type email...',
                      style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF94A3B8)),
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
                    child: Text(
                      '+ Add contact',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF00A884),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 5. Subject Field
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(
                      'Subject',
                      style: GoogleFonts.poppins(fontSize: 13.5, color: const Color(0xFF64748B)),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _subjectController,
                      style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF1E293B)),
                      decoration: InputDecoration(
                        hintText: 'Subject',
                        hintStyle: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 6. Formatting Toolbar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: const Color(0xFFF8FAFC),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildToolIconButton('B', isActive: _isBold, isBold: true, onTap: () {
                      setState(() => _isBold = !_isBold);
                    }),
                    _buildToolIconButton('I', isActive: _isItalic, isItalic: true, onTap: () {
                      setState(() => _isItalic = !_isItalic);
                    }),
                    _buildToolIconButton('U', isActive: _isUnderline, isUnderline: true, onTap: () {
                      setState(() => _isUnderline = !_isUnderline);
                    }),
                    const SizedBox(width: 10),
                    const SizedBox(
                      height: 24,
                      child: VerticalDivider(color: Color(0xFFCBD5E1), width: 1),
                    ),
                    const SizedBox(width: 10),
                    _buildHeadingOption('H1'),
                    _buildHeadingOption('H2'),
                    _buildHeadingOption('T'),
                    const SizedBox(width: 10),
                    const SizedBox(
                      height: 24,
                      child: VerticalDivider(color: Color(0xFFCBD5E1), width: 1),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () => _applyFormatPrefix('• ', ''),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Icon(Icons.format_list_bulleted, size: 20, color: Color(0xFF64748B)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _applyFormatPrefix('1. ', ''),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Icon(Icons.format_list_numbered, size: 20, color: Color(0xFF64748B)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Icon(Icons.attach_file_rounded, size: 20, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(width: 10),
                    const SizedBox(
                      height: 24,
                      child: VerticalDivider(color: Color(0xFFCBD5E1), width: 1),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () {
                        if (_bodyController.text.isNotEmpty) _bodyController.clear();
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Icon(Icons.undo_rounded, size: 20, color: Color(0xFF64748B)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Icon(Icons.redo_rounded, size: 20, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // 7. Email Body Input
            Expanded(
              child: Container(
                color: const Color(0xFFF8FAFC),
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _bodyController,
                  maxLines: null,
                  expands: true,
                  style: _getBodyStyle(),
                  decoration: InputDecoration(
                    hintText: 'Write your email here, or type / to insert a template...',
                    hintStyle: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF94A3B8)),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),

            // 8. Dynamic Associated Record Link Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                        fontSize: 13,
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
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // 9. Follow-up Task Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.white,
              child: Row(
                children: [
                  Checkbox(
                    value: _createFollowUpTask,
                    onChanged: (val) {
                      setState(() {
                        _createFollowUpTask = val ?? false;
                      });
                    },
                    activeColor: const Color(0xFF00A884),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                  ),
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Create a ',
                          style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF475569)),
                        ),
                        Text(
                          'To-do ⌄ ',
                          style: GoogleFonts.poppins(
                              fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF00A884)),
                        ),
                        Text(
                          'task to follow up ',
                          style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF475569)),
                        ),
                        Text(
                          'In 3 business days (Monday) ⌄ ',
                          style: GoogleFonts.poppins(
                              fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF00A884)),
                        ),
                        Text(
                          'at ',
                          style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF475569)),
                        ),
                        Text(
                          '8:00 AM ⌄',
                          style: GoogleFonts.poppins(
                              fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF00A884)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // 10. Footer Action Bar matching Image 2 (Tracking dropdown + Send split button)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text(
                    'Tracking:',
                    style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'CRM Sales Mode (Individual)',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                  const Spacer(),

                  // Send Split Button (Saves to Activities API)
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF00A884),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: _isSubmitting ? null : _submitEmail,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                            child: Text(
                              'Send',
                              style: GoogleFonts.poppins(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 22,
                          child: VerticalDivider(color: Colors.white54, width: 1),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          child: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 20),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolIconButton(String label, {required bool isActive, bool isBold = false, bool isItalic = false, bool isUnderline = false, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 17,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
            decoration: isUnderline ? TextDecoration.underline : TextDecoration.none,
            color: isActive ? const Color(0xFF00A884) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}
