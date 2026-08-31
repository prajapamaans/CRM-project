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
  final VoidCallback? onClearTap;
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
  final String? allLabel;
  final String? mineLabel;

  const SearchAndFilterBar({
    super.key,
    required this.searchHint,
    this.onSearchChanged,
    this.onSegmentChanged,
    this.currentSort,
    this.onSortChanged,
    this.onFilterTap,
    this.onClearTap,
    this.onRefreshTap,
    this.onImportTap,
    this.onExportTap,
    this.isFilterActive = false,
    this.isFilterExpanded = false,
    this.onToggleFilterExpanded,
    this.filterOptions,
    this.selectedStage,
    this.onStageSelected,
    this.allLabel,
    this.mineLabel,
  });

  @override
  State<SearchAndFilterBar> createState() => _SearchAndFilterBarState();
}

class _SearchAndFilterBarState extends State<SearchAndFilterBar> {
  int _selectedSegment = 0; // 0 for All, 1 for Mine

  /// The field was uncontrolled, so Clear dropped the search term from state
  /// while the typed text stayed on screen — the bar then showed a filter that
  /// was no longer being applied.
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Every screen's Clear drops its search term along with its filters, so the
  /// visible text is cleared here to match. The search callback fires with an
  /// empty string first, so a screen that reloads on search change is not left
  /// holding the old term.
  void _handleClear() {
    if (_searchController.text.isNotEmpty) {
      _searchController.clear();
      widget.onSearchChanged?.call('');
    }
    final clear = widget.onClearTap ?? widget.onFilterTap ?? widget.onToggleFilterExpanded;
    clear?.call();
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
            controller: _searchController,
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

        // 2. Segmented Pill & Filter Icon Button Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Segment Switch (All / Mine) inside a pill box
            Flexible(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSegmentItem(index: 0, label: widget.allLabel ?? 'All'),
                      _buildSegmentItem(index: 1, label: widget.mineLabel ?? 'Mine'),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (active || widget.isFilterActive || widget.isFilterExpanded) ...[
                  InkWell(
                    onTap: _handleClear,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F0),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFFCCC7)),
                      ),
                      child: Text(
                        'Clear',
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFFF4D4F),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                // Direct Filter Icon Button (Opens existing Filter UI)
                GestureDetector(
                  onTap: () {
                    if (widget.onToggleFilterExpanded != null) {
                      widget.onToggleFilterExpanded!();
                    } else if (widget.onFilterTap != null) {
                      widget.onFilterTap!();
                    }
                  },
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
                      Icons.tune_rounded,
                      size: 20,
                      color: active ? const Color(0xFF00A884) : const Color(0xFF4B5563),
                    ),
                  ),
                ),
              ],
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
