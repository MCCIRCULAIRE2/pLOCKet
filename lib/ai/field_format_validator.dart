/// Validateur de format pour les champs structurés
class FieldFormatValidator {
  /// Valide un numéro de sécurité sociale français
  /// Format: 1 ou 2 + 2 chiffres (année) + 2 chiffres (mois) + 2 chiffres (département) + 3 chiffres (ordre) + 2 chiffres (clé)
  /// Total: 13 ou 15 chiffres
  static ValidationResult validateSSN(String value) {
    final cleaned = value.replaceAll(RegExp(r'[\s-]'), '');
    
    // Vérifier la longueur
    if (cleaned.length != 13 && cleaned.length != 15) {
      return ValidationResult(
        isValid: false,
        confidence: 0,
        reason: 'Longueur incorrecte: ${cleaned.length} chiffres (attendu: 13 ou 15)',
      );
    }
    
    // Vérifier le format
    final ssnPattern = RegExp(r'^[12]\d{2}(0[1-9]|1[0-2])\d{2}\d{3}\d{2,4}$');
    if (!ssnPattern.hasMatch(cleaned)) {
      return ValidationResult(
        isValid: false,
        confidence: 0,
        reason: 'Format invalide',
      );
    }
    
    return ValidationResult(
      isValid: true,
      confidence: 95,
      reason: 'Format valide',
    );
  }

  /// Valide un numéro de téléphone français
  /// Formats acceptés: 0X XX XX XX XX, 0X.XX.XX.XX.XX, 0XXXXXXXXX, +33 X XX XX XX XX
  static ValidationResult validatePhone(String value) {
    final cleaned = value.replaceAll(RegExp(r'[\s.\-]'), '');
    
    // Format français: 0XXXXXXXXX (10 chiffres)
    if (cleaned.length == 10 && cleaned.startsWith('0')) {
      return ValidationResult(
        isValid: true,
        confidence: 95,
        reason: 'Format valide',
      );
    }
    
    // Format international: +33XXXXXXXXX (11 chiffres)
    if (cleaned.length == 11 && cleaned.startsWith('+33')) {
      return ValidationResult(
        isValid: true,
        confidence: 95,
        reason: 'Format valide',
      );
    }
    
    return ValidationResult(
      isValid: false,
      confidence: 0,
      reason: 'Format invalide',
    );
  }

  /// Valide un email
  static ValidationResult validateEmail(String value) {
    final emailPattern = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    
    if (emailPattern.hasMatch(value)) {
      return ValidationResult(
        isValid: true,
        confidence: 95,
        reason: 'Format valide',
      );
    }
    
    return ValidationResult(
      isValid: false,
      confidence: 0,
      reason: 'Format invalide',
    );
  }

  /// Valide un IBAN français
  /// Format: FR76 XXXX XXXX XXXX XXXX XXXX XXXX
  static ValidationResult validateIBAN(String value) {
    final cleaned = value.replaceAll(RegExp(r'[\s]'), '');
    
    // Format français: FR76 + 23 caractères alphanumériques
    final ibanPattern = RegExp(r'^FR\d{2}[A-Z0-9]{23}$');
    
    if (ibanPattern.hasMatch(cleaned)) {
      return ValidationResult(
        isValid: true,
        confidence: 95,
        reason: 'Format valide',
      );
    }
    
    return ValidationResult(
      isValid: false,
      confidence: 0,
      reason: 'Format invalide',
    );
  }

  /// Valide une plaque d'immatriculation française
  /// Formats acceptés: AA-123-AA, AB123CD, 123 ABC 09
  static ValidationResult validateLicensePlate(String value) {
    final cleaned = value.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
    
    // Format moderne: AA-123-AA (2 lettres + 3 chiffres + 2 lettres)
    final modernPattern = RegExp(r'^[A-Z]{2}\d{3}[A-Z]{2}$');
    if (modernPattern.hasMatch(cleaned)) {
      return ValidationResult(
        isValid: true,
        confidence: 95,
        reason: 'Format moderne valide',
      );
    }
    
    // Format ancien: 123 ABC 09 (1-4 chiffres + 1-3 lettres + 2 chiffres département)
    final oldPattern = RegExp(r'^\d{1,4}[A-Z]{1,3}\d{2,3}$');
    if (oldPattern.hasMatch(cleaned)) {
      return ValidationResult(
        isValid: true,
        confidence: 90,
        reason: 'Format ancien valide',
      );
    }
    
    return ValidationResult(
      isValid: false,
      confidence: 0,
      reason: 'Format invalide',
    );
  }

  /// Valide un numéro de contrat
  static ValidationResult validateContractNumber(String value) {
    final cleaned = value.replaceAll(RegExp(r'[\s-]'), '');
    
    // Accepter les formats alphanumériques de 4 à 20 caractères
    final pattern = RegExp(r'^[A-Za-z0-9\-/]{4,20}$');
    
    if (pattern.hasMatch(cleaned)) {
      return ValidationResult(
        isValid: true,
        confidence: 85,
        reason: 'Format valide',
      );
    }
    
    return ValidationResult(
      isValid: false,
      confidence: 0,
      reason: 'Format invalide',
    );
  }

  /// Valide un kilométrage
  static ValidationResult validateKilometrage(String value) {
    final cleaned = value.replaceAll(RegExp(r'[\s.]'), '');
    
    // Accepter les nombres avec ou sans "km"
    final pattern = RegExp(r'^(\d{1,3}(?:[\s.]?\d{3})*(?:[,.]\d+)?)\s*(?:km|kilomètres|kilometres)?$', caseSensitive: false);
    
    if (pattern.hasMatch(value)) {
      return ValidationResult(
        isValid: true,
        confidence: 90,
        reason: 'Format valide',
      );
    }
    
    return ValidationResult(
      isValid: false,
      confidence: 0,
      reason: 'Format invalide',
    );
  }

  /// Valide une date
  static ValidationResult validateDate(String value) {
    // Format JJ/MM/AAAA
    final pattern = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$');
    final match = pattern.firstMatch(value);
    
    if (match != null) {
      final day = int.tryParse(match.group(1)!);
      final month = int.tryParse(match.group(2)!);
      final year = int.tryParse(match.group(3)!);
      
      if (day != null && month != null && year != null) {
        if (day >= 1 && day <= 31 && month >= 1 && month <= 12 && year >= 1900 && year <= 2100) {
          return ValidationResult(
            isValid: true,
            confidence: 95,
            reason: 'Format valide',
          );
        }
      }
    }
    
    return ValidationResult(
      isValid: false,
      confidence: 0,
      reason: 'Format invalide',
    );
  }

  /// Valide un montant
  static ValidationResult validateMontant(String value) {
    final cleaned = value.replaceAll(RegExp(r'[\s€]'), '').replaceAll(',', '.');
    
    // Accepter les nombres décimaux
    final pattern = RegExp(r'^\d{1,3}(?:[\s.]?\d{3})*(?:[,.]\d{1,2})?$');
    
    if (pattern.hasMatch(value)) {
      return ValidationResult(
        isValid: true,
        confidence: 90,
        reason: 'Format valide',
      );
    }
    
    return ValidationResult(
      isValid: false,
      confidence: 0,
      reason: 'Format invalide',
    );
  }
}

/// Résultat de validation
class ValidationResult {
  final bool isValid;
  final int confidence;
  final String reason;

  ValidationResult({
    required this.isValid,
    required this.confidence,
    required this.reason,
  });
}
