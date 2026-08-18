import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/widgets/record_association_sheet.dart';
import '../../../companies/data/models/company_model.dart';
import '../../../companies/presentation/screens/company_details_screen.dart';
import '../../../contacts/data/models/contact_model.dart';
import '../../../contacts/presentation/screens/contact_details_screen.dart';
import '../../../deals/data/models/deal_model.dart';
import '../../../deals/presentation/screens/deal_details_screen.dart';
import '../widgets/log_meeting_modal.dart';

class MeetingDetailsScreen extends StatefulWidget {
  final MeetingModel meeting;

  const MeetingDetailsScreen({
    super.key,
    required this.meeting,
  });

  @override
  State<MeetingDetailsScreen> createState() => _MeetingDetailsScreenState();
}

class _MeetingDetailsScreenState extends State<MeetingDetailsScreen> {
  late MeetingModel _currentMeeting;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _currentMeeting = widget.meeting;
  }

  String _formatDisplayDate(String raw) {
    if (raw.isEmpty) return 'Aug 5, 2026 at 4:18 PM';
    try {
      if (raw.contains('T')) {
        final dt = DateTime.parse(raw);
        final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
        final ampm = dt.hour >= 12 ? 'PM' : 'AM';
        final min = dt.minute.toString().padLeft(2, '0');
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        final monthStr = months[dt.month - 1];
        return '$monthStr ${dt.day}, ${dt.year} at $hour:$min $ampm';
      }
    } catch (_) {}
    return raw;
  }

  Future<void> _handleDeleteMeeting() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete Meeting',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to delete this meeting?',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: const Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              elevation: 0,
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);
    try {
      final meetingId = _currentMeeting.id;
      if (meetingId != null && meetingId.isNotEmpty) {
        await ApiService().delete('${ApiConstants.activities}/$meetingId');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meeting deleted successfully'),
            backgroundColor: Color(0xFF0F766E),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('[DELETE MEETING ERROR]: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete meeting: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Future<void> _handleEditMeeting() async {
    final updated = await LogMeetingModal.show(
      context,
      existingMeeting: _currentMeeting,
    );

    if (updated != null && mounted) {
      setState(() {
        _currentMeeting = updated;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Meeting updated successfully'),
          backgroundColor: Color(0xFF0F766E),
        ),
      );
    }
  }

  Future<void> _handleChangeAssociation() async {
    final initialAssoc = <String, List<Map<String, String>>>{
      'Companies': _currentMeeting.companyId != null ? [{'id': _currentMeeting.companyId!, 'name': 'Associated Record'}] : [],
      'Contacts': _currentMeeting.contactId != null ? [{'id': _currentMeeting.contactId!, 'name': 'Associated Record'}] : [],
      'Deals': _currentMeeting.dealId != null ? [{'id': _currentMeeting.dealId!, 'name': 'Associated Record'}] : [],
    };

    final result = await RecordAssociationSheet.show(
      context,
      initialAssociations: initialAssoc,
    );

    if (result != null) {
      String? newContactId;
      String? newCompanyId;
      String? newDealId;

      if (result['Contacts'] != null && result['Contacts']!.isNotEmpty) {
        newContactId = result['Contacts']!.first['id'];
      }
      if (result['Companies'] != null && result['Companies']!.isNotEmpty) {
        newCompanyId = result['Companies']!.first['id'];
      }
      if (result['Deals'] != null && result['Deals']!.isNotEmpty) {
        newDealId = result['Deals']!.first['id'];
      }

      final meetingId = _currentMeeting.id;
      if (meetingId != null && meetingId.isNotEmpty) {
        try {
          await ApiService().put(
            '${ApiConstants.activities}/$meetingId',
            data: {
              'contactId': newContactId,
              'companyId': newCompanyId,
              'dealId': newDealId,
            },
          );
        } catch (e) {
          debugPrint('[UPDATE ASSOCIATION ERROR]: $e');
        }
      }

      setState(() {
        _currentMeeting = MeetingModel(
          id: _currentMeeting.id,
          title: _currentMeeting.title,
          outcome: _currentMeeting.outcome,
          duration: _currentMeeting.duration,
          startTime: _currentMeeting.startTime,
          notes: _currentMeeting.notes,
          assignedTo: _currentMeeting.assignedTo,
          contactId: newContactId,
          companyId: newCompanyId,
          dealId: newDealId,
        );
      });
    }
  }

  bool get _hasAssociation {
    return (_currentMeeting.contactId != null && _currentMeeting.contactId!.isNotEmpty) ||
        (_currentMeeting.companyId != null && _currentMeeting.companyId!.isNotEmpty) ||
        (_currentMeeting.dealId != null && _currentMeeting.dealId!.isNotEmpty);
  }

  void _openAssociationDetail() {
    if (_currentMeeting.contactId != null && _currentMeeting.contactId!.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ContactDetailsScreen(
            contact: ContactModel(
              id: _currentMeeting.contactId!,
              email: '',
              firstName: '',
              lastName: '',
            ),
          ),
        ),
      );
    } else if (_currentMeeting.companyId != null && _currentMeeting.companyId!.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CompanyDetailsScreen(
            company: CompanyModel(
              id: _currentMeeting.companyId!,
              name: '',
            ),
          ),
        ),
      );
    } else if (_currentMeeting.dealId != null && _currentMeeting.dealId!.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DealDetailsScreen(
            deal: DealModel(
              id: _currentMeeting.dealId!,
              title: '',
              amount: 0.0,
              stage: '',
              probability: 0,
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusLabel = _currentMeeting.outcome.isNotEmpty
        ? _currentMeeting.outcome.toUpperCase()
        : 'PENDING';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Go Back Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.chevron_left_rounded,
                          color: Color(0xFF0F766E),
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Go back',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F766E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 2. Main Details Card (Matching Image 1 & 2 layout)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Icon + Title + Status + Edit/Delete Icons
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE6F4F1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.videocam_outlined,
                                color: Color(0xFF0F766E),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _currentMeeting.title,
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF1F2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      statusLabel,
                                      style: GoogleFonts.poppins(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0F766E),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Action Icons: Pencil (Edit) & Trash (Delete)
                            Row(
                              children: [
                                IconButton(
                                  onPressed: _handleEditMeeting,
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: Color(0xFF64748B),
                                    size: 20,
                                  ),
                                  tooltip: 'Edit Meeting',
                                ),
                                IconButton(
                                  onPressed: _isDeleting ? null : _handleDeleteMeeting,
                                  icon: _isDeleting
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(
                                          Icons.delete_outline,
                                          color: Color(0xFF64748B),
                                          size: 20,
                                        ),
                                  tooltip: 'Delete Meeting',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const Divider(height: 1, color: Color(0xFFF1F5F9)),

                      // DESCRIPTION Section
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DESCRIPTION',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF475569),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _currentMeeting.notes.trim().isNotEmpty
                                    ? _currentMeeting.notes.trim()
                                    : 'No description provided for this meeting.',
                                style: GoogleFonts.poppins(
                                  fontSize: 13.5,
                                  fontStyle: _currentMeeting.notes.trim().isEmpty
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                                  color: _currentMeeting.notes.trim().isEmpty
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // MEETING INFORMATION Section
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MEETING INFORMATION',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF475569),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Date',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatDisplayDate(_currentMeeting.startTime),
                                        style: GoogleFonts.poppins(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF1E293B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Priority',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.circle,
                                            size: 8,
                                            color: Color(0xFFCBD5E1),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'None',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF1E293B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Assigned To / Creator',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.person_outline_rounded,
                                            size: 16,
                                            color: Color(0xFF64748B),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _currentMeeting.assignedTo ?? 'Admin User',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF1E293B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Queue / Type',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'meeting',
                                        style: GoogleFonts.poppins(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF1E293B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Associations Section
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Associations',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (!_hasAssociation) ...[
                                Text(
                                  'This meeting is currently unassigned and not associated with any contact, company, or deal.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12.5,
                                    color: const Color(0xFF64748B),
                                    height: 1.4,
                                  ),
                                ),
                              ] else ...[
                                InkWell(
                                  onTap: _openAssociationDetail,
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFCCFBF1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.link_rounded,
                                          size: 14,
                                          color: Color(0xFF0F766E),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'View Associated Record',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF0F766E),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              InkWell(
                                onTap: _handleChangeAssociation,
                                borderRadius: BorderRadius.circular(4),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _hasAssociation ? 'Change association' : 'Add association',
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF0F766E),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 18,
                                        color: Color(0xFF0F766E),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // HISTORY Section
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'HISTORY',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF475569),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: Icon(
                                    Icons.circle,
                                    size: 10,
                                    color: Color(0xFF0F766E),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Meeting created',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF1E293B),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatDisplayDate(_currentMeeting.startTime),
                                      style: GoogleFonts.poppins(
                                        fontSize: 11.5,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
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
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
