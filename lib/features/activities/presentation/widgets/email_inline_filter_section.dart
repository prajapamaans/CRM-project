import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/searchable_dropdown_form_field.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';

class EmailInlineFilterSection extends StatelessWidget {
  final String? selectedOwnerId;
  final String? selectedCreateDate;
  final String? selectedStatus;
  final ValueChanged<String?> onOwnerChanged;
  final ValueChanged<String?> onCreateDateChanged;
  final ValueChanged<String?> onStatusChanged;

  const EmailInlineFilterSection({
    super.key,
    required this.selectedOwnerId,
    required this.selectedCreateDate,
    required this.selectedStatus,
    required this.onOwnerChanged,
    required this.onCreateDateChanged,
    required this.onStatusChanged,
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

  static const List<String> _statusOptions = [
    'All statuses',
    'Scheduled',
    'Completed',
    'Cancelled',
    'Logged',
    'Sent',
    'Pending',
  ];

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final teamMembers = authProvider.teamMembers;

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            // 1. Email owner filter pill
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
                  context: context,
                  title: 'Email owner',
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
                  .map(
                    (d) => DropdownSearchItem<String>(
                      value: d,
                      label: d,
                    ),
                  )
                  .toList(),
              onChanged: onCreateDateChanged,
            ),
            const SizedBox(width: 16),

            // 3. Status filter pill
            _buildFilterPill<String>(
              context: context,
              title: 'Status',
              value: selectedStatus ?? 'All statuses',
              items: _statusOptions
                  .map(
                    (s) => DropdownSearchItem<String>(
                      value: s,
                      label: s,
                    ),
                  )
                  .toList(),
              onChanged: onStatusChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill<T>({
    required BuildContext context,
    required String title,
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
        selectedItem.value != 'All statuses';

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
                'FILTER BY ${title.toUpperCase()}',
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
