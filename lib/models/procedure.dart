class Procedure {
  final String id;
  final String title;
  final String description;
  final Map<String, dynamic> metadata;

  Procedure({
    required this.id,
    required this.title,
    required this.description,
    Map<String, dynamic>? metadata,
  }) : metadata = metadata ?? {};

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'metadata': metadata.toString(),
      };

  factory Procedure.fromMap(Map<String, dynamic> map) => Procedure(
        id: map['id'] as String,
        title: map['title'] as String,
        description: map['description'] as String,
      );
}

class ProcedureDocument {
  final String procedureId;
  final String documentId;

  ProcedureDocument({required this.procedureId, required this.documentId});

  Map<String, dynamic> toMap() => {
        'procedureId': procedureId,
        'documentId': documentId,
      };

  factory ProcedureDocument.fromMap(Map<String, dynamic> map) =>
      ProcedureDocument(
        procedureId: map['procedureId'] as String,
        documentId: map['documentId'] as String,
      );
}
