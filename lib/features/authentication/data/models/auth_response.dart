/// AuthResponse data model representing backend authentication response payloads.
class AuthResponse {
  final bool success;
  final String? message;
  final String? token;
  final Map<String, dynamic>? user;

  AuthResponse({
    required this.success,
    this.message,
    this.token,
    this.user,
  });

  /// Factory constructor to parse AuthResponse from JSON payload.
  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
      token: json['token'] as String?,
      user: json['user'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'token': token,
      'user': user,
    };
  }
}
