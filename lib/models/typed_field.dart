import 'dart:convert';
import 'field_type.dart';

class TypedField {
  String rawValue;
  FieldType type;
  bool needsReview;
  bool validatedByUser;

  TypedField({
    required this.rawValue,
    required this.type,
    this.needsReview = false,
    this.validatedByUser = false,
  });

  factory TypedField.fromRaw(String rawValue) {
    return TypedField(
      rawValue: rawValue,
      type: FieldType.detect(rawValue),
    );
  }

  factory TypedField.fromNameAndRaw(String name, String rawValue) {
    return TypedField(
      rawValue: rawValue,
      type: FieldType.detectFromName(name, rawValue),
    );
  }

  String get normalizedValue => type.normalize(rawValue);

  Map<String, dynamic> toJson() => {
        'v': rawValue,
        't': type.name,
        'nr': needsReview,
        'vu': validatedByUser,
      };

  factory TypedField.fromJson(Map<String, dynamic> json) => TypedField(
        rawValue: json['v'] as String? ?? '',
        type: FieldType.values.firstWhere(
          (t) => t.name == json['t'],
          orElse: () => FieldType.text,
        ),
        needsReview: json['nr'] as bool? ?? false,
        validatedByUser: json['vu'] as bool? ?? false,
      );

  TypedField copyWith({
    String? rawValue,
    FieldType? type,
    bool? needsReview,
    bool? validatedByUser,
  }) =>
      TypedField(
        rawValue: rawValue ?? this.rawValue,
        type: type ?? this.type,
        needsReview: needsReview ?? this.needsReview,
        validatedByUser: validatedByUser ?? this.validatedByUser,
      );

  /// Convert a Map<String, TypedField> to a raw JSON map for CardModel storage.
  static Map<String, dynamic> encodeMap(Map<String, TypedField> fields) {
    return fields.map((k, v) => MapEntry(k, v.toJson()));
  }

  /// Decode a raw JSON map from CardModel storage into Map<String, TypedField>.
  static Map<String, TypedField> decodeMap(Map<String, dynamic> raw) {
    return raw.map((k, v) {
      if (v is Map<String, dynamic>) {
        return MapEntry(k, TypedField.fromJson(v));
      }
      // Legacy plain string value — auto-detect type
      return MapEntry(k, TypedField.fromRaw(v.toString()));
    });
  }

  /// Convert old pipe-separated format to typed format.
  static Map<String, TypedField> fromLegacyMap(Map<String, dynamic> legacy) {
    return legacy.map((k, v) => MapEntry(k, TypedField.fromNameAndRaw(k, v.toString())));
  }

  /// Encode for DB storage (JSON string).
  static String toDbString(Map<String, TypedField> fields) {
    return jsonEncode(encodeMap(fields));
  }

  /// Decode from DB storage.
  static Map<String, TypedField> fromDbString(String raw) {
    if (raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decodeMap(decoded);
    } catch (_) {
      return {};
    }
  }
}
