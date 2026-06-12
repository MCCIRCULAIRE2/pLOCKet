class Event {
  final String id;
  final String eventType;
  final String? entityId;
  final DateTime date;
  final String description;
  final Map<String, dynamic> metadata;
  final String? documentId;

  Event({
    required this.id,
    required this.eventType,
    this.entityId,
    required this.date,
    required this.description,
    Map<String, dynamic>? metadata,
    this.documentId,
  }) : metadata = metadata ?? {};

  Map<String, dynamic> toMap() => {
        'id': id,
        'eventType': eventType,
        'entityId': entityId,
        'date': date.toIso8601String(),
        'description': description,
        'metadata': metadata.toString(),
        'documentId': documentId,
      };

  factory Event.fromMap(Map<String, dynamic> map) => Event(
        id: map['id'] as String,
        eventType: map['eventType'] as String,
        entityId: map['entityId'] as String?,
        date: DateTime.parse(map['date'] as String),
        description: map['description'] as String,
        documentId: map['documentId'] as String?,
      );
}
