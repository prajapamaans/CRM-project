import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../features/deals/data/models/deal_model.dart';

class DealTile extends StatelessWidget {
  final DealModel deal;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool showCheckbox;
  final ValueChanged<bool?>? onSelectionChanged;

  const DealTile({
    super.key,
    required this.deal,
    this.onTap,
    this.isSelected = false,
    this.showCheckbox = true,
    this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final int progressPercent = (deal.progress * 100).toInt();

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF1F5F9) : Colors.white,
          border: const Border(
            bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Checkbox + Dot Indicator + Deal Title + Trailing Chevron
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showCheckbox) ...[
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: isSelected,
                      onChanged: onSelectionChanged,
                      activeColor: const Color(0xFF00A884),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      side: const BorderSide(color: Color(0xFF94A3B8), width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    deal.title,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFCBD5E1),
                  size: 20,
                ),
              ],
            ),

            const SizedBox(height: 6),

            // 2. Status Badge Pill
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: UnconstrainedBox(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: deal.badgeBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    deal.statusBadge,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: deal.badgeTextColor,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // 3. Subtitle Row 1: Company + Owner
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Row(
                children: [
                  const Icon(
                    Icons.domain_outlined,
                    size: 14,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      deal.company,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.person_outline_rounded,
                    size: 14,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      deal.owner,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // 4. Subtitle Row 2: Date String
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 13,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    deal.date,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),

            if (deal.progress > 0) ...[
              const SizedBox(height: 10),

              // 5. Progress Bar & Percentage
              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: deal.progress,
                          minHeight: 5,
                          backgroundColor: const Color(0xFFF1F5F9),
                          color: progressPercent == 100
                              ? const Color(0xFF00A884)
                              : progressPercent >= 50
                                  ? const Color(0xFF0F766E)
                                  : deal.dotColor == const Color(0xFFF97316)
                                      ? const Color(0xFFF97316)
                                      : const Color(0xFF3B82F6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$progressPercent%',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
