/// Model representing POST /auth/login response payload.
class LoginResponseModel {
  final bool success;
  final String? message;
  final String? accessToken;
  final String? refreshToken;
  final Map<String, dynamic>? user;

  LoginResponseModel({
    required this.success,
    this.message,
    this.accessToken,
    this.refreshToken,
    this.user,
  });

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    return LoginResponseModel(
      success: json['success'] as bool? ?? true,
      message: json['message'] as String?,
      accessToken: data != null ? data['access_token'] as String? : json['access_token'] as String?,
      refreshToken: data != null ? data['refresh_token'] as String? : json['refresh_token'] as String?,
      user: data != null ? data['user'] as Map<String, dynamic>? : json['user'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'user': user,
    };
  }
}
