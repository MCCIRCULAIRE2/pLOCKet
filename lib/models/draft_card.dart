import 'dart:typed_data';
import '../ai/extraction_candidate.dart';
import 'card_model.dart';
import 'field_type.dart';
import 'typed_field.dart';

enum ValidationSeverity { info, warning, error }

class ValidationWarning {
  final String fieldKey;
  final String message;
  final ValidationSeverity severity;
  
  ValidationWarning({
    required this.fieldKey,
    required this.message,
    this.severity = ValidationSeverity.warning,
  });
  
  bool get isError => severity == ValidationSeverity.error;
}

class DraftCard {
  String title;
  final CardType type;
  final String subType;
  final String rawText;
  String? value;
  DateTime? date;
  String? filePath;
  String? mimeType;
  Map<String, TypedField> fields;
  Map<String, TypedField> customFields;
  List<String> tags;
  List<ValidationWarning> warnings;
  List<String> suggestedFields;
  final DateTime createdAt;

  final String? sourceFileName;
  final String? sourceFileExtension;
  final Uint8List? sourceBytes;
  final List<ExtractionCandidate> candidates;

  DraftCard({
    required this.title,
    required this.type,
    required this.subType,
    required this.rawText,
    this.value,
    this.date,
    this.filePath,
    this.mimeType,
    Map<String, TypedField>? fields,
    Map<String, TypedField>? customFields,
    List<String>? tags,
    this.sourceFileName,
    this.sourceFileExtension,
    this.sourceBytes,
    List<ValidationWarning>? warnings,
    this.candidates = const [],
    List<String>? suggestedFields,
  })  : fields = fields ?? {},
        customFields = customFields ?? {},
        tags = tags ?? [],
        warnings = warnings ?? [],
        suggestedFields = suggestedFields ?? [],
        createdAt = DateTime.now();

  /// Legacy constructor for backward compat — auto-detects types.
  DraftCard.fromLegacy({
    required this.title,
    required this.type,
    required this.subType,
    required this.rawText,
    this.value,
    this.date,
    this.filePath,
    this.mimeType,
    Map<String, dynamic>? legacyFields,
    Map<String, dynamic>? legacyCustomFields,
    List<String>? tags,
    this.sourceFileName,
    this.sourceFileExtension,
    this.sourceBytes,
    List<ValidationWarning>? warnings,
    this.candidates = const [],
    List<String>? suggestedFields,
  })  : fields = legacyFields != null
            ? TypedField.fromLegacyMap(legacyFields)
            : {},
        customFields = legacyCustomFields != null
            ? TypedField.fromLegacyMap(legacyCustomFields)
            : {},
        tags = tags ?? [],
        warnings = warnings ?? [],
        suggestedFields = suggestedFields ?? [],
        createdAt = DateTime.now();

  int get fieldCount => fields.length;
  int get customFieldCount => customFields.length;

  void markAmbiguousFields() {
    for (final key in fields.keys.toList()) {
      if (getAlternativesFor(key).length >= 2 && !fields[key]!.validatedByUser) {
        fields[key]!.needsReview = true;
      }
    }
  }

  void validate() {
    warnings.clear();
    for (final entry in fields.entries) {
      validateField(entry.key, entry.value);
    }
    validateAmountCoherence();
  }

  void validateField(String key, TypedField field) {
    final rawLC = key.toLowerCase();
    
    // Validation du type de champ
    final valid = field.type.validate(field.rawValue);
    if (!valid) {
      warnings.add(ValidationWarning(
        fieldKey: key,
        message: 'La valeur "${field.rawValue}" ne correspond pas au format attendu pour le type "${field.type.displayName}".',
        severity: ValidationSeverity.warning,
      ));
    }

    // Numéro de sécurité sociale
    if (field.type == FieldType.socialSecurityNumber ||
        rawLC.contains('securite') || rawLC.contains('ssn') || rawLC == 'numero_securite_sociale') {
      final digits = field.rawValue.replaceAll(RegExp(r'[\s-]'), '');
      print('[ENTITY] type=numero_securite_sociale');
      print('[ENTITY] candidate=${field.rawValue}');
      
      if (digits.length < 13) {
        print('[ENTITY] validation=failed (trop court: ${digits.length} chiffres)');
        print('[ENTITY] field_created=true');
        warnings.add(ValidationWarning(
          fieldKey: key,
          message: 'Le numéro de sécurité sociale détecté (${digits.length} chiffres) est incomplet. Format attendu : 13 ou 15 chiffres.',
          severity: ValidationSeverity.warning,
        ));
      } else if (digits.length > 15) {
        print('[ENTITY] validation=failed (trop long: ${digits.length} chiffres)');
        print('[ENTITY] field_created=true');
        warnings.add(ValidationWarning(
          fieldKey: key,
          message: 'Le numéro de sécurité sociale détecté (${digits.length} chiffres) semble trop long. Format attendu : 13 ou 15 chiffres.',
          severity: ValidationSeverity.warning,
        ));
      } else if (digits.length == 14) {
        print('[ENTITY] validation=warning (14 chiffres au lieu de 13 ou 15)');
        print('[ENTITY] field_created=true');
        warnings.add(ValidationWarning(
          fieldKey: key,
          message: 'Le numéro de sécurité sociale détecté a 14 chiffres. Format habituel : 13 ou 15 chiffres.',
          severity: ValidationSeverity.info,
        ));
      } else {
        print('[ENTITY] validation=success');
        print('[ENTITY] field_created=true');
      }
    }

    // Dates
    if (field.type == FieldType.date || rawLC.contains('date')) {
      if (!RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(field.normalizedValue)) {
        warnings.add(ValidationWarning(
          fieldKey: key,
          message: 'Format de date inhabituel détecté. Format recommandé : JJ/MM/AAAA.',
          severity: ValidationSeverity.info,
        ));
      }
    }

    // Email
    if (field.type == FieldType.email || rawLC.contains('email')) {
      if (!field.rawValue.contains('@')) {
        warnings.add(ValidationWarning(
          fieldKey: key,
          message: 'L\'adresse email détectée ne contient pas le caractère "@".',
          severity: ValidationSeverity.warning,
        ));
      } else if (!field.rawValue.contains('.')) {
        warnings.add(ValidationWarning(
          fieldKey: key,
          message: 'L\'adresse email détectée ne contient pas de domaine (ex: .fr, .com).',
          severity: ValidationSeverity.info,
        ));
      }
    }

    // Montants
    if (field.type == FieldType.currency || rawLC.contains('montant') || rawLC.contains('total')) {
      if (!RegExp(r'\d').hasMatch(field.rawValue)) {
        warnings.add(ValidationWarning(
          fieldKey: key,
          message: 'Aucun chiffre détecté dans le montant.',
          severity: ValidationSeverity.warning,
        ));
      }
    }

    // Identifiants génériques
    if (field.type == FieldType.identifier || rawLC.contains('facture') || rawLC.contains('numero')) {
      if (field.rawValue.length < 2) {
        warnings.add(ValidationWarning(
          fieldKey: key,
          message: 'L\'identifiant détecté semble très court (${field.rawValue.length} caractère${field.rawValue.length > 1 ? 's' : ''}).',
          severity: ValidationSeverity.info,
        ));
      }
    }
  }

  // ─── Candidate-based field disambiguation ───────────────────────────────────
  static const Map<String, String> _fieldCategories = {
    'montant_total': 'montant',
    'acompte': 'montant',
    'reste_a_payer': 'montant',
    'adresse': 'adresse',
    'adresse_bien': 'adresse_chantier',
  };

  List<ExtractionCandidate> getAlternativesFor(String fieldKey) {
    final cat = _fieldCategories[fieldKey];
    if (cat == null) return [];
    return candidates.where((c) => c.category == cat).toList();
  }

  bool isFieldAmbiguous(String fieldKey) {
    final field = fields[fieldKey];
    if (field != null && field.validatedByUser) return false;
    return getAlternativesFor(fieldKey).length >= 2;
  }

  void pickAlternative(String fieldKey, ExtractionCandidate candidate) {
    final existing = fields[fieldKey];
    if (existing != null) {
      fields[fieldKey] = existing.copyWith(
        rawValue: candidate.value,
        needsReview: false,
        validatedByUser: true,
      );
    } else {
      final f = TypedField.fromRaw(candidate.value);
      f.validatedByUser = true;
      fields[fieldKey] = f;
    }
  }

  void confirmField(String fieldKey) {
    final existing = fields[fieldKey];
    if (existing != null) {
      fields[fieldKey] = existing.copyWith(
        needsReview: false,
        validatedByUser: true,
      );
    }
  }

  void validateAmountCoherence() {
    final totalField = fields['montant_total'];
    final acompteField = fields['acompte'];

    if (totalField == null || acompteField == null) return;

    final totalOk = totalField.type == FieldType.currency ||
        totalField.type == FieldType.number;
    final acompteOk = acompteField.type == FieldType.currency ||
        acompteField.type == FieldType.number;
    if (!totalOk || !acompteOk) return;

    final total = double.tryParse(totalField.normalizedValue);
    final acompte = double.tryParse(acompteField.normalizedValue);
    if (total != null && acompte != null && total < acompte) {
      warnings.add(ValidationWarning(
        fieldKey: 'montant_total',
        message: 'L\'acompte ($acompte €) est supérieur au montant total ($total €). Vérifiez les valeurs.',
        severity: ValidationSeverity.error,
      ));
    }
  }
}
