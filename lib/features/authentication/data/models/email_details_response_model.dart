class EmailDetailsDepartmentModel {
  final String id;
  final String name;

  EmailDetailsDepartmentModel({
    required this.id,
    required this.name,
  });

  factory EmailDetailsDepartmentModel.fromJson(Map<String, dynamic> json) {
    return EmailDetailsDepartmentModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

class EmailDetailsDataModel {
  final bool isAdmin;
  final String? role;
  final String? departmentId;
  final String? departmentName;
  final List<EmailDetailsDepartmentModel> departments;

  EmailDetailsDataModel({
    required this.isAdmin,
    this.role,
    this.departmentId,
    this.departmentName,
    required this.departments,
  });

  factory EmailDetailsDataModel.fromJson(Map<String, dynamic> json) {
    String? deptId = json['department_id'] as String? ?? json['departmentId'] as String?;
    String? deptName = json['department_name'] as String? ?? json['departmentName'] as String? ?? json['department'] as String?;
    final deptList = (json['departments'] as List<dynamic>?)
            ?.map((e) => EmailDetailsDepartmentModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    if (deptList.isNotEmpty) {
      deptId ??= deptList.first.id;
      deptName ??= deptList.first.name;
    }

    return EmailDetailsDataModel(
      isAdmin: json['isAdmin'] as bool? ?? json['is_admin'] as bool? ?? false,
      role: json['role'] as String?,
      departmentId: deptId,
      departmentName: deptName,
      departments: deptList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isAdmin': isAdmin,
      'role': role,
      'department_id': departmentId,
      'department_name': departmentName,
      'departments': departments.map((e) => e.toJson()).toList(),
    };
  }
}

class EmailDetailsResponseModel {
  final bool success;
  final EmailDetailsDataModel? data;
  final String? message;

  EmailDetailsResponseModel({
    required this.success,
    this.data,
    this.message,
  });

  String? get role => data?.role;
  String? get departmentId => data?.departmentId;
  String? get departmentName => data?.departmentName;
  bool get isAdmin => data?.isAdmin ?? false;

  factory EmailDetailsResponseModel.fromJson(Map<String, dynamic> json) {
    return EmailDetailsResponseModel(
      success: json['success'] as bool? ?? false,
      data: json['data'] != null
          ? EmailDetailsDataModel.fromJson(json['data'] as Map<String, dynamic>)
          : null,
      message: json['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'data': data?.toJson(),
      'message': message,
    };
  }
}
