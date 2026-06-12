import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/analytical_field.dart';
import '../database/daos/analytical_field_dao.dart';

class AnalyticalFieldProvider extends ChangeNotifier {
  final AnalyticalFieldDao _dao = AnalyticalFieldDao();
  final Uuid _uuid = const Uuid();

  List<AnalyticalField> _fields = [];
  List<AnalyticalField> get fields => _fields;

  Map<String, List<AnalyticalValue>> _valuesByField = {};
  List<AnalyticalValue> valuesForField(String fieldId) =>
      _valuesByField[fieldId] ?? [];

  List<AnalyticalValue> _allValues = [];
  List<AnalyticalValue> get allValues => _allValues;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> loadAll() async {
    debugPrint('[SETTINGS LOAD] ═══════════════════════════════════════════════════════════');
    debugPrint('[SETTINGS LOAD] Début chargement des référentiels analytiques');
    debugPrint('[SETTINGS LOAD] ═══════════════════════════════════════════════════════════');
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      debugPrint('[SETTINGS LOAD] Chargement des champs analytiques...');
      _fields = await _dao.getAllFields();
      debugPrint('[SETTINGS LOAD] ✓ ${_fields.length} champ(s) chargé(s)');
      
      debugPrint('[SETTINGS LOAD] Chargement des valeurs analytiques...');
      _allValues = await _dao.getAllValues();
      debugPrint('[SETTINGS LOAD] ✓ ${_allValues.length} valeur(s) chargée(s)');
      
      _valuesByField = {};
      for (final v in _allValues) {
        _valuesByField.putIfAbsent(v.fieldId, () => []).add(v);
      }
      
      debugPrint('[SETTINGS LOAD] ═══════════════════════════════════════════════════════════');
      debugPrint('[SETTINGS LOAD] ✓ Chargement terminé avec succès');
      debugPrint('[SETTINGS LOAD] ═══════════════════════════════════════════════════════════');
    } catch (e, stackTrace) {
      debugPrint('[SETTINGS LOAD] ═══════════════════════════════════════════════════════════');
      debugPrint('[SETTINGS LOAD] ❌ ERREUR lors du chargement');
      debugPrint('[SETTINGS LOAD] Erreur: $e');
      debugPrint('[SETTINGS LOAD] Stack trace:\n$stackTrace');
      debugPrint('[SETTINGS LOAD] ═══════════════════════════════════════════════════════════');
      _error = 'Erreur chargement champs analytiques: $e';
    }
    
    _isLoading = false;
    notifyListeners();
  }

  Future<AnalyticalField> createField({required String name, String? icon}) async {
    final field = AnalyticalField(id: _uuid.v4(), name: name, icon: icon);
    await _dao.insertField(field);
    await loadAll();
    return field;
  }

  Future<void> renameField(AnalyticalField field, String newName) async {
    final updated = AnalyticalField(
        id: field.id, name: newName, icon: field.icon, createdAt: field.createdAt);
    await _dao.updateField(updated);
    await loadAll();
  }

  Future<void> deleteField(String fieldId) async {
    await _dao.deleteField(fieldId);
    await loadAll();
  }

  Future<AnalyticalValue> addValue({
    required String fieldId,
    required String label,
    List<String>? aliases,
    Map<String, String>? identifiers,
  }) async {
    final value = AnalyticalValue(
      id: _uuid.v4(),
      fieldId: fieldId,
      label: label,
      aliases: aliases,
      identifiers: identifiers,
    );
    await _dao.insertValue(value);
    await loadAll();
    return value;
  }

  Future<void> updateValue(AnalyticalValue value) async {
    await _dao.updateValue(value);
    await loadAll();
  }

  Future<void> deleteValue(String valueId) async {
    await _dao.deleteValue(valueId);
    await loadAll();
  }

  Future<void> renameValue(AnalyticalValue value, String newLabel) async {
    await _dao.updateValue(value.copyWith(label: newLabel));
    await loadAll();
  }

  List<AnalyticalValueMatch> findMatches(String text) {
    final matches = <AnalyticalValueMatch>[];
    final textLower = text.toLowerCase();
    
    print('[ENTITY] ═══════════════════════════════════════════════════════════');
    print('[ENTITY] Détection automatique d\'entités dans le texte');
    print('[ENTITY] ═══════════════════════════════════════════════════════════');
    
    for (final value in _allValues) {
      final field = _fields.where((f) => f.id == value.fieldId).firstOrNull;
      if (field == null) continue;

      if (textLower.contains(value.label.toLowerCase())) {
        print('[ENTITY] ✓ "${value.label}" détecté (label exact)');
        print('[ENTITY]   Référentiel: ${field.name}');
        print('[ENTITY]   Confiance: 95%');
        matches.add(AnalyticalValueMatch(
          field: field,
          value: value,
          confidence: 95,
          matchedOn: value.label,
        ));
        continue;
      }

      for (final alias in value.aliases) {
        if (textLower.contains(alias.toLowerCase())) {
          print('[ALIAS] ✓ "$alias" détecté');
          print('[ALIAS]   Résolu vers: ${value.label}');
          print('[ALIAS]   Référentiel: ${field.name}');
          print('[ALIAS]   Confiance: 80%');
          matches.add(AnalyticalValueMatch(
            field: field,
            value: value,
            confidence: 80,
            matchedOn: alias,
          ));
          break;
        }
      }
    }
    matches.sort((a, b) => b.confidence.compareTo(a.confidence));
    
    print('[ENTITY] ═══════════════════════════════════════════════════════════');
    print('[ENTITY] ${matches.length} entité(s) détectée(s)');
    for (final m in matches) {
      print('[ENTITY]   ${m.field.name} = ${m.value.label} (${m.confidence}%)');
    }
    print('[ENTITY] ═══════════════════════════════════════════════════════════');
    
    return matches;
  }

  Map<String, String> detectIdentifiers(String text) {
    final identifiers = <String, String>{};
    
    print('[IDENTIFIER] ═══════════════════════════════════════════════════════════');
    print('[IDENTIFIER] Détection d\'identifiants dans le texte');
    print('[IDENTIFIER] ═══════════════════════════════════════════════════════════');
    
    // Numéro de sécurité sociale français (13 chiffres + clé 2 chiffres)
    final ssRegex = RegExp(r'\b([12]\s?\d{2}\s?\d{2}\s?\d{2}\s?\d{3}\s?\d{3}\s?\d{2})\b');
    final ssMatch = ssRegex.firstMatch(text);
    if (ssMatch != null) {
      final ssNumber = ssMatch.group(1)!.replaceAll(' ', '');
      identifiers['numero_securite_sociale'] = ssNumber;
      print('[IDENTIFIER] ✓ Numéro SS détecté: $ssNumber');
    }
    
    // Numéro de permis (format variable, souvent 12 chiffres)
    final permisRegex = RegExp(r'\b(\d{12})\b');
    final permisMatch = permisRegex.firstMatch(text);
    if (permisMatch != null && !identifiers.containsKey('numero_securite_sociale')) {
      identifiers['numero_permis'] = permisMatch.group(1)!;
      print('[IDENTIFIER] ✓ Numéro permis détecté: ${permisMatch.group(1)}');
    }
    
    // Numéro de contrat (patterns courants)
    final contratRegex = RegExp(r'(?:contrat|n°|numéro)\s*[:#]?\s*(\w{5,20})', caseSensitive: false);
    final contratMatch = contratRegex.firstMatch(text);
    if (contratMatch != null) {
      identifiers['numero_contrat'] = contratMatch.group(1)!;
      print('[IDENTIFIER] ✓ Numéro contrat détecté: ${contratMatch.group(1)}');
    }
    
    // Numéro de client
    final clientRegex = RegExp(r'(?:client|adhérent)\s*[:#]?\s*(\w{5,20})', caseSensitive: false);
    final clientMatch = clientRegex.firstMatch(text);
    if (clientMatch != null) {
      identifiers['numero_client'] = clientMatch.group(1)!;
      print('[IDENTIFIER] ✓ Numéro client détecté: ${clientMatch.group(1)}');
    }
    
    print('[IDENTIFIER] ═══════════════════════════════════════════════════════════');
    print('[IDENTIFIER] ${identifiers.length} identifiant(s) détecté(s)');
    for (final entry in identifiers.entries) {
      print('[IDENTIFIER]   ${entry.key} = ${entry.value}');
    }
    print('[IDENTIFIER] ═══════════════════════════════════════════════════════════');
    
    return identifiers;
  }
}

class AnalyticalValueMatch {
  final AnalyticalField field;
  final AnalyticalValue value;
  final int confidence;
  final String matchedOn;

  AnalyticalValueMatch({
    required this.field,
    required this.value,
    required this.confidence,
    required this.matchedOn,
  });
}
