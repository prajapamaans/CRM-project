class EmailDetailsRequestModel {
  final String email;

  EmailDetailsRequestModel({required this.email});

  Map<String, dynamic> toJson() {
    return {
      'email': email,
    };
  }
}
