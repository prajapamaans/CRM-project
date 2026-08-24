/// Model representing a team member returned from GET /api/auth/team or /users.
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
  final List<String>? departmentIds;

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
    this.departmentIds,
  });

  factory TeamMemberModel.fromJson(Map<String, dynamic> json) {
    final List<String> deptNames = [];
    final List<String> deptIds = [];

    // 1. Parse departments array (maps or strings)
    if (json['departments'] is List) {
      for (var item in json['departments'] as List) {
        if (item is Map<String, dynamic>) {
          final idStr = item['id']?.toString() ?? item['_id']?.toString() ?? '';
          final nameStr = item['name']?.toString() ?? '';
          if (nameStr.isNotEmpty && !deptNames.contains(nameStr)) {
            deptNames.add(nameStr);
          }
          if (idStr.isNotEmpty && !deptIds.contains(idStr)) {
            deptIds.add(idStr);
          }
        } else if (item != null) {
          final str = item.toString().trim();
          if (str.isNotEmpty && !deptNames.contains(str)) {
            deptNames.add(str);
          }
        }
      }
    }

    // 2. Parse department_names / departmentNames
    final rawDeptNames = json['department_names'] ?? json['departmentNames'] ?? json['department_tags'];
    if (rawDeptNames is List) {
      for (var d in rawDeptNames) {
        if (d != null) {
          final str = d.toString().trim();
          if (str.isNotEmpty && !deptNames.contains(str)) {
            deptNames.add(str);
          }
        }
      }
    }

    // 3. Parse department_ids / departmentIds
    final rawDeptIds = json['department_ids'] ?? json['departmentIds'];
    if (rawDeptIds is List) {
      for (var d in rawDeptIds) {
        if (d != null) {
          final str = d.toString().trim();
          if (str.isNotEmpty && !deptIds.contains(str)) {
            deptIds.add(str);
          }
        }
      }
    }

    // 4. Parse single department string/id
    final singleName = json['department_name'] as String? ??
        json['departmentName'] as String? ??
        json['department'] as String?;
    if (singleName != null && singleName.isNotEmpty && !deptNames.contains(singleName)) {
      deptNames.add(singleName);
    }

    final singleId = json['department_id'] as String? ??
        json['departmentId'] as String?;
    if (singleId != null && singleId.isNotEmpty && !deptIds.contains(singleId)) {
      deptIds.add(singleId);
    }

    return TeamMemberModel(
      id: json['id'] as String? ?? json['userId'] as String? ?? json['_id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      firstName: json['first_name'] as String? ?? json['firstName'] as String?,
      lastName: json['last_name'] as String? ?? json['lastName'] as String?,
      avatarUrl: json['avatar_url'] as String? ?? json['avatarUrl'] as String?,
      role: json['role'] as String?,
      departmentId: singleId ?? (deptIds.isNotEmpty ? deptIds.first : null),
      departmentName: singleName ?? (deptNames.isNotEmpty ? deptNames.first : null),
      position: json['position'] as String?,
      departmentNames: deptNames.isNotEmpty ? deptNames : null,
      departmentIds: deptIds.isNotEmpty ? deptIds : null,
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

  List<String> get allDepartmentIdsList {
    if (departmentIds != null && departmentIds!.isNotEmpty) {
      return departmentIds!;
    }
    if (departmentId != null && departmentId!.isNotEmpty) {
      return [departmentId!];
    }
    return const [];
  }

  bool belongsToDepartment(String deptIdOrName) {
    if (deptIdOrName.isEmpty || deptIdOrName.toLowerCase() == 'all') return true;
    final lower = deptIdOrName.toLowerCase().trim();

    if (departmentIds != null && departmentIds!.any((id) => id.toLowerCase().trim() == lower)) {
      return true;
    }
    if (departmentId != null && departmentId!.toLowerCase().trim() == lower) {
      return true;
    }

    if (departmentNames != null && departmentNames!.any((name) => name.toLowerCase().trim() == lower)) {
      return true;
    }
    if (departmentName != null && departmentName!.toLowerCase().trim() == lower) {
      return true;
    }

    return false;
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
      'department_ids': departmentIds,
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
    List<String>? departmentIds,
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
      departmentIds: departmentIds ?? this.departmentIds,
    );
  }
}

