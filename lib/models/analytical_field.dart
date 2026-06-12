import 'dart:convert';

class AnalyticalField {
  final String id;
  final String name;
  final String? icon;
  final DateTime createdAt;

  AnalyticalField({
    required this.id,
    required this.name,
    this.icon,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'icon': icon,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AnalyticalField.fromMap(Map<String, dynamic> map) => AnalyticalField(
        id: map['id'] as String,
        name: map['name'] as String,
        icon: map['icon'] as String?,
        createdAt: map['createdAt'] != null
            ? DateTime.parse(map['createdAt'] as String)
            : null,
      );
}

class AnalyticalValue {
  final String id;
  final String fieldId;
  final String label;
  final List<String> aliases;
  final Map<String, String> identifiers;
  final DateTime createdAt;

  AnalyticalValue({
    required this.id,
    required this.fieldId,
    required this.label,
    List<String>? aliases,
    Map<String, String>? identifiers,
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
        createdAt: map['createdAt'] != null
            ? DateTime.parse(map['createdAt'] as String)
            : null,
      );

  AnalyticalValue copyWith({
    String? label,
    List<String>? aliases,
    Map<String, String>? identifiers,
  }) =>
      AnalyticalValue(
        id: id,
        fieldId: fieldId,
        label: label ?? this.label,
        aliases: aliases ?? this.aliases,
        identifiers: identifiers ?? this.identifiers,
        createdAt: createdAt,
      );
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
