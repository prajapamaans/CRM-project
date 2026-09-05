import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/datasources/master_data_remote_datasource.dart';
import '../../../../core/models/email_signature_model.dart';
import '../../../../core/models/email_template_models.dart';
import '../../../../core/network/network_exception.dart';
import '../../../../core/repositories/master_data_repository.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../widgets/create_signature_modal.dart';
import '../widgets/create_template_modal.dart';

import '../../../../core/utils/department_aware_state.dart';
import '../../../../core/utils/signature_variable_resolver.dart';

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> with DepartmentAwareState {
  final MasterDataRepository _repository = MasterDataRepositoryImpl();

  int _selectedSubTabIndex = 0; // 0 = Templates, 1 = Signatures

  List<EmailTemplateFolder> _allFolders = [];
  List<EmailTemplate> _allTemplates = [];

  List<EmailSignatureModel> _allSignatures = [];
  bool _isLoadingSignatures = false;
  String _signatureSearchQuery = '';

  String? _selectedFolderId; // null = Root level
  String _selectedFolderName = 'Root';

  String _selectedOwner = 'Any';
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTemplatesFromApi();
    _loadSignaturesFromApi();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AuthProvider>().fetchTeamMembers();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    watchDepartmentChanges(
      (_) => _loadTemplatesFromApi(),
      // Wiped as soon as the switch starts, so the department being left does
      // not stay on screen while its access token is swapped. The open folder
      // goes with it: a folder id belongs to one department, and keeping it
      // would leave the new one's templates hidden behind a folder that does
      // not exist there.
      onSwitchStarted: () {
        if (!mounted) return;
        setState(() {
          _allFolders.clear();
          _allTemplates.clear();
          _selectedFolderId = null;
          _selectedFolderName = 'Root';
        });
      },
    );
  }

  Future<void> _loadSignaturesFromApi() async {
    try {
      setState(() {
        _isLoadingSignatures = true;
      });
      final sigs = await _repository.getEmailSignatures();
      if (mounted) {
        setState(() {
          _allSignatures = sigs;
          _isLoadingSignatures = false;
        });
      }
    } catch (e) {
      debugPrint('[TemplatesScreen signatures load error]: $e');
      if (mounted) {
        setState(() {
          _isLoadingSignatures = false;
        });
      }
    }
  }

  void _createNewSignature() async {
    final result = await CreateSignatureModal.show(context);
    if (result == true) {
      _loadSignaturesFromApi();
    }
  }

  Future<void> _loadTemplatesFromApi() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final deptId = currentDepartmentId();
      final response = await _repository.getEmailTemplatesFull(departmentId: deptId);

      debugPrint(
        '[GET /api/email-templates/list SUCCESS (deptId=$deptId)]: success=${response.success}, folders=${response.folders.length}, templates=${response.templates.length}',
      );

      if (mounted) {
        setState(() {
          _allFolders = response.folders;
          _allTemplates = response.templates;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[TemplatesScreen API load error]: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load message templates from server.';
        });
      }
    }
  }

  /// What the server said about a rejected save, so the message names the real
  /// problem instead of asking the user to try the same thing again.
  String _saveFailureReason(Object error) {
    if (error is NetworkException) {
      final reason = error.message.trim();
      if (reason.isNotEmpty) {
        return error.statusCode == null ? reason : '$reason (${error.statusCode})';
      }
    }
    return 'Please try again.';
  }

  void _navigateToFolder(String? folderId, String folderName) {
    setState(() {
      _selectedFolderId = folderId;
      _selectedFolderName = folderName;
    });
  }

  List<EmailTemplateFolder> _getBreadcrumbPath() {
    final List<EmailTemplateFolder> path = [];
    String? currentId = _selectedFolderId;

    while (currentId != null && currentId.isNotEmpty && currentId != 'null') {
      final matches = _allFolders.where((f) => f.id == currentId).toList();
      if (matches.isNotEmpty) {
        final folder = matches.first;
        path.insert(0, folder);
        currentId = folder.parentId;
      } else {
        break;
      }
    }
    return path;
  }

  void _createNewTemplate() async {
    final newTemplateModel = await CreateTemplateModal.show(
      context,
      initialFolderId: _selectedFolderId,
    );
    if (newTemplateModel != null) {
      final targetFolderId = newTemplateModel.folderId ?? _selectedFolderId;
      final createdTemplate = EmailTemplate(
        id: newTemplateModel.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: newTemplateModel.name,
        subject: newTemplateModel.subject,
        body: newTemplateModel.body,
        sharedSetting:
            newTemplateModel.privacy.toLowerCase() == 'shared' ? 'shared' : 'private',
        folderId: targetFolderId,
        ownerName: newTemplateModel.owner,
        createdAt: 'Just now',
      );

      // Shown straight away, but only until the API answers — the reload below
      // replaces it with whatever the backend actually holds.
      setState(() {
        _allTemplates.insert(0, createdTemplate);
      });

      try {
        final ds = MasterDataRemoteDataSourceImpl();
        final deptId = currentDepartmentId();
        await ds.createEmailTemplate({
          'name': newTemplateModel.name,
          'subject': newTemplateModel.subject,
          'body': newTemplateModel.body.isNotEmpty ? newTemplateModel.body : '<p></p>',
          'sharedSetting':
              newTemplateModel.privacy.toLowerCase() == 'shared' ? 'shared' : 'private',
          'folderId': targetFolderId,
          'departmentId': deptId,
          'department_id': deptId,
        });
      } catch (e) {
        // The save failed, so the row that was added optimistically is taken
        // back out. Reporting success here is what made a template look saved
        // until the next reload dropped it.
        debugPrint('[TemplatesScreen create template API error]: $e');
        if (!mounted) return;
        setState(() {
          _allTemplates.removeWhere((t) => identical(t, createdTemplate));
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save template "${newTemplateModel.name}". ${_saveFailureReason(e)}'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
        return;
      }

      await _loadTemplatesFromApi();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Template "${newTemplateModel.name}" created successfully!'),
          backgroundColor: const Color(0xFF00A884),
        ),
      );
    }
  }

  void _editTemplate(EmailTemplate template) async {
    final templateModel = EmailTemplateModel(
      id: template.id,
      name: template.name,
      subject: template.subject,
      body: template.body,
      owner: template.ownerName,
      folder: _selectedFolderName,
      folderId: template.folderId,
      privacy: template.sharedSetting.toLowerCase() == 'shared' ? 'Shared' : 'Private',
      createdAt: template.createdAt ?? 'Just now',
    );

    final updatedTemplateModel = await CreateTemplateModal.show(
      context,
      templateToEdit: templateModel,
    );

    if (updatedTemplateModel != null) {
      final targetId = updatedTemplateModel.id ?? template.id;
      if (targetId != null && targetId.isNotEmpty) {
        try {
          final ds = MasterDataRemoteDataSourceImpl();
          final deptId = currentDepartmentId();
          await ds.updateEmailTemplate(targetId, {
            'name': updatedTemplateModel.name,
            'subject': updatedTemplateModel.subject,
            'body': updatedTemplateModel.body.isNotEmpty
                ? updatedTemplateModel.body
                : '<p></p>',
            'sharedSetting':
                updatedTemplateModel.privacy.toLowerCase() == 'shared'
                    ? 'shared'
                    : 'private',
            'folderId': template.folderId,
            'departmentId': deptId,
            'department_id': deptId,
          });
          await _loadTemplatesFromApi();
        } catch (e) {
          // Same as create: a failed save must not be reported as a success.
          debugPrint('[TemplatesScreen update template API error]: $e');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not save changes to "${updatedTemplateModel.name}". ${_saveFailureReason(e)}'),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Template "${updatedTemplateModel.name}" updated successfully!'),
            backgroundColor: const Color(0xFF00A884),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showNewFolderDialog() {
    final folderController = TextEditingController();
    // Taken before the dialog opens: the dialog's own context is gone by the
    // time the save answers, so the failure message has nowhere to go.
    final messenger = ScaffoldMessenger.of(context);
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
            onPressed: () async {
              final name = folderController.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(context).pop();
                try {
                  final ds = MasterDataRemoteDataSourceImpl();
                  final deptId = currentDepartmentId();
                  await ds.createEmailTemplateFolder({
                    'name': name,
                    'parentId': _selectedFolderId,
                    'departmentId': deptId,
                    'department_id': deptId,
                  });
                  await _loadTemplatesFromApi();
                } catch (e) {
                  // A folder that was not created must say so, rather than
                  // leaving the user looking for one that never existed.
                  debugPrint('[Create folder error]: $e');
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Could not create folder "$name". ${_saveFailureReason(e)}'),
                      backgroundColor: const Color(0xFFEF4444),
                    ),
                  );
                }
              }
            },
            child: Text('Create',
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _cleanHtml(String html) {
    final clean = html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .trim();
    return clean.isNotEmpty ? clean : html;
  }

  @override
  Widget build(BuildContext context) {
    // 1. Current level child folders (parentId == selectedFolderId)
    final currentFolders = _allFolders.where((f) {
      if (_selectedFolderId == null) {
        return f.parentId == null || f.parentId == 'null' || f.parentId == '';
      } else {
        return f.parentId == _selectedFolderId;
      }
    }).toList();

    // 2. Current level templates (folderId == selectedFolderId or folderId == selectedFolderName)
    final currentTemplates = _allTemplates.where((t) {
      final matchesFolder = (_selectedFolderId == null)
          ? (t.folderId == null ||
              t.folderId == 'null' ||
              t.folderId == '' ||
              t.folderId == 'Root')
          : (t.folderId == _selectedFolderId ||
              t.folderId == _selectedFolderName);
      final matchesOwner =
          _selectedOwner == 'Any' || t.ownerName == _selectedOwner;
      final q = _searchQuery.toLowerCase();
      final matchesSearch = _searchQuery.isEmpty ||
          t.name.toLowerCase().contains(q) ||
          t.subject.toLowerCase().contains(q);
      return matchesFolder && matchesOwner && matchesSearch;
    }).toList();

    final authProvider = context.watch<AuthProvider>();
    final teamMembers = authProvider.teamMembers;

    final fetchedUsers = <String>{};
    if (authProvider.currentUser != null) {
      final name = authProvider.currentUser!.fullName.isNotEmpty
          ? authProvider.currentUser!.fullName
          : 'Admin User';
      fetchedUsers.add(name);
    }
    for (var member in teamMembers) {
      if (member.fullName.isNotEmpty) {
        fetchedUsers.add(member.fullName);
      }
    }
    for (var template in _allTemplates) {
      if (template.ownerName.isNotEmpty) {
        fetchedUsers.add(template.ownerName);
      }
    }

    final ownersList = ['Any', ...fetchedUsers];
    final breadcrumbPath = _getBreadcrumbPath();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadTemplatesFromApi,
          color: const Color(0xFFFF7A59),
          child: ListView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // 1. Sub-Navigation Tabs: Templates | Signatures (matching screenshot 1)
              Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _selectedSubTabIndex = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: _selectedSubTabIndex == 0 ? const Color(0xFF00A884) : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.email_outlined,
                              size: 18,
                              color: _selectedSubTabIndex == 0 ? const Color(0xFF00A884) : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Templates',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: _selectedSubTabIndex == 0 ? FontWeight.bold : FontWeight.w500,
                                color: _selectedSubTabIndex == 0 ? const Color(0xFF00A884) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        setState(() => _selectedSubTabIndex = 1);
                        _loadSignaturesFromApi();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: _selectedSubTabIndex == 1 ? const Color(0xFF00A884) : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: _selectedSubTabIndex == 1 ? const Color(0xFF00A884) : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Signatures',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: _selectedSubTabIndex == 1 ? FontWeight.bold : FontWeight.w500,
                                color: _selectedSubTabIndex == 1 ? const Color(0xFF00A884) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_selectedSubTabIndex == 1) ...[
                // SIGNATURES TAB CONTENT
                _buildSignaturesView(context),
              ] else ...[
                // TEMPLATES TAB CONTENT
                // 2. Title Header & New Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Message templates',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E293B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${currentTemplates.length} template${currentTemplates.length == 1 ? '' : 's'} in this folder',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _showNewFolderDialog,
                          icon: const Icon(Icons.create_new_folder_outlined, size: 16, color: Color(0xFF475569)),
                          label: Text(
                            'Folder',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton.icon(
                          onPressed: _createNewTemplate,
                          icon: const Icon(Icons.add, size: 16, color: Colors.white),
                          label: Text(
                            'New',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF7A59),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

              // 3. Dynamic Breadcrumb Card (Root > Folder > Subfolder)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => _navigateToFolder(null, 'Root'),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.home_outlined,
                                size: 18, color: Color(0xFF009688)),
                            const SizedBox(width: 6),
                            Text(
                              'Root',
                              style: GoogleFonts.poppins(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF009688),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...breadcrumbPath.map((folder) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '  >  ',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                            InkWell(
                              onTap: () =>
                                  _navigateToFolder(folder.id, folder.name),
                              child: Text(
                                folder.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF009688),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 4. Search and Filter Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search,
                              size: 18, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              onChanged: (val) =>
                                  setState(() => _searchQuery = val),
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 2),
                            decoration: BoxDecoration(
                              border:
                                  Border.all(color: const Color(0xFFCBD5E1)),
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
                                if (val != null) {
                                  setState(() => _selectedOwner = val);
                                }
                              },
                              items: ownersList
                                  .map((o) => DropdownMenuItem(
                                      value: o, child: Text(o)))
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

              // 5. Template & Folder List / Loading / Error / Empty View
              if (_isLoading)
                Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFFFF7A59)),
                    ),
                  ),
                )
              else if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 36, color: Color(0xFFEF4444)),
                      const SizedBox(height: 10),
                      Text(
                        _errorMessage!,
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF475569),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: _loadTemplatesFromApi,
                        icon: const Icon(Icons.refresh_rounded,
                            size: 16, color: Colors.white),
                        label: Text(
                          'Retry',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF7A59),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ],
                  ),
                )
              else if (currentFolders.isEmpty && currentTemplates.isEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.folder_outlined,
                          size: 32,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'This folder is empty',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Create a template here, or add a subfolder to organise your content.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton(
                        onPressed: _createNewTemplate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF7A59),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Text(
                          'New template',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  constraints: const BoxConstraints(minHeight: 180),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      // 5a. Current Level Child Folders
                      if (currentFolders.isNotEmpty)
                        ...currentFolders.map((folder) {
                          return InkWell(
                            onTap: () =>
                                _navigateToFolder(folder.id, folder.name),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 4),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.folder_outlined,
                                    color: Color(0xFF009688),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          folder.name,
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF009688),
                                          ),
                                        ),
                                        Text(
                                          'Folder · ${folder.ownerName ?? 'Admin User'}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11.5,
                                            color: const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Color(0xFFCBD5E1),
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),

                      if (currentFolders.isNotEmpty &&
                          currentTemplates.isNotEmpty)
                        const Divider(height: 20, color: Color(0xFFE2E8F0)),

                      // 5b. Current Level Templates
                      if (currentTemplates.isNotEmpty)
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: currentTemplates.length,
                          separatorBuilder: (_, __) => const Divider(
                              height: 16, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, index) {
                            final item = currentTemplates[index];
                            final cleanBodyText = _cleanHtml(item.body);

                            return InkWell(
                              onTap: () => _editTemplate(item),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 4, horizontal: 4),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF1F0),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.email_outlined,
                                        color: Color(0xFFFF7A59),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                            item.subject.isNotEmpty
                                                ? item.subject
                                                : cleanBodyText,
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: const Color(0xFF64748B),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${item.ownerName} · ${item.sharedSetting}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              color: const Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
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
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignaturesView(BuildContext context) {
    final filteredSignatures = _allSignatures.where((s) {
      final q = _signatureSearchQuery.toLowerCase();
      return q.isEmpty || s.name.toLowerCase().contains(q) || s.body.toLowerCase().contains(q);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title Header & New Signature Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Email signatures',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Signatures are yours alone - nobody else can see or send with them.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _createNewSignature,
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
                backgroundColor: const Color(0xFFFF7A59),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Search Bar
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            onChanged: (val) => setState(() => _signatureSearchQuery = val),
            style: GoogleFonts.poppins(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search signatures',
              hintStyle: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        const SizedBox(height: 20),

        if (_isLoadingSignatures)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: Color(0xFFFF7A59)),
            ),
          )
        else if (filteredSignatures.isEmpty) ...[
          // Empty State Matching Screenshot 1
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.edit_outlined,
                    size: 32,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No email signatures yet',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Build a sign-off with your name, job title, phone number, a photo or a logo, then pick it when you write an email. You can keep as many as you like.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    color: const Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _createNewSignature,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7A59),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Create your first signature',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          // Signature List Cards
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredSignatures.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final sig = filteredSignatures[index];
              final currentUser = context.watch<AuthProvider>().currentUser;
              final cleanText = SignatureVariableResolver.cleanPreviewText(sig.body, currentUser);

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: sig.isDefault ? const Color(0xFF00A884) : const Color(0xFFE2E8F0),
                    width: sig.isDefault ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              sig.name,
                              style: GoogleFonts.poppins(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            if (sig.isDefault) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE6F4F1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFF00A884).withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded, size: 12, color: Color(0xFF00A884)),
                                    const SizedBox(width: 2),
                                    Text(
                                      'Default',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF00A884),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!sig.isDefault)
                              IconButton(
                                icon: const Icon(Icons.star_outline_rounded, color: Color(0xFF94A3B8), size: 20),
                                tooltip: 'Make default',
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                onPressed: () async {
                                  try {
                                    await _repository.updateEmailSignature(sig.id, {
                                      'id': sig.id,
                                      'name': sig.name,
                                      'body': sig.body,
                                      'isDefault': true,
                                    });
                                  } catch (e) {
                                    debugPrint('[Make default error]: $e');
                                  }
                                  _loadSignaturesFromApi();
                                },
                              ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Color(0xFF94A3B8), size: 20),
                              tooltip: 'Edit signature',
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                              onPressed: () async {
                                final result = await CreateSignatureModal.show(context, signatureToEdit: sig);
                                if (result == true) {
                                  _loadSignaturesFromApi();
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF94A3B8), size: 20),
                              tooltip: 'Delete signature',
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete Signature'),
                                    content: Text('Are you sure you want to delete signature "${sig.name}"?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                        child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  await _repository.deleteEmailSignature(sig.id);
                                  _loadSignaturesFromApi();
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Updated 2 hours ago',
                      style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      cleanText.isNotEmpty ? cleanText : '(No signature content)',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF334155),
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
