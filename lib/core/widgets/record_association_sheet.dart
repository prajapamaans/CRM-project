import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../features/companies/presentation/providers/company_provider.dart';
import '../../features/contacts/presentation/providers/contact_provider.dart';
import '../../features/deals/presentation/providers/deal_provider.dart';

class RecordAssociationSheet extends StatefulWidget {
  final Map<String, List<Map<String, String>>> initialAssociations;

  const RecordAssociationSheet({
    super.key,
    required this.initialAssociations,
  });

  static Future<Map<String, List<Map<String, String>>>?> show(
    BuildContext context, {
    required Map<String, List<Map<String, String>>> initialAssociations,
  }) {
    return showModalBottomSheet<Map<String, List<Map<String, String>>>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RecordAssociationSheet(initialAssociations: initialAssociations),
    );
  }

  @override
  State<RecordAssociationSheet> createState() => _RecordAssociationSheetState();
}

class _RecordAssociationSheetState extends State<RecordAssociationSheet> {
  String _selectedTab = 'Selected'; // 'Selected', 'Companies', 'Contacts', 'Deals'
  String _searchQuery = '';
  late Map<String, List<Map<String, String>>> _currentAssociations;

  @override
  void initState() {
    super.initState();
    _currentAssociations = {
      'Companies': List.from(widget.initialAssociations['Companies'] ?? []),
      'Contacts': List.from(widget.initialAssociations['Contacts'] ?? []),
      'Deals': List.from(widget.initialAssociations['Deals'] ?? []),
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CompanyProvider>().fetchCompanies();
      context.read<ContactProvider>().fetchContacts();
      context.read<DealProvider>().fetchDeals();
    });
  }

  int get _selectedCount {
    return _currentAssociations['Companies']!.length +
        _currentAssociations['Contacts']!.length +
        _currentAssociations['Deals']!.length;
  }

  bool _isRecordSelected(String type, String id) {
    return _currentAssociations[type]!.any((item) => item['id'] == id);
  }

  void _toggleRecord(String type, String id, String name) {
    setState(() {
      final list = _currentAssociations[type]!;
      final index = list.indexWhere((item) => item['id'] == id);
      if (index != -1) {
        list.removeAt(index);
      } else {
        list.add({'id': id, 'name': name});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final companyProvider = context.watch<CompanyProvider>();
    final contactProvider = context.watch<ContactProvider>();
    final dealProvider = context.watch<DealProvider>();

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: Row(
              children: [
                // Left Navigation Sidebar (Matching Image 2)
                Container(
                  width: 140,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Column(
                    children: [
                      _buildSidebarItem('Selected', count: _selectedCount, isHighlighted: true),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      _buildSidebarItem('Companies', count: companyProvider.companies.length),
                      _buildSidebarItem('Contacts', count: contactProvider.contacts.length),
                      _buildSidebarItem('Deals', count: dealProvider.deals.length),
                    ],
                  ),
                ),

                // Right Panel (Search bar & List of Associations)
                Expanded(
                  child: Column(
                    children: [
                      // Search bar
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                          decoration: InputDecoration(
                            hintText: 'Search associations',
                            hintStyle: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Color(0xFF00A884)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Color(0xFF00A884)),
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),

                      // Section Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        color: const Color(0xFFF8FAFC),
                        child: Text(
                          _getSectionTitle(),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF475569),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),

                      // List View
                      Expanded(
                        child: ListView(
                          children: _buildAssociationList(companyProvider, contactProvider, dealProvider),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Footer Apply Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: GoogleFonts.poppins(color: const Color(0xFF64748B))),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, _currentAssociations),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A884),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: Text('Save Associations (${_selectedCount})',
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(String title, {required int count, bool isHighlighted = false}) {
    final isSelected = _selectedTab == title;
    return InkWell(
      onTap: () => setState(() => _selectedTab = title),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          border: isSelected
              ? const Border(left: BorderSide(color: Color(0xFF00A884), width: 3))
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? const Color(0xFF00A884) : const Color(0xFF334155),
              ),
            ),
            Text(
              '$count',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? const Color(0xFF00A884) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSectionTitle() {
    if (_selectedTab == 'Selected') return 'SELECTED RECORDS (${_selectedCount})';
    if (_selectedTab == 'Companies') return 'COMPANIES (${_currentAssociations['Companies']!.length})';
    if (_selectedTab == 'Contacts') return 'CONTACTS (${_currentAssociations['Contacts']!.length})';
    return 'DEALS (${_currentAssociations['Deals']!.length})';
  }

  List<Widget> _buildAssociationList(
    CompanyProvider companyProvider,
    ContactProvider contactProvider,
    DealProvider dealProvider,
  ) {
    final List<Widget> items = [];

    if (_selectedTab == 'Selected' || _selectedTab == 'Contacts') {
      final contacts = contactProvider.contacts.where((c) {
        if (_searchQuery.isEmpty) return true;
        return c.name.toLowerCase().contains(_searchQuery);
      });
      for (final c in contacts) {
        final isChecked = _isRecordSelected('Contacts', c.id);
        if (_selectedTab == 'Selected' && !isChecked) continue;
        items.add(
          CheckboxListTile(
            value: isChecked,
            activeColor: const Color(0xFF00A884),
            title: Text(c.name, style: GoogleFonts.poppins(fontSize: 13.5, color: const Color(0xFF1E293B))),
            onChanged: (_) => _toggleRecord('Contacts', c.id, c.name),
          ),
        );
      }
    }

    if (_selectedTab == 'Selected' || _selectedTab == 'Companies') {
      final companies = companyProvider.companies.where((c) {
        if (_searchQuery.isEmpty) return true;
        return c.name.toLowerCase().contains(_searchQuery);
      });
      for (final c in companies) {
        final isChecked = _isRecordSelected('Companies', c.id);
        if (_selectedTab == 'Selected' && !isChecked) continue;
        items.add(
          CheckboxListTile(
            value: isChecked,
            activeColor: const Color(0xFF00A884),
            title: Text(c.name, style: GoogleFonts.poppins(fontSize: 13.5, color: const Color(0xFF1E293B))),
            onChanged: (_) => _toggleRecord('Companies', c.id, c.name),
          ),
        );
      }
    }

    if (_selectedTab == 'Selected' || _selectedTab == 'Deals') {
      final deals = dealProvider.deals.where((d) {
        if (_searchQuery.isEmpty) return true;
        return d.title.toLowerCase().contains(_searchQuery);
      });
      for (final d in deals) {
        final isChecked = _isRecordSelected('Deals', d.id);
        if (_selectedTab == 'Selected' && !isChecked) continue;
        items.add(
          CheckboxListTile(
            value: isChecked,
            activeColor: const Color(0xFF00A884),
            title: Text(d.title, style: GoogleFonts.poppins(fontSize: 13.5, color: const Color(0xFF1E293B))),
            onChanged: (_) => _toggleRecord('Deals', d.id, d.title),
          ),
        );
      }
    }

    if (items.isEmpty) {
      items.add(
        Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No records found',
              style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF94A3B8)),
            ),
          ),
        ),
      );
    }

    return items;
  }
}
