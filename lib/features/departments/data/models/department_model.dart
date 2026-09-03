/// Formats department name specifically for dropdown menus:
/// - APAC Team / APAC -> APAC
/// - Australia / Aus -> Aus
/// - Talent Acquisition (Night) / Night -> Night
String formatDepartmentDropdownName(String name, {String? slug}) {
  final lowerName = name.trim().toLowerCase();
  final lowerSlug = (slug ?? '').trim().toLowerCase();

  if (lowerName.contains('apac') || lowerSlug.contains('apac')) {
    return 'APAC';
  }
  if (lowerName.contains('australia') || lowerName.contains('aus') || lowerSlug.contains('australia')) {
    return 'Aus';
  }
  if (lowerName.contains('night') || lowerName.contains('talent') || lowerSlug.contains('night')) {
    return 'Night';
  }
  return name;
}

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

  /// Returns a concise display name specifically for dropdown menus.
  String get dropdownName => formatDepartmentDropdownName(name, slug: slug);

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
