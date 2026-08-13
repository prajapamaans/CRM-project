import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/master_data_provider.dart';
import '../../../../core/widgets/searchable_dropdown_form_field.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../providers/contact_provider.dart';

class ContactFilterSheet extends StatefulWidget {
  const ContactFilterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ContactFilterSheet(),
    );
  }

  @override
  State<ContactFilterSheet> createState() => _ContactFilterSheetState();
}

class _ContactFilterSheetState extends State<ContactFilterSheet> {
  late String? _selectedOwnerId;
  late String? _selectedLifecycleStage;
  late String? _selectedLeadStatus;
  late String? _selectedCreateDate;

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
    final provider = context.read<ContactProvider>();
    _selectedOwnerId = provider.selectedOwnerId;
    _selectedLifecycleStage = provider.selectedStage;
    _selectedLeadStatus = provider.selectedLeadStatus;
    _selectedCreateDate = provider.selectedCreateDate;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final masterProvider = context.watch<MasterDataProvider>();
    final teamMembers = authProvider.teamMembers;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Handle bar
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
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filter Contacts',
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedOwnerId = null;
                      _selectedLifecycleStage = null;
                      _selectedLeadStatus = null;
                      _selectedCreateDate = null;
                    });
                    context.read<ContactProvider>().clearAllFilters();
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Reset All',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Inline Quick Filter Bar (Image 2 style: Contact owner v  Lifecycle stage v  Lead status v  Create date v)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildQuickFilterTab('Contact owner'),
                  const SizedBox(width: 14),
                  _buildQuickFilterTab('Lifecycle stage'),
                  const SizedBox(width: 14),
                  _buildQuickFilterTab('Lead status'),
                  const SizedBox(width: 14),
                  _buildQuickFilterTab('Create date'),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Detailed Filter Form List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // 1. Contact owner (fetch users)
                _buildLabel('Contact owner'),
                const SizedBox(height: 6),
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

                    return SearchableDropdownFormField<String>(
                      initialValue: _selectedOwnerId ?? 'all',
                      hintText: 'Select contact owner',
                      items: ownerItems,
                      onChanged: (val) {
                        setState(() {
                          _selectedOwnerId = val;
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),

                // 2. Lifecycle stage (fetch all stages matching screenshot 4 & 5)
                _buildLabel('Lifecycle stage'),
                const SizedBox(height: 6),
                Builder(
                  builder: (context) {
                    final dynamicStages = masterProvider.contactLifecycleStages
                        .map((e) => e.name)
                        .toList();
                    final stageList = dynamicStages.isNotEmpty
                        ? dynamicStages
                        : _defaultLifecycleStages;

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

                    return SearchableDropdownFormField<String>(
                      initialValue: _selectedLifecycleStage ?? 'Select a stage',
                      hintText: 'Select a stage',
                      items: stageItems,
                      onChanged: (val) {
                        setState(() {
                          _selectedLifecycleStage = val;
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),

                // 3. Lead status (all lead status matching screenshot 3)
                _buildLabel('Lead status'),
                const SizedBox(height: 6),
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

                    return SearchableDropdownFormField<String>(
                      initialValue: _selectedLeadStatus ?? 'Select a status',
                      hintText: 'Select a status',
                      items: statusItems,
                      onChanged: (val) {
                        setState(() {
                          _selectedLeadStatus = val;
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),

                // 4. Create date
                _buildLabel('Create date'),
                const SizedBox(height: 6),
                SearchableDropdownFormField<String>(
                  initialValue: _selectedCreateDate ?? 'All time',
                  hintText: 'Select date range',
                  items: _createDateOptions
                      .map(
                        (d) => DropdownSearchItem<String>(
                          value: d,
                          label: d,
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedCreateDate = val;
                    });
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // Footer Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final provider = context.read<ContactProvider>();
                      provider.setOwnerFilter(_selectedOwnerId);
                      provider.setLifecycleStageFilter(_selectedLifecycleStage);
                      provider.setLeadStatusFilter(_selectedLeadStatus);
                      provider.setCreateDateFilter(_selectedCreateDate);
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A884),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Apply Filters',
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFilterTab(String title) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 13.5,
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
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF1E293B),
      ),
    );
  }
}
