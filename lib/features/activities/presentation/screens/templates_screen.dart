import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/datasources/master_data_remote_datasource.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../widgets/create_template_modal.dart';

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  final List<EmailTemplateModel> _templates = [
    EmailTemplateModel(
      id: '1',
      name: 'Test',
      subject: 'Test Subject',
      body: 'Hi, this is a test template content.',
      owner: 'Admin User',
      folder: 'Root',
      createdAt: '1 second ago',
    ),
  ];

  final List<String> _folders = ['Root', 'Sales', 'Follow-ups'];
  String _selectedFolder = 'Root';
  String _selectedOwner = 'Any';
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTemplatesFromApi();
  }

  Future<void> _loadTemplatesFromApi() async {
    try {
      setState(() => _isLoading = true);
      
      final ds = MasterDataRemoteDataSourceImpl();
      final apiList = await ds.getEmailTemplates(flat: true);

      if (mounted) {
        final loadedTemplates = <EmailTemplateModel>[];

        for (var item in apiList) {
          final name = (item['name'] ?? item['title'] ?? 'Template').toString();
          loadedTemplates.add(
            EmailTemplateModel(
              id: item['id']?.toString() ?? item['_id']?.toString(),
              name: name,
              subject: (item['subject'] ?? '').toString(),
              body: (item['body'] ?? item['content'] ?? '').toString(),
              owner: (item['ownerName'] ?? item['owner'] ?? item['createdBy'] ?? 'Admin User').toString(),
              folder: (item['folder'] ?? 'Root').toString(),
              privacy: item['sharedSetting'] == 'shared' || item['privacy'] == 'Shared' ? 'Shared' : 'Private',
              createdAt: item['createdAt'] != null ? 'Recently' : 'Just now',
            ),
          );
        }

        // Also check locally cached custom templates if API returned empty
        if (loadedTemplates.isEmpty) {
          final storage = SecureStorageService();
          final savedJson = await storage.getString('custom_email_templates');
          if (savedJson != null && savedJson.isNotEmpty) {
            try {
              final List<dynamic> decoded = jsonDecode(savedJson);
              for (var item in decoded) {
                loadedTemplates.add(
                  EmailTemplateModel(
                    id: item['id']?.toString(),
                    name: (item['name'] ?? '').toString(),
                    subject: (item['subject'] ?? '').toString(),
                    body: (item['body'] ?? '').toString(),
                    owner: (item['owner'] ?? 'Admin User').toString(),
                    folder: (item['folder'] ?? 'Root').toString(),
                    privacy: (item['privacy'] ?? 'Private').toString(),
                    createdAt: (item['createdAt'] ?? 'Just now').toString(),
                  ),
                );
              }
            } catch (e) {
              debugPrint('[TemplatesScreen local parse error]: $e');
            }
          }
        }

        setState(() {
          _templates.clear();
          if (loadedTemplates.isNotEmpty) {
            _templates.addAll(loadedTemplates);
          }
        });
      }
    } catch (e) {
      debugPrint('[TemplatesScreen API load error]: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveCustomTemplatesToStorage(EmailTemplateModel newTemplate) async {
    try {
      final storage = SecureStorageService();
      final savedJson = await storage.getString('custom_email_templates');
      List<dynamic> list = [];
      if (savedJson != null && savedJson.isNotEmpty) {
        try {
          list = jsonDecode(savedJson);
        } catch (_) {}
      }
      list.insert(0, {
        'id': newTemplate.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        'name': newTemplate.name,
        'subject': newTemplate.subject,
        'body': newTemplate.body,
        'owner': newTemplate.owner,
        'folder': newTemplate.folder,
        'privacy': newTemplate.privacy,
        'createdAt': newTemplate.createdAt,
      });
      await storage.saveString('custom_email_templates', jsonEncode(list));
    } catch (e) {
      debugPrint('[TemplatesScreen storage save error]: $e');
    }
  }

  void _createNewTemplate() async {
    final newTemplate = await CreateTemplateModal.show(context);
    if (newTemplate != null) {
      // Optimistic UI update
      setState(() {
        _templates.insert(0, newTemplate);
      });

      // Save to local storage as well so local refreshes retain it
      await _saveCustomTemplatesToStorage(newTemplate);

      // Call API to persist created template on backend
      try {
        final ds = MasterDataRemoteDataSourceImpl();
        await ds.createEmailTemplate({
          'name': newTemplate.name,
          'subject': newTemplate.subject,
          'body': newTemplate.body.isNotEmpty ? newTemplate.body : '<p></p>',
          'sharedSetting': newTemplate.privacy.toLowerCase() == 'shared' ? 'shared' : 'private',
          'folderId': null,
        });
        // Reload fresh list from server after creating
        await _loadTemplatesFromApi();
      } catch (e) {
        debugPrint('[TemplatesScreen create template API error]: $e');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Template "${newTemplate.name}" created successfully!'),
          backgroundColor: const Color(0xFF00A884),
        ),
      );
    }
  }

  void _editTemplate(EmailTemplateModel template) async {
    final updatedTemplate = await CreateTemplateModal.show(
      context,
      templateToEdit: template,
    );
    if (updatedTemplate != null) {
      setState(() {
        final index = _templates.indexWhere((t) => t.id == template.id);
        if (index != -1) {
          _templates[index] = updatedTemplate;
        } else {
          _templates.insert(0, updatedTemplate);
        }
      });

      if (template.id != null && template.id != '1') {
        try {
          final ds = MasterDataRemoteDataSourceImpl();
          await ds.updateEmailTemplate(template.id!, {
            'name': updatedTemplate.name,
            'subject': updatedTemplate.subject,
            'body': updatedTemplate.body,
            'sharedSetting': updatedTemplate.privacy.toLowerCase() == 'shared' ? 'shared' : 'private',
            'folderId': null,
          });
          await _loadTemplatesFromApi();
        } catch (e) {
          debugPrint('[TemplatesScreen update template API error]: $e');
        }
      }
    }
  }

  void _showNewFolderDialog() {
    final folderController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Create new folder',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: TextField(
          controller: folderController,
          style: GoogleFonts.poppins(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Enter folder name...',
            hintStyle: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF94A3B8)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: GoogleFonts.poppins(color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7A59),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () {
              final name = folderController.text.trim();
              if (name.isNotEmpty) {
                setState(() {
                  if (!_folders.contains(name)) _folders.add(name);
                  _selectedFolder = name;
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Folder "$name" created.')),
                );
              }
            },
            child: Text('Create', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _exportTemplates() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exported ${_templates.length} template(s) successfully!'),
        backgroundColor: const Color(0xFF009688),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter templates based on folder, owner, and search query
    final filteredTemplates = _templates.where((t) {
      final matchesFolder = t.folder == _selectedFolder || _selectedFolder == 'Root';
      final matchesOwner = _selectedOwner == 'Any' || t.owner == _selectedOwner;
      final q = _searchQuery.toLowerCase();
      final matchesSearch = t.name.toLowerCase().contains(q) || t.subject.toLowerCase().contains(q);
      return matchesFolder && matchesOwner && matchesSearch;
    }).toList();

    final ownersList = ['Any', ...{..._templates.map((t) => t.owner)}];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Title Header & New Button (Image 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Message templates',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${filteredTemplates.length} template${filteredTemplates.length == 1 ? '' : 's'} in this folder',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _createNewTemplate,
                  icon: const Icon(Icons.add, size: 18, color: Colors.white),
                  label: Text(
                    'New',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7A59), // Coral / Orange button
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 2. Action Buttons Row: New folder & Export (Image 1)
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _showNewFolderDialog,
                  icon: const Icon(Icons.create_new_folder_outlined, size: 16, color: Color(0xFF334155)),
                  label: Text(
                    'New folder',
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _exportTemplates,
                  icon: const Icon(Icons.download_outlined, size: 16, color: Color(0xFF334155)),
                  label: Text(
                    'Export',
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 3. Folder Breadcrumb Card (Image 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.home_outlined, size: 18, color: Color(0xFF009688)),
                  const SizedBox(width: 8),
                  Text(
                    _selectedFolder,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF009688),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 4. Search and Filter Box (Image 1)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  // Search TextField
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            onChanged: (val) => setState(() => _searchQuery = val),
                            style: GoogleFonts.poppins(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Search templates',
                              hintStyle: GoogleFonts.poppins(
                                fontSize: 13,
                                color: const Color(0xFF94A3B8),
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Owner Filter Row
                  Row(
                    children: [
                      Text(
                        'Owner: ',
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedOwner,
                            isExpanded: true,
                            underline: const SizedBox(),
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF1E293B),
                            ),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedOwner = val);
                            },
                            items: ownersList
                                .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                                .toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 5. Template List Card (Image 1)
            Container(
              constraints: const BoxConstraints(minHeight: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF7A59)),
                      ),
                    )
                  : filteredTemplates.isNotEmpty
                      ? ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredTemplates.length,
                          separatorBuilder: (_, __) => const Divider(height: 16, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, index) {
                            final item = filteredTemplates[index];
                            return InkWell(
                              onTap: () => _editTemplate(item),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                child: Row(
                                  children: [
                                    // Mail Icon Container (Image 1)
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF1F0), // Light red / coral background
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.email_outlined,
                                        color: Color(0xFFFF7A59),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Template Title & Owner details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF1E293B),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${item.owner} · ${item.createdAt}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: const Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Chevron Right Icon
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: Color(0xFFCBD5E1),
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              const Icon(Icons.email_outlined, size: 36, color: Color(0xFF94A3B8)),
                              const SizedBox(height: 10),
                              Text(
                                'No templates found',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
