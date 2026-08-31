import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/master_data_provider.dart';
import '../../../../core/utils/msp_field_utils.dart';
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
  void initState() {
    super.initState();
    // The filter row has an MSP pill — make sure GET /api/msp-options ran.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MasterDataProvider>().ensureMspOptionsLoaded();
    });
  }

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
            const SizedBox(width: 14),

            // 5. MSP Options from API
            Builder(
              builder: (context) {
                final mspList = MspFieldUtils.optionsWith(
                  masterProvider,
                  contactProvider.selectedMsp == 'All MSPs'
                      ? null
                      : contactProvider.selectedMsp,
                );

                final mspItems = [
                  DropdownSearchItem<String>(
                    value: 'All MSPs',
                    label: 'All MSPs',
                  ),
                  ...mspList.map(
                    (msp) => DropdownSearchItem<String>(
                      value: msp,
                      label: msp,
                    ),
                  ),
                  DropdownSearchItem<String>(
                    value: MspFieldUtils.addCustomMspValue,
                    label: MspFieldUtils.addCustomMspLabel,
                  ),
                ];

                return _buildFilterPill<String>(
                  title: 'MSP',
                  value: contactProvider.selectedMsp ?? 'All MSPs',
                  items: mspItems,
                  onChanged: (val) async {
                    if (val == MspFieldUtils.addCustomMspValue) {
                      final newMsp = await MspFieldUtils.showAddCustomMspDialog(context);
                      if (newMsp != null && context.mounted) {
                        context.read<ContactProvider>().setMspFilter(newMsp);
                      }
                    } else {
                      context.read<ContactProvider>().setMspFilter(val);
                    }
                  },
                );
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
              selectedItem.value != 'All MSPs' &&
              selectedItem.value != 'Select a stage' &&
              selectedItem.value != 'Select a status';

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
                  child: _InlineDropdownSearchModal<T>(
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
