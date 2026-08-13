import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DropdownSearchItem<T> {
  final T value;
  final String label;
  final String? subtext;
  final Color? dotColor;

  DropdownSearchItem({
    required this.value,
    required this.label,
    this.subtext,
    this.dotColor,
  });
}

class SearchableDropdownFormField<T> extends FormField<T> {
  final String hintText;
  final List<DropdownSearchItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final Widget Function(BuildContext, DropdownSearchItem<T>)? itemBuilder;

  SearchableDropdownFormField({
    super.key,
    super.initialValue,
    super.validator,
    super.onSaved,
    required this.hintText,
    required this.items,
    this.onChanged,
    this.itemBuilder,
    InputDecoration? decoration,
  }) : super(
          builder: (FormFieldState<T> state) {
            final context = state.context;
            final selectedItem = items.cast<DropdownSearchItem<T>?>().firstWhere(
                  (item) => item?.value == state.value,
                  orElse: () => null,
                );

            final effectiveDecoration = (decoration ??
                    InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                        borderSide:
                            const BorderSide(color: Color(0xFF00A884), width: 1.5),
                      ),
                    ))
                .copyWith(
              errorText: state.errorText,
            );

            return InkWell(
              onTap: () async {
                final selected = await showModalBottomSheet<T>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (ctx) => _SearchableDropdownModal<T>(
                    title: hintText,
                    items: items,
                    selectedValue: state.value,
                  ),
                );

                if (selected != null || state.value != null) {
                  state.didChange(selected);
                  if (onChanged != null) {
                    onChanged(selected);
                  }
                }
              },
              child: InputDecorator(
                decoration: effectiveDecoration,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: selectedItem != null
                          ? Row(
                              children: [
                                if (selectedItem.dotColor != null) ...[
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: selectedItem.dotColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: Text(
                                    selectedItem.label,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF1E293B),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              hintText,
                              style: GoogleFonts.poppins(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF94A3B8),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF64748B),
                      size: 20,
                    ),
                  ],
                ),
              ),
            );
          },
        );
}

class _SearchableDropdownModal<T> extends StatefulWidget {
  final String title;
  final List<DropdownSearchItem<T>> items;
  final T? selectedValue;

  const _SearchableDropdownModal({
    required this.title,
    required this.items,
    this.selectedValue,
  });

  @override
  State<_SearchableDropdownModal<T>> createState() =>
      __SearchableDropdownModalState<T>();
}

class __SearchableDropdownModalState<T> extends State<_SearchableDropdownModal<T>> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredItems = widget.items.where((item) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final labelMatch = item.label.toLowerCase().contains(q);
      final subMatch = item.subtext?.toLowerCase().contains(q) ?? false;
      return labelMatch || subMatch;
    }).toList();

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
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Search input box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
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
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1E293B),
                ),
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
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
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Items list
          Expanded(
            child: filteredItems.isEmpty
                ? Center(
                    child: Text(
                      'No options found',
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filteredItems.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      final isSelected = item.value == widget.selectedValue;

                      return InkWell(
                        onTap: () {
                          Navigator.of(context).pop(item.value);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          color: isSelected ? const Color(0xFFF0FDF4) : Colors.transparent,
                          child: Row(
                            children: [
                              if (item.dotColor != null) ...[
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: item.dotColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.label,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13.5,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? const Color(0xFF00A884)
                                            : const Color(0xFF1E293B),
                                      ),
                                    ),
                                    if (item.subtext != null &&
                                        item.subtext!.isNotEmpty)
                                      Text(
                                        item.subtext!,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
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
