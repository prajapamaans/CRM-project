import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ActionPillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isHighlighted;
  final bool isSelected;
  final VoidCallback? onTap;

  const ActionPillButton({
    super.key,
    required this.label,
    required this.icon,
    this.isHighlighted = false,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color borderColor;
    Color contentColor;

    if (isHighlighted) {
      // "Ask Bingo" purple pill
      bgColor = AppColors.purpleLightBg;
      borderColor = AppColors.accentPurple.withValues(alpha: 0.25);
      contentColor = AppColors.accentPurple;
    } else if (isSelected) {
      // Selected "Team" pill — Solid teal fill with white content
      bgColor = AppColors.primaryTeal;
      borderColor = AppColors.primaryTeal;
      contentColor = Colors.white;
    } else {
      // Unselected "My work" pill — White fill with light gray border
      bgColor = AppColors.cardBackground;
      borderColor = AppColors.cardBorder;
      contentColor = AppColors.textPrimary;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primaryTeal.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: contentColor,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: contentColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
