import 'dart:convert';

class AnalyticalField {
  final String id;
  final String userId;
  final String name;
  final String? category;
  final String? entityTypeId;
  final bool isSensitive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  AnalyticalField({
    required this.id,
    required this.userId,
    required this.name,
    this.category,
    this.entityTypeId,
    this.isSensitive = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'category': category,
        'entity_type_id': entityTypeId,
        'is_sensitive': isSensitive,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'deleted_at': deletedAt?.toIso8601String(),
      };

  factory AnalyticalField.fromMap(Map<String, dynamic> map) => AnalyticalField(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        name: map['name'] as String,
        category: map['category'] as String?,
        entityTypeId: map['entity_type_id'] as String?,
        isSensitive: map['is_sensitive'] as bool? ?? false,
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

  AnalyticalField copyWith({
    String? name,
    String? category,
    String? entityTypeId,
    bool? isSensitive,
    DateTime? deletedAt,
  }) =>
      AnalyticalField(
        id: id,
        userId: userId,
        name: name ?? this.name,
        category: category ?? this.category,
        entityTypeId: entityTypeId ?? this.entityTypeId,
        isSensitive: isSensitive ?? this.isSensitive,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        deletedAt: deletedAt ?? this.deletedAt,
      );
}

class AnalyticalValue {
  final String id;
  final String fieldId;
  final String label;
  final List<String> aliases;
  final Map<String, String> identifiers;
  final String? role;
  final String? category;
  final String? relation;
  final DateTime createdAt;

  AnalyticalValue({
    required this.id,
    required this.fieldId,
    required this.label,
    List<String>? aliases,
    Map<String, String>? identifiers,
    this.role,
    this.category,
    this.relation,
    DateTime? createdAt,
  })  : aliases = aliases ?? [],
        identifiers = identifiers ?? {},
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'fieldId': fieldId,
        'label': label,
        'aliases': jsonEncode(aliases),
        'identifiers': jsonEncode(identifiers),
        'role': role,
        'category': category,
        'relation': relation,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AnalyticalValue.fromMap(Map<String, dynamic> map) => AnalyticalValue(
        id: map['id'] as String,
        fieldId: map['fieldId'] as String,
        label: map['label'] as String,
        aliases: map['aliases'] != null
            ? List<String>.from(jsonDecode(map['aliases'] as String))
            : [],
        identifiers: map['identifiers'] != null
            ? Map<String, String>.from(jsonDecode(map['identifiers'] as String))
            : {},
        role: map['role'] as String?,
        category: map['category'] as String?,
        relation: map['relation'] as String?,
        createdAt: map['createdAt'] != null
            ? DateTime.parse(map['createdAt'] as String)
            : null,
      );

  AnalyticalValue copyWith({
    String? label,
    List<String>? aliases,
    Map<String, String>? identifiers,
    String? role,
    String? category,
    String? relation,
  }) =>
      AnalyticalValue(
        id: id,
        fieldId: fieldId,
        label: label ?? this.label,
        aliases: aliases ?? this.aliases,
        identifiers: identifiers ?? this.identifiers,
        role: role ?? this.role,
        category: category ?? this.category,
        relation: relation ?? this.relation,
        createdAt: createdAt,
      );

  /// Calcule la similarité avec une autre valeur (pour détection de doublons)
  double similarityTo(AnalyticalValue other) {
    final label1 = label.toLowerCase().trim();
    final label2 = other.label.toLowerCase().trim();
    
    // Similarité exacte
    if (label1 == label2) return 1.0;
    
    // Similarité avec les alias
    for (final alias in aliases) {
      if (alias.toLowerCase().trim() == label2) return 0.95;
    }
    for (final alias in other.aliases) {
      if (alias.toLowerCase().trim() == label1) return 0.95;
    }
    
    // Similarité Levenshtein simplifiée
    final distance = _levenshteinDistance(label1, label2);
    final maxLen = label1.length > label2.length ? label1.length : label2.length;
    if (maxLen == 0) return 0.0;
    
    final similarity = 1.0 - (distance / maxLen);
    return similarity;
  }

  static int _levenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final matrix = List.generate(
      s1.length + 1,
      (i) => List.filled(s2.length + 1, 0),
    );

    for (int i = 0; i <= s1.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[s1.length][s2.length];
  }
}

class AnalyticalFieldValue {
  final String fieldId;
  final String valueId;
  final String label;

  AnalyticalFieldValue({
    required this.fieldId,
    required this.valueId,
    required this.label,
  });

  Map<String, dynamic> toJson() => {
        'fieldId': fieldId,
        'valueId': valueId,
        'label': label,
      };

  factory AnalyticalFieldValue.fromJson(Map<String, dynamic> json) =>
      AnalyticalFieldValue(
        fieldId: json['fieldId'] as String,
        valueId: json['valueId'] as String,
        label: json['label'] as String? ?? '',
      );
}
