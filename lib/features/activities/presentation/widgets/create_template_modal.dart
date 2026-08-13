import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EmailTemplateModel {
  final String? id;
  final String name;
  final String subject;
  final String body;
  final String owner;
  final String folder;
  final String privacy;
  final String createdAt;

  EmailTemplateModel({
    this.id,
    required this.name,
    required this.subject,
    required this.body,
    this.owner = 'Admin User',
    this.folder = 'Root',
    this.privacy = 'Private',
    String? createdAt,
  }) : createdAt = createdAt ?? 'Just now';
}

class CreateTemplateModal extends StatefulWidget {
  final EmailTemplateModel? templateToEdit;

  const CreateTemplateModal({super.key, this.templateToEdit});

  static Future<EmailTemplateModel?> show(
    BuildContext context, {
    EmailTemplateModel? templateToEdit,
  }) {
    return showModalBottomSheet<EmailTemplateModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateTemplateModal(templateToEdit: templateToEdit),
    );
  }

  @override
  State<CreateTemplateModal> createState() => _CreateTemplateModalState();
}

class _CreateTemplateModalState extends State<CreateTemplateModal> {
  int _selectedTab = 0; // 0: Compose, 1: Live preview

  late final TextEditingController _nameController;
  late final TextEditingController _subjectController;
  late final TextEditingController _bodyController;
  final TextEditingController _contactSearchController = TextEditingController();

  String _selectedPrivacy = 'Private';
  String _selectedFolder = 'Root';
  String _ownerName = 'Admin User';

  // Active formatting state toggles
  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderline = false;
  String _activeHeading = 'T';

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
    double fontSize = 13.5;
    FontWeight fontWeight = _isBold ? FontWeight.bold : FontWeight.normal;
    FontStyle fontStyle = _isItalic ? FontStyle.italic : FontStyle.normal;
    TextDecoration decoration = _isUnderline ? TextDecoration.underline : TextDecoration.none;

    if (_activeHeading == 'H1') {
      fontSize = 18.0;
      fontWeight = FontWeight.bold;
    } else if (_activeHeading == 'H2') {
      fontSize = 15.5;
      fontWeight = FontWeight.bold;
    }

    return GoogleFonts.poppins(
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      decoration: decoration,
      color: const Color(0xFF1E293B),
    );
  }

  // Sample contacts for live preview resolution
  final List<Map<String, String>> _sampleContacts = [
    {
      'name': 'Sarah Smith',
      'email': 'sarah.smith@acme.com',
      'first_name': 'Sarah',
      'company': 'Acme Corp',
    },
    {
      'name': 'John Doe',
      'email': 'john.doe@globaltech.com',
      'first_name': 'John',
      'company': 'Global Tech',
    },
    {
      'name': 'Michael Jordan',
      'email': 'michael@bulls.com',
      'first_name': 'Michael',
      'company': 'Bulls Inc',
    },
  ];

  Map<String, String>? _selectedPreviewContact;
  String _contactSearchQuery = '';

  final List<String> _variables = const [
    '{{contact.first_name}}',
    '{{contact.email}}',
    '{{company.name}}',
    '{{owner.name}}',
  ];

  @override
  void initState() {
    super.initState();
    final template = widget.templateToEdit;
    _nameController = TextEditingController(text: template?.name ?? '');
    _subjectController = TextEditingController(text: template?.subject ?? '');
    _bodyController = TextEditingController(text: template?.body ?? '');

    if (template != null) {
      _selectedPrivacy = template.privacy;
      _selectedFolder = template.folder;
      _ownerName = template.owner;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    _contactSearchController.dispose();
    super.dispose();
  }

  void _insertVariableIntoSubject(String variable) {
    final text = _subjectController.text;
    final selection = _subjectController.selection;
    if (selection.isValid && selection.start >= 0) {
      final newText = text.replaceRange(selection.start, selection.end, variable);
      _subjectController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + variable.length),
      );
    } else {
      _subjectController.text = '$text $variable';
    }
    setState(() {});
  }

  void _insertVariableIntoBody(String variable) {
    final text = _bodyController.text;
    final selection = _bodyController.selection;
    if (selection.isValid && selection.start >= 0) {
      final newText = text.replaceRange(selection.start, selection.end, variable);
      _bodyController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + variable.length),
      );
    } else {
      _bodyController.text = '$text $variable';
    }
    setState(() {});
  }

  String _resolveVariables(String rawText) {
    if (_selectedPreviewContact == null) return rawText;
    final contact = _selectedPreviewContact!;
    return rawText
        .replaceAll('{{contact.first_name}}', contact['first_name'] ?? 'Contact')
        .replaceAll('{{contact.email}}', contact['email'] ?? 'contact@example.com')
        .replaceAll('{{company.name}}', contact['company'] ?? 'Company')
        .replaceAll('{{owner.name}}', _ownerName);
  }

  void _saveTemplate() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a template name.')),
      );
      return;
    }

    final newTemplate = EmailTemplateModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      subject: _subjectController.text.trim(),
      body: _bodyController.text.trim(),
      owner: _ownerName,
      folder: _selectedFolder,
      privacy: _selectedPrivacy,
      createdAt: '1 second ago',
    );

    Navigator.of(context).pop(newTemplate);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 1. Dark Teal Top Header (Image 2 & 3)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFF009688), // Cyan / Teal header as image 2 & 3
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.templateToEdit == null ? 'New template' : 'Edit template',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
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

          // 2. Tab Bar Row: Compose vs Live preview (Image 2 & 3)
          Container(
            color: const Color(0xFFF1F5F9),
            padding: const EdgeInsets.all(6),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedTab == 0 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: _selectedTab == 0
                            ? Border.all(color: const Color(0xFFCBD5E1))
                            : null,
                        boxShadow: _selectedTab == 0
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: _selectedTab == 0
                                ? const Color(0xFF009688)
                                : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Compose',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight:
                                  _selectedTab == 0 ? FontWeight.bold : FontWeight.w500,
                              color: _selectedTab == 0
                                  ? const Color(0xFF009688)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedTab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedTab == 1 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: _selectedTab == 1
                            ? Border.all(color: const Color(0xFFCBD5E1))
                            : null,
                        boxShadow: _selectedTab == 1
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.remove_red_eye_outlined,
                            size: 16,
                            color: _selectedTab == 1
                                ? const Color(0xFF009688)
                                : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Live preview',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight:
                                  _selectedTab == 1 ? FontWeight.bold : FontWeight.w500,
                              color: _selectedTab == 1
                                  ? const Color(0xFF009688)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Tab Body
          Expanded(
            child: _selectedTab == 0 ? _buildComposeView() : _buildLivePreviewView(),
          ),

          // 4. Bottom Footer Bar (Image 2 & 3)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveTemplate,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: const Color(0xFFFF7A59), // Coral / orange save button
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Save template',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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

  /// -------------------------------------------------------------
  /// COMPOSE TAB VIEW (Image 2)
  /// -------------------------------------------------------------
  Widget _buildComposeView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Meta Row: Private dropdown, Folder dropdown, Owner info
        Row(
          children: [
            // Private Dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFCBD5E1)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: DropdownButton<String>(
                value: _selectedPrivacy,
                underline: const SizedBox(),
                isDense: true,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF334155),
                ),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedPrivacy = val);
                },
                items: const ['Private', 'Shared']
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
              ),
            ),
            const SizedBox(width: 8),

            // Folder Dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFCBD5E1)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.folder_outlined, size: 15, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  DropdownButton<String>(
                    value: _selectedFolder,
                    underline: const SizedBox(),
                    isDense: true,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF334155),
                    ),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedFolder = val);
                    },
                    items: const ['Root', 'Sales', 'Follow-ups']
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Owner Display
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.person_outline, size: 15, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Owner: $_ownerName',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // TEMPLATE NAME Label & Field
        Text(
          'TEMPLATE NAME',
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: TextField(
            controller: _nameController,
            style: GoogleFonts.poppins(fontSize: 13.5, color: const Color(0xFF1E293B)),
            decoration: InputDecoration(
              hintText: 'e.g. Follow-up after introduction call',
              hintStyle: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF94A3B8)),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 14),

        // From Display Container (Image 2)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF475569)),
              children: [
                const TextSpan(text: 'From:   '),
                TextSpan(
                  text: '$_ownerName <dev@apideltech.com>',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // SUBJECT Label & Counter (Image 2)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'SUBJECT',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
            Text(
              '${_subjectController.text.length}/200',
              style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.only(left: 12, right: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _subjectController,
                  onChanged: (_) => setState(() {}),
                  style: GoogleFonts.poppins(fontSize: 13.5, color: const Color(0xFF1E293B)),
                  decoration: InputDecoration(
                    hintText: 'Enter email subject line',
                    hintStyle:
                        GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF94A3B8)),
                    border: InputBorder.none,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: _insertVariableIntoSubject,
                child: Row(
                  children: [
                    Text(
                      'Insert',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF475569),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF64748B)),
                  ],
                ),
                itemBuilder: (context) => _variables
                    .map((v) => PopupMenuItem(
                          value: v,
                          child: Text(v, style: GoogleFonts.poppins(fontSize: 12.5)),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // BODY Label (Image 2)
        Text(
          'BODY',
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),

        // Rich Text Formatting Box
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Column(
            children: [
              // Rich Text Toolbar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    _toolbarTextBtn('B', isActive: _isBold, bold: true, onTap: () {
                      setState(() => _isBold = !_isBold);
                    }),
                    _toolbarTextBtn('I', isActive: _isItalic, italic: true, onTap: () {
                      setState(() => _isItalic = !_isItalic);
                    }),
                    _toolbarTextBtn('U', isActive: _isUnderline, underline: true, onTap: () {
                      setState(() => _isUnderline = !_isUnderline);
                    }),
                    const SizedBox(width: 8),
                    _toolbarHeading('H1'),
                    _toolbarHeading('H2'),
                    _toolbarHeading('T'),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _applyFormatPrefix('• ', ''),
                      child: const Icon(Icons.format_list_bulleted, size: 16, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => _applyFormatPrefix('1. ', ''),
                      child: const Icon(Icons.format_list_numbered, size: 16, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.attach_file, size: 16, color: Color(0xFF64748B)),
                    const Spacer(),
                    InkWell(
                      onTap: () {
                        if (_bodyController.text.isNotEmpty) _bodyController.clear();
                      },
                      child: const Icon(Icons.undo, size: 16, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.redo, size: 16, color: Color(0xFF64748B)),
                  ],
                ),
              ),

              // Textarea
              Container(
                color: const Color(0xFFF8FAFC),
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _bodyController,
                  onChanged: (_) => setState(() {}),
                  maxLines: 7,
                  style: _getBodyStyle(),
                  decoration: InputDecoration(
                    hintText: 'Compose your email template here...',
                    hintStyle:
                        GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF94A3B8)),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Insert Variable & Insert Draft Buttons Row (Image 2)
        Row(
          children: [
            PopupMenuButton<String>(
              onSelected: _insertVariableIntoBody,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                  borderRadius: BorderRadius.circular(6),
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    Text(
                      'Insert variable',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF64748B)),
                  ],
                ),
              ),
              itemBuilder: (context) => _variables
                  .map((v) => PopupMenuItem(
                        value: v,
                        child: Text(v, style: GoogleFonts.poppins(fontSize: 12.5)),
                      ))
                  .toList(),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _bodyController.text =
                      'Hi {{contact.first_name}},\n\nThanks for connecting! Let us know if you have any questions.\n\nBest regards,\n{{owner.name}}';
                });
              },
              icon: const Icon(Icons.extension_outlined, size: 15, color: Color(0xFF9333EA)),
              label: Text(
                'Insert draft',
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF9333EA),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF3E8FF),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _toolbarTextBtn(
    String label, {
    bool isActive = false,
    bool bold = false,
    bool italic = false,
    bool underline = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            decoration: underline ? TextDecoration.underline : TextDecoration.none,
            color: isActive ? const Color(0xFF00A884) : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _toolbarHeading(String type) {
    final isSelected = _activeHeading == type;
    return InkWell(
      onTap: () => setState(() => _activeHeading = type),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFCCFBF1) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          type,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isSelected ? const Color(0xFF0F766E) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  /// -------------------------------------------------------------
  /// LIVE PREVIEW TAB VIEW (Image 3)
  /// -------------------------------------------------------------
  Widget _buildLivePreviewView() {
    final filteredContacts = _sampleContacts.where((c) {
      final q = _contactSearchQuery.toLowerCase();
      return (c['name']?.toLowerCase().contains(q) ?? false) ||
          (c['email']?.toLowerCase().contains(q) ?? false);
    }).toList();

    final subjectText = _subjectController.text.trim();
    final bodyText = _bodyController.text.trim();

    final resolvedSubject =
        subjectText.isEmpty ? '(No subject)' : _resolveVariables(subjectText);
    final resolvedBody =
        bodyText.isEmpty ? 'Start typing to log or draft...' : _resolveVariables(bodyText);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // PREVIEW Header & Hide preview toggle (Image 3)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'PREVIEW',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
            Row(
              children: [
                const Icon(Icons.visibility_off_outlined, size: 15, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(
                  'Hide preview',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // PREVIEW AS CONTACT Card (Image 3)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PREVIEW AS CONTACT',
                style: GoogleFonts.poppins(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _contactSearchController,
                        onChanged: (val) => setState(() => _contactSearchQuery = val),
                        style: GoogleFonts.poppins(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search contacts by name or email',
                          hintStyle: GoogleFonts.poppins(
                              fontSize: 12.5, color: const Color(0xFF94A3B8)),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Contact Selector list if searching
              if (_contactSearchQuery.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: filteredContacts.length,
                    itemBuilder: (context, index) {
                      final c = filteredContacts[index];
                      return ListTile(
                        dense: true,
                        title: Text(c['name']!, style: GoogleFonts.poppins(fontSize: 12.5)),
                        subtitle: Text(c['email']!, style: GoogleFonts.poppins(fontSize: 11)),
                        onTap: () {
                          setState(() {
                            _selectedPreviewContact = c;
                            _contactSearchQuery = '';
                            _contactSearchController.text = c['name']!;
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Live Mail Preview Display Box (Image 3)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'From: $_ownerName <dev@apideltech.com>',
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'To: ${_selectedPreviewContact != null ? '${_selectedPreviewContact!['name']} <${_selectedPreviewContact!['email']}>' : 'Select a contact to see resolved values'}',
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF009688),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Subject: $resolvedSubject',
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF334155),
                ),
              ),
              const Divider(height: 24, color: Color(0xFFF1F5F9)),
              Text(
                resolvedBody,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF334155),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
