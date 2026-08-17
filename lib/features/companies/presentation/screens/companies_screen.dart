import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:crmproject/core/widgets/app_refresh_indicator.dart';
import '../../../../core/providers/master_data_provider.dart';
import '../../../../core/widgets/company_tile.dart';
import '../../../../core/widgets/search_and_filter_bar.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import 'package:crmproject/features/contacts/presentation/providers/contact_provider.dart';
import '../providers/company_provider.dart';
import '../widgets/company_inline_filter_section.dart';
import '../widgets/create_company_modal.dart';
import 'company_details_screen.dart';

class CompaniesScreen extends StatefulWidget {
  const CompaniesScreen({super.key});

  @override
  State<CompaniesScreen> createState() => _CompaniesScreenState();
}

class _CompaniesScreenState extends State<CompaniesScreen> {
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  int _selectedSegment = 0; // 0 for All, 1 for Mine
  bool _isFilterExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MasterDataProvider>().fetchAllMasterData();
      _loadCompaniesForSegment(_selectedSegment);
    });
  }

  void _loadCompaniesForSegment(int segmentIndex) {
    final auth = context.read<AuthProvider>();
    final currentUserId = auth.currentUser?.id;

    if (segmentIndex == 1) {
      context.read<CompanyProvider>().fetchCompanies(
            search: _searchQuery,
            ownerId: currentUserId,
            ignorePermissions: false,
          );
    } else {
      context.read<CompanyProvider>().fetchCompanies(
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
    _loadCompaniesForSegment(_selectedSegment);
  }

  void _onSegmentChanged(int index) {
    setState(() {
      _selectedSegment = index;
    });
    _loadCompaniesForSegment(index);
  }

  String _formatCount(int number) {
    final str = number.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (Match m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    final companyProvider = context.watch<CompanyProvider>();
    final companies = companyProvider.companies;
    final totalCount = companyProvider.totalCount;

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
                    searchHint: 'Search companies...',
                    onSearchChanged: _onSearchChanged,
                    onSegmentChanged: _onSegmentChanged,
                    currentSort: companyProvider.sortOption,
                    onSortChanged: (ContactSortOption option) {
                      context.read<CompanyProvider>().setSortOption(option);
                    },
                    isFilterActive: companyProvider.isFilterActive,
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
                            'Import companies feature coming soon',
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
                            'Exporting ${companies.length} companies...',
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
                  if (_isFilterExpanded) const CompanyInlineFilterSection(),
                ],
              ),
            ),

            // 2. Summary Count Sub-header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFF8FAFC),
              child: Text(
                companyProvider.isLoading && companies.isEmpty
                    ? 'Loading companies...'
                    : '${_formatCount(totalCount > 0 ? totalCount : companies.length)} companies',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),

            // 3. Companies List View
            Expanded(
              child: AppRefreshIndicator(
                onRefresh: () async {
                  _loadCompaniesForSegment(_selectedSegment);
                },
                child: companyProvider.isLoading && companies.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(color: Color(0xFF00A884)),
                      )
                    : companies.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics()),
                            children: [
                              const SizedBox(height: 120),
                              Center(
                                child: Text(
                                  'No companies found',
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
                            itemCount: companies.length +
                                (companyProvider.totalPages > 1 ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == companies.length) {
                                return Container(
                                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
                                  margin: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      OutlinedButton(
                                        onPressed: companyProvider.currentPage > 1 &&
                                                !companyProvider.isLoading
                                            ? () {
                                                context
                                                    .read<CompanyProvider>()
                                                    .changePage(
                                                      companyProvider.currentPage - 1,
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
                                        'Page ${companyProvider.currentPage} of ${companyProvider.totalPages}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF475569),
                                        ),
                                      ),
                                      const SizedBox(width: 24),
                                      OutlinedButton(
                                        onPressed: companyProvider.currentPage <
                                                    companyProvider.totalPages &&
                                                !companyProvider.isLoading
                                            ? () {
                                                context
                                                    .read<CompanyProvider>()
                                                    .changePage(
                                                      companyProvider.currentPage + 1,
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

                              final company = companies[index];
                              return CompanyTile(
                                company: company,
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => CompanyDetailsScreen(
                                        company: company,
                                      ),
                                    ),
                                  );
                                  if (mounted) {
                                    _loadCompaniesForSegment(_selectedSegment);
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
          final created = await CreateCompanyModal.show(context);
          if (created == true && mounted) {
            _loadCompaniesForSegment(_selectedSegment);
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
