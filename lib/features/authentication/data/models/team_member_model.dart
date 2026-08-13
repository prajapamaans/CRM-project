/// Model representing a team member returned from GET /api/auth/team.
class TeamMemberModel {
  final String id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;
  final String? role;
  final String? departmentId;
  final String? departmentName;
  final String? position;
  final List<String>? departmentNames;

  TeamMemberModel({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.avatarUrl,
    this.role,
    this.departmentId,
    this.departmentName,
    this.position,
    this.departmentNames,
  });

  factory TeamMemberModel.fromJson(Map<String, dynamic> json) {
    List<String>? deptNames;
    if (json['departments'] is List) {
      deptNames = (json['departments'] as List)
          .whereType<Map<String, dynamic>>()
          .map((d) => d['name']?.toString() ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
    }

    return TeamMemberModel(
      id: json['id'] as String? ?? json['userId'] as String? ?? '',
      email: json['email'] as String? ?? '',
      firstName: json['first_name'] as String? ?? json['firstName'] as String?,
      lastName: json['last_name'] as String? ?? json['lastName'] as String?,
      avatarUrl: json['avatar_url'] as String? ?? json['avatarUrl'] as String?,
      role: json['role'] as String?,
      departmentId: json['department_id'] as String? ?? json['departmentId'] as String?,
      departmentName: json['department_name'] as String? ?? json['departmentName'] as String? ?? json['department'] as String?,
      position: json['position'] as String?,
      departmentNames: deptNames,
    );
  }

  String get fullName {
    final first = firstName ?? '';
    final last = lastName ?? '';
    final full = '$first $last'.trim();
    return full.isNotEmpty ? full : email;
  }

  List<String> get allDepartmentTags {
    if (departmentNames != null && departmentNames!.isNotEmpty) {
      return departmentNames!;
    }
    if (departmentName != null && departmentName!.isNotEmpty) {
      return [departmentName!];
    }
    return const [];
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'avatar_url': avatarUrl,
      'role': role,
      'department_id': departmentId,
      'department_name': departmentName,
      'position': position,
      'department_names': departmentNames,
    };
  }

  TeamMemberModel copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    String? avatarUrl,
    String? role,
    String? departmentId,
    String? departmentName,
    String? position,
    List<String>? departmentNames,
  }) {
    return TeamMemberModel(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      departmentId: departmentId ?? this.departmentId,
      departmentName: departmentName ?? this.departmentName,
      position: position ?? this.position,
      departmentNames: departmentNames ?? this.departmentNames,
    );
  }
}
