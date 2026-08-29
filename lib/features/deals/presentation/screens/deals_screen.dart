import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/navigation/route_names.dart';
import '../../../../core/navigation/route_paths.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:crmproject/core/widgets/app_refresh_indicator.dart';
import '../../../../core/providers/master_data_provider.dart';
import '../../../../core/widgets/deal_tile.dart';
import '../../../../core/widgets/search_and_filter_bar.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../departments/presentation/providers/department_provider.dart';
import 'package:crmproject/features/contacts/presentation/providers/contact_provider.dart';
import '../providers/deal_provider.dart';
import '../widgets/create_deal_modal.dart';
import '../widgets/deal_inline_filter_section.dart';

class DealsScreen extends StatefulWidget {
  const DealsScreen({super.key});

  @override
  State<DealsScreen> createState() => _DealsScreenState();
}

class _DealsScreenState extends State<DealsScreen> {
  String _searchQuery = '';
  int _selectedSegment = 0; // 0 for All, 1 for Mine
  bool _isFilterExpanded = true;
  final Set<String> _selectedDealIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final deptId = context.read<DepartmentProvider>().selectedDepartmentId;
      context.read<MasterDataProvider>().fetchAllMasterData(departmentId: deptId);
      _loadDealsForSegment(_selectedSegment);
      context.read<DealProvider>().fetchDealStats(departmentId: deptId);
    });
  }

  void _loadDealsForSegment(int segmentIndex) {
    setState(() {
      _selectedDealIds.clear();
    });
    final auth = context.read<AuthProvider>();
    final currentUserId = auth.currentUser?.id;
    final deptId = context.read<DepartmentProvider>().selectedDepartmentId;

    if (segmentIndex == 1) {
      context.read<DealProvider>().fetchDeals(
            search: _searchQuery,
            ownerId: currentUserId,
            departmentId: deptId,
            ignorePermissions: false,
          );
    } else {
      context.read<DealProvider>().fetchDeals(
            search: _searchQuery,
            ownerId: null,
            departmentId: deptId,
            ignorePermissions: true,
          );
    }
  }

  Future<void> _confirmDeleteSelectedDeals() async {
    if (_selectedDealIds.isEmpty) return;
    final count = _selectedDealIds.length;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Deal${count > 1 ? 's' : ''}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete $count selected deal${count > 1 ? 's' : ''}? This action cannot be undone.',
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

    final provider = context.read<DealProvider>();
    final idsToDelete = List<String>.from(_selectedDealIds);

    for (final id in idsToDelete) {
      await provider.deleteDeal(id);
    }

    if (mounted) {
      setState(() {
        _selectedDealIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count deal${count > 1 ? 's' : ''} deleted successfully!', style: GoogleFonts.poppins()),
          backgroundColor: const Color(0xFF00A884),
          behavior: SnackBarBehavior.floating,
        ),
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
                    onRefreshTap: () {
                      context.read<DealProvider>().fetchDeals();
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
                      value: deals.isNotEmpty && _selectedDealIds.length == deals.length,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedDealIds.addAll(deals.map((d) => d.id));
                          } else {
                            _selectedDealIds.clear();
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
                  if (_selectedDealIds.isNotEmpty) ...[
                    ElevatedButton.icon(
                      onPressed: _confirmDeleteSelectedDeals,
                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.white),
                      label: Text(
                        'Delete (${_selectedDealIds.length})',
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
                      dealProvider.isLoading && deals.isEmpty
                          ? 'Loading deals...'
                          : '${_formatCount(dealProvider.totalCount > 0 ? dealProvider.totalCount : deals.length)} deals${dealProvider.stats != null ? " • Pipeline: \$${dealProvider.stats!.pipelineValue.toStringAsFixed(0)}" : ""}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                ],
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
                              final isSelected = _selectedDealIds.contains(deal.id);
                              return DealTile(
                                deal: deal,
                                isSelected: isSelected,
                                showCheckbox: true,
                                onSelectionChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedDealIds.add(deal.id);
                                    } else {
                                      _selectedDealIds.remove(deal.id);
                                    }
                                  });
                                },
                                onTap: () async {
                                  // /deals/details/:id
                                  await context.pushNamed(
                                    RouteNames.dealDetails,
                                    pathParameters: {RoutePaths.idParam: deal.id},
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
          if (!mounted) return;
          if (created == true) {
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
