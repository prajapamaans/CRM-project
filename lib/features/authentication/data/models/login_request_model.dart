/// Model representing the POST /auth/login request payload.
class LoginRequestModel {
  final String email;
  final String password;
  final String? departmentId;

  LoginRequestModel({
    required this.email,
    required this.password,
    this.departmentId,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'email': email,
      'password': password,
    };
    if (departmentId != null) {
      data['departmentId'] = departmentId;
    }
    return data;
  }
}
