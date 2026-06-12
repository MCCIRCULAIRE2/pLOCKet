class DocumentTag {
  final String documentId;
  final String tagId;

  DocumentTag({required this.documentId, required this.tagId});

  Map<String, dynamic> toMap() => {
        'documentId': documentId,
        'tagId': tagId,
      };

  factory DocumentTag.fromMap(Map<String, dynamic> map) => DocumentTag(
        documentId: map['documentId'] as String,
        tagId: map['tagId'] as String,
      );
}

class DocumentEvent {
  final String documentId;
  final String eventId;

  DocumentEvent({required this.documentId, required this.eventId});

  Map<String, dynamic> toMap() => {
        'documentId': documentId,
        'eventId': eventId,
      };

  factory DocumentEvent.fromMap(Map<String, dynamic> map) => DocumentEvent(
        documentId: map['documentId'] as String,
        eventId: map['eventId'] as String,
      );
}
