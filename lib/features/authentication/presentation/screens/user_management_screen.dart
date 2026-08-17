import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../authentication/data/models/team_member_model.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../contacts/data/repositories/contact_repository.dart';
import '../../../departments/presentation/providers/department_provider.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  int _selectedFilterIndex = 0; // 0: All, 1: APAC Team, 2: Australia, 3: Talent Acquisition (Night)
  bool _isLoading = false;
  String? _error;

  List<TeamMemberModel> _teamMembers = [];
  Map<String, bool> _emailPreferences = {}; // userId -> isEmailEnabled

  @override
  void initState() {
    super.initState();
    _fetchUsersAndPreferences();
  }

  Future<void> _fetchUsersAndPreferences() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final deptProvider = context.read<DepartmentProvider>();

      // Load real department IDs from GET /api/departments so the per-department
      // team fetches hit the correct departments (falls back to defaults on error).
      try {
        await deptProvider.fetchDepartments();
      } catch (e) {
        debugPrint('[UserManagementScreen fetchDepartments error]: $e');
      }

      final depts = deptProvider.availableDepartments;

      // Single source of truth keyed by user id (or email when id is missing).
      // All API sources use the SAME key so no user is ever added twice.
      final Map<String, TeamMemberModel> membersById = {};

      String memberKey(TeamMemberModel m) => m.id.isNotEmpty ? m.id : m.email;

      void upsert(TeamMemberModel m, {String? fallbackDeptId, String? fallbackDeptName}) {
        final key = memberKey(m);
        if (key.isEmpty) return;

        final existing = membersById[key];
        if (existing == null) {
          membersById[key] = m.copyWith(
            departmentId: m.departmentId ?? fallbackDeptId,
            departmentName: (m.departmentName != null && m.departmentName!.isNotEmpty)
                ? m.departmentName
                : fallbackDeptName,
          );
        } else {
          // Merge department tags so multi-department users keep ALL their
          // department tags instead of only the first one seen.
          final incomingTags = m.allDepartmentTags.isNotEmpty
              ? m.allDepartmentTags
              : (fallbackDeptName != null && fallbackDeptName.isNotEmpty
                  ? <String>[fallbackDeptName]
                  : const <String>[]);
          final mergedTags = <String>{...existing.allDepartmentTags, ...incomingTags}.toList();

          membersById[key] = existing.copyWith(
            id: existing.id.isNotEmpty ? existing.id : m.id,
            email: existing.email.isNotEmpty ? existing.email : m.email,
            firstName: existing.firstName ?? m.firstName,
            lastName: existing.lastName ?? m.lastName,
            avatarUrl: existing.avatarUrl ?? m.avatarUrl,
            role: existing.role ?? m.role,
            departmentId: m.departmentId ?? existing.departmentId ?? fallbackDeptId,
            departmentName: existing.departmentName ?? m.departmentName ?? fallbackDeptName,
            departmentNames: mergedTags.isEmpty ? existing.departmentNames : mergedTags,
          );
        }
      }

      // 1. GET /api/users - returns ALL users across every department. This is
      //    the primary source, matching the records shown on the original site.
      try {
        final allDeptOpt = Options(headers: {'X-Department-Id': 'all', 'departmentId': 'all', 'department_id': 'all'});
        final resp = await ApiService().get(
          '/users',
          queryParameters: {'limit': 1000},
          options: allDeptOpt,
        );
        final dynamic rawData = resp.data;
        final List<dynamic> list = [];
        if (rawData is List) {
          list.addAll(rawData);
        } else if (rawData is Map<String, dynamic>) {
          if (rawData['data'] is List) {
            list.addAll(rawData['data'] as List);
          } else if (rawData['users'] is List) {
            list.addAll(rawData['users'] as List);
          }
        }
        for (var e in list) {
          if (e is Map<String, dynamic>) {
            upsert(TeamMemberModel.fromJson(e));
          }
        }
      } catch (e) {
        debugPrint('[UserManagementScreen /users fetch error]: $e');
      }

      // 2. Fetch users one by one for each department to fill in/enrich
      //    department tags when the /users payload omits them.
      for (final dept in depts) {
        try {
          debugPrint('[UserManagementScreen] Fetching users for department: ${dept.name} (${dept.id})...');
          final deptMembers = await authProvider.fetchTeamMembers(
            departmentId: dept.id,
            departmentName: dept.name,
          );
          for (var m in deptMembers) {
            upsert(m, fallbackDeptId: dept.id, fallbackDeptName: dept.name);
          }
        } catch (e) {
          debugPrint('[UserManagementScreen fetch dept ${dept.name} error]: $e');
        }
      }

      // 2. Global team fetch WITHOUT any department filter, to catch users that
      //    are not returned by any single-department call. Passing an 'all'
      //    department header stops AuthInterceptor from injecting the currently
      //    selected department (auth_interceptor.dart).
      try {
        final allDeptOpt = Options(headers: {'X-Department-Id': 'all', 'departmentId': 'all', 'department_id': 'all'});
        final resp = await ApiService().get(ApiConstants.team, options: allDeptOpt);
        final dynamic rawData = resp.data;
        final List<dynamic> list = [];
        if (rawData is List) {
          list.addAll(rawData);
        } else if (rawData is Map<String, dynamic> && rawData['data'] is List) {
          list.addAll(rawData['data'] as List);
        }
        for (var e in list) {
          if (e is Map<String, dynamic>) {
            upsert(TeamMemberModel.fromJson(e));
          }
        }
      } catch (e) {
        debugPrint('[UserManagementScreen global team fetch error]: $e');
      }

      // 3. Call GET /api/users/email-preferences
      Map<String, bool> prefsMap = {};
      try {
        dynamic raw;
        final allDeptOpt = Options(headers: {'X-Department-Id': 'all', 'departmentId': 'all', 'department_id': 'all'});
        try {
          final resp = await ApiService().get('/users/email-preferences', options: allDeptOpt);
          raw = resp.data;
        } catch (_) {
          final resp = await ApiService().get('/email-preferences', options: allDeptOpt);
          raw = resp.data;
        }
        
        List<dynamic> items = [];
        if (raw is List) {
          items = raw;
        } else if (raw is Map<String, dynamic>) {
          if (raw['data'] is List) {
            items = raw['data'] as List;
          } else {
            raw.forEach((key, val) {
              prefsMap[key] = val == true || val == 1 || val == 'true';
            });
          }
        }

        for (var item in items) {
          if (item is Map<String, dynamic>) {
            final uId = item['userId']?.toString() ?? item['id']?.toString();
            if (uId != null && uId.isNotEmpty) {
              final prefs = item['preferences'];
              if (prefs is Map<String, dynamic>) {
                final isAnyEnabled = prefs.values.any((v) => v == true || v == 1 || v == 'true');
                prefsMap[uId] = isAnyEnabled;
              } else if (item['enabled'] != null) {
                prefsMap[uId] = item['enabled'] == true;
              }
            }

            final email = item['email'] as String? ?? '';
            final id = item['userId'] as String? ?? item['id'] as String? ?? '';
            if (id.isNotEmpty || email.isNotEmpty) {
              final member = TeamMemberModel(
                id: id,
                email: email,
                firstName: item['firstName'] as String?,
                lastName: item['lastName'] as String?,
                avatarUrl: item['avatarUrl'] as String?,
                role: item['role'] as String?,
                departmentId: item['departmentId'] as String?,
                departmentName: item['departmentName'] as String?,
              );
              upsert(member);
            }
          }
        }
      } catch (e) {
        debugPrint('[UserManagementScreen users/email-preferences error]: $e');
      }

      // 4. Fetch contacts from GET /api/contacts to extract pure API contact entries & assignees
      try {
        final contactsRes = await ContactRepositoryImpl().getContacts(
          page: '1',
          limit: '100',
          ignorePermissions: true,
        );
        for (var c in contactsRes.contacts) {
          if (c.email.isEmpty && (c.firstName == null || c.firstName!.isEmpty)) continue;

          final contactUser = TeamMemberModel(
            id: c.id,
            email: c.email,
            firstName: c.firstName,
            lastName: c.lastName,
            avatarUrl: c.avatarUrl,
            role: 'user',
            departmentId: c.companyId,
            departmentName: c.companyName,
          );

          upsert(contactUser);
        }
      } catch (e) {
        debugPrint('[UserManagementScreen contacts fetch error]: $e');
      }

      if (mounted) {
        setState(() {
          _teamMembers = _dedupeByName(membersById.values.toList());
          _emailPreferences = prefsMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load team members: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// Ranks how complete a member record is so dedup keeps the richest entry.
  int _completeness(TeamMemberModel m) {
    var score = 0;
    if (m.id.isNotEmpty) score += 4;
    if (m.email.isNotEmpty) score += 2;
    if (m.allDepartmentTags.isNotEmpty) score += 2;
    if ((m.firstName?.isNotEmpty ?? false) || (m.lastName?.isNotEmpty ?? false)) score += 1;
    return score;
  }

  /// Normalizes a name for duplicate detection: lowercases, trims each part and
  /// collapses internal whitespace so "Mansi  Prajapati" == "mansi prajapati".
  String _normalizedName(TeamMemberModel m) {
    final first = (m.firstName ?? '').trim();
    final last = (m.lastName ?? '').trim();
    final full = '$first $last'.trim().toLowerCase();
    return full.replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Merges a group of records that belong to the same person: keeps the most
  /// complete record and unions department tags.
  TeamMemberModel _mergeMembers(List<TeamMemberModel> group) {
    var best = group.first;
    for (final m in group.skip(1)) {
      if (_completeness(m) > _completeness(best)) best = m;
    }

    final mergedTags = <String>{};
    for (final m in group) {
      mergedTags.addAll(m.allDepartmentTags);
    }

    return mergedTags.isEmpty ? best : best.copyWith(departmentNames: mergedTags.toList());
  }

  /// Removes duplicate people that appear under different ids/emails across the
  /// merged API sources (e.g. a user who is also a contact). Two passes:
  /// 1) merge records sharing the same email (even if names differ), then
  /// 2) merge remaining records sharing the same normalized name (even if the
  /// ids/emails differ). The richest record is kept and department tags are
  /// unioned, so a person in multiple departments shows every department badge.
  List<TeamMemberModel> _dedupeByName(List<TeamMemberModel> members) {
    // Pass 1: group by email (case-insensitive).
    final byEmail = <String, List<TeamMemberModel>>{};
    for (final m in members) {
      final email = m.email.trim().toLowerCase();
      if (email.isEmpty) continue;
      byEmail.putIfAbsent(email, () => []).add(m);
    }

    final afterEmail = <TeamMemberModel>[];
    for (final group in byEmail.values) {
      afterEmail.add(_mergeMembers(group));
    }
    for (final m in members) {
      if (m.email.trim().isEmpty) afterEmail.add(m);
    }

    // Pass 2: group remaining records by normalized name.
    final byName = <String, List<TeamMemberModel>>{};
    for (final m in afterEmail) {
      final nameKey = _normalizedName(m);
      if (nameKey.isEmpty) continue;
      byName.putIfAbsent(nameKey, () => []).add(m);
    }

    final result = <TeamMemberModel>[];
    for (final group in byName.values) {
      result.add(_mergeMembers(group));
    }
    for (final m in afterEmail) {
      if (_normalizedName(m).isEmpty) result.add(m);
    }

    return result;
  }

  Future<void> _savePreferences() async {
    try {
      final List<Map<String, dynamic>> payload = _teamMembers
          .where((m) => m.id.isNotEmpty)
          .map((m) {
            final isEnabled = _emailPreferences[m.id] ?? false;
            return {
              'userId': m.id,
              'preferences': {
                'companies': isEnabled,
                'contacts': isEnabled,
                'deals': isEnabled,
                'tasks': isEnabled,
                'meetings': isEnabled,
                'calls': isEnabled,
                'exports': isEnabled,
              }
            };
          })
          .toList();

      await ApiService().put('/users/email-preferences', data: {'preferences': payload});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User preferences saved successfully!', style: GoogleFonts.poppins()),
            backgroundColor: const Color(0xFF00A884),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[UserManagementScreen _savePreferences error]: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save preferences. Please try again.', style: GoogleFonts.poppins()),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showAddUserModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddUserModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deptProvider = context.watch<DepartmentProvider>();
    final depts = deptProvider.availableDepartments;

    // Filter categories matching UI header pills
    final filterChips = [
      {'label': 'All', 'count': _teamMembers.length},
      ...depts.map((d) {
        final count = _teamMembers.where((m) {
          return m.allDepartmentTags.any((t) => t.toLowerCase().contains(d.name.toLowerCase()));
        }).length;
        return {'label': d.name, 'count': count};
      }),
    ];

    final filteredUsers = _teamMembers.where((user) {
      if (_selectedFilterIndex == 0) return true;
      if (_selectedFilterIndex - 1 < depts.length) {
        final targetDept = depts[_selectedFilterIndex - 1];
        return user.allDepartmentTags.any((t) => t.toLowerCase().contains(targetDept.name.toLowerCase()));
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: AppRefreshIndicator(
          onRefresh: _fetchUsersAndPreferences,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Header Bar: Icon, Title, Add User, Save
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.mail_outline_rounded,
                        color: Color(0xFF00A884),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'User Management',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _showAddUserModal,
                        icon: const Icon(Icons.person_add_alt_outlined, size: 16, color: Color(0xFF334155)),
                        label: Text(
                          'Add User',
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _savePreferences,
                        icon: const Icon(Icons.save_outlined, size: 16, color: Color(0xFF334155)),
                        label: Text(
                          'Save',
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 2. Department Filter Chips Row: All (23), APAC Team (3), Australia (4), Talent...
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(filterChips.length, (index) {
                    final isSelected = _selectedFilterIndex == index;
                    final chip = filterChips[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () => setState(() => _selectedFilterIndex = index),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFE2F1ED) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF00A884) : const Color(0xFFE2E8F0),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected ? const Color(0xFF00A884) : const Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                chip['label'].toString(),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                  color: isSelected ? const Color(0xFF0F5C5B) : const Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF0F5C5B) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  chip['count'].toString(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 14),

              // Subtitle Description
              Text(
                'Configure access permissions and email notifications for each user.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),

              const SizedBox(height: 16),

              // 3. User Table Container
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Table Header: USER & ACTIONS
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'USER',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF94A3B8),
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            'ACTIONS',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF94A3B8),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1, color: Color(0xFFF1F5F9)),

                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(color: Color(0xFF00A884)),
                        ),
                      )
                    else if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
                        child: Text(_error!, style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 13)),
                      )
                    else if (filteredUsers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text('No users match selected filter.', style: GoogleFonts.poppins(color: const Color(0xFF94A3B8))),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredUsers.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        itemBuilder: (context, index) {
                          final user = filteredUsers[index];
                          return _buildUserListItem(user);
                        },
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 4. Bottom Legend: Email enabled / Email disabled
              Row(
                children: [
                  Text(
                    'Legend:',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00A884),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Icon(Icons.check, size: 10, color: Colors.white),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Email enabled',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Email disabled',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
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
      ),
    ),
    );
  }

  /// User list item matching screenshot with Teal initial circle, expandable arrow, tags, and 3-dots action
  Widget _buildUserListItem(TeamMemberModel user) {
    final initial = user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U';
    final tags = user.allDepartmentTags;
    final subtitle = (user.position != null && user.position!.isNotEmpty)
        ? '${user.email} • ${user.position}'
        : user.email;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Expand chevron icon
          const Padding(
            padding: EdgeInsets.only(top: 10, right: 8),
            child: Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFCBD5E1),
              size: 20,
            ),
          ),

          // User Avatar Circle
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

          // User Name, Department Badges, Email
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                // Department Badges Pill List
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2F1ED),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        tag,
                        style: GoogleFonts.poppins(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F5C5B),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),

          // Actions vertical 3-dots popup button
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
                child: Text('Edit Access & Permissions', style: GoogleFonts.poppins(fontSize: 13)),
              ),
              PopupMenuItem(
                value: 2,
                child: Text('Toggle Email Notifications', style: GoogleFonts.poppins(fontSize: 13)),
              ),
            ],
            onSelected: (val) {
              if (val == 1) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Editing permissions for ${user.fullName}'), behavior: SnackBarBehavior.floating),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Add User Modal Bottom Sheet
class _AddUserModal extends StatefulWidget {
  const _AddUserModal();

  @override
  State<_AddUserModal> createState() => _AddUserModalState();
}

class _AddUserModalState extends State<_AddUserModal> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  String _selectedRole = 'USER';
  String _selectedDept = DepartmentConstants.apacId;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Add New User', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _firstNameController,
              decoration: const InputDecoration(labelText: 'First Name', border: OutlineInputBorder()),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lastNameController,
              decoration: const InputDecoration(labelText: 'Last Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder()),
              validator: (v) => v == null || !v.contains('@') ? 'Enter valid email' : null,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A884),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('User invitation sent successfully!'), behavior: SnackBarBehavior.floating),
                    );
                  }
                },
                child: Text('Add User', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
