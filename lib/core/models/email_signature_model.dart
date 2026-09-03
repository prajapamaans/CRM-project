/// Data model representing an Email Signature entity.
class EmailSignatureModel {
  final String id;
  final String name;
  final String body;
  final bool isDefault;
  final String? createdAt;
  final String? updatedAt;

  EmailSignatureModel({
    required this.id,
    required this.name,
    required this.body,
    this.isDefault = false,
    this.createdAt,
    this.updatedAt,
  });

  factory EmailSignatureModel.fromJson(Map<String, dynamic> json) {
    return EmailSignatureModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      isDefault: json['isDefault'] == true || json['is_default'] == true,
      createdAt: json['createdAt']?.toString() ?? json['created_at']?.toString(),
      updatedAt: json['updatedAt']?.toString() ?? json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'name': name,
      'body': body,
      'isDefault': isDefault,
    };
  }
}
