class EntityAttribute {
  final String id;
  final String entityId;
  final String fieldId;
  final String attributeValue;
  final String provenance;
  final DateTime createdAt;

  EntityAttribute({
    required this.id,
    required this.entityId,
    required this.fieldId,
    required this.attributeValue,
    this.provenance = 'manual',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'entity_id': entityId,
        'field_id': fieldId,
        'attribute_value': attributeValue,
        'provenance': provenance,
        'created_at': createdAt.toIso8601String(),
      };

  factory EntityAttribute.fromMap(Map<String, dynamic> map) => EntityAttribute(
        id: map['id'] as String,
        entityId: map['entity_id'] as String,
        fieldId: map['field_id'] as String,
        attributeValue: map['attribute_value'] as String,
        provenance: map['provenance'] as String? ?? 'manual',
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'] as String)
            : null,
      );

  EntityAttribute copyWith({
    String? attributeValue,
    String? provenance,
  }) =>
      EntityAttribute(
        id: id,
        entityId: entityId,
        fieldId: fieldId,
        attributeValue: attributeValue ?? this.attributeValue,
        provenance: provenance ?? this.provenance,
        createdAt: createdAt,
      );
}
