import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:crmproject/core/widgets/app_refresh_indicator.dart';
import '../../../../core/providers/master_data_provider.dart';
import '../../../../core/widgets/contact_tile.dart';
import '../../../../core/widgets/search_and_filter_bar.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
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
  bool _isFilterExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MasterDataProvider>().fetchAllMasterData();
      _loadContactsForSegment(_selectedSegment);
    });
  }

  void _loadContactsForSegment(int segmentIndex) {
    final auth = context.read<AuthProvider>();
    final currentUserId = auth.currentUser?.id;

    if (segmentIndex == 1) {
      context.read<ContactProvider>().fetchContacts(
            search: _searchQuery,
            ownerId: currentUserId,
            ignorePermissions: false,
          );
    } else {
      context.read<ContactProvider>().fetchContacts(
            search: _searchQuery,
            ownerId: null,
            ignorePermissions: true,
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

            // 2. Summary Count Sub-header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFF8FAFC),
              child: Text(
                contactProvider.isLoading && contacts.isEmpty
                    ? 'Loading contacts...'
                    : '${_formatCount(totalCount > 0 ? totalCount : contacts.length)} contacts',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
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
                              return ContactTile(
                                contact: contact,
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
