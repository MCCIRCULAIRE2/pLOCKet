import '../models/analytical_field.dart';

/// Résultat de suggestion contextuelle
class ContextualSuggestion {
  final String fieldKey;
  final String fieldLabel;
  final int confidence;
  final String reason;
  final String? suggestedValue;
  final String? relatedEntity;

  ContextualSuggestion({
    required this.fieldKey,
    required this.fieldLabel,
    required this.confidence,
    required this.reason,
    this.suggestedValue,
    this.relatedEntity,
  });
}

/// Moteur de raisonnement contextuel pour générer des suggestions pertinentes
class ContextualSuggestionEngine {
  /// Génère des suggestions contextuelles basées sur le contenu du document
  static List<ContextualSuggestion> generateSuggestions({
    required String text,
    required Map<String, String> extractedFields,
    required List<AnalyticalField> analyticalFields,
    required List<AnalyticalValue> analyticalValues,
  }) {
    final suggestions = <ContextualSuggestion>[];
    final textLower = text.toLowerCase();
    
    // Identifier le contexte principal
    final context = _identifyContext(textLower);
    
    // Identifier les informations manquantes
    final missingInfo = _identifyMissingInfo(context, extractedFields);
    
    // Générer des suggestions basées sur le contexte
    for (final info in missingInfo) {
      // Chercher une entité analytique correspondante
      final relatedEntity = _findRelatedEntity(
        info.fieldKey,
        textLower,
        analyticalFields,
        analyticalValues,
      );
      
      // Calculer la confiance
      final confidence = _calculateConfidence(
        info.fieldKey,
        context,
        extractedFields,
        relatedEntity != null,
      );
      
      // Ne proposer que si confiance >= 60%
      if (confidence >= 60) {
        suggestions.add(ContextualSuggestion(
          fieldKey: info.fieldKey,
          fieldLabel: info.fieldLabel,
          confidence: confidence,
          reason: info.reason,
          relatedEntity: relatedEntity,
        ));
      }
    }
    
    // Trier par confiance décroissante
    suggestions.sort((a, b) => b.confidence.compareTo(a.confidence));
    
    // Limiter à 3 suggestions
    return suggestions.take(3).toList();
  }

  /// Identifie le contexte principal du document
  static String _identifyContext(String textLower) {
    // Détecter le type de document
    if (textLower.contains('travaux') || textLower.contains('rénovation') || textLower.contains('chantier')) {
      return 'travaux';
    }
    if (textLower.contains('contrôle technique') || textLower.contains('controle technique')) {
      return 'controle_technique';
    }
    if (textLower.contains('facture') || textLower.contains('devis')) {
      return 'facture';
    }
    if (textLower.contains('courses') || textLower.contains('achat')) {
      return 'achat';
    }
    if (textLower.contains('assurance') || textLower.contains('contrat')) {
      return 'assurance';
    }
    if (textLower.contains('véhicule') || textLower.contains('voiture')) {
      return 'vehicule';
    }
    if (textLower.contains('santé') || textLower.contains('médecin') || textLower.contains('consultation')) {
      return 'sante';
    }
    return 'general';
  }

  /// Identifie les informations manquantes basées sur le contexte
  static List<_MissingInfo> _identifyMissingInfo(
    String context,
    Map<String, String> extractedFields,
  ) {
    final missing = <_MissingInfo>[];
    
    // Suggestions basées sur le contexte
    switch (context) {
      case 'travaux':
        if (!extractedFields.containsKey('date')) {
          missing.add(_MissingInfo(
            fieldKey: 'date',
            fieldLabel: 'Date des travaux',
            reason: 'Date non spécifiée',
          ));
        }
        if (!extractedFields.containsKey('entreprise')) {
          missing.add(_MissingInfo(
            fieldKey: 'entreprise',
            fieldLabel: 'Entreprise/Artisan',
            reason: 'Entreprise non identifiée',
          ));
        }
        if (!extractedFields.containsKey('type_travaux')) {
          missing.add(_MissingInfo(
            fieldKey: 'type_travaux',
            fieldLabel: 'Type de travaux',
            reason: 'Type de travaux non spécifié',
          ));
        }
        break;
        
      case 'controle_technique':
        if (!extractedFields.containsKey('kilometrage')) {
          missing.add(_MissingInfo(
            fieldKey: 'kilometrage',
            fieldLabel: 'Kilométrage',
            reason: 'Kilométrage non spécifié',
          ));
        }
        if (!extractedFields.containsKey('centre')) {
          missing.add(_MissingInfo(
            fieldKey: 'centre',
            fieldLabel: 'Centre de contrôle',
            reason: 'Centre non identifié',
          ));
        }
        break;
        
      case 'achat':
        if (!extractedFields.containsKey('categorie')) {
          missing.add(_MissingInfo(
            fieldKey: 'categorie',
            fieldLabel: 'Catégorie de dépense',
            reason: 'Catégorie non spécifiée',
          ));
        }
        if (!extractedFields.containsKey('mode_paiement')) {
          missing.add(_MissingInfo(
            fieldKey: 'mode_paiement',
            fieldLabel: 'Mode de paiement',
            reason: 'Mode de paiement non spécifié',
          ));
        }
        break;
        
      case 'assurance':
        if (!extractedFields.containsKey('assureur')) {
          missing.add(_MissingInfo(
            fieldKey: 'assureur',
            fieldLabel: 'Assureur',
            reason: 'Assureur non identifié',
          ));
        }
        if (!extractedFields.containsKey('type_contrat')) {
          missing.add(_MissingInfo(
            fieldKey: 'type_contrat',
            fieldLabel: 'Type de contrat',
            reason: 'Type de contrat non spécifié',
          ));
        }
        break;
        
      case 'vehicule':
        if (!extractedFields.containsKey('plaque')) {
          missing.add(_MissingInfo(
            fieldKey: 'plaque',
            fieldLabel: 'Plaque d\'immatriculation',
            reason: 'Plaque non spécifiée',
          ));
        }
        break;
        
      case 'sante':
        if (!extractedFields.containsKey('medecin')) {
          missing.add(_MissingInfo(
            fieldKey: 'medecin',
            fieldLabel: 'Médecin/Praticien',
            reason: 'Praticien non identifié',
          ));
        }
        break;
    }
    
    // Suggestions génériques
    if (!extractedFields.containsKey('date') && !missing.any((m) => m.fieldKey == 'date')) {
      missing.add(_MissingInfo(
        fieldKey: 'date',
        fieldLabel: 'Date',
        reason: 'Date non spécifiée',
      ));
    }
    
    return missing;
  }

  /// Cherche une entité analytique correspondante
  static String? _findRelatedEntity(
    String fieldKey,
    String textLower,
    List<AnalyticalField> analyticalFields,
    List<AnalyticalValue> analyticalValues,
  ) {
    // Mapper les clés de champs aux types d'entités
    final entityTypeMapping = <String, String>{
      'logement': 'Logement',
      'vehicule': 'Véhicule',
      'personne': 'Personne',
      'entreprise': 'Entreprise',
    };
    
    final expectedEntityType = entityTypeMapping[fieldKey];
    if (expectedEntityType == null) return null;
    
    // Chercher une entité correspondante
    for (final field in analyticalFields) {
      if (field.name == expectedEntityType) {
        // Chercher une valeur correspondante dans le texte
        for (final value in analyticalValues) {
          if (value.fieldId == field.id) {
            if (textLower.contains(value.label.toLowerCase())) {
              return value.label;
            }
            // Vérifier les alias
            for (final alias in value.aliases) {
              if (textLower.contains(alias.toLowerCase())) {
                return value.label;
              }
            }
          }
        }
      }
    }
    
    return null;
  }

  /// Calcule la confiance d'une suggestion
  static int _calculateConfidence(
    String fieldKey,
    String context,
    Map<String, String> extractedFields,
    bool hasRelatedEntity,
  ) {
    int confidence = 50; // Confiance de base
    
    // Augmenter la confiance si une entité correspondante existe
    if (hasRelatedEntity) {
      confidence += 30;
    }
    
    // Augmenter la confiance si le contexte est clair
    if (context != 'general') {
      confidence += 10;
    }
    
    // Augmenter la confiance si des informations connexes existent
    if (extractedFields.containsKey('montant')) {
      confidence += 5;
    }
    
    // Limiter à 95%
    return confidence.clamp(0, 95);
  }
}

/// Information manquante
class _MissingInfo {
  final String fieldKey;
  final String fieldLabel;
  final String reason;

  _MissingInfo({
    required this.fieldKey,
    required this.fieldLabel,
    required this.reason,
  });
}
