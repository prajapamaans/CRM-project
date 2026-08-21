import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../features/authentication/presentation/providers/auth_provider.dart';
import '../../features/navigation/presentation/providers/navigation_provider.dart';
import 'user_profile_menu.dart';

class SidebarDrawer extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final bool isFullScreen;
  final VoidCallback onToggleFullScreen;
  final VoidCallback? onClose;

  const SidebarDrawer({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.isFullScreen,
    required this.onToggleFullScreen,
    this.onClose,
  });

  @override
  State<SidebarDrawer> createState() => _SidebarDrawerState();
}

class _SidebarDrawerState extends State<SidebarDrawer> {
  bool _crmCoreExpanded = true;
  bool _salesEngagementExpanded = true;
  bool _productivityExpanded = true;
  bool _contentExpanded = true;
  bool _reportingExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Consumer<NavigationProvider>(
      builder: (context, navProvider, child) {
        return Container(
          width: widget.isFullScreen ? MediaQuery.of(context).size.width : 280,
          height: MediaQuery.of(context).size.height,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              right: BorderSide(color: Color(0xFFE5E7EB), width: 1),
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // 1. User Profile Header with Popup Menu in Sidebar
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: UserProfileMenu(showNameAndRole: true),
                      ),
                      if (widget.onClose != null)
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFF64748B),
                            size: 20,
                          ),
                          onPressed: widget.onClose,
                        ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: Color(0xFFF1F5F9)),

                // 2. Navigation Tree List
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    children: [
                      // Top Item: Dashboard (Before CRM Core!)
                      _buildSubTile(
                        context,
                        navProvider: navProvider,
                        itemKey: 'dashboard',
                        index: 0,
                        icon: Icons.grid_view_rounded,
                        label: 'Dashboard',
                        showPinButton: false,
                      ),

                      const SizedBox(height: 4),

                      // CRM Core Group
                      _buildGroupTile(
                        icon: Icons.work_outline_rounded,
                        label: 'CRM Core',
                        isExpanded: _crmCoreExpanded,
                        onToggle: () => setState(() => _crmCoreExpanded = !_crmCoreExpanded),
                      ),
                      if (_crmCoreExpanded)
                        _buildSubItemsTreeContainer([
                          _buildSubTile(context, navProvider: navProvider, itemKey: 'companies', index: 2, icon: Icons.domain_outlined, label: 'Companies'),
                          _buildSubTile(context, navProvider: navProvider, itemKey: 'contacts', index: 1, icon: Icons.people_outline_rounded, label: 'Contacts'),
                          _buildSubTile(context, navProvider: navProvider, itemKey: 'deals', index: 3, icon: Icons.attach_money_rounded, label: 'Deals'),
                          _buildSubTile(context, navProvider: navProvider, itemKey: 'quarter_view', index: 14, icon: Icons.layers_outlined, label: 'Quarter View'),
                        ]),

                      const SizedBox(height: 4),

                      // Sales Engagement Group
                      _buildGroupTile(
                        icon: Icons.handshake_outlined,
                        label: 'Sales Engagement',
                        isExpanded: _salesEngagementExpanded,
                        onToggle: () => setState(() => _salesEngagementExpanded = !_salesEngagementExpanded),
                      ),
                      if (_salesEngagementExpanded)
                        _buildSubItemsTreeContainer([
                          _buildSubTile(context, navProvider: navProvider, itemKey: 'meetings', index: 7, icon: Icons.videocam_outlined, label: 'Meetings'),
                          _buildSubTile(context, navProvider: navProvider, itemKey: 'meeting_scheduler', index: 8, icon: Icons.access_time_outlined, label: 'Meeting Scheduler'),
                          _buildSubTile(context, navProvider: navProvider, itemKey: 'calls', index: 9, icon: Icons.phone_outlined, label: 'Calls'),
                          _buildSubTile(context, navProvider: navProvider, itemKey: 'emails', index: 10, icon: Icons.mail_outline_rounded, label: 'Emails'),
                        ]),

                      const SizedBox(height: 4),

                      // Productivity Group
                      _buildGroupTile(
                        icon: Icons.check_box_outlined,
                        label: 'Productivity',
                        isExpanded: _productivityExpanded,
                        onToggle: () => setState(() => _productivityExpanded = !_productivityExpanded),
                      ),
                      if (_productivityExpanded)
                        _buildSubItemsTreeContainer([
                          _buildSubTile(context, navProvider: navProvider, itemKey: 'tasks', index: 12, icon: Icons.check_box_outlined, label: 'Tasks'),
                          _buildSubTile(context, navProvider: navProvider, itemKey: 'calendar', index: 13, icon: Icons.calendar_today_outlined, label: 'Calendar'),
                        ]),

                      const SizedBox(height: 4),

                      // Content Group
                      _buildGroupTile(
                        icon: Icons.folder_open_outlined,
                        label: 'Content',
                        isExpanded: _contentExpanded,
                        onToggle: () => setState(() => _contentExpanded = !_contentExpanded),
                      ),
                      if (_contentExpanded)
                        _buildSubItemsTreeContainer([
                          _buildSubTile(context, navProvider: navProvider, itemKey: 'documents', index: 15, icon: Icons.folder_open_outlined, label: 'Documents'),
                          _buildSubTile(context, navProvider: navProvider, itemKey: 'templates', index: 16, icon: Icons.grid_view_outlined, label: 'Templates'),
                        ]),

                      const SizedBox(height: 4),

                      // Reporting Group
                      _buildGroupTile(
                        icon: Icons.bar_chart_rounded,
                        label: 'Reporting',
                        isExpanded: _reportingExpanded,
                        onToggle: () => setState(() => _reportingExpanded = !_reportingExpanded),
                      ),
                      if (_reportingExpanded)
                        _buildSubItemsTreeContainer([
                          _buildSubTile(context, navProvider: navProvider, itemKey: 'dashboard_rep', index: 0, icon: Icons.grid_view_rounded, label: 'Dashboard', showPinButton: false),
                          _buildSubTile(context, navProvider: navProvider, itemKey: 'reports', index: 4, icon: Icons.insert_chart_outlined_rounded, label: 'Reports', showPinButton: false),
                        ]),

                      const SizedBox(height: 6),

                      // Bingo AI Item
                      _buildStandaloneItem(
                        context,
                        navProvider: navProvider,
                        itemKey: 'bingo_ai',
                        index: 5,
                        iconWidget: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00A884).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF00A884)),
                        ),
                        label: 'Bingo',
                        badgeWidget: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F766E),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'AI',
                            style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                      ),

                      const SizedBox(height: 4),

                      // Notifications Item
                      _buildStandaloneItem(
                        context,
                        navProvider: navProvider,
                        itemKey: 'notifications',
                        index: 6,
                        iconWidget: const Icon(Icons.notifications_none_rounded, size: 20, color: Color(0xFF64748B)),
                        label: 'Notifications',
                        badgeWidget: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '2',
                            style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatarFallback(String name) {
    final initials = name.isNotEmpty
        ? name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join('').toUpperCase()
        : 'AT';
    return Container(
      color: const Color(0xFF0F766E),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildGroupTile({
    required IconData icon,
    required String label,
    required bool isExpanded,
    required VoidCallback onToggle,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 19, color: const Color(0xFF475569)),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              Icon(
                isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: const Color(0xFF64748B),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubItemsTreeContainer(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Stack(
        children: [
          Positioned(
            left: 8,
            top: 4,
            bottom: 4,
            child: Container(
              width: 1.2,
              color: const Color(0xFFCBD5E1),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ],
      ),
    );
  }

  Widget _buildSubTile(
    BuildContext context, {
    required NavigationProvider navProvider,
    required String itemKey,
    required int index,
    required IconData icon,
    required String label,
    bool showPinButton = true,
  }) {
    final bool isSelected = widget.selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.only(left: 10, top: 2, bottom: 2),
      child: Material(
        color: isSelected ? const Color(0xFFE6F4F1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {
            widget.onItemSelected(index);
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: isSelected ? const Color(0xFF00A884) : const Color(0xFF64748B),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? const Color(0xFF00A884) : const Color(0xFF334155),
                    ),
                  ),
                ),
                if (showPinButton) _buildPinButton(context, navProvider, itemKey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStandaloneItem(
    BuildContext context, {
    required NavigationProvider navProvider,
    required String itemKey,
    required int index,
    required Widget iconWidget,
    required String label,
    required Widget badgeWidget,
  }) {
    final bool isSelected = widget.selectedIndex == index;

    return Material(
      color: isSelected ? const Color(0xFFE6F4F1) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () {
          widget.onItemSelected(index);
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  iconWidget,
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? const Color(0xFF00A884) : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  badgeWidget,
                  const SizedBox(width: 6),
                  _buildPinButton(context, navProvider, itemKey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinButton(BuildContext context, NavigationProvider navProvider, String itemKey) {
    final bool isPinned = navProvider.isPinned(itemKey);
    return GestureDetector(
      onTap: () {
        final res = navProvider.togglePin(itemKey);
        if (res == null) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maximum 3 items can be pinned to the bottom navigation bar.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
          size: 15,
          color: isPinned ? const Color(0xFF00A884) : const Color(0xFF94A3B8),
        ),
      ),
    );
  }
}
