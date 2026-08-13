import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/repositories/master_data_repository.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../widgets/log_call_modal.dart';
import 'call_details_screen.dart';

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  int _selectedTab = 0; // 0: All calls, 1: My calls
  String _searchQuery = '';
  final List<CallModel> _calls = [];
  bool _isLoadingCalls = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCalls();
    });
  }

  Future<void> _loadCalls() async {
    if (!mounted) return;
    setState(() {
      _isLoadingCalls = true;
    });
    try {
      final repository = MasterDataRepositoryImpl();
      final activities = await repository.getActivities(type: 'call', page: 1, limit: 25);
      final loadedCalls = activities.map((item) {
        final title = item['title'] as String? ?? item['subject'] as String? ?? 'Call';
        
        final rawOutcome = item['outcome'] as String? ?? 'Scheduled';
        String outcomeLabel = rawOutcome;
        if (rawOutcome.toLowerCase() == 'scheduled') outcomeLabel = 'Scheduled';
        else if (rawOutcome.toLowerCase() == 'completed') outcomeLabel = 'Completed';
        else if (rawOutcome.toLowerCase() == 'rescheduled') outcomeLabel = 'Rescheduled';
        else if (rawOutcome.toLowerCase() == 'no_show') outcomeLabel = 'No show';
        else if (rawOutcome.toLowerCase() == 'canceled') outcomeLabel = 'Canceled';
        else if (rawOutcome.toLowerCase() == 'connected') outcomeLabel = 'Connected';
        else if (rawOutcome.toLowerCase() == 'busy') outcomeLabel = 'Busy';
        else if (rawOutcome.toLowerCase() == 'left message') outcomeLabel = 'Left Message';
        else if (rawOutcome.toLowerCase() == 'no answer') outcomeLabel = 'No Answer';
        else if (rawOutcome.toLowerCase() == 'wrong number') outcomeLabel = 'Wrong Number';
        else if (rawOutcome.isNotEmpty) {
          outcomeLabel = rawOutcome[0].toUpperCase() + rawOutcome.substring(1);
        }

        final id = item['id']?.toString() ?? item['_id']?.toString() ?? item['activityId']?.toString();
        final duration = item['duration'] as String? ?? '15 Minutes';
        final startTime = item['startTime'] as String? ?? item['start_time'] as String? ?? '';
        final notes = item['notes'] as String? ?? item['description'] as String? ?? '';
        final assignedTo = item['ownerName'] as String? ?? 'Admin User';
        final priority = item['priority'] as String? ?? 'Medium';
        final status = item['status'] as String? ?? 'PENDING';
        final type = item['type'] as String? ?? 'call';

        return CallModel(
          id: id,
          title: title,
          outcome: outcomeLabel,
          duration: duration,
          startTime: startTime,
          notes: notes,
          assignedTo: assignedTo,
          priority: priority,
          status: status,
          type: type,
          rawMap: item,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _calls.clear();
          _calls.addAll(loadedCalls);
        });
      }
    } catch (e) {
      debugPrint('[_loadCalls ERROR]: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCalls = false;
        });
      }
    }
  }

  String _formatCallDateTime(String raw) {
    if (raw.isEmpty) return '--';
    try {
      DateTime? dt;
      if (raw.contains('T')) {
        dt = DateTime.parse(raw);
      } else {
        dt = DateTime.tryParse(raw);
        if (dt == null) {
          final parts = raw.split(' ');
          if (parts.length >= 2) {
            final dateParts = parts[0].split('/');
            final timeParts = parts[1].split(':');
            if (dateParts.length == 3 && timeParts.length >= 2) {
              final day = int.parse(dateParts[0]);
              final month = int.parse(dateParts[1]);
              final year = int.parse(dateParts[2]);
              final hour = int.parse(timeParts[0]);
              final minute = int.parse(timeParts[1]);
              dt = DateTime(year, month, day, hour, minute);
            }
          }
        }
      }

      if (dt != null) {
        int hour = dt.hour;
        final ampm = hour >= 12 ? 'PM' : 'AM';
        hour = hour % 12;
        if (hour == 0) hour = 12;
        final hourStr = hour.toString().padLeft(2, '0');
        final minStr = dt.minute.toString().padLeft(2, '0');
        final dateStr = '${dt.month}/${dt.day}/${dt.year}';
        return '$hourStr:$minStr $ampm  $dateStr';
      }
    } catch (_) {}
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    try {
      final auth = context.watch<AuthProvider>();
      final currentUserName = auth.currentUser?.fullName ?? 'Admin User';
      final myCallsCount = _calls.where((c) => (c.assignedTo ?? 'Admin User') == currentUserName).length;

      final filteredCalls = _calls.where((c) {
        if (_selectedTab == 1 && (c.assignedTo ?? 'Admin User') != currentUserName) return false;
        if (_searchQuery.isEmpty) return true;
        return c.title.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();

      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Column(
            children: [
              // 1. Top Header Row: Call Icon + Calls Title + "+ Call" Button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.white,
                child: Row(
                  children: [
                    const Icon(
                      Icons.phone_outlined,
                      color: Color(0xFF00A884),
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Calls',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const Spacer(),

                    // + Call Button
                    ElevatedButton.icon(
                      onPressed: () async {
                        final newCall = await LogCallModal.show(context);
                        if (newCall != null) {
                          _loadCalls();
                        }
                      },
                      icon: const Icon(Icons.add, size: 18, color: Colors.white),
                      label: Text(
                        'Call',
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

              // 2. Sub-header Segmented Pill: "All calls" | "My calls"
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
                          _buildTabButton('All calls', 0, _calls.length),
                          _buildTabButton('My calls', 1, myCallsCount),
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
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
                                _buildFilterPill(Icons.file_download_outlined, 'Export'),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
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
                          child: _isLoadingCalls
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF00A884),
                                  ),
                                )
                              : filteredCalls.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Text(
                                          'No call logs found. Click "+ Call" to add one.',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.poppins(
                                            fontSize: 13.5,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.all(14),
                                      itemCount: filteredCalls.length,
                                      itemBuilder: (context, index) {
                                        final c = filteredCalls[index];
                                        return _buildCallTile(c);
                                      },
                                    ),
                        ),
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                filteredCalls.isEmpty 
                                    ? '0-0 of 0' 
                                    : '1-${filteredCalls.length} of ${filteredCalls.length}',
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
      debugPrint('[CallsScreen Build Crash]: $e\n$stack');
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
                    ? const Color(0xFF00A884)
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

  Widget _buildCallTile(CallModel call) {
    return InkWell(
      onTap: () async {
        final refreshed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => CallDetailsScreen(call: call),
          ),
        );
        if (refreshed == true) {
          _loadCalls();
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
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
              Icons.phone_outlined,
              color: Color(0xFF00A884),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  call.title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F766E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatCallDateTime(call.startTime),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Logged by: ${call.assignedTo ?? 'Admin User'}',
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
    ),
  );
}
}
