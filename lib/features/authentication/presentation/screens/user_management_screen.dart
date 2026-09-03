import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../departments/data/models/department_model.dart';
import '../../../departments/presentation/providers/department_provider.dart';
import '../../data/models/team_member_model.dart';
import '../providers/auth_provider.dart';

/// Comprehensive User Management screen.
/// Features dynamic multi-department tabs, accurate count calculations,
/// multi-department membership display, administrator cross-visibility,
/// deduplicated user lists, and dynamic department selection for user creation.
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilterDeptId = 'all';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().fetchTeamMembers();
      context.read<DepartmentProvider>().fetchDepartments();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Deduplicates list of team members strictly by user ID (or email fallback)
  List<TeamMemberModel> _deduplicateUsers(List<TeamMemberModel> users) {
    final Map<String, TeamMemberModel> uniqueMap = {};
    for (var u in users) {
      final key = u.id.isNotEmpty ? u.id : u.email.toLowerCase().trim();
      if (key.isNotEmpty && !uniqueMap.containsKey(key)) {
        uniqueMap[key] = u;
      }
    }
    return uniqueMap.values.toList();
  }

  /// Returns user list filtered by selected department and administrator visibility rules.
  List<TeamMemberModel> _getFilteredUsers(
    List<TeamMemberModel> allUsers,
    String? currentUserId,
    String selectedDeptId,
    String selectedDeptName,
  ) {
    final uniqueUsers = _deduplicateUsers(allUsers);

    return uniqueUsers.where((u) {
      // 1. Search Query Filter
      if (_searchQuery.isNotEmpty) {
        final matchesName = u.fullName.toLowerCase().contains(_searchQuery);
        final matchesEmail = u.email.toLowerCase().contains(_searchQuery);
        final matchesRole = (u.role ?? '').toLowerCase().contains(_searchQuery);
        final matchesDept = u.allDepartmentTags.any((d) => d.toLowerCase().contains(_searchQuery));
        if (!matchesName && !matchesEmail && !matchesRole && !matchesDept) {
          return false;
        }
      }

      // 2. Department Tab Filter
      if (selectedDeptId == 'all') {
        return true;
      }

      // Admin cross-visibility rule: currently logged-in admin remains visible across tabs
      if (currentUserId != null && currentUserId.isNotEmpty && u.id == currentUserId) {
        return true;
      }

      // Check if user belongs to the selected department by ID or Name
      return u.belongsToDepartment(selectedDeptId) || u.belongsToDepartment(selectedDeptName);
    }).toList();
  }

  /// Calculates dynamic department counts
  Map<String, int> _calculateDepartmentCounts(
    List<TeamMemberModel> allUsers,
    List<DepartmentModel> departments,
  ) {
    final uniqueUsers = _deduplicateUsers(allUsers);
    final Map<String, int> counts = {'all': uniqueUsers.length};

    for (var dept in departments) {
      counts[dept.id] = 0;
    }

    for (var u in uniqueUsers) {
      for (var dept in departments) {
        if (u.belongsToDepartment(dept.id) || u.belongsToDepartment(dept.name)) {
          counts[dept.id] = (counts[dept.id] ?? 0) + 1;
        }
      }
    }

    return counts;
  }

  void _showAddUserModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddUserModal(
        currentSelectedDeptId: _selectedFilterDeptId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final deptProvider = context.watch<DepartmentProvider>();

    final allMembers = authProvider.teamMembers;
    final departments = deptProvider.departments;
    final currentUser = authProvider.currentUser;

    final countsMap = _calculateDepartmentCounts(allMembers, departments);

    // Selected department name lookup
    String selectedDeptName = '';
    if (_selectedFilterDeptId != 'all') {
      final deptObj = departments.firstWhere(
        (d) => d.id == _selectedFilterDeptId,
        orElse: () => DepartmentModel(id: _selectedFilterDeptId, name: _selectedFilterDeptId),
      );
      selectedDeptName = deptObj.name;
    }

    final filteredUsers = _getFilteredUsers(
      allMembers,
      currentUser?.id,
      _selectedFilterDeptId,
      selectedDeptName,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: AppRefreshIndicator(
          onRefresh: () async {
            await authProvider.fetchTeamMembers();
            await deptProvider.fetchDepartments();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Card matching screenshot
                _buildHeaderCard(),
                const SizedBox(height: 16),

                // Department Filter Tabs Row
                _buildDepartmentFilterTabs(departments, countsMap),
                const SizedBox(height: 16),

                // Search Bar & Counter Row
                _buildSearchAndCounterRow(filteredUsers.length),
                const SizedBox(height: 16),

                // User List Container
                if (authProvider.isLoading && allMembers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFF00A884)),
                    ),
                  )
                else if (filteredUsers.isEmpty)
                  _buildEmptyState()
                else
                  Container(
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
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredUsers.length,
                      separatorBuilder: (context, index) => const Divider(
                        height: 1,
                        color: Color(0xFFF1F5F9),
                      ),
                      itemBuilder: (context, index) {
                        return _buildUserListItem(filteredUsers[index]);
                      },
                    ),
                  ),

                const SizedBox(height: 16),
                _buildInfoBanner(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Top Card: Header, Title, Subtitle & Add User Button
  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F4F1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.people_alt_outlined,
                  color: Color(0xFF00A884),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User Management',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Manage organization users, multi-department access, roles, and permissions.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: _showAddUserModal,
              icon: const Icon(Icons.add, size: 18, color: Colors.white),
              label: Text(
                'Add User',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A884),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Department Filter Tabs Header Row
  Widget _buildDepartmentFilterTabs(
    List<DepartmentModel> departments,
    Map<String, int> countsMap,
  ) {
    final List<Map<String, dynamic>> tabs = [
      {
        'id': 'all',
        'name': 'All',
        'count': countsMap['all'] ?? 0,
      },
      ...departments.map((d) => {
            'id': d.id,
            'name': d.name,
            'count': countsMap[d.id] ?? 0,
          }),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: tabs.map((tab) {
          final String id = tab['id'] as String;
          final String name = tab['name'] as String;
          final int count = tab['count'] as int;
          final bool isSelected = _selectedFilterDeptId == id;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              showCheckmark: false,
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.25)
                          : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : const Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
              selectedColor: const Color(0xFF00A884),
              backgroundColor: Colors.white,
              side: BorderSide(
                color: isSelected ? const Color(0xFF00A884) : const Color(0xFFCBD5E1),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedFilterDeptId = id;
                  });
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Search Bar and Filtered User Counter
  Widget _buildSearchAndCounterRow(int filteredCount) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.poppins(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search users by name, email, or department...',
                hintStyle: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            '$filteredCount users',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
        ),
      ],
    );
  }

  /// User List Item Display with Avatar, Role, Multi-Department Badges, and Action Popup
  Widget _buildUserListItem(TeamMemberModel user) {
    final initial = user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U';
    final deptTags = user.allDepartmentTags;
    final roleText = (user.role != null && user.role!.isNotEmpty) ? user.role! : 'User';
    final subtitle = (user.position != null && user.position!.isNotEmpty)
        ? '${user.email} • ${user.position}'
        : user.email;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF00A884),
            child: Text(
              initial,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        roleText.toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Multi-Department Badges Display
                if (deptTags.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: deptTags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F4F1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFB2DFDB)),
                        ),
                        child: Text(
                          tag,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF00796B),
                          ),
                        ),
                      );
                    }).toList(),
                  )
                else
                  Text(
                    'No Department Assigned',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),

                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<int>(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: Color(0xFF94A3B8),
              size: 20,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 1,
                child: Text('Edit User Access', style: GoogleFonts.poppins(fontSize: 13)),
              ),
              PopupMenuItem(
                value: 2,
                child: Text('View Details', style: GoogleFonts.poppins(fontSize: 13)),
              ),
            ],
            onSelected: (val) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Selected option for ${user.fullName}'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(Icons.people_outline, size: 48, color: Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text(
            'No users found',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try adjusting your department filter or search term.',
            style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: Color(0xFF0F766E)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Users with multiple departments have data access across all assigned departments. Adding a user saves them under the exact selected department ID.',
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                color: const Color(0xFF334155),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Add User Modal Dialog Form
class _AddUserModal extends StatefulWidget {
  final String currentSelectedDeptId;

  const _AddUserModal({required this.currentSelectedDeptId});

  @override
  State<_AddUserModal> createState() => _AddUserModalState();
}

class _AddUserModalState extends State<_AddUserModal> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();

  String _selectedRole = 'USER';
  String? _selectedDeptId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final depts = context.read<DepartmentProvider>().departments;
    if (depts.isNotEmpty) {
      if (widget.currentSelectedDeptId != 'all' &&
          depts.any((d) => d.id == widget.currentSelectedDeptId)) {
        _selectedDeptId = widget.currentSelectedDeptId;
      } else {
        _selectedDeptId = depts.first.id;
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submitUser() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDeptId == null || _selectedDeptId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a valid department'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.createUser(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      email: _emailController.text.trim(),
      role: _selectedRole,
      departmentId: _selectedDeptId!,
    );

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });

      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'User ${_firstNameController.text.trim()} added successfully!',
            ),
            backgroundColor: const Color(0xFF00A884),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        final errorMsg = authProvider.error ?? 'Failed to create user. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final depts = context.watch<DepartmentProvider>().departments;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Add New User',
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // First Name
              Text(
                'First Name *',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _firstNameController,
                style: GoogleFonts.poppins(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'John',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'First name is required' : null,
              ),
              const SizedBox(height: 12),

              // Last Name
              Text(
                'Last Name',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _lastNameController,
                style: GoogleFonts.poppins(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Doe',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),

              // Email Address
              Text(
                'Email Address *',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.poppins(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'john.doe@example.com',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  if (!v.contains('@') || !v.contains('.')) return 'Enter valid email address';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Dynamic Department Dropdown
              Text(
                'Department *',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: depts.any((d) => d.id == _selectedDeptId) ? _selectedDeptId : (depts.isNotEmpty ? depts.first.id : null),
                style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF1E293B)),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: depts.map((d) {
                  return DropdownMenuItem<String>(
                    value: d.id,
                    child: Text(d.dropdownName, style: GoogleFonts.poppins(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedDeptId = val;
                  });
                },
                validator: (v) => v == null || v.isEmpty ? 'Select department' : null,
              ),
              const SizedBox(height: 12),

              // Role Dropdown
              Text(
                'Role *',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF1E293B)),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: const [
                  DropdownMenuItem(value: 'USER', child: Text('User')),
                  DropdownMenuItem(value: 'ADMIN', child: Text('Administrator')),
                  DropdownMenuItem(value: 'SUPER_ADMIN', child: Text('Super Admin')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedRole = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 20),

              // Action Buttons
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A884),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: _isSubmitting ? null : _submitUser,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Create User',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
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
