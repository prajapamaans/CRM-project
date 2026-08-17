import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:crmproject/core/widgets/app_refresh_indicator.dart';
import '../../../../core/providers/master_data_provider.dart';
import '../../../../core/repositories/master_data_repository.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../companies/presentation/providers/company_provider.dart';
import '../../../contacts/presentation/providers/contact_provider.dart';
import '../../../deals/presentation/providers/deal_provider.dart';
import '../../../departments/presentation/providers/department_provider.dart';
import '../widgets/log_meeting_modal.dart';

class MeetingsScreen extends StatefulWidget {
  const MeetingsScreen({super.key});

  @override
  State<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends State<MeetingsScreen> {
  int _selectedTab = 0; // 0: All meetings, 1: My meetings
  String _searchQuery = '';
  final List<MeetingModel> _meetings = [];
  bool _isLoadingMeetings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final currentUserId = auth.currentUser?.id ?? '311fee58-ba54-42b9-8795-f3ba19255b20';

      // 1. GET /api/auth/me
      auth.fetchUserProfile();

      // 2. GET /api/auth/team
      auth.fetchTeamMembers();

      // 3. Master Data, Notifications, Deal Stages, Activities:
      context.read<MasterDataProvider>().fetchAllMasterData(currentUserId: currentUserId);

      // 4. GET /api/companies?page=1&limit=25
      context.read<CompanyProvider>().fetchCompanies(ignorePermissions: true);

      // 5. GET /api/contacts?page=1&limit=25
      context.read<ContactProvider>().fetchContacts(ignorePermissions: true);

      // 6. GET /api/deals?page=1&limit=25
      context.read<DealProvider>().fetchDeals(ignorePermissions: true);

      // Load existing meetings from API
      _loadMeetings();
    });
  }

  Future<void> _loadMeetings() async {
    if (!mounted) return;
    setState(() {
      _isLoadingMeetings = true;
    });
    try {
      final repository = MasterDataRepositoryImpl();
      final deptId = context.read<DepartmentProvider>().selectedDepartmentId;
      final activities = await repository.getActivities(type: 'meeting', departmentId: deptId);
      final loadedMeetings = activities.map((item) {
        final title = item['title'] as String? ?? item['subject'] as String? ?? 'Meeting';
        
        final rawOutcome = item['outcome'] as String? ?? 'Scheduled';
        String outcomeLabel = rawOutcome;
        if (rawOutcome.toLowerCase() == 'scheduled') outcomeLabel = 'Scheduled';
        else if (rawOutcome.toLowerCase() == 'completed') outcomeLabel = 'Completed';
        else if (rawOutcome.toLowerCase() == 'rescheduled') outcomeLabel = 'Rescheduled';
        else if (rawOutcome.toLowerCase() == 'no_show') outcomeLabel = 'No show';
        else if (rawOutcome.toLowerCase() == 'canceled') outcomeLabel = 'Canceled';
        else if (rawOutcome.isNotEmpty) {
          outcomeLabel = rawOutcome[0].toUpperCase() + rawOutcome.substring(1);
        }

        final duration = item['duration'] as String? ?? '15 Minutes';
        final startTime = item['startTime'] as String? ?? item['start_time'] as String? ?? '';
        final notes = item['notes'] as String? ?? item['description'] as String? ?? '';
        final assignedTo = item['ownerName'] as String? ?? 'Admin User';

        return MeetingModel(
          title: title,
          outcome: outcomeLabel,
          duration: duration,
          startTime: startTime,
          notes: notes,
          assignedTo: assignedTo,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _meetings.clear();
          _meetings.addAll(loadedMeetings);
        });
      }
    } catch (e) {
      debugPrint('[_loadMeetings ERROR]: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMeetings = false;
        });
      }
    }
  }

  String _formatDateTime(String raw) {
    if (raw.isEmpty) return '--  2026-08-05';
    try {
      if (raw.contains('T')) {
        final dt = DateTime.parse(raw);
        final hour = dt.hour.toString().padLeft(2, '0');
        final min = dt.minute.toString().padLeft(2, '0');
        final y = dt.year.toString();
        final m = dt.month.toString().padLeft(2, '0');
        final d = dt.day.toString().padLeft(2, '0');
        return '$hour:$min  $y-$m-$d';
      }
      final parts = raw.split(' ');
      if (parts.length >= 2) {
        final datePart = parts[0];
        final timePart = parts[1];
        final ampmPart = parts.length > 2 ? ' ${parts[2]}' : '';
        String formattedDate = '2026-08-05';
        final dateSubparts = datePart.split('/');
        if (dateSubparts.length == 3) {
          formattedDate = '${dateSubparts[2]}-${dateSubparts[1].padLeft(2, '0')}-${dateSubparts[0].padLeft(2, '0')}';
        }
        return '$timePart$ampmPart  $formattedDate';
      }
    } catch (_) {}
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    try {
      final auth = context.watch<AuthProvider>();
      final currentUserName = auth.currentUser?.fullName ?? 'Admin User';
      final myMeetingsCount = _meetings.where((m) => (m.assignedTo ?? 'Admin User') == currentUserName).length;

      final filteredMeetings = _meetings.where((m) {
        if (_selectedTab == 1 && (m.assignedTo ?? 'Admin User') != currentUserName) return false;
        if (_searchQuery.isEmpty) return true;
        return m.title.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();

      return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Header Row: Camera Icon + Meetings Title + "+ Meeting" Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Row(
                children: [
                  const Icon(
                    Icons.videocam_outlined,
                    color: Color(0xFF0F766E),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Meetings',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const Spacer(),

                  // + Meeting Button
                  ElevatedButton.icon(
                    onPressed: () async {
                      final newMeeting = await LogMeetingModal.show(context);
                      if (newMeeting != null) {
                        _loadMeetings();
                      }
                    },
                    icon: const Icon(Icons.add, size: 18, color: Colors.white),
                    label: Text(
                      'Meeting',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A884),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Sub-header Segmented Pill: "All meetings" | "My meetings"
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        _buildTabButton('All meetings', 0, _meetings.length),
                        _buildTabButton('My meetings', 1, myMeetingsCount),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // 3. Search and Action Filter Container Card
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      // Search Field
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: TextField(
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val;
                              });
                            },
                            decoration: InputDecoration(
                              hintText: 'Search',
                              hintStyle: GoogleFonts.poppins(
                                fontSize: 13,
                                color: const Color(0xFF94A3B8),
                              ),
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: Color(0xFF94A3B8),
                                size: 20,
                              ),
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ),

                      // Filter Buttons Row (Filters, Sort, Export, ...)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterPill(Icons.tune_rounded, 'Filters'),
                              const SizedBox(width: 8),
                              _buildFilterPill(Icons.swap_vert_rounded, 'Sort'),
                              const SizedBox(width: 8),
                              _buildFilterPill(
                                  Icons.file_download_outlined, 'Export'),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border:
                                      Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: const Icon(
                                  Icons.more_horiz_rounded,
                                  size: 16,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Divider(height: 1, color: Color(0xFFF1F5F9)),

                      // Main List Content or Empty State
                      Expanded(
                        child: AppRefreshIndicator(
                          onRefresh: () async {
                            await _loadMeetings();
                          },
                          child: _isLoadingMeetings && _meetings.isEmpty
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF0F766E),
                                  ),
                                )
                              : filteredMeetings.isEmpty
                                  ? ListView(
                                      physics: const AlwaysScrollableScrollPhysics(
                                          parent: BouncingScrollPhysics()),
                                      children: [
                                        const SizedBox(height: 120),
                                        Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(24),
                                            child: Text(
                                              'No meetings found. Click "Create meeting" to add one.',
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.poppins(
                                                fontSize: 13.5,
                                                color: const Color(0xFF64748B),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : ListView.builder(
                                      physics: const AlwaysScrollableScrollPhysics(
                                          parent: BouncingScrollPhysics()),
                                      padding: const EdgeInsets.all(14),
                                      itemCount: filteredMeetings.length,
                                      itemBuilder: (context, index) {
                                        final m = filteredMeetings[index];
                                        return _buildMeetingTile(m);
                                      },
                                    ),
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              filteredMeetings.isEmpty 
                                  ? '0-0 of 0' 
                                  : '1-${filteredMeetings.length} of ${filteredMeetings.length}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF334155),
                              ),
                            ),
                            Row(
                              children: [
                                TextButton.icon(
                                  onPressed: null,
                                  icon: const Icon(Icons.chevron_left_rounded, size: 16),
                                  label: Text(
                                    'Prev',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF94A3B8),
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '1/1',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: null,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Next',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right_rounded, size: 16),
                                    ],
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF94A3B8),
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      );
    } catch (e, stack) {
      debugPrint('[MeetingsScreen Build Crash]: $e\n$stack');
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: SelectableText(
                'Crash: $e\n\nStack:\n$stack',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          ),
        ),
      );
    }
  }

  Widget _buildTabButton(String label, int index, int count) {
    final bool isSelected = _selectedTab == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected
                    ? const Color(0xFF0F766E)
                    : const Color(0xFF64748B),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingTile(MeetingModel meeting) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE6F4F1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.videocam_outlined,
              color: Color(0xFF0F766E),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meeting.title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F766E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDateTime(meeting.startTime),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Assigned: ${meeting.assignedTo ?? 'Admin User'}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
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
    );
  }
}
