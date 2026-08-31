import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const double _kRowHeight = 44.0;
const double _kMinMenuWidth = 240.0;
const double _kMenuVerticalPadding = 6.0;
const Color _kMenuBackground = Color(0xFFEEF3F0);

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
                    final screenWidth = mediaQuery.size.width;

                    const double edgeGap = 12.0;
                    final topLimit = mediaQuery.padding.top + edgeGap;
                    final bottomLimit = screenHeight - mediaQuery.padding.bottom - edgeGap;

                    final menuWidth = size.width
                        .clamp(_kMinMenuWidth, screenWidth - edgeGap * 2)
                        .toDouble();

                    final hasSearch = items.length > 5;
                    final headerHeight = hasSearch ? 48.0 : 0.0;
                    final wantedHeight = items.length * _kRowHeight + _kMenuVerticalPadding * 2 + headerHeight;
                    final maxMenuHeight = (bottomLimit - topLimit).clamp(160.0, double.infinity);
                    final menuHeight = wantedHeight.clamp(100.0, maxMenuHeight).toDouble();

                    final spaceBelow = bottomLimit - (offset.dy + size.height + 4);
                    final spaceAbove = (offset.dy - 4) - topLimit;
                    final openUpwards = spaceBelow < menuHeight && spaceAbove > spaceBelow;

                    final idealTop = openUpwards
                        ? (offset.dy - menuHeight - 4)
                        : (offset.dy + size.height + 4);

                    final top = idealTop.clamp(topLimit, (bottomLimit - menuHeight).clamp(topLimit, double.infinity)).toDouble();

                    return Stack(
                      children: [
                        Positioned(
                          left: offset.dx
                              .clamp(edgeGap, (screenWidth - menuWidth - edgeGap).clamp(edgeGap, double.infinity))
                              .toDouble(),
                          top: top,
                          width: menuWidth,
                          child: Material(
                            elevation: 6,
                            borderRadius: BorderRadius.circular(10),
                            color: _kMenuBackground,
                            shadowColor: Colors.black26,
                            child: Container(
                              height: menuHeight,
                              decoration: BoxDecoration(
                                color: _kMenuBackground,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFD3E0D8), width: 1),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: _DropdownMenuPanel<T>(
                                  title: hintText,
                                  items: items,
                                  selectedValue: state.value,
                                ),
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

class _DropdownMenuPanel<T> extends StatefulWidget {
  final String title;
  final List<DropdownSearchItem<T>> items;
  final T? selectedValue;

  const _DropdownMenuPanel({
    required this.title,
    required this.items,
    this.selectedValue,
  });

  @override
  State<_DropdownMenuPanel<T>> createState() => _DropdownMenuPanelState<T>();
}

class _DropdownMenuPanelState<T> extends State<_DropdownMenuPanel<T>> {
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
      color: _kMenuBackground,
      child: Column(
        children: [
          if (widget.items.length > 5) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFD3E0D8)),
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
            const Divider(height: 1, color: Color(0xFFDDE7E1)),
          ],
          Expanded(
            child: filteredItems.isEmpty
                ? Center(
                    child: Text(
                      'No options found',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  )
                : Scrollbar(
                    thumbVisibility: true,
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: _kMenuVerticalPadding),
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        final isSelected = item.value == widget.selectedValue;
                        final hasSubtext = item.subtext != null && item.subtext!.isNotEmpty;

                        return InkWell(
                          onTap: () => Navigator.of(context).pop(item.value),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: _kRowHeight),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            color: isSelected ? const Color(0xFFDDEAE3) : Colors.transparent,
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
                                  const SizedBox(width: 10),
                                ],
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.label,
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                          color: isSelected
                                              ? const Color(0xFF00A884)
                                              : const Color(0xFF1E293B),
                                        ),
                                      ),
                                      if (hasSubtext)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(
                                            item.subtext!,
                                            style: GoogleFonts.poppins(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w400,
                                              color: const Color(0xFF64748B),
                                            ),
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
          ),
        ],
      ),
    );
  }
}
