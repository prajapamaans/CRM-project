class DepartmentModel {
  final String id;
  final String name;
  final String? slug;
  final String? deletedAt;

  const DepartmentModel({
    required this.id,
    required this.name,
    this.slug,
    this.deletedAt,
  });

  factory DepartmentModel.fromJson(Map<String, dynamic> json) {
    return DepartmentModel(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String?,
      deletedAt: json['deleted_at'] as String? ?? json['deletedAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'deleted_at': deletedAt,
    };
  }
}
