import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:crmproject/core/widgets/app_refresh_indicator.dart';
import '../../../../core/providers/master_data_provider.dart';
import '../../../../core/widgets/deal_tile.dart';
import '../../../../core/widgets/search_and_filter_bar.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import 'package:crmproject/features/contacts/presentation/providers/contact_provider.dart';
import '../providers/deal_provider.dart';
import '../widgets/create_deal_modal.dart';
import '../widgets/deal_inline_filter_section.dart';
import 'deal_details_screen.dart';

class DealsScreen extends StatefulWidget {
  const DealsScreen({super.key});

  @override
  State<DealsScreen> createState() => _DealsScreenState();
}

class _DealsScreenState extends State<DealsScreen> {
  String _searchQuery = '';
  int _selectedSegment = 0; // 0 for All, 1 for Mine
  bool _isFilterExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MasterDataProvider>().fetchAllMasterData();
      _loadDealsForSegment(_selectedSegment);
      context.read<DealProvider>().fetchDealStats();
    });
  }

  void _loadDealsForSegment(int segmentIndex) {
    final auth = context.read<AuthProvider>();
    final currentUserId = auth.currentUser?.id;

    if (segmentIndex == 1) {
      context.read<DealProvider>().fetchDeals(
            search: _searchQuery,
            ownerId: currentUserId,
            ignorePermissions: false,
          );
    } else {
      context.read<DealProvider>().fetchDeals(
            search: _searchQuery,
            ownerId: null,
            ignorePermissions: true,
          );
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _loadDealsForSegment(_selectedSegment);
  }

  void _onSegmentChanged(int index) {
    setState(() {
      _selectedSegment = index;
    });
    _loadDealsForSegment(index);
  }

  String _formatCount(int number) {
    final str = number.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (Match m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    final dealProvider = context.watch<DealProvider>();
    final deals = dealProvider.deals;

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
                    searchHint: 'Search deals...',
                    onSearchChanged: _onSearchChanged,
                    onSegmentChanged: _onSegmentChanged,
                    currentSort: dealProvider.sortOption,
                    onSortChanged: (ContactSortOption option) {
                      context.read<DealProvider>().setSortOption(option);
                    },
                    isFilterActive: dealProvider.isFilterActive,
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
                            'Import deals feature coming soon',
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
                            'Exporting ${deals.length} deals...',
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
                  if (_isFilterExpanded) const DealInlineFilterSection(),
                ],
              ),
            ),

            // 2. Summary Count Sub-header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFF8FAFC),
              child: Text(
                dealProvider.isLoading && deals.isEmpty
                    ? 'Loading deals...'
                    : '${_formatCount(dealProvider.totalCount > 0 ? dealProvider.totalCount : deals.length)} deals${dealProvider.stats != null ? " • Pipeline: \$${dealProvider.stats!.pipelineValue.toStringAsFixed(0)}" : ""}',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),

            // 3. Deals List View
            Expanded(
              child: AppRefreshIndicator(
                onRefresh: () async {
                  _loadDealsForSegment(_selectedSegment);
                  await context.read<DealProvider>().fetchDealStats();
                },
                child: dealProvider.isLoading && deals.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(color: Color(0xFF00A884)),
                      )
                    : deals.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics()),
                            children: [
                              const SizedBox(height: 120),
                              Center(
                                child: Text(
                                  'No deals found',
                                  style: GoogleFonts.poppins(
                                      color: const Color(0xFF64748B), fontSize: 14),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics()),
                            itemCount: deals.length +
                                (dealProvider.totalPages > 1 ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == deals.length) {
                                return Container(
                                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
                                  margin: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      OutlinedButton(
                                        onPressed: dealProvider.currentPage > 1 &&
                                                !dealProvider.isLoading
                                            ? () {
                                                context.read<DealProvider>().changePage(
                                                      dealProvider.currentPage - 1,
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
                                        'Page ${dealProvider.currentPage} of ${dealProvider.totalPages}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF475569),
                                        ),
                                      ),
                                      const SizedBox(width: 24),
                                      OutlinedButton(
                                        onPressed: dealProvider.currentPage <
                                                    dealProvider.totalPages &&
                                                !dealProvider.isLoading
                                            ? () {
                                                context.read<DealProvider>().changePage(
                                                      dealProvider.currentPage + 1,
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

                              final deal = deals[index];
                              return DealTile(
                                deal: deal,
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => DealDetailsScreen(
                                        deal: deal,
                                      ),
                                    ),
                                  );
                                  if (mounted) {
                                    _loadDealsForSegment(_selectedSegment);
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
          final created = await CreateDealModal.show(context);
          if (created == true && mounted) {
            _loadDealsForSegment(_selectedSegment);
            context.read<DealProvider>().fetchDealStats();
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
