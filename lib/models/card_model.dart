import 'dart:convert';

enum CardType { information, event, document }

class CardModel {
  final String id;
  final String title;
  final CardType type;
  final String subType;
  final String rawText;
  final String? value;
  final DateTime? date;
  final Map<String, dynamic> fields;
  final List<String> tags;
  final String? sourceDocumentId;
  final String? filePath;
  final String? mimeType;
  final DateTime createdAt;

  CardModel({
    required this.id,
    required this.title,
    required this.type,
    required this.subType,
    required this.rawText,
    this.value,
    this.date,
    Map<String, dynamic>? fields,
    List<String>? tags,
    this.sourceDocumentId,
    this.filePath,
    this.mimeType,
    DateTime? createdAt,
  })  : fields = fields ?? {},
        tags = tags ?? [],
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'type': type.name,
        'subType': subType,
        'rawText': rawText,
        'value': value,
        'date': date?.toIso8601String(),
        'fields': _mapToString(fields),
        'tags': tags.join(','),
        'sourceDocumentId': sourceDocumentId,
        'filePath': filePath,
        'mimeType': mimeType,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CardModel.fromMap(Map<String, dynamic> map) => CardModel(
        id: map['id'] as String,
        title: map['title'] as String,
        type: CardType.values.firstWhere(
            (c) => c.name == map['type'],
            orElse: () => CardType.information),
        subType: map['subType'] as String? ?? 'general',
        rawText: map['rawText'] as String? ?? '',
        value: map['value'] as String?,
        date: map['date'] != null ? DateTime.parse(map['date'] as String) : null,
        fields: _parseMap(map['fields'] as String?),
        tags: (map['tags'] as String? ?? '').split(',').where((t) => t.isNotEmpty).toList(),
        sourceDocumentId: map['sourceDocumentId'] as String?,
        filePath: map['filePath'] as String?,
        mimeType: map['mimeType'] as String?,
        createdAt: map['createdAt'] != null
            ? DateTime.parse(map['createdAt'] as String)
            : DateTime.now(),
      );

  static String _mapToString(Map<String, dynamic> map) {
    return jsonEncode(map);
  }

  static Map<String, dynamic> _parseMap(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      // Try new JSON format first
      if (raw.trim().startsWith('{')) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
      }
    } catch (_) {}
    // Fall back to legacy pipe-separated format
    return _parseLegacyMap(raw);
  }

  static Map<String, dynamic> _parseLegacyMap(String raw) {
    final map = <String, dynamic>{};
    for (final entry in raw.split('|')) {
      final parts = entry.split(': ');
      if (parts.length >= 2) {
        map[parts[0]] = parts.sublist(1).join(': ');
      }
    }
    return map;
  }

  CardModel copyWith({
    String? id,
    String? title,
    CardType? type,
    String? subType,
    String? rawText,
    String? value,
    DateTime? date,
    Map<String, dynamic>? fields,
    List<String>? tags,
    String? sourceDocumentId,
    String? filePath,
    String? mimeType,
    DateTime? createdAt,
  }) =>
      CardModel(
        id: id ?? this.id,
        title: title ?? this.title,
        type: type ?? this.type,
        subType: subType ?? this.subType,
        rawText: rawText ?? this.rawText,
        value: value ?? this.value,
        date: date ?? this.date,
        fields: fields ?? this.fields,
        tags: tags ?? this.tags,
        sourceDocumentId: sourceDocumentId ?? this.sourceDocumentId,
        filePath: filePath ?? this.filePath,
        mimeType: mimeType ?? this.mimeType,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, String> get displayFields {
    final display = <String, String>{};
    if (value != null) display['Valeur'] = value!;
    if (date != null) {
      display['Date'] =
          '${date!.day.toString().padLeft(2, '0')}/${date!.month.toString().padLeft(2, '0')}/${date!.year}';
    }
    for (final e in fields.entries) {
      final val = e.value;
      if (val is Map<String, dynamic>) {
        display[e.key] = val['v']?.toString() ?? val.toString();
      } else {
        display[e.key] = val.toString();
      }
    }
    return display;
  }
}
