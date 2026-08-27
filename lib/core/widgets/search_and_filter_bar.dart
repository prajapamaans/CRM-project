import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_theme.dart';
import '../../features/contacts/presentation/providers/contact_provider.dart';

class SearchAndFilterBar extends StatefulWidget {
  final String searchHint;
  final ValueChanged<String>? onSearchChanged;
  final ValueChanged<int>? onSegmentChanged;

  // Optional 3-dot popup menu & sorting
  final ContactSortOption? currentSort;
  final ValueChanged<ContactSortOption>? onSortChanged;
  final VoidCallback? onFilterTap;
  final VoidCallback? onRefreshTap;
  final VoidCallback? onImportTap;
  final VoidCallback? onExportTap;
  final bool isFilterActive;
  final bool isFilterExpanded;
  final VoidCallback? onToggleFilterExpanded;

  // Optional legacy filter options support for other screens
  final List<String>? filterOptions;
  final String? selectedStage;
  final ValueChanged<String>? onStageSelected;

  const SearchAndFilterBar({
    super.key,
    required this.searchHint,
    this.onSearchChanged,
    this.onSegmentChanged,
    this.currentSort,
    this.onSortChanged,
    this.onFilterTap,
    this.onRefreshTap,
    this.onImportTap,
    this.onExportTap,
    this.isFilterActive = false,
    this.isFilterExpanded = false,
    this.onToggleFilterExpanded,
    this.filterOptions,
    this.selectedStage,
    this.onStageSelected,
  });

  @override
  State<SearchAndFilterBar> createState() => _SearchAndFilterBarState();
}

class _SearchAndFilterBarState extends State<SearchAndFilterBar> {
  int _selectedSegment = 0; // 0 for All, 1 for Mine

  void _showSortMenu(BuildContext context, TapDownDetails details) async {
    final position = RelativeRect.fromLTRB(
      details.globalPosition.dx - 100,
      details.globalPosition.dy,
      details.globalPosition.dx,
      details.globalPosition.dy + 100,
    );

    final selected = await showMenu<ContactSortOption>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 6,
      items: [
        PopupMenuItem<ContactSortOption>(
          enabled: false,
          height: 32,
          child: Text(
            'SORT BY',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF94A3B8),
              letterSpacing: 0.8,
            ),
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<ContactSortOption>(
          value: ContactSortOption.aToZ,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'A to Z',
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  fontWeight: widget.currentSort == ContactSortOption.aToZ
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: const Color(0xFF1E293B),
                ),
              ),
              if (widget.currentSort == ContactSortOption.aToZ)
                const Icon(Icons.check_rounded, color: Color(0xFF00A884), size: 18),
            ],
          ),
        ),
        PopupMenuItem<ContactSortOption>(
          value: ContactSortOption.zToA,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Z to A',
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  fontWeight: widget.currentSort == ContactSortOption.zToA
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: const Color(0xFF1E293B),
                ),
              ),
              if (widget.currentSort == ContactSortOption.zToA)
                const Icon(Icons.check_rounded, color: Color(0xFF00A884), size: 18),
            ],
          ),
        ),
        PopupMenuItem<ContactSortOption>(
          value: ContactSortOption.mostRecent,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Most recent',
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  fontWeight: widget.currentSort == ContactSortOption.mostRecent
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: const Color(0xFF1E293B),
                ),
              ),
              if (widget.currentSort == ContactSortOption.mostRecent)
                const Icon(Icons.check_rounded, color: Color(0xFF00A884), size: 18),
            ],
          ),
        ),
      ],
    );

    if (selected != null && widget.onSortChanged != null) {
      widget.onSortChanged!(selected);
    }
  }

  void _showThreeDotMenu(BuildContext context, TapDownDetails details) async {
    final position = RelativeRect.fromLTRB(
      details.globalPosition.dx - 140,
      details.globalPosition.dy,
      details.globalPosition.dx,
      details.globalPosition.dy + 100,
    );

    final selectedAction = await showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 6,
      items: [
        PopupMenuItem<String>(
          value: 'sort',
          child: Row(
            children: [
              const Icon(Icons.sort_rounded, color: Color(0xFF64748B), size: 18),
              const SizedBox(width: 10),
              Text(
                'Sort',
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'filter',
          child: Row(
            children: [
              Icon(
                Icons.tune_rounded,
                color: widget.isFilterActive ? const Color(0xFF00A884) : const Color(0xFF64748B),
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                'Filter',
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  fontWeight: widget.isFilterActive || widget.isFilterExpanded
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: widget.isFilterActive || widget.isFilterExpanded
                      ? const Color(0xFF00A884)
                      : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (!context.mounted) return;

    if (selectedAction == 'sort') {
      _showSortMenu(context, details);
    } else if (selectedAction == 'filter') {
      if (widget.onToggleFilterExpanded != null) {
        widget.onToggleFilterExpanded!();
      } else if (widget.onFilterTap != null) {
        widget.onFilterTap!();
      }
    } else if (selectedAction == 'import') {
      if (widget.onImportTap != null) widget.onImportTap!();
    } else if (selectedAction == 'export') {
      if (widget.onExportTap != null) widget.onExportTap!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.isFilterActive || widget.isFilterExpanded;

    return Column(
      children: [
        // 1. Search TextField Input
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          ),
          child: TextField(
            onChanged: widget.onSearchChanged,
            style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: widget.searchHint,
              hintStyle: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xFF9CA3AF),
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFF9CA3AF),
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 11),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 2. Segmented Pill & 3-Dot Button Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Segment Switch (All / Mine) inside a pill box
            Container(
              height: 36,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
              ),
              child: Row(
                children: [
                  _buildSegmentItem(index: 0, label: 'All'),
                  _buildSegmentItem(index: 1, label: 'Mine'),
                ],
              ),
            ),

            // 3-Dot Menu Icon Button
            GestureDetector(
              onTapDown: (details) => _showThreeDotMenu(context, details),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: active ? const Color(0xFFE6F4F1) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: active ? const Color(0xFF00A884) : const Color(0xFFD1D5DB),
                    width: active ? 1.5 : 1,
                  ),
                ),
                child: Icon(
                  Icons.more_vert_rounded,
                  size: 20,
                  color: active ? const Color(0xFF00A884) : const Color(0xFF4B5563),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSegmentItem({required int index, required String label}) {
    final bool isSelected = _selectedSegment == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSegment = index;
        });
        if (widget.onSegmentChanged != null) {
          widget.onSegmentChanged!(index);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  )
                ]
              : [],
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? const Color(0xFF111827) : const Color(0xFF6B7280),
            ),
          ),
        ),
      ),
    );
  }
}
