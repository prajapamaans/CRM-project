import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const double _kRowHeight = 52.0;
const double _kMinMenuWidth = 280.0;
const double _kMenuVerticalPadding = 8.0;
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
                final selected = await showDialog<T>(
                  context: context,
                  barrierDismissible: true,
                  barrierColor: Colors.black38,
                  builder: (dialogCtx) {
                    final mediaQuery = MediaQuery.of(dialogCtx);
                    final screenWidth = mediaQuery.size.width;
                    final screenHeight = mediaQuery.size.height;

                    final menuWidth = (screenWidth * 0.88)
                        .clamp(_kMinMenuWidth, 380.0)
                        .toDouble();

                    final maxMenuHeight = screenHeight * 0.65;

                    return Dialog(
                      alignment: Alignment.center,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 8,
                      backgroundColor: _kMenuBackground,
                      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                      child: Container(
                        width: menuWidth,
                        constraints: BoxConstraints(maxHeight: maxMenuHeight),
                        decoration: BoxDecoration(
                          color: _kMenuBackground,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFD3E0D8), width: 1),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: _DropdownMenuPanel<T>(
                            title: hintText,
                            items: items,
                            selectedValue: state.value,
                          ),
                        ),
                      ),
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
                                      fontSize: 14,
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
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF94A3B8),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF64748B),
                      size: 22,
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

  Widget _buildItemTile(DropdownSearchItem<T> item) {
    final isSelected = item.value == widget.selectedValue;
    final hasSubtext = item.subtext != null && item.subtext!.isNotEmpty;

    return InkWell(
      onTap: () => Navigator.of(context).pop(item.value),
      child: Container(
        constraints: const BoxConstraints(minHeight: _kRowHeight),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isSelected ? const Color(0xFFDDEAE3) : Colors.transparent,
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
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: GoogleFonts.poppins(
                      fontSize: 14.5,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF00A884)
                          : const Color(0xFF1E293B),
                    ),
                  ),
                  if (hasSubtext)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        item.subtext!,
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
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
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

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
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.items.length > 5) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD3E0D8)),
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
                    hintText: 'Search ${widget.title}...',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF94A3B8),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF94A3B8),
                      size: 18,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFDDE7E1)),
          ],
          if (filteredItems.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  'No options found',
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
            )
          else if (widget.items.length <= 5)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: _kMenuVerticalPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: filteredItems.map((item) => _buildItemTile(item)).toList(),
              ),
            )
          else
            Flexible(
              child: Scrollbar(
                thumbVisibility: true,
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: _kMenuVerticalPadding),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    return _buildItemTile(filteredItems[index]);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
