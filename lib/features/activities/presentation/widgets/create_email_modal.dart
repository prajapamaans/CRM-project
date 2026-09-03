import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/navigation/route_names.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/datasources/master_data_remote_datasource.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/widgets/record_association_sheet.dart';
import '../../../../core/utils/activity_utils.dart';
import 'create_template_modal.dart';
import 'follow_up_task_section.dart';
import 'create_signature_modal.dart';
import '../../../../core/models/email_signature_model.dart';
import '../../../../core/repositories/master_data_repository.dart';
import '../../../../core/utils/signature_variable_resolver.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class CreateEmailModal extends StatefulWidget {
  final Map<String, dynamic>? emailToEdit;
  final String? contactId;
  final String? companyId;
  final String? dealId;
  final String associatedRecordName;
  final String fromEmail;

  const CreateEmailModal({
    super.key,
    this.emailToEdit,
    this.contactId,
    this.companyId,
    this.dealId,
    this.associatedRecordName = 'xyzzzz',
    this.fromEmail = 'dev@apideltech.com',
  });

  static Future<bool?> show(
    BuildContext context, {
    Map<String, dynamic>? emailToEdit,
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
        emailToEdit: emailToEdit,
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
  final TextEditingController _toEmailController = TextEditingController();

  // Cc / Bcc each get their own row under To, opened from the Cc and Bcc links.
  final TextEditingController _ccController = TextEditingController();
  final TextEditingController _bccController = TextEditingController();
  final FocusNode _ccFocusNode = FocusNode();
  final FocusNode _bccFocusNode = FocusNode();
  bool _showCc = false;
  bool _showBcc = false;

  // Signatures State
  List<EmailSignatureModel> _signatures = [];
  EmailSignatureModel? _selectedSignature;
  bool _showSignaturePreview = false;
  bool _isLoadingSignatures = false;
  final MasterDataRepositoryImpl _masterDataRepository = MasterDataRepositoryImpl();

  bool _createFollowUpTask = false;
  bool _isSubmitting = false;
  bool _isLoadingTemplates = false;

  /// Opens the Cc (or Bcc) row and puts the cursor in it. Tapping the link
  /// again closes the row and clears what was typed there.
  void _toggleRecipientRow({required bool cc}) {
    setState(() {
      if (cc) {
        _showCc = !_showCc;
        if (!_showCc) _ccController.clear();
      } else {
        _showBcc = !_showBcc;
        if (!_showBcc) _bccController.clear();
      }
    });

    final shouldFocus = cc ? _showCc : _showBcc;
    if (!shouldFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      (cc ? _ccFocusNode : _bccFocusNode).requestFocus();
    });
  }

  /// A stored cc/bcc value as editable text — the API may hand back either a
  /// string or a list of addresses.
  static String _recipientText(dynamic stored) {
    if (stored == null) return '';
    if (stored is List) {
      return stored.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).join(', ');
    }
    return stored.toString().trim();
  }

  /// Splits a recipient field into addresses, accepting commas or semicolons.
  static List<String> _recipients(String raw) => raw
      .split(RegExp(r'[,;]'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  /// One row of the header block, laid out like the To row.
  Widget _buildRecipientRow({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required VoidCallback onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: GoogleFonts.poppins(fontSize: 13.5, color: const Color(0xFF64748B)),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: TextInputType.emailAddress,
              style: GoogleFonts.poppins(fontSize: 13.5, color: const Color(0xFF1E293B)),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Type email...',
                hintStyle: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF94A3B8)),
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
                  final contactNames = _associations['Contacts']?.map((e) => e['name']).whereType<String>().join(', ');
                  if (contactNames != null && contactNames.isNotEmpty) {
                    if (controller.text.isNotEmpty) {
                      controller.text = '${controller.text}, $contactNames';
                    } else {
                      controller.text = contactNames;
                    }
                  }
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
          const SizedBox(width: 8),
          InkWell(
            onTap: onRemove,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Icon(Icons.close, size: 14, color: Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    );
  }

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
      'Contacts': widget.contactId != null ? [{'id': widget.contactId!, 'name': widget.associatedRecordName}] : [],
      'Deals': widget.dealId != null ? [{'id': widget.dealId!, 'name': widget.associatedRecordName}] : [],
    };

    if (widget.emailToEdit != null) {
      final rawSubj = widget.emailToEdit!['subject'] ?? widget.emailToEdit!['title'] ?? '';
      _subjectController.text = parseActivityDescription(rawSubj);
      final rawBody = widget.emailToEdit!['body'] ?? widget.emailToEdit!['description'] ?? widget.emailToEdit!['notes'] ?? '';
      _bodyController.text = parseActivityDescription(rawBody);

      // Show the Cc / Bcc rows already filled when the email has recipients.
      _ccController.text = _recipientText(widget.emailToEdit!['cc']);
      _bccController.text = _recipientText(widget.emailToEdit!['bcc']);
      _showCc = _ccController.text.isNotEmpty;
      _showBcc = _bccController.text.isNotEmpty;
    }

    _undoHistory.add(_bodyController.text);
    _bodyController.addListener(_onContentChanged);
    _fetchSignatures();
  }



  Future<void> _fetchSignatures() async {
    setState(() => _isLoadingSignatures = true);
    try {
      final list = await _masterDataRepository.getEmailSignatures();
      if (mounted) {
        setState(() {
          _signatures = list;
          _isLoadingSignatures = false;
          if (_signatures.isNotEmpty) {
            _selectedSignature = _signatures.firstWhere(
              (s) => s.isDefault,
              orElse: () => _signatures.first,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingSignatures = false);
    }
  }

  void _onContentChanged() {
    if (_isProgrammaticChange) return;
    final currentText = _bodyController.text;

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
      _bodyController.value = TextEditingValue(
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
      _bodyController.value = TextEditingValue(
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
    _bodyController.removeListener(_onContentChanged);
    _subjectController.dispose();
    _bodyController.dispose();
    _toEmailController.dispose();
    _ccController.dispose();
    _bccController.dispose();
    _ccFocusNode.dispose();
    _bccFocusNode.dispose();
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

    if (subject.isEmpty && body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an email subject or body.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final api = ApiService();
      String? selectedCompanyId = widget.companyId ?? widget.emailToEdit?['companyId'] ?? widget.emailToEdit?['company_id'];
      if ((selectedCompanyId == null || selectedCompanyId.isEmpty) &&
          _associations['Companies'] != null &&
          _associations['Companies']!.isNotEmpty) {
        selectedCompanyId = _associations['Companies']!.first['id'];
      }

      String? selectedContactId = widget.contactId ?? widget.emailToEdit?['contactId'] ?? widget.emailToEdit?['contact_id'];
      if ((selectedContactId == null || selectedContactId.isEmpty) &&
          _associations['Contacts'] != null &&
          _associations['Contacts']!.isNotEmpty) {
        selectedContactId = _associations['Contacts']!.first['id'];
      }

      String? selectedDealId = widget.dealId ?? widget.emailToEdit?['dealId'] ?? widget.emailToEdit?['deal_id'];
      if ((selectedDealId == null || selectedDealId.isEmpty) &&
          _associations['Deals'] != null &&
          _associations['Deals']!.isNotEmpty) {
        selectedDealId = _associations['Deals']!.first['id'];
      }

      if (selectedContactId == '1') selectedContactId = null;
      if (selectedCompanyId == '1') selectedCompanyId = null;
      if (selectedDealId == '1') selectedDealId = null;

      final companyIds = _associations['Companies']?.map((e) => e['id']).whereType<String>().where((id) => id != '1').toList() ?? [];
      if (selectedCompanyId != null && selectedCompanyId.isNotEmpty && !companyIds.contains(selectedCompanyId)) {
        companyIds.add(selectedCompanyId);
      }

      final contactIds = _associations['Contacts']?.map((e) => e['id']).whereType<String>().where((id) => id != '1').toList() ?? [];
      if (selectedContactId != null && selectedContactId.isNotEmpty && !contactIds.contains(selectedContactId)) {
        contactIds.add(selectedContactId);
      }

      final dealIds = _associations['Deals']?.map((e) => e['id']).whereType<String>().where((id) => id != '1').toList() ?? [];
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

      final ccList = _recipients(_ccController.text);
      final bccList = _recipients(_bccController.text);

      final payload = {
        'title': subject.isNotEmpty ? subject : 'Email Activity',
        'type': 'email',
        'notes': body,
        'description': body,
        'activityDate': DateTime.now().toIso8601String(),
        if (ccList.isNotEmpty) 'cc': ccList.join(', '),
        if (bccList.isNotEmpty) 'bcc': bccList.join(', '),
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

      bool emailSuccess = false;
      final emailId = widget.emailToEdit?['id'] ?? widget.emailToEdit?['_id'];
      try {
        if (emailId != null && emailId.toString().isNotEmpty) {
          // PATCH /api/activities/:id is the documented update route.
          await api.patch('${ApiConstants.activities}/$emailId', data: payload);
        } else {
          await api.post(ApiConstants.activities, data: payload);
        }
        emailSuccess = true;
      } catch (e) {
        debugPrint('[CreateEmail Error]: $e');
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save email: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (emailSuccess && _createFollowUpTask) {
        try {
          final String taskDescJson = jsonEncode({
            'type': 'doc',
            'content': [
              {
                'type': 'paragraph',
                if (body.isNotEmpty)
                  'content': [{'type': 'text', 'text': body}]
              }
            ]
          });

          final taskPayload = {
            'type': 'task',
            'title': 'Follow-up: ${subject.isNotEmpty ? subject : "Email"}',
            'subject': 'Follow-up: ${subject.isNotEmpty ? subject : "Email"}',
            'priority': 'medium',
            'notes': body,
            'description': taskDescJson,
            'scheduledAt': DateTime.now().toIso8601String(),
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
          await api.post(ApiConstants.activities, data: taskPayload);
        } catch (e) {
          debugPrint('[Create Follow-up Task Warning]: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email saved successfully!'),
            backgroundColor: Color(0xFF00A884),
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _subjectController.clear();
                              _bodyController.clear();
                              _createFollowUpTask = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Email form data refreshed'),
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

              // Scrollable content area so form remains scrollable & responsive with keyboard
              Expanded(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
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
                            // Each opens its own row below To.
                            InkWell(
                              onTap: () => _toggleRecipientRow(cc: true),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Text(
                                  'Cc',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: _showCc
                                        ? const Color(0xFF0F766E)
                                        : const Color(0xFF00A884),
                                    decoration: _showCc ? TextDecoration.underline : null,
                                  ),
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => _toggleRecipientRow(cc: false),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Text(
                                  'Bcc',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: _showBcc
                                        ? const Color(0xFF0F766E)
                                        : const Color(0xFF00A884),
                                    decoration: _showBcc ? TextDecoration.underline : null,
                                  ),
                                ),
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
                            if (_displayToName.isNotEmpty) ...[
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
                                      const SizedBox(width: 4),
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            _associations['Contacts']?.clear();
                                          });
                                        },
                                        child: const Icon(Icons.close, size: 14, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: TextField(
                                controller: _toEmailController,
                                keyboardType: TextInputType.emailAddress,
                                style: GoogleFonts.poppins(fontSize: 13.5, color: const Color(0xFF1E293B)),
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  hintText: 'Type email...',
                                  hintStyle: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF94A3B8)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
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

                      // 4b. Cc / Bcc — their own rows, laid out like To.
                      if (_showCc)
                        _buildRecipientRow(
                          label: 'Cc',
                          controller: _ccController,
                          focusNode: _ccFocusNode,
                          onRemove: () => _toggleRecipientRow(cc: true),
                        ),
                      if (_showBcc)
                        _buildRecipientRow(
                          label: 'Bcc',
                          controller: _bccController,
                          focusNode: _bccFocusNode,
                          onRemove: () => _toggleRecipientRow(cc: false),
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
                              width: 62,
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
                                onTap: _undoHistory.length > 1 ? _undo : null,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Icon(
                                    Icons.undo_rounded,
                                    size: 20,
                                    color: _undoHistory.length > 1 ? const Color(0xFF00A884) : const Color(0xFFCBD5E1),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: _redoHistory.isNotEmpty ? _redo : null,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Icon(
                                    Icons.redo_rounded,
                                    size: 20,
                                    color: _redoHistory.isNotEmpty ? const Color(0xFF00A884) : const Color(0xFFCBD5E1),
                                  ),
                                ),
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
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),

                      // 7b. Signature Row (Matching Design Screenshot)
                      _buildSignatureSection(),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),

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
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'CRM Sales Mode (Individual)',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF334155),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                                    ],
                                  ),
                                ),
                              ],
                            ),

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
                                      child: _isSubmitting
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                            )
                                          : Text(
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
                      const SizedBox(height: 160),
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

  Widget _buildSignatureSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text(
                    'Signature',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_isLoadingSignatures)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00A884)),
                    )
                  else if (_signatures.isEmpty)
                    Text(
                      'No signature',
                      style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF00A884)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<EmailSignatureModel>(
                          value: _selectedSignature,
                          isDense: true,
                          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF334155), fontWeight: FontWeight.w500),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF334155)),
                          items: _signatures.map((sig) {
                            return DropdownMenuItem<EmailSignatureModel>(
                              value: sig,
                              child: Text('${sig.name}${sig.isDefault ? ' (default)' : ''}'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedSignature = val;
                            });
                          },
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  if (_selectedSignature != null)
                    InkWell(
                      onTap: () {
                        setState(() {
                          _showSignaturePreview = !_showSignaturePreview;
                        });
                      },
                      child: Text(
                        _showSignaturePreview ? 'Hide' : 'Preview',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF00A884),
                        ),
                      ),
                    ),
                ],
              ),
              InkWell(
                onTap: () async {
                  final created = await CreateSignatureModal.show(context);
                  if (created == true) {
                    _fetchSignatures();
                  }
                },
                child: Text(
                  'Manage signatures',
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          if (_showSignaturePreview && _selectedSignature != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Text(
                _selectedSignature!.body.isEmpty
                    ? '(Empty signature body)'
                    : SignatureVariableResolver.cleanPreviewText(
                        _selectedSignature!.body,
                        context.watch<AuthProvider>().currentUser,
                      ),
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
