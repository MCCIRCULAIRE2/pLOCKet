class AnalyticalRelation {
  final String id;
  final String userId;
  final String sourceEntityId;
  final String targetEntityId;
  final String relationTypeId;
  final DateTime createdAt;
  final DateTime? deletedAt;

  AnalyticalRelation({
    required this.id,
    required this.userId,
    required this.sourceEntityId,
    required this.targetEntityId,
    required this.relationTypeId,
    DateTime? createdAt,
    this.deletedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'source_entity_id': sourceEntityId,
        'target_entity_id': targetEntityId,
        'relation_type_id': relationTypeId,
        'created_at': createdAt.toIso8601String(),
        'deleted_at': deletedAt?.toIso8601String(),
      };

  factory AnalyticalRelation.fromMap(Map<String, dynamic> map) =>
      AnalyticalRelation(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        sourceEntityId: map['source_entity_id'] as String,
        targetEntityId: map['target_entity_id'] as String,
        relationTypeId: map['relation_type_id'] as String,
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'] as String)
            : null,
        deletedAt: map['deleted_at'] != null
            ? DateTime.parse(map['deleted_at'] as String)
            : null,
      );
}
