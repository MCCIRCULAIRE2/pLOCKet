import '../models/analytical_field.dart';

/// Moteur de relations sémantiques entre entités analytiques
class SemanticRelationEngine {
  /// Relations familiales
  static const Map<String, List<String>> _familyRelations = {
    'conjoint': ['conjoint', 'conjointe', 'époux', 'épouse', 'femme', 'mari', 'partenaire'],
    'enfant': ['enfant', 'fils', 'fille', 'enfants'],
    'fils': ['fils', 'garçon'],
    'fille': ['fille', 'fille'],
    'parent': ['parent', 'père', 'mère', 'papa', 'maman'],
    'fratrie': ['frère', 'soeur', 'soeur', 'fratrie'],
  };

  /// Catégories de logements
  static const Map<String, List<String>> _housingCategories = {
    'résidence principale': ['résidence principale', 'résidence principale', 'domicile principal'],
    'résidence secondaire': ['résidence secondaire', 'maison secondaire', 'appartement secondaire', 'maison de vacances', 'maison de vacances'],
    'investissement locatif': ['investissement locatif', 'locatif', 'location'],
    'logement étudiant': ['logement étudiant', 'étudiant'],
  };

  /// Catégories de véhicules
  static const Map<String, List<String>> _vehicleCategories = {
    'véhicule principal': ['véhicule principal', 'voiture principale', 'véhicule principal'],
    'véhicule familial': ['véhicule familial', 'voiture familiale', 'véhicule familial'],
    'véhicule professionnel': ['véhicule professionnel', 'voiture professionnelle', 'véhicule professionnel'],
    'véhicule loisir': ['véhicule loisir', 'voiture de loisir', 'véhicule de loisir', 'voiture du week-end', 'véhicule du week-end'],
  };

  /// Groupes sémantiques
  static const Map<String, List<String>> _semanticGroups = {
    'famille': ['famille', 'toute la famille', 'toute ma famille'],
    'enfants': ['enfants', 'mes enfants', 'tous mes enfants'],
    'filles': ['filles', 'mes filles', 'toutes mes filles'],
    'fils': ['fils', 'mes fils', 'tous mes fils'],
    'logements': ['logements', 'mes logements', 'tous mes logements'],
    'résidences secondaires': ['résidences secondaires', 'mes résidences secondaires', 'toutes mes résidences secondaires'],
    'maisons de vacances': ['maisons de vacances', 'mes maisons de vacances', 'toutes mes maisons de vacances'],
    'véhicules': ['véhicules', 'mes véhicules', 'tous mes véhicules', 'voitures', 'mes voitures'],
  };

  /// Trouve les entités correspondant à une requête sémantique
  static List<AnalyticalValue> findEntitiesBySemanticQuery(
    String query,
    List<AnalyticalField> fields,
    List<AnalyticalValue> values,
  ) {
    final queryLower = query.toLowerCase();
    final results = <AnalyticalValue>[];

    // 1. Chercher dans les groupes sémantiques
    for (final entry in _semanticGroups.entries) {
      if (entry.value.any((alias) => queryLower.contains(alias))) {
        print('[SEMANTIC] Groupe sémantique détecté: ${entry.key}');
        
        // Trouver le champ correspondant
        final field = _findFieldByGroup(entry.key, fields);
        if (field != null) {
          final fieldValues = values.where((v) => v.fieldId == field.id).toList();
          
          // Filtrer par sous-groupe si nécessaire
          final filteredValues = _filterBySubGroup(entry.key, fieldValues);
          results.addAll(filteredValues);
          
          print('[SEMANTIC] ${filteredValues.length} entité(s) trouvée(s) pour le groupe ${entry.key}');
        }
      }
    }

    // 2. Chercher par relation familiale
    for (final entry in _familyRelations.entries) {
      if (entry.value.any((alias) => queryLower.contains(alias))) {
        print('[SEMANTIC] Relation familiale détectée: ${entry.key}');
        
        final field = _findFieldByName('Personne', fields);
        if (field != null) {
          final fieldValues = values.where((v) => v.fieldId == field.id).toList();
          final filteredValues = fieldValues.where((v) => v.relation == entry.key).toList();
          results.addAll(filteredValues);
          
          print('[SEMANTIC] ${filteredValues.length} entité(s) trouvée(s) pour la relation ${entry.key}');
        }
      }
    }

    // 3. Chercher par catégorie de logement
    for (final entry in _housingCategories.entries) {
      if (entry.value.any((alias) => queryLower.contains(alias))) {
        print('[SEMANTIC] Catégorie de logement détectée: ${entry.key}');
        
        final field = _findFieldByName('Logement', fields);
        if (field != null) {
          final fieldValues = values.where((v) => v.fieldId == field.id).toList();
          final filteredValues = fieldValues.where((v) => v.category == entry.key).toList();
          results.addAll(filteredValues);
          
          print('[SEMANTIC] ${filteredValues.length} entité(s) trouvée(s) pour la catégorie ${entry.key}');
        }
      }
    }

    // 4. Chercher par catégorie de véhicule
    for (final entry in _vehicleCategories.entries) {
      if (entry.value.any((alias) => queryLower.contains(alias))) {
        print('[SEMANTIC] Catégorie de véhicule détectée: ${entry.key}');
        
        final field = _findFieldByName('Véhicule', fields);
        if (field != null) {
          final fieldValues = values.where((v) => v.fieldId == field.id).toList();
          final filteredValues = fieldValues.where((v) => v.category == entry.key).toList();
          results.addAll(filteredValues);
          
          print('[SEMANTIC] ${filteredValues.length} entité(s) trouvée(s) pour la catégorie ${entry.key}');
        }
      }
    }

    return results;
  }

  /// Trouve un champ par nom
  static AnalyticalField? _findFieldByName(String name, List<AnalyticalField> fields) {
    return fields.firstWhere(
      (f) => f.name.toLowerCase() == name.toLowerCase(),
      orElse: () => AnalyticalField(id: '', name: ''),
    );
  }

  /// Trouve un champ par groupe sémantique
  static AnalyticalField? _findFieldByGroup(String group, List<AnalyticalField> fields) {
    final groupToField = {
      'famille': 'Personne',
      'enfants': 'Personne',
      'filles': 'Personne',
      'fils': 'Personne',
      'logements': 'Logement',
      'résidences secondaires': 'Logement',
      'maisons de vacances': 'Logement',
      'véhicules': 'Véhicule',
    };

    final fieldName = groupToField[group];
    if (fieldName != null) {
      return _findFieldByName(fieldName, fields);
    }
    return null;
  }

  /// Filtre les entités par sous-groupe
  static List<AnalyticalValue> _filterBySubGroup(String group, List<AnalyticalValue> values) {
    if (group == 'filles') {
      return values.where((v) => v.relation == 'fille').toList();
    } else if (group == 'fils') {
      return values.where((v) => v.relation == 'fils').toList();
    } else if (group == 'enfants') {
      return values.where((v) => v.relation == 'enfant' || v.relation == 'fils' || v.relation == 'fille').toList();
    } else if (group == 'résidences secondaires' || group == 'maisons de vacances') {
      return values.where((v) => v.category == 'résidence secondaire').toList();
    } else if (group == 'véhicules') {
      return values; // Tous les véhicules
    } else if (group == 'famille') {
      return values; // Toute la famille
    }
    return values;
  }

  /// Obtient les suggestions de relations pour un type de champ
  static List<String> getRelationSuggestions(String fieldName) {
    final fieldNameLower = fieldName.toLowerCase();
    
    if (fieldNameLower == 'personne') {
      return ['conjoint', 'enfant', 'fils', 'fille', 'parent', 'frère', 'soeur', 'ami', 'collègue'];
    } else if (fieldNameLower == 'logement') {
      return ['résidence principale', 'résidence secondaire', 'investissement locatif', 'logement étudiant'];
    } else if (fieldNameLower == 'véhicule') {
      return ['véhicule principal', 'véhicule familial', 'véhicule professionnel', 'véhicule loisir'];
    }
    
    return [];
  }
}
