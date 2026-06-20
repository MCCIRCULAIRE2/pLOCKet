import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/analytical_field.dart';
import '../models/card_model.dart';
import '../services/cloud_repository.dart';
import '../database/daos/analytical_field_dao.dart';
import '../ai/semantic_relation_engine.dart';
import 'card_provider.dart';

class AnalyticalFieldProvider extends ChangeNotifier {
  final CloudRepository _cloudRepo = CloudRepository();
  final AnalyticalFieldDao _dao = AnalyticalFieldDao();
  final Uuid _uuid = const Uuid();
  CardProvider? _cardProvider;

  void setCardProvider(CardProvider cardProvider) {
    _cardProvider = cardProvider;
  }

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
      debugPrint('[SETTINGS LOAD] Chargement des champs analytiques (Cloud)...');
      _fields = await _cloudRepo.getAllAnalyticalFields();
      debugPrint('[SETTINGS LOAD] ✓ ${_fields.length} champ(s) chargé(s)');

      debugPrint('[SETTINGS LOAD] Chargement des valeurs analytiques (local)...');
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

  Future<AnalyticalField> createField({
    required String name,
    String? icon,
    String? category,
    String? entityTypeId,
    bool isSensitive = false,
  }) async {
    final field = AnalyticalField(
      id: _uuid.v4(),
      userId: '',
      name: name,
      category: category,
      entityTypeId: entityTypeId,
      isSensitive: isSensitive,
    );
    await _cloudRepo.insertAnalyticalField(field);
    await loadAll();
    return field;
  }

  Future<void> renameField(AnalyticalField field, String newName) async {
    final updated = field.copyWith(name: newName);
    await _cloudRepo.updateAnalyticalField(updated);
    await loadAll();
  }

  Future<void> deleteField(String fieldId) async {
    await _cloudRepo.deleteAnalyticalField(fieldId);
    await loadAll();
  }

  Future<AnalyticalValue> addValue({
    required String fieldId,
    required String label,
    List<String>? aliases,
    Map<String, String>? identifiers,
    String? role,
    String? category,
    String? relation,
  }) async {
    final value = AnalyticalValue(
      id: _uuid.v4(),
      fieldId: fieldId,
      label: label,
      aliases: aliases,
      identifiers: identifiers,
      role: role,
      category: category,
      relation: relation,
    );
    await _dao.insertValue(value);
    await loadAll();
    return value;
  }

  Future<void> updateValue(AnalyticalValue value) async {
    await _dao.updateValue(value);

    if (_cardProvider != null) {
      await _cardProvider!.updateCardsWithAnalyticalValue(
        fieldName: _getFieldNameById(value.fieldId),
        oldLabel: value.label,
        newLabel: value.label,
      );
    }

    await loadAll();
  }

  Future<void> deleteValue(String valueId) async {
    await _dao.deleteValue(valueId);
    await loadAll();
  }

  List<CardModel> getCardsUsingValue(AnalyticalValue value) {
    if (_cardProvider == null) return [];
    final fieldName = _getFieldNameById(value.fieldId);
    final cards = <CardModel>[];
    for (final card in _cardProvider!.cards) {
      for (final entry in card.fields.entries) {
        if (entry.key != fieldName) continue;
        final v = entry.value;
        String? fieldValue;
        if (v is Map<String, dynamic>) {
          fieldValue = v['v']?.toString();
        } else if (v is String) {
          fieldValue = v;
        }
        if (fieldValue == value.label ||
            value.aliases.any((a) => a == fieldValue)) {
          cards.add(card);
          break;
        }
      }
    }
    return cards;
  }

  int countCardUsage(AnalyticalValue value) =>
      getCardsUsingValue(value).length;

  Future<AnalyticalValue?> findSimilarValue(String fieldId, String label) async {
    final values = valuesForField(fieldId);
    final candidate = AnalyticalValue(id: '', fieldId: fieldId, label: label);
    for (final v in values) {
      if (v.similarityTo(candidate) >= 0.85) return v;
    }
    return null;
  }

  Future<void> deleteValueWithOption(
    AnalyticalValue value,
    ValueDeletionOption option,
  ) async {
    switch (option) {
      case ValueDeletionOption.unlinkOnly:
        await _dao.deleteValue(value.id);
        break;
      case ValueDeletionOption.removeFromAll:
        final fieldName = _getFieldNameById(value.fieldId);
        if (_cardProvider != null) {
          await _cardProvider!.removeAnalyticalValueFromCards(
            fieldName: fieldName,
            label: value.label,
            aliases: value.aliases,
          );
        }
        await _dao.deleteValue(value.id);
        break;
      case ValueDeletionOption.cancel:
        return;
    }
    await loadAll();
  }

  Future<void> mergeValues(AnalyticalValue keep, AnalyticalValue merge) async {
    final mergedAliases = List<String>.from(keep.aliases);
    if (!mergedAliases.contains(merge.label)) {
      mergedAliases.add(merge.label);
    }
    for (final alias in merge.aliases) {
      if (!mergedAliases.contains(alias)) {
        mergedAliases.add(alias);
      }
    }
    final mergedIdentifiers = Map<String, String>.from(keep.identifiers);
    mergedIdentifiers.addAll(merge.identifiers);

    final fieldName = _getFieldNameById(keep.fieldId);
    if (_cardProvider != null) {
      await _cardProvider!.updateCardsWithAnalyticalValue(
        fieldName: fieldName,
        oldLabel: merge.label,
        newLabel: keep.label,
      );
      for (final alias in merge.aliases) {
        await _cardProvider!.updateCardsWithAnalyticalValue(
          fieldName: fieldName,
          oldLabel: alias,
          newLabel: keep.label,
        );
      }
    }

    await _dao.updateValue(keep.copyWith(
      aliases: mergedAliases,
      identifiers: mergedIdentifiers,
    ));
    await _dao.deleteValue(merge.id);
    await loadAll();
  }

  Future<void> renameValue(AnalyticalValue value, String newLabel) async {
    final oldLabel = value.label;
    final fieldName = _getFieldNameById(value.fieldId);

    debugPrint('[ANALYTICAL] ═══════════════════════════════════════════════════════════');
    debugPrint('[ANALYTICAL] Renommage valeur: "$oldLabel" → "$newLabel"');
    debugPrint('[ANALYTICAL] Champ: $fieldName');

    await _dao.updateValue(value.copyWith(label: newLabel));

    if (_cardProvider != null) {
      await _cardProvider!.updateCardsWithAnalyticalValue(
        fieldName: fieldName,
        oldLabel: oldLabel,
        newLabel: newLabel,
      );
    }

    await loadAll();
    debugPrint('[ANALYTICAL] ✓ Renommage terminé');
    debugPrint('[ANALYTICAL] ═══════════════════════════════════════════════════════════');
  }

  String _getFieldNameById(String fieldId) {
    final field = _fields.firstWhere(
      (f) => f.id == fieldId,
      orElse: () => AnalyticalField(id: fieldId, userId: '', name: 'unknown'),
    );
    return field.name;
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

      bool aliasMatched = false;
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
          aliasMatched = true;
          break;
        }
      }
      if (aliasMatched) continue;

      if (value.relation != null && value.relation!.isNotEmpty) {
        final synonyms = SemanticRelationEngine.getRelationSynonyms(value.relation!);
        for (final syn in synonyms) {
          if (textLower.contains(syn.toLowerCase())) {
            print('[RELATION] ✓ Synonyme "$syn" détecté (relation: ${value.relation})');
            print('[RELATION]   Résolu vers: ${value.label}');
            print('[RELATION]   Référentiel: ${field.name}');
            print('[RELATION]   Confiance: 70%');
            matches.add(AnalyticalValueMatch(
              field: field,
              value: value,
              confidence: 70,
              matchedOn: '$syn (via ${value.relation})',
            ));
            break;
          }
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

    final ssRegex = RegExp(r'\b([12]\s?\d{2}\s?\d{2}\s?\d{2}\s?\d{3}\s?\d{3}\s?\d{2})\b');
    final ssMatch = ssRegex.firstMatch(text);
    if (ssMatch != null) {
      final ssNumber = ssMatch.group(1)!.replaceAll(' ', '');
      identifiers['numero_securite_sociale'] = ssNumber;
      print('[IDENTIFIER] ✓ Numéro SS détecté: $ssNumber');
    }

    final permisRegex = RegExp(r'\b(\d{12})\b');
    final permisMatch = permisRegex.firstMatch(text);
    if (permisMatch != null && !identifiers.containsKey('numero_securite_sociale')) {
      identifiers['numero_permis'] = permisMatch.group(1)!;
      print('[IDENTIFIER] ✓ Numéro permis détecté: ${permisMatch.group(1)}');
    }

    final contratRegex = RegExp(r'(?:contrat|n°|numéro)\s*[:#]?\s*(\w{5,20})', caseSensitive: false);
    final contratMatch = contratRegex.firstMatch(text);
    if (contratMatch != null) {
      identifiers['numero_contrat'] = contratMatch.group(1)!;
      print('[IDENTIFIER] ✓ Numéro contrat détecté: ${contratMatch.group(1)}');
    }

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

enum ValueDeletionOption {
  unlinkOnly,
  removeFromAll,
  cancel,
}
