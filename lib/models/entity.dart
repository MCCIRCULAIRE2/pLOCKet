class Entity {
  final String id;
  final String entityType;
  final String name;
  final Map<String, dynamic> metadata;

  Entity({
    required this.id,
    required this.entityType,
    required this.name,
    Map<String, dynamic>? metadata,
  }) : metadata = metadata ?? {};

  Map<String, dynamic> toMap() => {
        'id': id,
        'entityType': entityType,
        'name': name,
        'metadata': metadata.toString(),
      };

  factory Entity.fromMap(Map<String, dynamic> map) => Entity(
        id: map['id'] as String,
        entityType: map['entityType'] as String,
        name: map['name'] as String,
        metadata: _parseMetadata(map['metadata'] as String?),
      );

  static Map<String, dynamic> _parseMetadata(String? raw) {
    if (raw == null) return {};
    try {
      final map = <String, dynamic>{};
      for (final m in RegExp(r"(\w+): ([^,\n]+)").allMatches(raw)) {
        map[m.group(1)!] = m.group(2)!;
      }
      return map;
    } catch (_) {
      return {};
    }
  }
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
