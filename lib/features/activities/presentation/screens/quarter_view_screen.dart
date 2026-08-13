import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/master_data_provider.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../companies/data/models/company_model.dart';
import '../../../companies/presentation/providers/company_provider.dart';
import '../../../contacts/presentation/providers/contact_provider.dart';
import '../../../deals/data/models/deal_model.dart';
import '../../../deals/presentation/providers/deal_provider.dart';

class QuarterViewScreen extends StatefulWidget {
  const QuarterViewScreen({super.key});

  @override
  State<QuarterViewScreen> createState() => _QuarterViewScreenState();
}

class _QuarterViewScreenState extends State<QuarterViewScreen> {
  int _selectedTypeIndex = 0; // 0 for Deals, 1 for Companies
  int _selectedQuarterIndex = 2; // 0: Q1, 1: Q2, 2: Q3, 3: Q4
  bool _isQuarterExpanded = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final currentUserId = auth.currentUser?.id ?? '311fee58-ba54-42b9-8795-f3ba19255b20';

      // 1. GET /api/auth/me
      auth.fetchUserProfile();

      // 2. GET /api/auth/team
      auth.fetchTeamMembers();

      // 3. All Master Data, Notifications, Deal Stages, Activities:
      // - GET /api/activities/notifications
      // - GET /api/activities/notifications?isRead=false&limit=10
      // - GET /api/activities?ownerId=...&status=pending&limit=10&type=task
      // - GET /api/departments
      // - GET /api/deals/stages
      // - GET /api/lifecycle-stages?entityType=company
      // - GET /api/lifecycle-stages?entityType=contact
      // - GET /api/master-dropdowns/key/company_industry?includeInactive=false
      // - GET /api/master-dropdowns/key/company_type?includeInactive=false
      // - GET /api/master-dropdowns/key/contact_lead_status?includeInactive=false
      // - GET /api/msp-options
      context.read<MasterDataProvider>().fetchAllMasterData(currentUserId: currentUserId);

      // 4. GET /api/companies?page=1&limit=25
      context.read<CompanyProvider>().fetchCompanies(
        ignorePermissions: true,
      );

      // 5. GET /api/contacts?page=1&limit=25
      context.read<ContactProvider>().fetchContacts(
        ignorePermissions: true,
      );

      // 6. GET /api/deals?page=1&limit=25 & GET /api/deals?page=1&limit=500
      context.read<DealProvider>().fetchDeals(
        ignorePermissions: true,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final dealProvider = context.watch<DealProvider>();
    final companyProvider = context.watch<CompanyProvider>();

    final deals = dealProvider.deals;
    final companies = companyProvider.companies;

    // Filter deals or companies based on search
    final filteredDeals = deals.where((d) {
      if (_searchQuery.isEmpty) return true;
      return d.title.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final filteredCompanies = companies.where((c) {
      if (_searchQuery.isEmpty) return true;
      return c.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    // 1. Group deals by Quarter (Q1: Jan-Mar, Q2: Apr-Jun, Q3: Jul-Sep, Q4: Oct-Dec)
    final dealsForQ0 = filteredDeals.where((d) => _getDealQuarter(d) == 0).toList();
    final dealsForQ1 = filteredDeals.where((d) => _getDealQuarter(d) == 1).toList();
    final dealsForQ2 = filteredDeals.where((d) => _getDealQuarter(d) == 2).toList();
    final dealsForQ3 = filteredDeals.where((d) => _getDealQuarter(d) == 3).toList();

    // 2. Group companies by Quarter
    final companiesForQ0 = filteredCompanies.where((c) => _getCompanyQuarter(c) == 0).toList();
    final companiesForQ1 = filteredCompanies.where((c) => _getCompanyQuarter(c) == 1).toList();
    final companiesForQ2 = filteredCompanies.where((c) => _getCompanyQuarter(c) == 2).toList();
    final companiesForQ3 = filteredCompanies.where((c) => _getCompanyQuarter(c) == 3).toList();

    final dealsCounts = [dealsForQ0.length, dealsForQ1.length, dealsForQ2.length, dealsForQ3.length];
    final companiesCounts = [companiesForQ0.length, companiesForQ1.length, companiesForQ2.length, companiesForQ3.length];

    final currentDeals = [dealsForQ0, dealsForQ1, dealsForQ2, dealsForQ3][_selectedQuarterIndex];
    final currentCompanies = [companiesForQ0, companiesForQ1, companiesForQ2, companiesForQ3][_selectedQuarterIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Header Row: Layers Icon + "Quarter View" + Deals/Companies Toggle Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Row(
                children: [
                  const Icon(
                    Icons.layers_outlined,
                    color: Color(0xFF00A884),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Quarter View',
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const Spacer(),

                  // Deals / Companies Segmented Pill
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTypeSegmentButton('Deals', 0),
                        _buildTypeSegmentButton('Companies', 1),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // 2. Search Input Field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: _selectedTypeIndex == 0 ? 'Search deals...' : 'Search companies...',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF94A3B8),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF94A3B8),
                      size: 20,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),

            // 3. Quarter Tabs Bar Container
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _buildQuarterTab('Q1', 0, _selectedTypeIndex == 0 ? dealsCounts[0] : companiesCounts[0]),
                    _buildQuarterTab('Q2', 1, _selectedTypeIndex == 0 ? dealsCounts[1] : companiesCounts[1]),
                    _buildQuarterTab(
                      'Q3',
                      2,
                      _selectedTypeIndex == 0 ? dealsCounts[2] : companiesCounts[2],
                      showDot: true,
                    ),
                    _buildQuarterTab('Q4', 3, _selectedTypeIndex == 0 ? dealsCounts[3] : companiesCounts[3]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 4. Quarter Details Box Container
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row of Box (e.g. QUARTER 3 (JUL - SEP) N <)
                      InkWell(
                        onTap: () {
                          setState(() {
                            _isQuarterExpanded = !_isQuarterExpanded;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _getQuarterTitle(_selectedQuarterIndex),
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF334155),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      _selectedTypeIndex == 0
                                          ? currentDeals.length.toString()
                                          : currentCompanies.length.toString(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Icon(
                                _isQuarterExpanded
                                    ? Icons.keyboard_arrow_left_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: const Color(0xFF94A3B8),
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (_isQuarterExpanded)
                        Expanded(
                          child: _selectedTypeIndex == 0
                              ? (currentDeals.isEmpty
                                  ? Center(
                                      child: Text(
                                        'No deals in this quarter',
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.symmetric(horizontal: 14),
                                      itemCount: currentDeals.length,
                                      itemBuilder: (context, index) {
                                        final deal = currentDeals[index];
                                        return _buildQuarterItemCard(
                                          title: deal.title,
                                          owner: deal.owner,
                                        );
                                      },
                                    ))
                              : (currentCompanies.isEmpty
                                  ? Center(
                                      child: Text(
                                        'No companies in this quarter',
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.symmetric(horizontal: 14),
                                      itemCount: currentCompanies.length,
                                      itemBuilder: (context, index) {
                                        final company = currentCompanies[index];
                                        return _buildQuarterItemCard(
                                          title: company.name,
                                          owner: 'Admin User',
                                        );
                                      },
                                    )),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  int _getQuarterFromDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return -1;
    final str = dateStr.trim();
    try {
      final dt = DateTime.tryParse(str);
      if (dt != null) {
        final m = dt.month;
        if (m >= 1 && m <= 3) return 0;
        if (m >= 4 && m <= 6) return 1;
        if (m >= 7 && m <= 9) return 2;
        if (m >= 10 && m <= 12) return 3;
      }
    } catch (_) {}

    if (str.contains('-')) {
      final parts = str.split('-');
      if (parts.length >= 2) {
        final m = int.tryParse(parts[1]);
        if (m != null) {
          if (m >= 1 && m <= 3) return 0;
          if (m >= 4 && m <= 6) return 1;
          if (m >= 7 && m <= 9) return 2;
          if (m >= 10 && m <= 12) return 3;
        }
      }
    } else if (str.contains('/')) {
      final parts = str.split('/');
      if (parts.length >= 2) {
        final m = int.tryParse(parts[0]) ?? int.tryParse(parts[1]);
        if (m != null) {
          if (m >= 1 && m <= 3) return 0;
          if (m >= 4 && m <= 6) return 1;
          if (m >= 7 && m <= 9) return 2;
          if (m >= 10 && m <= 12) return 3;
        }
      }
    }
    return -1;
  }

  int _getDealQuarter(DealModel deal) {
    int q = _getQuarterFromDate(deal.createdAt);
    if (q != -1) return q;
    q = _getQuarterFromDate(deal.expectedCloseDate);
    if (q != -1) return q;
    return 2;
  }

  int _getCompanyQuarter(CompanyModel company) {
    int q = _getQuarterFromDate(company.createdAt);
    if (q != -1) return q;
    return 2;
  }

  String _getQuarterTitle(int index) {
    switch (index) {
      case 0:
        return 'QUARTER 1 (JAN - MAR)';
      case 1:
        return 'QUARTER 2 (APR - JUN)';
      case 2:
        return 'QUARTER 3 (JUL - SEP)';
      case 3:
        return 'QUARTER 4 (OCT - DEC)';
      default:
        return 'QUARTER 3 (JUL - SEP)';
    }
  }

  Widget _buildTypeSegmentButton(String label, int index) {
    final bool isSelected = _selectedTypeIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTypeIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? const Color(0xFF0F766E) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildQuarterTab(String label, int index, int count, {bool showDot = false}) {
    final bool isSelected = _selectedQuarterIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedQuarterIndex = index;
          });
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? const Color(0xFF0F766E) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFE6F4F1) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? const Color(0xFF0F766E) : const Color(0xFF64748B),
                  ),
                ),
              ),
              if (showDot && isSelected) ...[
                const SizedBox(width: 4),
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00A884),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuarterItemCard({
    required String title,
    required String owner,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF00A884),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                '⌛',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Deal owner: $owner',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: const [
              Icon(
                Icons.check_box_outlined,
                size: 18,
                color: Color(0xFF00A884),
              ),
              SizedBox(width: 12),
              Icon(
                Icons.mail_outline_rounded,
                size: 18,
                color: Color(0xFF00A884),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
