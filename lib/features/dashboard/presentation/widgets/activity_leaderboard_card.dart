import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/dashboard_leaderboard_model.dart';

class ActivityLeaderboardCard extends StatelessWidget {
  final List<ActivityLeaderboardItem> items;
  final bool isLoading;
  final String? error;
  final String subtitleLabel;
  final VoidCallback? onRefresh;

  const ActivityLeaderboardCard({
    super.key,
    required this.items,
    this.isLoading = false,
    this.error,
    this.subtitleLabel = 'LAST 7 DAYS',
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00A884).withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Activity leaderboard by rep with ...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F766E),
                        ),
                      ),
                    ),
                    if (onRefresh != null)
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF64748B)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: onRefresh,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    subtitleLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0284C7),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Body Content
          Padding(
            padding: const EdgeInsets.all(14),
            child: _buildBodyContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent() {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00A884)),
          ),
        ),
      );
    }

    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Center(
          child: Text(
            'No activity data available for this timeframe',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legend Row matching Web Dashboard: Call, Email, Meeting, Note, Task
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _buildLegendItem('Call', const Color(0xFFF97316)),
            _buildLegendItem('Email', const Color(0xFFA16207)),
            _buildLegendItem('Meeting', const Color(0xFF64748B)),
            _buildLegendItem('Note', const Color(0xFFEC4899)),
            _buildLegendItem('Task', const Color(0xFFF59E0B)),
          ],
        ),
        const SizedBox(height: 16),

        // Stacked Horizontal Bars per Representative
        () {
          final maxTotal = items.fold<int>(0, (max, item) => item.totalCount > max ? item.totalCount : max);
          return Column(
            children: items.map((item) {
              final total = item.totalCount;
              final double widthFactor = maxTotal > 0 ? (total / maxTotal).clamp(0.0, 1.0) : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Rep Name Label
                    SizedBox(
                      width: 80,
                      child: Text(
                        item.repName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Horizontal Stacked Bar
                    Expanded(
                      child: Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: total == 0
                            ? const SizedBox.shrink()
                            : FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: widthFactor,
                                child: Row(
                                  children: [
                                    if (item.callCount > 0)
                                      Flexible(
                                        flex: item.callCount,
                                        child: Container(color: const Color(0xFFF97316)),
                                      ),
                                    if (item.emailCount > 0)
                                      Flexible(
                                        flex: item.emailCount,
                                        child: Container(color: const Color(0xFFA16207)),
                                      ),
                                    if (item.meetingCount > 0)
                                      Flexible(
                                        flex: item.meetingCount,
                                        child: Container(color: const Color(0xFF64748B)),
                                      ),
                                    if (item.noteCount > 0)
                                      Flexible(
                                        flex: item.noteCount,
                                        child: Container(color: const Color(0xFFEC4899)),
                                      ),
                                    if (item.taskCount > 0)
                                      Flexible(
                                        flex: item.taskCount,
                                        child: Container(color: const Color(0xFFF59E0B)),
                                      ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Total Count Badge
                    SizedBox(
                      width: 32,
                      child: Text(
                        '$total',
                        textAlign: TextAlign.end,
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F766E),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        }(),

        const SizedBox(height: 14),
        // X-Axis Footer Label
        Center(
          child: Text(
            'ACTIVITIES COUNT',
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF64748B),
              letterSpacing: 0.8,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF475569),
          ),
        ),
      ],
    );
  }
}
