import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/navigation/app_router.dart';
import '../../../../core/widgets/font_size_modal.dart';
import '../providers/navigation_provider.dart';

class MoreScreen extends StatelessWidget {
  final bool isBottomSheet;

  const MoreScreen({
    super.key,
    this.isBottomSheet = false,
  });

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => _MoreSheetContent(scrollController: controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: _MoreSheetContent(),
      ),
    );
  }
}

class _MoreSheetContent extends StatelessWidget {
  final ScrollController? scrollController;

  const _MoreSheetContent({this.scrollController});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // 1. Top Header Bar with APIDEL Icon, Title "More", and Close X button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00A884),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.dashboard_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'More',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // 2. Scrollable List of Menu Sections
          Expanded(
            child: Consumer<NavigationProvider>(
              builder: (context, navProvider, child) {
                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  children: [
                    // SECTION 1: SALES ENGAGEMENT
                    _buildSectionTitle('SALES ENGAGEMENT'),
                    _buildMenuItem(
                      context,
                      navProvider: navProvider,
                      icon: Icons.videocam_outlined,
                      title: 'Meetings',
                      screenIndex: 7,
                    ),
                    _buildMenuItem(
                      context,
                      navProvider: navProvider,
                      icon: Icons.access_time_outlined,
                      title: 'Meeting Scheduler',
                      screenIndex: 8,
                    ),
                    _buildMenuItem(
                      context,
                      navProvider: navProvider,
                      icon: Icons.phone_outlined,
                      title: 'Calls',
                      screenIndex: 9,
                    ),
                    _buildMenuItem(
                      context,
                      navProvider: navProvider,
                      icon: Icons.mail_outline_rounded,
                      title: 'Emails',
                      screenIndex: 10,
                    ),

                    const SizedBox(height: 20),

                    // SECTION 2: CRM CORE
                    _buildSectionTitle('CRM CORE'),
                    _buildMenuItem(
                      context,
                      navProvider: navProvider,
                      icon: Icons.domain_outlined,
                      title: 'Companies',
                      screenIndex: 2,
                    ),
                    _buildMenuItem(
                      context,
                      navProvider: navProvider,
                      icon: Icons.people_outline_rounded,
                      title: 'Contacts',
                      screenIndex: 1,
                    ),
                    _buildMenuItem(
                      context,
                      navProvider: navProvider,
                      icon: Icons.attach_money_rounded,
                      title: 'Deals',
                      screenIndex: 3,
                    ),

                    const SizedBox(height: 20),

                    // SECTION 3: PRODUCTIVITY
                    _buildSectionTitle('PRODUCTIVITY'),
                    _buildMenuItem(
                      context,
                      navProvider: navProvider,
                      icon: Icons.check_box_outlined,
                      title: 'Tasks',
                      screenIndex: 12,
                    ),
                    _buildMenuItem(
                      context,
                      navProvider: navProvider,
                      icon: Icons.calendar_today_outlined,
                      title: 'Calendar',
                      screenIndex: 13,
                    ),
                    _buildMenuItem(
                      context,
                      navProvider: navProvider,
                      icon: Icons.layers_outlined,
                      title: 'Quarter View',
                      screenIndex: 14,
                    ),

                    const SizedBox(height: 20),

                    // SECTION 4: REPORTS & ANALYTICS
                    _buildSectionTitle('REPORTS & ANALYTICS'),
                    _buildMenuItem(
                      context,
                      navProvider: navProvider,
                      icon: Icons.bar_chart_rounded,
                      title: 'Reports',
                      screenIndex: 4,
                    ),

                    const SizedBox(height: 20),

                    // SECTION 5: CONTENT
                    _buildSectionTitle('CONTENT'),
                    _buildMenuItem(
                      context,
                      navProvider: navProvider,
                      icon: Icons.grid_view_outlined,
                      title: 'Templates',
                      screenIndex: 16,
                    ),
                    _buildMenuItem(
                      context,
                      navProvider: navProvider,
                      icon: Icons.folder_open_outlined,
                      title: 'Documents',
                      screenIndex: 15,
                    ),

                    const SizedBox(height: 20),

                    // SECTION 6: ADMINISTRATION
                    _buildSectionTitle('ADMINISTRATION'),
                    _buildMenuItem(
                      context,
                      navProvider: navProvider,
                      icon: Icons.people_outline_rounded,
                      title: 'User Management',
                      screenIndex: 17,
                    ),
                    _buildMenuItem(
                      context,
                      navProvider: navProvider,
                      icon: Icons.list_alt_rounded,
                      title: 'Master Dropdowns',
                      screenIndex: 18,
                    ),
                    _buildMenuItem(
                      context,
                      navProvider: navProvider,
                      icon: Icons.apartment_rounded,
                      title: 'Departments Configuration',
                      screenIndex: 19,
                    ),

                    const SizedBox(height: 20),

                    // SECTION 7: GENERAL
                    _buildSectionTitle('GENERAL'),
                    _buildMenuItem(
                      context,
                      navProvider: navProvider,
                      icon: Icons.notifications_none_rounded,
                      title: 'Notifications',
                      screenIndex: 6,
                    ),
                    _buildMenuItem(
                      context,
                      navProvider: navProvider,
                      icon: Icons.auto_awesome_outlined,
                      title: 'Bingo AI',
                      screenIndex: 5,
                    ),
                    _buildCustomActionItem(
                      context,
                      icon: Icons.format_size_rounded,
                      title: 'Font Size Settings',
                      onTap: () {
                        FontSizeModal.show(context);
                      },
                    ),

                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF94A3B8),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required NavigationProvider navProvider,
    required IconData icon,
    required String title,
    required int screenIndex,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF475569),
              size: 20,
            ),
          ),
          title: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFFCBD5E1),
            size: 20,
          ),
          onTap: () {
            navProvider.selectScreen(screenIndex);
            final location = AppRouter.locationForTab(screenIndex);
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
            if (location != null && location.isNotEmpty) {
              context.go(location);
            }
          },
        ),
      ),
    );
  }

  Widget _buildCustomActionItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF475569),
              size: 20,
            ),
          ),
          title: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFFCBD5E1),
            size: 20,
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
