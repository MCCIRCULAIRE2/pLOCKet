import 'dart:convert';
import 'dart:typed_data';

class Document {
  final String id;
  final String title;
  final String? filePath;
  final String? mimeType;
  final String? ocrText;
  final String? sourceData;
  final DateTime createdAt;
  final DateTime? documentDate;

  Uint8List? get decodedSourceData =>
      sourceData != null ? base64Decode(sourceData!) : null;

  Document({
    required this.id,
    required this.title,
    this.filePath,
    this.mimeType,
    this.ocrText,
    this.sourceData,
    DateTime? createdAt,
    this.documentDate,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'filePath': filePath,
        'mimeType': mimeType,
        'ocrText': ocrText,
        'sourceData': sourceData,
        'createdAt': createdAt.toIso8601String(),
        'documentDate': documentDate?.toIso8601String(),
      };

  factory Document.fromMap(Map<String, dynamic> map) => Document(
        id: map['id'] as String,
        title: map['title'] as String,
        filePath: map['filePath'] as String?,
        mimeType: map['mimeType'] as String?,
        ocrText: map['ocrText'] as String?,
        sourceData: map['sourceData'] as String?,
        createdAt: DateTime.parse(map['createdAt'] as String),
        documentDate: map['documentDate'] != null
            ? DateTime.parse(map['documentDate'] as String)
            : null,
      );

  Document copyWith({
    String? id,
    String? title,
    String? filePath,
    String? mimeType,
    String? ocrText,
    String? sourceData,
    DateTime? createdAt,
    DateTime? documentDate,
  }) =>
      Document(
        id: id ?? this.id,
        title: title ?? this.title,
        filePath: filePath ?? this.filePath,
        mimeType: mimeType ?? this.mimeType,
        ocrText: ocrText ?? this.ocrText,
        sourceData: sourceData ?? this.sourceData,
        createdAt: createdAt ?? this.createdAt,
        documentDate: documentDate ?? this.documentDate,
      );
}
