import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../features/companies/presentation/providers/company_provider.dart';
import '../../features/companies/presentation/widgets/create_company_modal.dart';
import '../../features/contacts/presentation/providers/contact_provider.dart';
import '../../features/contacts/presentation/widgets/create_contact_modal.dart';
import '../../features/deals/presentation/providers/deal_provider.dart';
import '../../features/deals/presentation/widgets/create_deal_modal.dart';

class AddAssociationModal extends StatefulWidget {
  final String entityType; // 'company', 'contact', 'deal'

  const AddAssociationModal({
    super.key,
    required this.entityType,
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required String entityType,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddAssociationModal(entityType: entityType),
    );
  }

  @override
  State<AddAssociationModal> createState() => _AddAssociationModalState();
}

class _AddAssociationModalState extends State<AddAssociationModal> {
  int _selectedTab = 1; // 0 = Create new, 1 = Add existing
  String _searchQuery = '';
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.entityType == 'company') {
        context.read<CompanyProvider>().fetchCompanies(ignorePermissions: true);
      } else if (widget.entityType == 'contact') {
        context.read<ContactProvider>().fetchContacts(ignorePermissions: true);
      } else if (widget.entityType == 'deal') {
        context.read<DealProvider>().fetchDeals(ignorePermissions: true);
      }
    });
  }

  String get _title {
    if (widget.entityType == 'company') return 'Add Company';
    if (widget.entityType == 'contact') return 'Add Contact';
    if (widget.entityType == 'deal') return 'Add Deal';
    return 'Add Association';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF00A884),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.of(context).pop();
                    }
                  },
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Tab Selector: Create new vs Add existing
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedTab = 0;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedTab == 0 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _selectedTab == 0
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                        child: Center(
                          child: Text(
                            'Create new',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: _selectedTab == 0
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: _selectedTab == 0
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedTab = 1;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedTab == 1 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _selectedTab == 1
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                        child: Center(
                          child: Text(
                            'Add existing',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: _selectedTab == 1
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: _selectedTab == 1
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content Area
          Expanded(
            child: _selectedTab == 0
                ? _buildCreateNewView()
                : _buildAddExistingView(),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateNewView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
        if (widget.entityType == 'company') {
          CreateCompanyModal.show(context);
        } else if (widget.entityType == 'contact') {
          CreateContactModal.show(context);
        } else {
          CreateDealModal.show(context);
        }
      }
    });

    return const Center(
      child: CircularProgressIndicator(color: Color(0xFF00A884)),
    );
  }

  Widget _buildAddExistingView() {
    List<Map<String, dynamic>> items = [];

    if (widget.entityType == 'company') {
      final compProv = context.watch<CompanyProvider>();
      items = compProv.companies
          .map((c) => {
                'id': c.id,
                'name': c.name,
                'subtext': c.domain ?? c.websiteUrl ?? '',
              })
          .toList();
    } else if (widget.entityType == 'contact') {
      final contProv = context.watch<ContactProvider>();
      items = contProv.contacts
          .map((c) => {
                'id': c.id,
                'name': c.name,
                'subtext': c.email,
              })
          .toList();
    } else if (widget.entityType == 'deal') {
      final dealProv = context.watch<DealProvider>();
      items = dealProv.deals
          .map((d) => {
                'id': d.id,
                'name': d.title,
                'subtext': '\$${d.amount.toStringAsFixed(0)} • ${d.stage}',
              })
          .toList();
    }

    final filtered = items.where((item) {
      if (_searchQuery.isEmpty) return true;
      final name = (item['name'] ?? '').toString().toLowerCase();
      final sub = (item['subtext'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase()) ||
          sub.contains(_searchQuery.toLowerCase());
    }).toList();

    final typeLabel = widget.entityType == 'company'
        ? 'Companies'
        : widget.entityType == 'contact'
            ? 'Contacts'
            : 'Deals';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Input
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search $typeLabel...',
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
              const SizedBox(height: 12),

              // Header Count & Sort
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${filtered.length} $typeLabel',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'Default (Recently added) ',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF00A884),
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF00A884),
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // List View of Items
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No $typeLabel found',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final id = item['id'].toString();
                    final isChecked = _selectedIds.contains(id);

                    return InkWell(
                      onTap: () {
                        setState(() {
                          if (isChecked) {
                            _selectedIds.remove(id);
                          } else {
                            _selectedIds.add(id);
                          }
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: Checkbox(
                                value: isChecked,
                                activeColor: const Color(0xFF00A884),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedIds.add(id);
                                    } else {
                                      _selectedIds.remove(id);
                                    }
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  text: item['name'].toString(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1E293B),
                                  ),
                                  children: [
                                    if (item['subtext'].toString().isNotEmpty)
                                      TextSpan(
                                        text: ' (${item['subtext']})',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w400,
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
                  },
                ),
        ),

        // Bottom Actions Bar (Add & Cancel)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              SizedBox(
                height: 40,
                child: ElevatedButton(
                  onPressed: _selectedIds.isEmpty
                      ? null
                      : () {
                          final selectedObjects = items
                              .where((it) => _selectedIds.contains(it['id'].toString()))
                              .toList();
                          Navigator.of(context).pop({
                            'action': 'add_existing',
                            'selected': selectedObjects,
                          });
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF87171).withValues(alpha: 0.8),
                    disabledBackgroundColor: const Color(0xFFFECACA),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Add',
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 40,
                child: OutlinedButton(
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.of(context).pop();
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF475569),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
