import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashGap;
  final double borderRadius;

  DashedBorderPainter({
    this.color = AppColors.cardBorder,
    this.strokeWidth = 1.0,
    this.dashWidth = 5.0,
    this.dashGap = 3.0,
    this.borderRadius = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );

    final Path path = Path()..addRRect(rrect);
    final Path dashPath = Path();

    for (final PathMetric pathMetric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < pathMetric.length) {
        final double length = (distance + dashWidth < pathMetric.length)
            ? dashWidth
            : pathMetric.length - distance;
        dashPath.addPath(
          pathMetric.extractPath(distance, distance + length),
          Offset.zero,
        );
        distance += dashWidth + dashGap;
      }
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) => false;
}

class EmptyStateCard extends StatelessWidget {
  final String title;
  final String? description;
  final IconData? icon;
  final bool isDashed;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  const EmptyStateCard({
    super.key,
    required this.title,
    this.description,
    this.icon,
    this.isDashed = true,
    this.borderRadius = 14.0,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.xl,
    ),
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primaryTeal.withValues(alpha: 0.4),
                width: 1,
              ),
              color: AppColors.badgeTealBg.withValues(alpha: 0.3),
            ),
            child: Icon(
              icon,
              color: AppColors.primaryTeal,
              size: 18,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Text(
          title,
          style: AppTextStyles.headingSmall.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: description == null ? AppColors.textMuted : AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        if (description != null) ...[
          const SizedBox(height: 2),
          Text(
            description!,
            style: AppTextStyles.bodyMedium.copyWith(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );

    if (isDashed) {
      return CustomPaint(
        painter: DashedBorderPainter(
          color: AppColors.cardBorder,
          strokeWidth: 1.0,
          dashWidth: 4.0,
          dashGap: 3.0,
          borderRadius: borderRadius,
        ),
        child: Container(
          width: double.infinity,
          padding: padding,
          child: content,
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: AppColors.cardBorder,
          width: 1,
        ),
      ),
      child: content,
    );
  }
}
