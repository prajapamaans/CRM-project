import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Reusable, keyboard-avoidant bottom sheet wrapper for form modals.
/// Automatically handles MediaQuery.of(context).viewInsets.bottom,
/// keeps header sticky at top and action buttons visible/scrollable above keyboard,
/// and provides auto-scroll support when text fields gain focus.
class KeyboardSafeFormSheet extends StatefulWidget {
  final String title;
  final Widget child;
  final Widget? footer;
  final VoidCallback? onClose;
  final Color headerColor;
  final double heightFactor;

  const KeyboardSafeFormSheet({
    super.key,
    required this.title,
    required this.child,
    this.footer,
    this.onClose,
    this.headerColor = const Color(0xFF00A884),
    this.heightFactor = 0.9,
  });

  @override
  State<KeyboardSafeFormSheet> createState() => _KeyboardSafeFormSheetState();
}

class _KeyboardSafeFormSheetState extends State<KeyboardSafeFormSheet> {
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxSheetHeight = MediaQuery.of(context).size.height * widget.heightFactor;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: bottomInset),
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: maxSheetHeight,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Sticky Teal Modal Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: widget.headerColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.title,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onClose ?? () => Navigator.of(context).pop(false),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // 2. Scrollable Form Body
              Expanded(
                child: widget.child,
              ),

              // 3. Optional Sticky/Bottom Action Buttons Footer
              if (widget.footer != null)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                    ),
                  ),
                  child: widget.footer!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
