import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/navigation/route_names.dart';
import '../../../../core/navigation/route_paths.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:crmproject/core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/company_tile.dart';
import '../../../../core/widgets/list_error_state.dart';
import '../../../../core/widgets/search_and_filter_bar.dart';
import '../../../../core/providers/master_data_provider.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../departments/presentation/providers/department_provider.dart';
import '../providers/company_provider.dart';
import '../../data/models/company_model.dart';
import '../widgets/company_inline_filter_section.dart';
import '../widgets/create_company_modal.dart';

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
  final Set<String> _selectedCompanyIds = {};
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final deptId = context.read<DepartmentProvider>().selectedDepartmentId;
      context.read<MasterDataProvider>().fetchAllMasterData(departmentId: deptId);
      _loadCompaniesForSegment(_selectedSegment);
    });
  }

  void _loadCompaniesForSegment(int segmentIndex) {
    setState(() {
      _selectedCompanyIds.clear();
    });
    final auth = context.read<AuthProvider>();
    final currentUserId = auth.currentUser?.id;
    final deptId = context.read<DepartmentProvider>().selectedDepartmentId;

    // setSegmentScope is the one path allowed to clear the owner scope back to
    // null; fetchCompanies keeps whatever scope is set so that a refresh or a
    // filter change does not drop the user out of the Mine segment.
    context.read<CompanyProvider>().setSegmentScope(
          search: _searchQuery,
          ownerId: segmentIndex == 1 ? currentUserId : null,
          departmentId: deptId,
          ignorePermissions: segmentIndex != 1,
        );
  }

  Future<void> _confirmDeleteSelectedCompanies() async {
    if (_selectedCompanyIds.isEmpty || _isDeleting) return;
    final count = _selectedCompanyIds.length;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Compan${count > 1 ? 'ies' : 'y'}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete $count selected compan${count > 1 ? 'ies' : 'y'}? This action cannot be undone.',
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

    setState(() {
      _isDeleting = true;
    });

    try {
      final provider = context.read<CompanyProvider>();
      final deptId = context.read<DepartmentProvider>().selectedDepartmentId;
      final idsToDelete = List<String>.from(_selectedCompanyIds);

      final successCount = await provider.deleteCompanies(idsToDelete, departmentId: deptId);

      if (mounted) {
        setState(() {
          _selectedCompanyIds.clear();
          _isDeleting = false;
        });
        _loadCompaniesForSegment(_selectedSegment);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              successCount > 0
                  ? '$successCount compan${successCount > 1 ? 'ies' : 'y'} deleted successfully!'
                  : (provider.error != null && provider.error!.isNotEmpty
                      ? 'Failed to delete company: ${provider.error}'
                      : 'Failed to delete selected compan${count > 1 ? 'ies' : 'y'}'),
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: successCount > 0 ? const Color(0xFF00A884) : Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting companies: $e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteSingleCompany(CompanyModel company) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Company', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete ${company.name}? This action cannot be undone.',
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

    final deptId = context.read<DepartmentProvider>().selectedDepartmentId;
    final success = await context.read<CompanyProvider>().deleteCompany(company.id, departmentId: deptId);

    if (mounted) {
      if (success) {
        setState(() {
          _selectedCompanyIds.remove(company.id);
        });
        _loadCompaniesForSegment(_selectedSegment);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Company deleted successfully!', style: GoogleFonts.poppins()),
            backgroundColor: const Color(0xFF00A884),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        final err = context.read<CompanyProvider>().error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              err != null && err.isNotEmpty ? err : 'Failed to delete company',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
                    allLabel: 'All Companies',
                    mineLabel: 'My Companies',
                    onSearchChanged: _onSearchChanged,
                    onSegmentChanged: _onSegmentChanged,
                    isFilterActive: companyProvider.isFilterActive,
                    isFilterExpanded: _isFilterExpanded,
                    onToggleFilterExpanded: () {
                      setState(() {
                        _isFilterExpanded = !_isFilterExpanded;
                      });
                    },
                    onClearTap: () {
                      setState(() {
                        _searchQuery = '';
                      });
                      context.read<CompanyProvider>().clearAllFilters();
                    },
                    onRefreshTap: () {
                      // Re-issues the current segment so a refresh keeps the
                      // All/Mine scope instead of silently falling back to All.
                      _loadCompaniesForSegment(_selectedSegment);
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
                      value: companies.isNotEmpty && _selectedCompanyIds.length == companies.length,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedCompanyIds.addAll(companies.map((c) => c.id));
                          } else {
                            _selectedCompanyIds.clear();
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
                  if (_selectedCompanyIds.isNotEmpty) ...[
                    _isDeleting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: Padding(
                              padding: EdgeInsets.all(4.0),
                              child: CircularProgressIndicator(
                                color: Colors.redAccent,
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: _confirmDeleteSelectedCompanies,
                            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.white),
                            label: Text(
                              'Delete (${_selectedCompanyIds.length})',
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
                      companyProvider.isLoading && companies.isEmpty
                          ? 'Loading companies...'
                          : '${_formatCount(totalCount > 0 ? totalCount : companies.length)} companies',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                ],
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
                    // A failed request is reported as a failure. It used to
                    // fall through to "No companies found", so a filter whose
                    // request the API rejected looked like one that matched
                    // nothing.
                    : (companyProvider.error != null && companies.isEmpty)
                        ? ListErrorState(
                            message: companyProvider.error!,
                            onRetry: () => _loadCompaniesForSegment(_selectedSegment),
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
                              final isSelected = _selectedCompanyIds.contains(company.id);
                              return CompanyTile(
                                company: company,
                                isSelected: isSelected,
                                showCheckbox: true,
                                onDeleteTap: () => _confirmDeleteSingleCompany(company),
                                onSelectionChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedCompanyIds.add(company.id);
                                    } else {
                                      _selectedCompanyIds.remove(company.id);
                                    }
                                  });
                                },
                                onTap: () async {
                                  // /companies/details/:id
                                  await context.pushNamed(
                                    RouteNames.companyDetails,
                                    pathParameters: {RoutePaths.idParam: company.id},
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
