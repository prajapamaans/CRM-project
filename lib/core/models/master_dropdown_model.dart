/// Model representing a single master dropdown option item.
class MasterDropdownOptionModel {
  final String id;
  final String value;
  final String label;
  final String? color;
  final int position;
  final bool isDefault;
  final bool isActive;

  MasterDropdownOptionModel({
    required this.id,
    required this.value,
    required this.label,
    this.color,
    this.position = 0,
    this.isDefault = false,
    this.isActive = true,
  });

  factory MasterDropdownOptionModel.fromJson(Map<String, dynamic> json) {
    return MasterDropdownOptionModel(
      id: json['id'] as String? ?? '',
      value: json['value'] as String? ?? json['label'] as String? ?? '',
      label: json['label'] as String? ?? json['value'] as String? ?? '',
      color: json['color'] as String?,
      position: (json['position'] as num?)?.toInt() ?? 0,
      isDefault: json['isDefault'] as bool? ?? json['is_default'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'value': value,
      'label': label,
      if (color != null) 'color': color,
      'position': position,
      'isDefault': isDefault,
      'isActive': isActive,
    };
  }
}

/// Model representing an entity lifecycle stage.
class LifecycleStageModel {
  final String id;
  final String name;
  final int position;
  final String entityType;

  LifecycleStageModel({
    required this.id,
    required this.name,
    this.position = 0,
    required this.entityType,
  });

  factory LifecycleStageModel.fromJson(Map<String, dynamic> json) {
    return LifecycleStageModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? json['label'] as String? ?? '',
      position: (json['position'] as num?)?.toInt() ?? 0,
      entityType: json['entityType'] as String? ?? json['entity_type'] as String? ?? 'company',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'position': position,
      'entityType': entityType,
    };
  }
}

/// Model representing a Managed Service Provider (MSP) option.
class MspOptionModel {
  final String id;
  final String name;
  final int position;
  final String? entityType;

  MspOptionModel({
    required this.id,
    required this.name,
    this.position = 0,
    this.entityType,
  });

  factory MspOptionModel.fromJson(Map<String, dynamic> json) {
    return MspOptionModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? json['title'] as String? ?? json['label'] as String? ?? '',
      position: (json['position'] as num?)?.toInt() ?? 0,
      entityType: json['entityType'] as String? ?? json['entity_type'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'position': position,
      if (entityType != null) 'entityType': entityType,
    };
  }
}
