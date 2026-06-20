class RelationType {
  final String id;
  final String code;
  final String label;
  final bool isSystem;
  final DateTime createdAt;

  RelationType({
    required this.id,
    required this.code,
    required this.label,
    this.isSystem = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'code': code,
        'label': label,
        'is_system': isSystem,
        'created_at': createdAt.toIso8601String(),
      };

  factory RelationType.fromMap(Map<String, dynamic> map) => RelationType(
        id: map['id'] as String,
        code: map['code'] as String,
        label: map['label'] as String,
        isSystem: map['is_system'] as bool? ?? true,
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'] as String)
            : null,
      );
}
