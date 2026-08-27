import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:crmproject/core/widgets/app_refresh_indicator.dart';
import '../../../../core/providers/master_data_provider.dart';
import '../../../../core/widgets/contact_tile.dart';
import '../../../../core/widgets/search_and_filter_bar.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../departments/presentation/providers/department_provider.dart';
import '../providers/contact_provider.dart';
import '../widgets/contact_inline_filter_section.dart';
import '../widgets/create_contact_modal.dart';
import 'contact_details_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  int _selectedSegment = 0; // 0 for All, 1 for Mine
  bool _isFilterExpanded = true;
  final Set<String> _selectedContactIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final deptId = context.read<DepartmentProvider>().selectedDepartmentId;
      context.read<MasterDataProvider>().fetchAllMasterData(departmentId: deptId);
      _loadContactsForSegment(_selectedSegment);
    });
  }

  void _loadContactsForSegment(int segmentIndex) {
    setState(() {
      _selectedContactIds.clear();
    });
    final auth = context.read<AuthProvider>();
    final currentUserId = auth.currentUser?.id;
    final deptId = context.read<DepartmentProvider>().selectedDepartmentId;

    if (segmentIndex == 1) {
      context.read<ContactProvider>().fetchContacts(
            search: _searchQuery,
            ownerId: currentUserId,
            departmentId: deptId,
            ignorePermissions: false,
          );
    } else {
      context.read<ContactProvider>().fetchContacts(
            search: _searchQuery,
            ownerId: null,
            departmentId: deptId,
            ignorePermissions: true,
          );
    }
  }

  Future<void> _confirmDeleteSelectedContacts() async {
    if (_selectedContactIds.isEmpty) return;
    final count = _selectedContactIds.length;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Contact${count > 1 ? 's' : ''}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete $count selected contact${count > 1 ? 's' : ''}? This action cannot be undone.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final provider = context.read<ContactProvider>();
    final idsToDelete = List<String>.from(_selectedContactIds);

    for (final id in idsToDelete) {
      await provider.deleteContact(id);
    }

    if (mounted) {
      setState(() {
        _selectedContactIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count contact${count > 1 ? 's' : ''} deleted successfully!', style: GoogleFonts.poppins()),
          backgroundColor: const Color(0xFF00A884),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _loadContactsForSegment(_selectedSegment);
  }

  void _onSegmentChanged(int index) {
    setState(() {
      _selectedSegment = index;
    });
    _loadContactsForSegment(index);
  }

  String _formatCount(int number) {
    final str = number.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (Match m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    final contactProvider = context.watch<ContactProvider>();
    final contacts = contactProvider.contacts;
    final totalCount = contactProvider.totalCount;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Top Search and 3-Dot Filter Bar Section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  SearchAndFilterBar(
                    searchHint: 'Search contacts...',
                    onSearchChanged: _onSearchChanged,
                    onSegmentChanged: _onSegmentChanged,
                    currentSort: contactProvider.sortOption,
                    onSortChanged: (ContactSortOption option) {
                      context.read<ContactProvider>().setSortOption(option);
                    },
                    isFilterActive: contactProvider.isFilterActive,
                    isFilterExpanded: _isFilterExpanded,
                    onToggleFilterExpanded: () {
                      setState(() {
                        _isFilterExpanded = !_isFilterExpanded;
                      });
                    },
                    onRefreshTap: () {
                      context.read<ContactProvider>().fetchContacts();
                    },
                    onImportTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Import contacts feature coming soon',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    onExportTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Exporting ${contacts.length} contacts...',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          backgroundColor: const Color(0xFF00A884),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),

                  // Inline Filter Dropdown Section (Appears right after All/Mine tab when clicking Filter)
                  if (_isFilterExpanded) const ContactInlineFilterSection(),
                ],
              ),
            ),

            // 2. Summary Count & Table Header Row matching reference screenshot
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFF8FAFC),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: contacts.isNotEmpty && _selectedContactIds.length == contacts.length,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedContactIds.addAll(contacts.map((c) => c.id));
                          } else {
                            _selectedContactIds.clear();
                          }
                        });
                      },
                      activeColor: const Color(0xFF00A884),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      side: const BorderSide(color: Color(0xFF94A3B8), width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'NAME',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2563EB),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  if (_selectedContactIds.isNotEmpty) ...[
                    ElevatedButton.icon(
                      onPressed: _confirmDeleteSelectedContacts,
                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.white),
                      label: Text(
                        'Delete (${_selectedContactIds.length})',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ] else
                    Text(
                      contactProvider.isLoading && contacts.isEmpty
                          ? 'Loading contacts...'
                          : '${_formatCount(totalCount > 0 ? totalCount : contacts.length)} contacts',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                ],
              ),
            ),

            // 3. Contacts List View
            Expanded(
              child: AppRefreshIndicator(
                onRefresh: () async {
                  _loadContactsForSegment(_selectedSegment);
                },
                child: contactProvider.isLoading && contacts.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(color: Color(0xFF00A884)),
                      )
                    : contacts.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics()),
                            children: [
                              const SizedBox(height: 120),
                              Center(
                                child: Text(
                                  'No contacts found',
                                  style: GoogleFonts.poppins(
                                      color: const Color(0xFF64748B), fontSize: 14),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics()),
                            itemCount: contacts.length +
                                (contactProvider.totalPages > 1 ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == contacts.length) {
                                return Container(
                                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
                                  margin: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      OutlinedButton(
                                        onPressed: contactProvider.currentPage > 1 &&
                                                !contactProvider.isLoading
                                            ? () {
                                                context
                                                    .read<ContactProvider>()
                                                    .changePage(
                                                      contactProvider.currentPage - 1,
                                                    );
                                              }
                                            : null,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFF334155),
                                          disabledForegroundColor:
                                              const Color(0xFFCBD5E1),
                                          side: const BorderSide(
                                              color: Color(0xFFE2E8F0)),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 10),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: Text(
                                          'Previous',
                                          style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                      const SizedBox(width: 24),
                                      Text(
                                        'Page ${contactProvider.currentPage} of ${contactProvider.totalPages}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF475569),
                                        ),
                                      ),
                                      const SizedBox(width: 24),
                                      OutlinedButton(
                                        onPressed: contactProvider.currentPage <
                                                    contactProvider.totalPages &&
                                                !contactProvider.isLoading
                                            ? () {
                                                context
                                                    .read<ContactProvider>()
                                                    .changePage(
                                                      contactProvider.currentPage + 1,
                                                    );
                                              }
                                            : null,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFF334155),
                                          disabledForegroundColor:
                                              const Color(0xFFCBD5E1),
                                          side: const BorderSide(
                                              color: Color(0xFFE2E8F0)),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20, vertical: 10),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: Text(
                                          'Next',
                                          style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              final contact = contacts[index];
                              final isSelected = _selectedContactIds.contains(contact.id);
                              return ContactTile(
                                contact: contact,
                                isSelected: isSelected,
                                showCheckbox: true,
                                onSelectionChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedContactIds.add(contact.id);
                                    } else {
                                      _selectedContactIds.remove(contact.id);
                                    }
                                  });
                                },
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => ContactDetailsScreen(
                                        contact: contact,
                                      ),
                                    ),
                                  );
                                  if (mounted) {
                                    _loadContactsForSegment(_selectedSegment);
                                  }
                                },
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await CreateContactModal.show(context);
          if (created == true && mounted) {
            _loadContactsForSegment(_selectedSegment);
          }
        },
        backgroundColor: const Color(0xFF00A884),
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(
          Icons.add_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
