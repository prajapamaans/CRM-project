import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/master_data_provider.dart';
import '../../../../core/widgets/searchable_dropdown_form_field.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../providers/contact_provider.dart';

class ContactInlineFilterSection extends StatefulWidget {
  const ContactInlineFilterSection({super.key});

  @override
  State<ContactInlineFilterSection> createState() => _ContactInlineFilterSectionState();
}

class _ContactInlineFilterSectionState extends State<ContactInlineFilterSection> {
  final List<String> _defaultLifecycleStages = const [
    'Added',
    'Subscriber',
    'Lead',
    'Marketing Qualified Lead',
    'Sales Qualified Lead',
    'Opportunity',
    'Customer',
    'Evangelist',
    'Other',
  ];

  final List<String> _defaultLeadStatuses = const [
    'New',
    'Open',
    'In progress',
    'Open Opportunity',
    'Unqualified',
    'Attempted to contact',
    'Connected',
    'Bad timing',
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
    final contactProvider = context.watch<ContactProvider>();
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
            // 1. Contact owner
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
                  title: 'Contact owner',
                  value: contactProvider.selectedOwnerId ?? 'all',
                  items: ownerItems,
                  onChanged: (val) {
                    context.read<ContactProvider>().setOwnerFilter(val);
                  },
                );
              },
            ),
            const SizedBox(width: 14),

            // 2. Lifecycle stage
            Builder(
              builder: (context) {
                final dynamicStages =
                    masterProvider.contactLifecycleStages.map((e) => e.name).toList();
                final stageList =
                    dynamicStages.isNotEmpty ? dynamicStages : _defaultLifecycleStages;

                final stageItems = [
                  DropdownSearchItem<String>(
                    value: 'Select a stage',
                    label: 'Select a stage',
                  ),
                  ...stageList.map(
                    (stage) => DropdownSearchItem<String>(
                      value: stage,
                      label: stage,
                    ),
                  ),
                  DropdownSearchItem<String>(
                    value: 'Other (Custom stage)',
                    label: 'Other (Custom stage)',
                  ),
                ];

                return _buildFilterPill<String>(
                  title: 'Lifecycle stage',
                  value: contactProvider.selectedStage ?? 'Select a stage',
                  items: stageItems,
                  onChanged: (val) {
                    context.read<ContactProvider>().setLifecycleStageFilter(val);
                  },
                );
              },
            ),
            const SizedBox(width: 14),

            // 3. Lead status
            Builder(
              builder: (context) {
                final dynamicOptions = masterProvider.contactLeadStatusOptions;
                final list = dynamicOptions.isNotEmpty
                    ? dynamicOptions.map((e) => e.label).toList()
                    : _defaultLeadStatuses;

                final statusItems = [
                  DropdownSearchItem<String>(
                    value: 'Select a status',
                    label: 'Select a status',
                  ),
                  ...list.map(
                    (st) => DropdownSearchItem<String>(
                      value: st,
                      label: st,
                    ),
                  ),
                ];

                return _buildFilterPill<String>(
                  title: 'Lead status',
                  value: contactProvider.selectedLeadStatus ?? 'Select a status',
                  items: statusItems,
                  onChanged: (val) {
                    context.read<ContactProvider>().setLeadStatusFilter(val);
                  },
                );
              },
            ),
            const SizedBox(width: 14),

            // 4. Create date
            _buildFilterPill<String>(
              title: 'Create date',
              value: contactProvider.selectedCreateDate ?? 'All time',
              items: _createDateOptions
                  .map(
                    (d) => DropdownSearchItem<String>(
                      value: d,
                      label: d,
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                context.read<ContactProvider>().setCreateDateFilter(val);
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
              selectedItem.value != 'Select a stage' &&
              selectedItem.value != 'Select a status';

          final String displayTitle = isFiltered ? '$title: ${selectedItem.label}' : title;

          return InkWell(
            onTap: () async {
              final result = await showModalBottomSheet<T>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (modalContext) => _InlineDropdownSearchModal<T>(
                  title: title,
                  items: items,
                  selectedValue: state.value,
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
}

class _InlineDropdownSearchModal<T> extends StatefulWidget {
  final String title;
  final List<DropdownSearchItem<T>> items;
  final T? selectedValue;

  const _InlineDropdownSearchModal({
    required this.title,
    required this.items,
    this.selectedValue,
  });

  @override
  State<_InlineDropdownSearchModal<T>> createState() => _InlineDropdownSearchModalState<T>();
}

class _InlineDropdownSearchModalState<T> extends State<_InlineDropdownSearchModal<T>> {
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
          final subtextMatches = item.subtext?.toLowerCase().contains(query.toLowerCase()) ?? false;
          return labelMatches || subtextMatches;
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
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

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Search Field
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: _filterItems,
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
          ),

          // Item List
          Expanded(
            child: ListView.separated(
              itemCount: _filteredItems.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final item = _filteredItems[index];
                final isSelected = item.value == widget.selectedValue;

                return ListTile(
                  title: Text(
                    item.label,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? const Color(0xFF00A884) : const Color(0xFF1E293B),
                    ),
                  ),
                  subtitle: item.subtext != null
                      ? Text(
                          item.subtext!,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                        )
                      : null,
                  trailing: isSelected
                      ? const Icon(Icons.check_rounded, color: Color(0xFF00A884), size: 18)
                      : null,
                  onTap: () => Navigator.pop(context, item.value),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
