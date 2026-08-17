import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../features/navigation/presentation/providers/navigation_provider.dart';
import '../../features/navigation/presentation/screens/more_screen.dart';
import '../../theme/app_theme.dart';

/// A sleek, modern custom bottom navigation bar that dynamically renders
/// user-pinned menu fields and fixed tabs (Home & More).
class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<NavigationProvider>(
      builder: (context, navProvider, child) {
        final List<NavItem> defaultFallback = navProvider.allNavItems
            .where((item) => ['contacts', 'companies', 'deals'].contains(item.key))
            .toList();
        final pinnedItems = navProvider.pinnedNavItems.isNotEmpty
            ? navProvider.pinnedNavItems
            : defaultFallback;

        return Container(
          decoration: const BoxDecoration(
            color: AppColors.cardBackground,
            border: Border(
              top: BorderSide(color: AppColors.cardBorder, width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 10,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // 1. Fixed Home / Dashboard Tab (Index 0)
                  _buildNavItem(
                    context: context,
                    targetIndex: 0,
                    label: 'Home',
                    icon: Icons.grid_view_rounded,
                    isSelected: currentIndex == 0,
                  ),

                  // 2. Dynamic User-Pinned Tabs
                  for (final item in pinnedItems)
                    _buildNavItem(
                      context: context,
                      targetIndex: item.screenIndex,
                      label: item.title,
                      icon: currentIndex == item.screenIndex
                          ? item.selectedIcon
                          : item.icon,
                      isSelected: currentIndex == item.screenIndex,
                    ),

                  // 3. Fixed "More" Tab (Opens Draggable Menu Sheet)
                  _buildNavItem(
                    context: context,
                    targetIndex: -1, // Special index for More
                    label: 'More',
                    icon: Icons.more_horiz_rounded,
                    isSelected: false,
                    isMoreTab: true,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int targetIndex,
    required String label,
    required IconData icon,
    required bool isSelected,
    bool isMoreTab = false,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          if (isMoreTab) {
            MoreScreen.show(context);
          } else {
            onTap(targetIndex);
          }
        },
        borderRadius: BorderRadius.circular(16),
        splashColor: const Color(0x1A00A884),
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFCCFBF1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: isSelected
                      ? AppColors.primaryTeal
                      : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected
                        ? AppColors.primaryTeal
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
