import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/models/email_signature_model.dart';
import '../../../../core/repositories/master_data_repository.dart';
import '../../../../core/utils/signature_variable_resolver.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';

class CreateSignatureModal extends StatefulWidget {
  final EmailSignatureModel? signatureToEdit;
  final MasterDataRepository? repository;

  const CreateSignatureModal({super.key, this.signatureToEdit, this.repository});

  static Future<bool?> show(
    BuildContext context, {
    EmailSignatureModel? signatureToEdit,
    MasterDataRepository? repository,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateSignatureModal(
        signatureToEdit: signatureToEdit,
        repository: repository,
      ),
    );
  }

  @override
  State<CreateSignatureModal> createState() => _CreateSignatureModalState();
}

class _CreateSignatureModalState extends State<CreateSignatureModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bodyController = TextEditingController();

  bool _isDefault = false;
  bool _isSubmitting = false;
  bool _showPreview = true;

  /// The id of the signature being edited, captured once when the form opens so
  /// that nothing in the form lifecycle can drop it and turn a save into a
  /// create. `null` means the form is in create mode.
  String? _editingSignatureId;

  bool get _isEditing => _editingSignatureId != null;

  late final MasterDataRepository _repository = widget.repository ?? MasterDataRepositoryImpl();

  @override
  void initState() {
    super.initState();
    final editing = widget.signatureToEdit;
    if (editing != null) {
      final id = editing.id.trim();
      _editingSignatureId = id.isEmpty ? null : id;
      _nameController.text = editing.name;
      _bodyController.text = editing.body;
      _isDefault = editing.isDefault;

      if (_editingSignatureId == null) {
        debugPrint('[CreateSignatureModal]: opened to edit "${editing.name}" but the '
            'record carries no id, so it cannot be updated.');
      } else {
        debugPrint('[CreateSignatureModal]: EDIT mode for signature $_editingSignatureId');
      }
    } else {
      debugPrint('[CreateSignatureModal]: CREATE mode');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _insertVariable(String variable) {
    final text = _bodyController.text;
    final selection = _bodyController.selection;
    if (selection.isValid && selection.start >= 0) {
      final newText = text.replaceRange(selection.start, selection.end, variable);
      _bodyController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + variable.length),
      );
    } else {
      _bodyController.text = text + variable;
    }
    setState(() {});
  }

  void _applyFormat(String prefix, String suffix) {
    final text = _bodyController.text;
    final selection = _bodyController.selection;
    if (selection.isValid && selection.start >= 0) {
      final selectedText = text.substring(selection.start, selection.end);
      final newText = text.replaceRange(selection.start, selection.end, '$prefix$selectedText$suffix');
      _bodyController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + prefix.length + selectedText.length + suffix.length),
      );
    } else {
      _bodyController.text = '$text$prefix$suffix';
    }
    setState(() {});
  }

  Future<void> _submitSignature() async {
    final name = _nameController.text.trim();
    final body = _bodyController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Signature name is required',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Signature content is required',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // The form was opened on an existing signature but that record has no id,
    // so saving would silently add a duplicate instead of updating it.
    if (widget.signatureToEdit != null && !_isEditing) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This signature is missing its ID, so it cannot be updated. Please refresh the list and try again.',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    final isEditing = _isEditing;
    final payload = {
      'name': name,
      'body': body.contains('<') ? body : '<p>$body</p>',
      'isDefault': _isDefault,
    };

    try {
      if (isEditing) {
        debugPrint('[Signature Save]: UPDATE $_editingSignatureId payload=$payload');
        await _repository.updateEmailSignature(_editingSignatureId!, payload);
      } else {
        debugPrint('[Signature Save]: CREATE payload=$payload');
        await _repository.createEmailSignature(payload);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing ? 'Signature updated successfully.' : 'Signature created successfully.',
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          backgroundColor: const Color(0xFF00A884),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('[CreateSignatureModal Submit Error]: $e');
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing ? 'Failed to update signature. Please try again.' : 'Failed to create signature. Please try again.',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  String _renderPreviewBody(String rawBody, AuthProvider auth) {
    return SignatureVariableResolver.cleanPreviewText(rawBody, auth.currentUser);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 1. Teal Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFF00A884),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.signatureToEdit != null ? 'Edit signature' : 'New signature',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // 2. Form Body (Scrollable & Keyboard Safe)
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Signature Name
                  Text(
                    'SIGNATURE NAME',
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF475569),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    style: GoogleFonts.poppins(fontSize: 13.5, color: const Color(0xFF1E293B)),
                    decoration: InputDecoration(
                      hintText: 'e.g. New business, with photo',
                      hintStyle: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF94A3B8)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF00A884), width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Only you see this name. It is how you will pick this signature when writing an email.',
                    style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 20),

                  // Signature Content
                  Text(
                    'SIGNATURE CONTENT',
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF475569),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Rich Formatting Toolbar
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Text('B', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            onPressed: () => _applyFormat('<strong>', '</strong>'),
                            tooltip: 'Bold',
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            padding: EdgeInsets.zero,
                          ),
                          IconButton(
                            icon: const Text('I', style: TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.bold, fontSize: 15)),
                            onPressed: () => _applyFormat('<em>', '</em>'),
                            tooltip: 'Italic',
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            padding: EdgeInsets.zero,
                          ),
                          IconButton(
                            icon: const Text('U', style: TextStyle(decoration: TextDecoration.underline, fontWeight: FontWeight.bold, fontSize: 15)),
                            onPressed: () => _applyFormat('<u>', '</u>'),
                            tooltip: 'Underline',
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            padding: EdgeInsets.zero,
                          ),
                          const SizedBox(width: 4),
                          const SizedBox(height: 20, child: VerticalDivider(width: 1, color: Color(0xFFCBD5E1))),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => _applyFormat('<h1>', '</h1>'),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: Text('H1', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
                            ),
                          ),
                          InkWell(
                            onTap: () => _applyFormat('<h2>', '</h2>'),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: Text('H2', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const SizedBox(height: 20, child: VerticalDivider(width: 1, color: Color(0xFFCBD5E1))),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.format_list_bulleted_rounded, size: 18, color: Color(0xFF334155)),
                            onPressed: () => _applyFormat('<ul><li>', '</li></ul>'),
                            tooltip: 'Bullet List',
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            padding: EdgeInsets.zero,
                          ),
                          IconButton(
                            icon: const Icon(Icons.format_list_numbered_rounded, size: 18, color: Color(0xFF334155)),
                            onPressed: () => _applyFormat('<ol><li>', '</li></ol>'),
                            tooltip: 'Numbered List',
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            padding: EdgeInsets.zero,
                          ),
                          IconButton(
                            icon: const Icon(Icons.image_outlined, size: 18, color: Color(0xFF334155)),
                            onPressed: () => _insertVariable('<img src="logo.png" alt="logo"/>'),
                            tooltip: 'Insert Image',
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Textarea Input
                  TextFormField(
                    controller: _bodyController,
                    maxLines: 5,
                    onChanged: (_) => setState(() {}),
                    style: GoogleFonts.poppins(fontSize: 13.5, color: const Color(0xFF1E293B)),
                    decoration: InputDecoration(
                      hintText: 'Add your name, job title, phone number, a photo or a logo...',
                      hintStyle: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF94A3B8)),
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
                        borderSide: BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
                        borderSide: BorderSide(color: Color(0xFF00A884), width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Variable inserter & Default checkbox row
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      PopupMenuButton<String>(
                        onSelected: _insertVariable,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        itemBuilder: (ctx) => SignatureVariableResolver.menuItems.map((item) {
                          return PopupMenuItem<String>(
                            value: item['value'],
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item['label']!,
                                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  item['value']!,
                                  style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Insert variable',
                                style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w500, color: const Color(0xFF334155)),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                            ],
                          ),
                        ),
                      ),

                      InkWell(
                        onTap: () => setState(() => _isDefault = !_isDefault),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: _isDefault,
                              onChanged: (val) => setState(() => _isDefault = val ?? false),
                              activeColor: const Color(0xFF00A884),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              'Use this signature by default',
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF334155)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // PREVIEW Panel
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'PREVIEW',
                              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569), letterSpacing: 0.5),
                            ),
                            InkWell(
                              onTap: () => setState(() => _showPreview = !_showPreview),
                              child: Row(
                                children: [
                                  Icon(_showPreview ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 14, color: const Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    _showPreview ? 'Hide' : 'Show',
                                    style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_showPreview) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'This is how the signature appears at the bottom of your emails, with your own details filled in.',
                                  style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
                                ),
                                if (_bodyController.text.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                  const SizedBox(height: 12),
                                  Text(
                                    _renderPreviewBody(_bodyController.text, authProvider),
                                    style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'The company confidentiality notice is added below your signature on every email and is not part of it.',
                            style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Footer Action Buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Variables use double braces, e.g. {{sender.fullName}}. Add photos and logos with the image button - they are stored when you save.',
                  style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF475569),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      child: Text('Cancel', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitSignature,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF7A59),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text('Save signature', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
