import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/datasources/master_data_remote_datasource.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/widgets/record_association_sheet.dart';
import 'create_template_modal.dart';
import 'follow_up_task_section.dart';

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
  bool _isLoadingTemplates = false;

  Future<void> _showTemplatesMenu(BuildContext context, Offset tapPosition) async {
    setState(() => _isLoadingTemplates = true);

    List<EmailTemplateModel> templates = [];
    try {
      final ds = MasterDataRemoteDataSourceImpl();
      final apiList = await ds.getEmailTemplates(flat: true);
      for (var item in apiList) {
        final name = (item['name'] ?? item['title'] ?? 'Template').toString();
        templates.add(
          EmailTemplateModel(
            id: item['id']?.toString() ?? item['_id']?.toString(),
            name: name,
            subject: (item['subject'] ?? '').toString(),
            body: (item['body'] ?? item['content'] ?? '').toString(),
            owner: (item['ownerName'] ?? item['owner'] ?? item['createdBy'] ?? 'Admin User').toString(),
            folder: (item['folder'] ?? 'Root').toString(),
          ),
        );
      }

      if (templates.isEmpty) {
        final storage = SecureStorageService();
        final savedJson = await storage.getString('custom_email_templates');
        if (savedJson != null && savedJson.isNotEmpty) {
          final List<dynamic> decoded = jsonDecode(savedJson);
          for (var item in decoded) {
            templates.add(
              EmailTemplateModel(
                id: item['id']?.toString(),
                name: (item['name'] ?? '').toString(),
                subject: (item['subject'] ?? '').toString(),
                body: (item['body'] ?? '').toString(),
                owner: (item['owner'] ?? 'Admin User').toString(),
                folder: (item['folder'] ?? 'Root').toString(),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[CreateEmailModal getTemplates ERROR]: $e');
    } finally {
      if (mounted) setState(() => _isLoadingTemplates = false);
    }

    if (templates.isEmpty) {
      templates = [
        EmailTemplateModel(
          name: 'Test Template',
          subject: 'Test Subject',
          body: 'Hi, this is a test email template body.',
        ),
        EmailTemplateModel(
          name: 'Follow-up Email',
          subject: 'Following up on our conversation',
          body: 'Hi,\n\nI wanted to follow up on our previous conversation. Please let me know if you have any questions.\n\nBest regards,',
        ),
        EmailTemplateModel(
          name: 'Sales Introduction',
          subject: 'Introducing APIDEL Solutions',
          body: 'Hi,\n\nI hope this email finds you well. I am reaching out from APIDEL to share how we can support your business goals.\n\nBest regards,',
        ),
      ];
    }

    if (!mounted) return;

    final selected = await showMenu<EmailTemplateModel>(
      context: context,
      position: RelativeRect.fromLTRB(
        tapPosition.dx,
        tapPosition.dy,
        tapPosition.dx + 260,
        tapPosition.dy + 300,
      ),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: templates.map((t) {
        return PopupMenuItem<EmailTemplateModel>(
          value: t,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t.name,
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
              if (t.subject.isNotEmpty)
                Text(
                  t.subject,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        );
      }).toList(),
    );

    if (selected != null) {
      setState(() {
        if (selected.subject.isNotEmpty) {
          _subjectController.text = selected.subject;
        }
        if (selected.body.isNotEmpty) {
          _bodyController.text = selected.body;
        }
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Applied template: ${selected.name}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

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
    final screenHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.9,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Scrollable content area so form remains scrollable & responsive with keyboard
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 2. Templates Header Row
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTapDown: (details) {
                                _showTemplatesMenu(context, details.globalPosition);
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Templates',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF00A884),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  _isLoadingTemplates
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF00A884),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: Color(0xFF00A884),
                                          size: 18,
                                        ),
                                ],
                              ),
                            ),
                            Flexible(
                              child: Text(
                                'Click Templates to insert a template',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color(0xFF94A3B8),
                                ),
                                overflow: TextOverflow.ellipsis,
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
                                overflow: TextOverflow.ellipsis,
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

                      // 4. To Field
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
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _displayToName,
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF334155),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.close, size: 14, color: Color(0xFF64748B)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
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

                      // 5. Subject Field (Fixed: No duplicate hintText)
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
                                decoration: const InputDecoration(
                                  hintText: '',
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
                      Container(
                        color: const Color(0xFFF8FAFC),
                        constraints: const BoxConstraints(minHeight: 140),
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: _bodyController,
                          minLines: 5,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          style: _getBodyStyle(),
                          decoration: InputDecoration(
                            hintText: 'Write your email here, or type / to insert a template...',
                            hintStyle: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF94A3B8)),
                            border: InputBorder.none,
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
                      FollowUpTaskSection(
                        initialChecked: _createFollowUpTask,
                        onCheckedChanged: (val) {
                          setState(() {
                            _createFollowUpTask = val;
                          });
                        },
                      ),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),

                      // 10. Footer Action Bar (Tracking dropdown + Send split button)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          runSpacing: 10,
                          spacing: 10,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Tracking:',
                                  style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF64748B)),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            'CRM Sales Mode (Individual)',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFF334155),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Send Split Button
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF00A884),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
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
              ),
            ],
          ),
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
