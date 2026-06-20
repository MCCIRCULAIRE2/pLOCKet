class Entity {
  final String id;
  final String userId;
  final String? entityTypeId;
  final String label;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  Entity({
    required this.id,
    required this.userId,
    this.entityTypeId,
    required this.label,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'entity_type_id': entityTypeId,
        'label': label,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'deleted_at': deletedAt?.toIso8601String(),
      };

  factory Entity.fromMap(Map<String, dynamic> map) => Entity(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        entityTypeId: map['entity_type_id'] as String?,
        label: map['label'] as String,
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'] as String)
            : null,
        updatedAt: map['updated_at'] != null
            ? DateTime.parse(map['updated_at'] as String)
            : null,
        deletedAt: map['deleted_at'] != null
            ? DateTime.parse(map['deleted_at'] as String)
            : null,
      );

  Entity copyWith({
    String? entityTypeId,
    String? label,
    DateTime? deletedAt,
  }) =>
      Entity(
        id: id,
        userId: userId,
        entityTypeId: entityTypeId ?? this.entityTypeId,
        label: label ?? this.label,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        deletedAt: deletedAt ?? this.deletedAt,
      );
}

class DocumentEntity {
  final String documentId;
  final String entityId;

  DocumentEntity({required this.documentId, required this.entityId});

  Map<String, dynamic> toMap() => {
        'documentId': documentId,
        'entityId': entityId,
      };

  factory DocumentEntity.fromMap(Map<String, dynamic> map) => DocumentEntity(
        documentId: map['documentId'] as String,
        entityId: map['entityId'] as String,
      );
}
