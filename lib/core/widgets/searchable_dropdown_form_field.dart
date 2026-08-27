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
                final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
                if (renderBox == null) return;
                final size = renderBox.size;
                final offset = renderBox.localToGlobal(Offset.zero);

                final selected = await showDialog<T>(
                  context: context,
                  barrierDismissible: true,
                  barrierColor: Colors.black26,
                  builder: (dialogCtx) {
                    final mediaQuery = MediaQuery.of(dialogCtx);
                    final screenHeight = mediaQuery.size.height;
                    final dropdownHeight = items.length > 5 ? 260.0 : (items.length * 48.0 + 60.0).clamp(120.0, 260.0);
                    final spaceBelow = screenHeight - offset.dy - size.height;
                    final showAbove = spaceBelow < dropdownHeight && offset.dy > dropdownHeight;
                    final topPos = showAbove
                        ? (offset.dy - dropdownHeight - 4).clamp(10.0, screenHeight - 100.0)
                        : (offset.dy + size.height + 4).clamp(10.0, screenHeight - dropdownHeight - 10.0);

                    return Stack(
                      children: [
                        Positioned(
                          left: offset.dx.clamp(8.0, mediaQuery.size.width - size.width - 8.0),
                          top: topPos,
                          width: size.width,
                          child: Material(
                            elevation: 8,
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.white,
                            shadowColor: Colors.black26,
                            child: Container(
                              height: dropdownHeight,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                              ),
                              child: _SearchableDropdownModal<T>(
                                title: hintText,
                                items: items,
                                selectedValue: state.value,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
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
      _SearchableDropdownModalState<T>();
}

class _SearchableDropdownModalState<T> extends State<_SearchableDropdownModal<T>> {
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

    return Column(
      children: [
        if (widget.items.length > 3)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim();
                  });
                },
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1E293B),
                ),
                decoration: InputDecoration(
                  hintText: 'Search ${widget.title}...',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF94A3B8),
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF94A3B8),
                    size: 16,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        // Items list
        Expanded(
          child: filteredItems.isEmpty
              ? Center(
                  child: Text(
                    'No options found',
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
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
                          horizontal: 14,
                          vertical: 10,
                        ),
                        color: isSelected ? const Color(0xFFF0FDF4) : Colors.transparent,
                        child: Row(
                          children: [
                            if (item.dotColor != null) ...[
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: item.dotColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.label,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.5,
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
                                        fontSize: 11,
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
                                size: 16,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
