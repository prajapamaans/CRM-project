import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/searchable_dropdown_form_field.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../companies/presentation/providers/company_provider.dart';
import '../../../contacts/presentation/providers/contact_provider.dart';
import '../../../deals/presentation/providers/deal_provider.dart';

class TaskInlineFilterSection extends StatelessWidget {
  final String? selectedOwnerId;
  final String? selectedCreateDate;
  final String? selectedStatus;
  final String? selectedPriority;
  final String? selectedCompany;
  final String? selectedContact;
  final String? selectedDeal;

  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> companies;
  final List<Map<String, dynamic>> contacts;
  final List<Map<String, dynamic>> deals;
  final List<String> taskStatuses;
  final List<String> taskPriorities;

  final ValueChanged<String?> onOwnerChanged;
  final ValueChanged<String?> onCreateDateChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onPriorityChanged;
  final ValueChanged<String?> onCompanyChanged;
  final ValueChanged<String?> onContactChanged;
  final ValueChanged<String?> onDealChanged;

  const TaskInlineFilterSection({
    super.key,
    required this.selectedOwnerId,
    required this.selectedCreateDate,
    required this.selectedStatus,
    this.selectedPriority,
    required this.selectedCompany,
    required this.selectedContact,
    required this.selectedDeal,
    required this.users,
    required this.companies,
    required this.contacts,
    required this.deals,
    required this.taskStatuses,
    this.taskPriorities = const [],
    required this.onOwnerChanged,
    required this.onCreateDateChanged,
    required this.onStatusChanged,
    required this.onPriorityChanged,
    required this.onCompanyChanged,
    required this.onContactChanged,
    required this.onDealChanged,
  });

  static const List<String> _createDateOptions = [
    'All time',
    'Today',
    'Yesterday',
    'This week',
    'This month',
    'This quarter',
    'This year',
  ];

  static const List<String> _defaultPriorities = [
    'ALL PRIORITIES',
    'NONE',
    'LOW',
    'MEDIUM',
    'HIGH',
  ];

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            // 1. Task owner filter pill
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
                  ...users.map(
                    (u) {
                      final fn = u['firstName'] ?? u['first_name'] ?? '';
                      final ln = u['lastName'] ?? u['last_name'] ?? '';
                      final name = '$fn $ln'.trim();
                      return DropdownSearchItem(
                        value: (u['id'] ?? u['_id'] ?? '').toString(),
                        label: name.isNotEmpty ? name : (u['email'] ?? 'User').toString(),
                        subtext: u['email']?.toString(),
                      );
                    },
                  ),
                ];

                return _buildFilterPill<String>(
                  context: context,
                  title: 'Task owner',
                  value: selectedOwnerId ?? 'all',
                  items: ownerItems,
                  onChanged: onOwnerChanged,
                );
              },
            ),
            const SizedBox(width: 16),

            // 2. Create date filter pill
            _buildFilterPill<String>(
              context: context,
              title: 'Create date',
              value: selectedCreateDate ?? 'All time',
              items: _createDateOptions
                  .map((d) => DropdownSearchItem<String>(value: d, label: d))
                  .toList(),
              onChanged: onCreateDateChanged,
            ),
            const SizedBox(width: 16),

            // 3. Status filter pill
            _buildFilterPill<String>(
              context: context,
              title: 'Status',
              value: selectedStatus ?? 'All statuses',
              items: [
                DropdownSearchItem<String>(value: 'All statuses', label: 'All statuses'),
                if (taskStatuses.isNotEmpty)
                  ...taskStatuses.map((s) => DropdownSearchItem<String>(value: s, label: s))
                else ...[
                  DropdownSearchItem<String>(value: 'Pending', label: 'Pending'),
                  DropdownSearchItem<String>(value: 'Completed', label: 'Completed'),
                  DropdownSearchItem<String>(value: 'Reopened', label: 'Reopened'),
                ]
              ],
              onChanged: onStatusChanged,
            ),
            const SizedBox(width: 16),

            // 4. Priority filter pill (Matching screenshot)
            _buildFilterPill<String>(
              context: context,
              title: 'Priority',
              menuTitle: 'TASK PRIORITY',
              value: selectedPriority ?? 'ALL PRIORITIES',
              items: [
                if (taskPriorities.isNotEmpty) ...[
                  DropdownSearchItem<String>(value: 'ALL PRIORITIES', label: 'ALL PRIORITIES'),
                  ...taskPriorities.map(
                    (p) => DropdownSearchItem<String>(
                      value: p.toUpperCase(),
                      label: p.toUpperCase(),
                    ),
                  )
                ] else
                  ..._defaultPriorities.map(
                    (p) => DropdownSearchItem<String>(
                      value: p,
                      label: p,
                    ),
                  )
              ],
              onChanged: onPriorityChanged,
            ),
            const SizedBox(width: 16),

            // 5. Company filter pill
            Builder(
              builder: (context) {
                final companyProvider = context.watch<CompanyProvider>();
                final providerCompanies = companyProvider.companies;

                final List<String> companyNames = [];
                final Set<String> added = {};

                for (final c in providerCompanies) {
                  final name = c.name.trim();
                  if (name.isNotEmpty && !added.contains(name)) {
                    added.add(name);
                    companyNames.add(name);
                  }
                }

                for (final c in companies) {
                  final name = (c['name'] ?? c['companyName'] ?? c['company_name'] ?? c['title'] ?? '').toString().trim();
                  if (name.isNotEmpty && !added.contains(name)) {
                    added.add(name);
                    companyNames.add(name);
                  }
                }

                return _buildFilterPill<String>(
                  context: context,
                  title: 'Company',
                  value: selectedCompany ?? 'All companies',
                  items: [
                    DropdownSearchItem<String>(value: 'All companies', label: 'All companies'),
                    ...companyNames.map(
                      (name) => DropdownSearchItem<String>(
                        value: name,
                        label: name,
                      ),
                    )
                  ],
                  onChanged: onCompanyChanged,
                );
              },
            ),
            const SizedBox(width: 16),

            // 6. Contact filter pill
            Builder(
              builder: (context) {
                final contactProvider = context.watch<ContactProvider>();
                final providerContacts = contactProvider.contacts;

                final List<String> contactNames = [];
                final Set<String> added = {};

                for (final c in providerContacts) {
                  final fn = (c.firstName ?? '').trim();
                  final ln = (c.lastName ?? '').trim();
                  final name = '$fn $ln'.trim();
                  if (name.isNotEmpty && !added.contains(name)) {
                    added.add(name);
                    contactNames.add(name);
                  }
                }

                for (final c in contacts) {
                  final fn = (c['firstName'] ?? c['first_name'] ?? '').toString().trim();
                  final ln = (c['lastName'] ?? c['last_name'] ?? '').toString().trim();
                  final name = ('$fn $ln').trim().isNotEmpty
                      ? ('$fn $ln').trim()
                      : (c['name'] ?? c['fullName'] ?? c['email'] ?? '').toString().trim();
                  if (name.isNotEmpty && !added.contains(name)) {
                    added.add(name);
                    contactNames.add(name);
                  }
                }

                return _buildFilterPill<String>(
                  context: context,
                  title: 'Contact',
                  value: selectedContact ?? 'All contacts',
                  items: [
                    DropdownSearchItem<String>(value: 'All contacts', label: 'All contacts'),
                    ...contactNames.map(
                      (name) => DropdownSearchItem<String>(
                        value: name,
                        label: name,
                      ),
                    )
                  ],
                  onChanged: onContactChanged,
                );
              },
            ),
            const SizedBox(width: 16),

            // 7. Deal filter pill
            Builder(
              builder: (context) {
                final dealProvider = context.watch<DealProvider>();
                final providerDeals = dealProvider.deals;

                final List<String> dealTitles = [];
                final Set<String> added = {};

                for (final d in providerDeals) {
                  final title = d.title.trim();
                  if (title.isNotEmpty && !added.contains(title)) {
                    added.add(title);
                    dealTitles.add(title);
                  }
                }

                for (final d in deals) {
                  final title = (d['title'] ?? d['name'] ?? d['dealName'] ?? d['deal_name'] ?? '').toString().trim();
                  if (title.isNotEmpty && !added.contains(title)) {
                    added.add(title);
                    dealTitles.add(title);
                  }
                }

                return _buildFilterPill<String>(
                  context: context,
                  title: 'Deal',
                  value: selectedDeal ?? 'All deals',
                  items: [
                    DropdownSearchItem<String>(value: 'All deals', label: 'All deals'),
                    ...dealTitles.map(
                      (title) => DropdownSearchItem<String>(
                        value: title,
                        label: title,
                      ),
                    )
                  ],
                  onChanged: onDealChanged,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill<T>({
    required BuildContext context,
    required String title,
    String? menuTitle,
    required T value,
    required List<DropdownSearchItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final selectedItem = items.cast<DropdownSearchItem<T>?>().firstWhere(
          (item) => item?.value == value,
          orElse: () => null,
        );

    final bool isFiltered = selectedItem != null &&
        selectedItem.value != 'all' &&
        selectedItem.value != 'All time' &&
        selectedItem.value != 'All statuses' &&
        selectedItem.value != 'ALL PRIORITIES' &&
        selectedItem.value != 'All priorities' &&
        selectedItem.value != 'All companies' &&
        selectedItem.value != 'All contacts' &&
        selectedItem.value != 'All deals';

    final String displayTitle = isFiltered ? '$title: ${selectedItem.label}' : title;

    return GestureDetector(
      onTapDown: (details) async {
        final position = RelativeRect.fromLTRB(
          details.globalPosition.dx,
          details.globalPosition.dy + 10,
          details.globalPosition.dx + 220,
          details.globalPosition.dy + 300,
        );

        final selected = await showMenu<T>(
          context: context,
          position: position,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 6,
          items: [
            PopupMenuItem<T>(
              enabled: false,
              height: 36,
              child: Text(
                menuTitle ?? 'FILTER BY ${title.toUpperCase()}',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF475569),
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const PopupMenuDivider(height: 1),
            ...items.map((item) {
              final isSelected = item.value == value;
              return PopupMenuItem<T>(
                value: item.value,
                height: 40,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.label,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? const Color(0xFF00A884) : const Color(0xFF1E293B),
                        ),
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
              );
            }),
          ],
        );

        if (selected != null) {
          onChanged(selected);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayTitle,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: isFiltered ? FontWeight.w700 : FontWeight.w600,
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
