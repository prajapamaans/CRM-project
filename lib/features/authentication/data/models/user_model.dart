/// Model representing department item assigned to a user.
class UserDepartment {
  final String id;
  final String name;

  UserDepartment({required this.id, required this.name});

  factory UserDepartment.fromJson(Map<String, dynamic> json) {
    return UserDepartment(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

/// Model representing resource permission details.
class PermissionDetail {
  final bool view;
  final bool edit;
  final bool delete;

  PermissionDetail({
    this.view = false,
    this.edit = false,
    this.delete = false,
  });

  factory PermissionDetail.fromJson(Map<String, dynamic> json) {
    return PermissionDetail(
      view: json['view'] as bool? ?? false,
      edit: json['edit'] as bool? ?? false,
      delete: json['delete'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {'view': view, 'edit': edit, 'delete': delete};
}

/// Model representing authenticated user profile from GET /auth/me.
class UserModel {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final String? organizationId;
  final String? teamId;
  final String? role;
  final String? position;
  final String? phone;
  final String? departmentId;
  final String? departmentName;
  final List<UserDepartment> departments;
  final Map<String, PermissionDetail> permissions;

  UserModel({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    this.organizationId,
    this.teamId,
    this.role,
    this.position,
    this.phone,
    this.departmentId,
    this.departmentName,
    this.departments = const [],
    this.permissions = const {},
  });

  String get fullName => '$firstName $lastName'.trim();
  List<String> get allDepartmentIds => departments.map((d) => d.id).toList();

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final rootData = json['data'] as Map<String, dynamic>?;
    final userJson = (rootData != null && rootData.containsKey('user'))
        ? rootData['user'] as Map<String, dynamic>
        : (json.containsKey('user') ? json['user'] as Map<String, dynamic> : json);

    final deptsJson = userJson['departments'] as List<dynamic>? ?? [];
    final permissionsJson = userJson['permissions'] as Map<String, dynamic>? ?? {};

    final Map<String, PermissionDetail> parsedPermissions = {};
    permissionsJson.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        parsedPermissions[key] = PermissionDetail.fromJson(value);
      }
    });

    return UserModel(
      id: userJson['id'] as String? ?? userJson['_id'] as String? ?? '',
      email: userJson['email'] as String? ?? '',
      firstName: userJson['firstName'] as String? ?? userJson['first_name'] as String? ?? '',
      lastName: userJson['lastName'] as String? ?? userJson['last_name'] as String? ?? '',
      avatarUrl: userJson['avatarUrl'] as String? ?? userJson['avatar_url'] as String?,
      organizationId: userJson['organization_id'] as String? ?? userJson['organizationId'] as String?,
      teamId: userJson['teamId'] as String? ?? userJson['team_id'] as String?,
      role: userJson['role'] as String?,
      position: userJson['position'] as String?,
      phone: userJson['phone'] as String?,
      departmentId: userJson['departmentId'] as String? ?? userJson['department_id'] as String?,
      departmentName: userJson['departmentName'] as String? ?? userJson['department_name'] as String?,
      departments: deptsJson
          .map((e) => UserDepartment.fromJson(e as Map<String, dynamic>))
          .toList(),
      permissions: parsedPermissions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'avatarUrl': avatarUrl,
      'organization_id': organizationId,
      'teamId': teamId,
      'role': role,
      'position': position,
      'phone': phone,
      'departmentId': departmentId,
      'departmentName': departmentName,
      'departments': departments.map((d) => d.toJson()).toList(),
      'permissions': permissions.map((k, v) => MapEntry(k, v.toJson())),
    };
  }
}
