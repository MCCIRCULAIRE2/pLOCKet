class EntityType {
  final String id;
  final String code;
  final String label;
  final String? icon;
  final bool isSystem;
  final DateTime createdAt;

  EntityType({
    required this.id,
    required this.code,
    required this.label,
    this.icon,
    this.isSystem = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'code': code,
        'label': label,
        'icon': icon,
        'is_system': isSystem,
        'created_at': createdAt.toIso8601String(),
      };

  factory EntityType.fromMap(Map<String, dynamic> map) => EntityType(
        id: map['id'] as String,
        code: map['code'] as String,
        label: map['label'] as String,
        icon: map['icon'] as String?,
        isSystem: map['is_system'] as bool? ?? true,
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'] as String)
            : null,
      );
}
