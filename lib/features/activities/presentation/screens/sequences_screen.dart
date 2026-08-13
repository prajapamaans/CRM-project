import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/repositories/master_data_repository.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../companies/presentation/providers/company_provider.dart';
import '../../../contacts/presentation/providers/contact_provider.dart';
import '../../../deals/presentation/providers/deal_provider.dart';
import 'sequence_details_screen.dart';

class SequenceModel {
  final String id;
  final String name;
  final String? description;
  final bool isActive;
  final String creatorName;
  final int enrollmentCount;
  final int activeEnrollmentCount;
  final int automatedStepCount;
  final int manualStepCount;

  SequenceModel({
    required this.id,
    required this.name,
    this.description,
    required this.isActive,
    required this.creatorName,
    required this.enrollmentCount,
    required this.activeEnrollmentCount,
    required this.automatedStepCount,
    required this.manualStepCount,
  });

  factory SequenceModel.fromJson(Map<String, dynamic> json) {
    return SequenceModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? 'Untitled Sequence',
      description: json['description'] as String?,
      isActive: json['isActive'] as bool? ?? false,
      creatorName: json['creatorName'] as String? ?? 'Admin User',
      enrollmentCount: (json['enrollmentCount'] as num?)?.toInt() ?? 0,
      activeEnrollmentCount: (json['activeEnrollmentCount'] as num?)?.toInt() ?? 0,
      automatedStepCount: (json['automatedStepCount'] as num?)?.toInt() ?? 0,
      manualStepCount: (json['manualStepCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class SequencesScreen extends StatefulWidget {
  const SequencesScreen({super.key});

  @override
  State<SequencesScreen> createState() => _SequencesScreenState();
}

class _SequencesScreenState extends State<SequencesScreen> {
  bool _isLoading = true;
  List<SequenceModel> _sequences = [];
  int _totalCount = 0;
  String _selectedOwner = 'Any';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadScreenDataAndAPIs();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadScreenDataAndAPIs() async {
    if (!mounted) return;

    final auth = context.read<AuthProvider>();

    // Trigger standard app startup background API calls shown in Image 2 network logs
    auth.fetchUserProfile().catchError((e, s) => false);
    auth.fetchTeamMembers().then((_) {}).catchError((e, s) {});
    context.read<CompanyProvider>().fetchCompanies(ignorePermissions: true).catchError((e) => []);
    context.read<ContactProvider>().fetchContacts(ignorePermissions: true).catchError((e) => []);
    context.read<DealProvider>().fetchDeals(ignorePermissions: true).catchError((e) => []);

    // Call Sequences API http://192.168.250.2:8050/api/sequences?page=1&limit=20
    try {
      final repo = MasterDataRepositoryImpl();
      final res = await repo.getSequences(page: 1, limit: 20);
      if (mounted) {
        final List rawList = res['data'] is List ? res['data'] as List : [];
        final meta = res['meta'] is Map ? res['meta'] as Map : {};
        final total = (meta['total'] as num?)?.toInt() ?? rawList.length;

        setState(() {
          _sequences = rawList.map((e) => SequenceModel.fromJson(Map<String, dynamic>.from(e))).toList();
          _totalCount = total;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[SequencesScreen fetch error]: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter by search text if present
    final searchText = _searchController.text.trim().toLowerCase();
    final displayedSequences = _sequences.where((seq) {
      if (searchText.isEmpty) return true;
      return seq.name.toLowerCase().contains(searchText) ||
          seq.creatorName.toLowerCase().contains(searchText);
    }).toList();

    return Scaffold(
     
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadScreenDataAndAPIs,
          color: const Color(0xFF00897B),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subheader row: "1 of 5,000 created" | Actions dropdown | + Create button
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_totalCount > 0 ? _totalCount : _sequences.length} of 5,000 created',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF475569),
                              ),
                            ),
                          ),
                          // Actions dropdown button
                          OutlinedButton(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              backgroundColor: Colors.white,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Actions',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF00897B),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 16,
                                  color: Color(0xFF00897B),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // + Create button
                          ElevatedButton.icon(
                            onPressed: () {
                              final auth = context.read<AuthProvider>();
                              final user = auth.currentUser;
                              final currentUser = user != null
                                  ? '${user.firstName} ${user.lastName}'.trim()
                                  : 'Admin User';
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => SequenceDetailsScreen(
                                    ownerName: currentUser.isNotEmpty ? currentUser : 'Admin User',
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00897B),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            icon: const Icon(Icons.add, size: 16, color: Colors.white),
                            label: Text(
                              'Create',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Search bar field (Image 1 style)
                      Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Search sequences...',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF94A3B8),
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              size: 18,
                              color: Color(0xFF94A3B8),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          style: GoogleFonts.inter(fontSize: 13),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Filter Row: Owner: Any dropdown | New folder button (Image 1 style)
                      Row(
                        children: [
                          Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedOwner,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 16,
                                  color: Color(0xFF64748B),
                                ),
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  color: const Color(0xFF0F172A),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'Any',
                                    child: Text('Owner: Any'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Admin User',
                                    child: Text('Owner: Admin User'),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedOwner = val);
                                },
                              ),
                            ),
                          ),
                          const Spacer(),
                          OutlinedButton(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              backgroundColor: Colors.white,
                            ),
                            child: Text(
                              'New folder',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF334155),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Sequences List or Loading state matching Image 1 exact card design
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00897B)),
                            ),
                          ),
                        )
                      else if (displayedSequences.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.layers_clear_outlined, size: 36, color: Color(0xFF94A3B8)),
                              const SizedBox(height: 8),
                              Text(
                                'No sequences found',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: displayedSequences.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            return _buildSequenceCard(displayedSequences[index]);
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sequence card layout matching Image 1 box
  Widget _buildSequenceCard(SequenceModel item) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SequenceDetailsScreen(
              sequenceId: item.id,
              initialName: item.name,
              ownerName: item.creatorName,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x05000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title ("Test") in teal color
                    Text(
                      item.name,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF00897B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Subtitle line: "Enrolled: 1  •  Owner: Admin User"
                    Row(
                      children: [
                        Text(
                          'Enrolled: ${item.enrollmentCount}',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF475569),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '•',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Owner: ${item.creatorName}',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Right chevron icon (Image 1 style)
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: Color(0xFFCBD5E1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
