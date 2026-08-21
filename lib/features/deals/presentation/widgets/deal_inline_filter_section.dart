import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/master_data_provider.dart';
import '../../../../core/widgets/searchable_dropdown_form_field.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../providers/deal_provider.dart';

class DealInlineFilterSection extends StatefulWidget {
  const DealInlineFilterSection({super.key});

  @override
  State<DealInlineFilterSection> createState() => _DealInlineFilterSectionState();
}

class _DealInlineFilterSectionState extends State<DealInlineFilterSection> {
  final List<String> _defaultStages = const [
    'All stages',
    'Prospect',
    'Capability Statement',
    'RFI',
    'RFP/RFQ',
    'MSA',
    'Closed Won',
    'Closed Lost',
  ];

  final List<String> _staleDaysOptions = const [
    'All deals',
    '7 days',
    '15 days',
    '30 days',
    '60 days',
    '90 days',
  ];

  final List<String> _createDateOptions = const [
    'All time',
    'Today',
    'Yesterday',
    'This week',
    'This month',
    'This quarter',
    'This year',
  ];

  @override
  Widget build(BuildContext context) {
    final dealProvider = context.watch<DealProvider>();
    final authProvider = context.watch<AuthProvider>();
    final masterProvider = context.watch<MasterDataProvider>();
    final teamMembers = authProvider.teamMembers;

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            // 1. Deal owner (fetch users)
            Builder(
              builder: (context) {
                final ownerItems = <DropdownSearchItem<String>>[
                  DropdownSearchItem(value: 'all', label: 'All Owners'),
                  if (authProvider.currentUser != null)
                    DropdownSearchItem(
                      value: authProvider.currentUser!.id,
                      label: authProvider.currentUser!.fullName.isNotEmpty
                          ? authProvider.currentUser!.fullName
                          : 'Admin User',
                      subtext: authProvider.currentUser!.email,
                    ),
                  ...teamMembers.map(
                    (m) => DropdownSearchItem(
                      value: m.id,
                      label: m.fullName,
                      subtext: m.email,
                    ),
                  ),
                ];

                return _buildFilterPill<String>(
                  title: 'Deal owner',
                  value: dealProvider.selectedOwnerId ?? 'all',
                  items: ownerItems,
                  onChanged: (val) {
                    context.read<DealProvider>().setOwnerFilter(val);
                  },
                );
              },
            ),
            const SizedBox(width: 14),

            // 2. Deal stage
            Builder(
              builder: (context) {
                final dynamicStages = masterProvider.dealStages
                    .map((e) => e['name'] as String? ?? e['label'] as String? ?? '')
                    .where((e) => e.isNotEmpty)
                    .toList();
                final stageList =
                    dynamicStages.isNotEmpty ? dynamicStages : _defaultStages;

                final stageItems = stageList
                    .map(
                      (stage) => DropdownSearchItem<String>(
                        value: stage,
                        label: stage,
                      ),
                    )
                    .toList();

                return _buildFilterPill<String>(
                  title: 'Deal stage',
                  value: dealProvider.selectedStage ?? 'All stages',
                  items: stageItems,
                  onChanged: (val) {
                    context.read<DealProvider>().setStageFilter(val);
                  },
                );
              },
            ),
            const SizedBox(width: 14),

            // 3. Create date
            _buildFilterPill<String>(
              title: 'Create date',
              value: dealProvider.selectedCreateDate ?? 'All time',
              items: _createDateOptions
                  .map(
                    (d) => DropdownSearchItem<String>(
                      value: d,
                      label: d,
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                context.read<DealProvider>().setCreateDateFilter(val);
              },
            ),
            const SizedBox(width: 14),

            // 4. Stale days (matching screenshot #1)
            _buildStaleDaysPill(
              title: 'Stale days',
              value: dealProvider.selectedStaleDays ?? 'All deals',
              items: _staleDaysOptions,
              onChanged: (val) {
                context.read<DealProvider>().setStaleDaysFilter(val);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill<T>({
    required String title,
    required T value,
    required List<DropdownSearchItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return SizedBox(
      height: 32,
      child: FormField<T>(
        initialValue: value,
        builder: (state) {
          final context = state.context;
          final selectedItem = items.cast<DropdownSearchItem<T>?>().firstWhere(
                (item) => item?.value == state.value,
                orElse: () => null,
              );

          final bool isFiltered = selectedItem != null &&
              selectedItem.value != 'all' &&
              selectedItem.value != 'All time' &&
              selectedItem.value != 'All stages' &&
              selectedItem.value != 'Select a stage' &&
              selectedItem.value != 'Select a priority';

          final String displayTitle = isFiltered ? '$title: ${selectedItem.label}' : title;

          return InkWell(
            onTap: () async {
              final result = await showDialog<T>(
                context: context,
                barrierColor: Colors.black12,
                builder: (dialogContext) => Dialog(
                  alignment: Alignment.topCenter,
                  insetPadding: const EdgeInsets.only(top: 140, left: 16, right: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 6,
                  child: _InlineDealDropdownSearchModal<T>(
                    title: title,
                    items: items,
                    selectedValue: state.value,
                  ),
                ),
              );

              if (result != null) {
                state.didChange(result);
                onChanged(result);
              }
            },
            borderRadius: BorderRadius.circular(6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayTitle,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF00A884),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF00A884),
                  size: 18,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStaleDaysPill({
    required String title,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final bool isFiltered = value != 'All deals' && value != 'all';
    final String displayTitle = isFiltered ? '$title: $value' : title;

    return SizedBox(
      height: 32,
      child: InkWell(
        onTap: () async {
          final result = await showModalBottomSheet<String>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (modalContext) => _StaleDaysFilterModal(
              selectedValue: value,
              items: items,
            ),
          );

          if (result != null) {
            onChanged(result);
          }
        },
        borderRadius: BorderRadius.circular(6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayTitle,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF00A884),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF00A884),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineDealDropdownSearchModal<T> extends StatefulWidget {
  final String title;
  final List<DropdownSearchItem<T>> items;
  final T? selectedValue;

  const _InlineDealDropdownSearchModal({
    required this.title,
    required this.items,
    this.selectedValue,
  });

  @override
  State<_InlineDealDropdownSearchModal<T>> createState() =>
      _InlineDealDropdownSearchModalState<T>();
}

class _InlineDealDropdownSearchModalState<T>
    extends State<_InlineDealDropdownSearchModal<T>> {
  late List<DropdownSearchItem<T>> _filteredItems;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = widget.items;
      } else {
        _filteredItems = widget.items.where((item) {
          final labelMatches = item.label.toLowerCase().contains(query.toLowerCase());
          final subtextMatches =
              item.subtext?.toLowerCase().contains(query.toLowerCase()) ?? false;
          return labelMatches || subtextMatches;
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      constraints: const BoxConstraints(maxHeight: 420),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Top Search Field (Matching User Image)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _filterItems,
              style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF1E293B)),
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF00A884)),
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // 2. Options List View (Matching User Image)
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _filteredItems.length,
              itemBuilder: (context, index) {
                final item = _filteredItems[index];
                final isSelected = item.value == widget.selectedValue;

                return InkWell(
                  onTap: () => Navigator.pop(context, item.value),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.label,
                                style: GoogleFonts.poppins(
                                  fontSize: 13.5,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                  color: isSelected ? const Color(0xFF00A884) : const Color(0xFF334155),
                                ),
                              ),
                              if (item.subtext != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  item.subtext!,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.5,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_rounded,
                            color: Color(0xFF00A884),
                            size: 18,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StaleDaysFilterModal extends StatefulWidget {
  final String selectedValue;
  final List<String> items;

  const _StaleDaysFilterModal({
    required this.selectedValue,
    required this.items,
  });

  @override
  State<_StaleDaysFilterModal> createState() => _StaleDaysFilterModalState();
}

class _StaleDaysFilterModalState extends State<_StaleDaysFilterModal> {
  final TextEditingController _customDaysController = TextEditingController();

  @override
  void dispose() {
    _customDaysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Text(
            'FILTER BY STALE DAYS',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF94A3B8),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          Expanded(
            child: ListView(
              children: [
                ...widget.items.map((opt) {
                  final isSel = widget.selectedValue == opt;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      opt,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                        color: isSel ? const Color(0xFF00A884) : const Color(0xFF334155),
                      ),
                    ),
                    trailing: isSel
                        ? const Icon(Icons.check_rounded, color: Color(0xFF00A884), size: 18)
                        : null,
                    onTap: () => Navigator.pop(context, opt),
                  );
                }),

                const SizedBox(height: 12),
                Text(
                  'Custom days',
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customDaysController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Enter days...',
                          hintStyle: GoogleFonts.poppins(
                              fontSize: 13, color: const Color(0xFF94A3B8)),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final val = _customDaysController.text.trim();
                        if (val.isNotEmpty) {
                          Navigator.pop(context, '$val days');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00A884),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Apply',
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
