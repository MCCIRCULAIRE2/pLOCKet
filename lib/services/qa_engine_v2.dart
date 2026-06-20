import '../ai/ai_service.dart';
import '../models/analytical_field.dart';
import '../models/entity.dart';
import '../models/entity_type.dart';
import '../models/relation_type.dart';
import '../services/cloud_repository.dart';
import '../services/qa_session_cache.dart';
import '../providers/entity_provider.dart';
import '../providers/entity_attribute_provider.dart';
import '../providers/analytical_field_provider.dart';
import '../providers/entity_type_provider.dart';
import '../providers/relation_type_provider.dart';
import '../providers/relation_provider.dart';
import '../providers/user_profile_provider.dart';
import '../providers/card_provider.dart';

class QaEngineV2 {
  QaSessionCache? _cache;

  static final Set<String> _stopwords = {
    'de', 'du', 'le', 'la', 'des', 'les', 'aux', 'un', 'une', 'mon', 'ma', 'mes',
    'son', 'sa', 'ses', 'ton', 'ta', 'tes', 'notre', 'nos', 'votre', 'vos',
    'leur', 'leurs', 'ce', 'cet', 'cette', 'ces', 'je', 'tu', 'il', 'elle',
    'nous', 'vous', 'ils', 'elles', 'qui', 'que', 'quoi', 'dont', 'ou', 'est',
    'sont', 'dans', 'pour', 'avec', 'sur', 'par', 'pas', 'plus', 'moins',
    'tres', 'bien', 'mal', 'non', 'oui', 'si', 'ca',
  };

  // ===== Helpers =====

  void _log(String stage, Map<String, dynamic> data) {
    print('[QA_V2] ═══════════════════════════════════════');
    print('[QA_V2] Stage: $stage');
    for (final entry in data.entries) {
      print('[QA_V2]   ${entry.key}: ${entry.value}');
    }
    print('[QA_V2] ═══════════════════════════════════════');
  }

  String _buildAmbiguityMessage(String label, List<String> entityLabels) {
    if (entityLabels.length > 5) {
      final top = entityLabels.take(5).map((l) => '• $l').join('\n');
      return 'J\'ai trouvé plusieurs $label :\n'
          '$top\n'
          'et ${entityLabels.length - 5} autre(s).\n'
          'Pouvez-vous préciser ?';
    }
    return 'J\'ai trouvé plusieurs $label :\n'
        '${entityLabels.map((l) => '• $l').join('\n')}\n'
        'Pouvez-vous préciser ?';
  }

  String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ô', 'o')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ç', 'c')
        .replaceAll('·', '');
  }

  List<String> _fieldKeywords(AnalyticalField field) {
    final name = _normalize(field.name);
    final keywords = <String>{name};

    final words = name.split(RegExp(r'[\s\-]+'));
    for (final word in words) {
      if (word.length > 2 && !_stopwords.contains(word)) {
        keywords.add(word);
      }
    }

    return keywords.toList();
  }

  // ===== Matching methods =====

  List<AnalyticalField> _matchFieldInQuestion(
    String question,
    List<AnalyticalField> fields,
  ) {
    final normalizedQ = _normalize(question);
    final matched = <AnalyticalField>[];

    for (final field in fields) {
      final keywords = _fieldKeywords(field);
      for (final keyword in keywords) {
        if (normalizedQ.contains(keyword)) {
          matched.add(field);
          break;
        }
      }
    }

    return matched;
  }

  List<RelationType> _matchRelationInQuestion(
    String question,
    Map<String, RelationType> relationsByCode,
  ) {
    final normalizedQ = _normalize(question);
    final matched = <RelationType>[];

    for (final entry in relationsByCode.entries) {
      final rt = entry.value;
      final normalizedCode = _normalize(rt.code.replaceAll('_', ' '));
      final normalizedLabel = _normalize(rt.label);
      if (normalizedQ.contains(normalizedCode) ||
          normalizedQ.contains(normalizedLabel)) {
        matched.add(rt);
      }
    }

    return matched;
  }

  List<EntityType> _matchEntityTypeInQuestion(
    String question,
    Map<String, EntityType> typesByCode,
  ) {
    final normalizedQ = _normalize(question);
    final matched = <EntityType>[];

    for (final entry in typesByCode.entries) {
      final et = entry.value;
      final normalizedCode = _normalize(et.code);
      final normalizedLabel = _normalize(et.label);
      if (normalizedQ.contains(normalizedCode) ||
          normalizedQ.contains(normalizedLabel)) {
        matched.add(et);
      }
    }

    return matched;
  }

  // ===== Context loading =====

  Future<void> _loadContext({
    required EntityProvider entityProvider,
    required EntityAttributeProvider attrProvider,
    required AnalyticalFieldProvider fieldProvider,
    required EntityTypeProvider entityTypeProvider,
    required RelationTypeProvider relationTypeProvider,
    required RelationProvider relationProvider,
    required UserProfileProvider userProfileProvider,
  }) async {
    if (_cache != null && _cache!.isValid) return;

    final cache = QaSessionCache();

    await Future.wait([
      entityTypeProvider.loadTypes(),
      relationTypeProvider.loadTypes(),
      fieldProvider.loadAll(),
      entityProvider.loadEntities(),
    ]);

    cache.allFields = List.from(fieldProvider.fields);
    cache.allEntities = List.from(entityProvider.entities);
    cache.entityTypesByCode = {
      for (var t in entityTypeProvider.types) t.code: t,
    };
    cache.relationTypesByCode = {
      for (var t in relationTypeProvider.types) t.code: t,
    };

    cache.meEntity = await entityProvider.getMeEntity(
      userProfileProvider: userProfileProvider,
      entityTypeProvider: entityTypeProvider,
    );
    if (cache.meEntity == null) {
      _cache = cache;
      _cache!.markLoaded();
      return;
    }

    final results = await Future.wait([
      attrProvider.getAttributesWithFields(cache.meEntity!.id, cache.allFields),
      relationProvider.getAllRelationsWithDetails(cache.meEntity!.id),
    ]);
    cache.meAttributes = results[0] as List<EntityAttributeWithField>;
    cache.meRelations = results[1] as List<EntityRelationWithEntities>;

    cache.markLoaded();
    _cache = cache;
  }

  // ===== Resolution methods =====

  Future<AnswerResult?> _resolvePersonalAttribute(
    List<AnalyticalField> matchedFields,
    List<EntityAttributeWithField> meAttributes,
  ) async {
    if (matchedFields.isEmpty) return null;

    if (matchedFields.length > 1) {
      return AnswerResult(
        answerText:
            'Plusieurs informations correspondent à votre demande :\n'
            '${matchedFields.map((f) => '• ${f.name}').join('\n')}\n'
            'Pouvez-vous préciser ?',
        confidence: 'Moyen',
      );
    }

    final targetField = matchedFields.first;
    final matching = meAttributes
        .where((a) => a.field.id == targetField.id)
        .toList();

    if (matching.isEmpty) {
      return AnswerResult(
        answerText:
            'Je n\'ai pas trouvé votre ${targetField.name.toLowerCase()} dans vos données.',
        confidence: 'Faible',
      );
    }

    return AnswerResult(
      answerText:
          'Votre ${targetField.name.toLowerCase()} est : ${matching.first.attribute.attributeValue}',
      confidence: 'Fort',
      values: matching.map((a) => AnswerValue(
        label: targetField.name,
        value: a.attribute.attributeValue,
      )).toList(),
    );
  }

  Future<AnswerResult?> _resolveRelationAttribute({
    required List<RelationType> matchedRelations,
    required List<AnalyticalField> matchedFields,
    required List<EntityRelationWithEntities> meRelations,
    required List<AnalyticalField> allFields,
    required EntityAttributeProvider attrProvider,
  }) async {
    if (matchedRelations.isEmpty) return null;

    final relation = matchedRelations.first;
    final related = meRelations
        .where((r) => r.relationType.id == relation.id)
        .toList();

    if (related.isEmpty) {
      _log('STAGE2', {
        'pattern': 'B',
        'relationCode': relation.code,
        'entityCount': 0,
        'failure': 'Aucune entite liee trouvee',
      });
      return null;
    }

    final uniqueEntities = <Entity>{};
    for (final r in related) {
      uniqueEntities.add(r.isOutgoing ? r.targetEntity : r.sourceEntity);
    }
    final entityList = uniqueEntities.toList();

    if (matchedFields.isEmpty) {
      final labels = entityList.map((e) => e.label).toList();
      if (entityList.length == 1) {
        return AnswerResult(
          answerText: 'Votre ${relation.label.toLowerCase()} : ${entityList.first.label}',
          confidence: 'Fort',
        );
      }
      return AnswerResult(
        answerText: _buildAmbiguityMessage(
          '${relation.label.toLowerCase()}s',
          labels,
        ),
        confidence: 'Moyen',
      );
    }

    if (matchedFields.length > 1) {
      return AnswerResult(
        answerText:
            'Plusieurs informations correspondent à votre demande :\n'
            '${matchedFields.map((f) => '• ${f.name}').join('\n')}\n'
            'Pouvez-vous préciser ?',
        confidence: 'Moyen',
      );
    }

    final targetField = matchedFields.first;
    final results = <String, String>{};

    for (final entity in entityList) {
      final attrs = await attrProvider.getAttributesWithFields(
          entity.id, allFields);
      final match = attrs.where((a) => a.field.id == targetField.id).firstOrNull;
      if (match != null) {
        results[entity.label] = match.attribute.attributeValue;
      }
    }

    if (results.isEmpty) {
      _log('STAGE2', {
        'pattern': 'B',
        'relationCode': relation.code,
        'entityCount': entityList.length,
        'field': targetField.name,
        'failure': 'Attribut non trouve sur les entites liees',
      });
      final name = entityList.length == 1
          ? entityList.first.label
          : 'vos ${relation.label.toLowerCase()}s';
      return AnswerResult(
        answerText:
            'Je n\'ai pas trouvé votre ${targetField.name.toLowerCase()} pour $name.',
        confidence: 'Faible',
      );
    }

    if (results.length == 1) {
      final entry = results.entries.first;
      return AnswerResult(
        answerText:
            'Le ${targetField.name.toLowerCase()} de ${entry.key} est : ${entry.value}',
        confidence: 'Fort',
        values: [AnswerValue(label: targetField.name, value: entry.value)],
      );
    }

    final labels = results.entries.map((e) => e.key).toList();
    return AnswerResult(
      answerText: _buildAmbiguityMessage(
        '${relation.label.toLowerCase()}s',
        labels,
      ),
      confidence: 'Moyen',
    );
  }

  Future<AnswerResult?> _resolveEntitiesByType({
    required List<EntityType> matchedEntityTypes,
    required List<AnalyticalField> matchedFields,
    required List<Entity> allEntities,
    required Map<String, EntityType> entityTypesByCode,
    required List<AnalyticalField> allFields,
    required EntityAttributeProvider attrProvider,
    required String meEntityId,
  }) async {
    if (matchedEntityTypes.isEmpty) return null;

    final type = matchedEntityTypes.first;
    final entitiesOfType = allEntities
        .where((e) => e.entityTypeId == type.id && e.id != meEntityId)
        .toList();

    if (entitiesOfType.isEmpty) {
      _log('STAGE3', {
        'pattern': 'C',
        'typeCode': type.code,
        'entityCount': 0,
        'failure': 'Aucune entite de ce type trouvee',
      });
      return null;
    }

    if (matchedFields.isEmpty) {
      final labels = entitiesOfType.map((e) => e.label).toList();
      if (entitiesOfType.length == 1) {
        return AnswerResult(
          answerText: 'Votre ${type.label.toLowerCase()} : ${entitiesOfType.first.label}',
          confidence: 'Fort',
        );
      }
      return AnswerResult(
        answerText: _buildAmbiguityMessage(
          '${type.label.toLowerCase()}s',
          labels,
        ),
        confidence: 'Moyen',
      );
    }

    if (matchedFields.length > 1) {
      return AnswerResult(
        answerText:
            'Plusieurs informations correspondent à votre demande :\n'
            '${matchedFields.map((f) => '• ${f.name}').join('\n')}\n'
            'Pouvez-vous préciser ?',
        confidence: 'Moyen',
      );
    }

    final targetField = matchedFields.first;
    final results = <String, String>{};

    for (final entity in entitiesOfType) {
      final attrs = await attrProvider.getAttributesWithFields(
          entity.id, allFields);
      final match = attrs.where((a) => a.field.id == targetField.id).firstOrNull;
      if (match != null) {
        results[entity.label] = match.attribute.attributeValue;
      }
    }

    if (results.isEmpty) {
      _log('STAGE3', {
        'pattern': 'C',
        'typeCode': type.code,
        'entityCount': entitiesOfType.length,
        'field': targetField.name,
        'failure': 'Attribut non trouve sur les entites de ce type',
      });
      final name = entitiesOfType.length == 1
          ? entitiesOfType.first.label
          : 'vos ${type.label.toLowerCase()}s';
      return AnswerResult(
        answerText:
            'Je n\'ai pas trouvé votre ${targetField.name.toLowerCase()} pour $name.',
        confidence: 'Faible',
      );
    }

    if (results.length == 1) {
      final entry = results.entries.first;
      return AnswerResult(
        answerText:
            'Le ${targetField.name.toLowerCase()} de ${entry.key} est : ${entry.value}',
        confidence: 'Fort',
        values: [AnswerValue(label: targetField.name, value: entry.value)],
      );
    }

    final labels = results.entries.map((e) => e.key).toList();
    return AnswerResult(
      answerText: _buildAmbiguityMessage(
        '${type.label.toLowerCase()}s',
        labels,
      ),
      confidence: 'Moyen',
    );
  }

  // ===== Entry point =====

  Future<AnswerResult> answer({
    required String question,
    required EntityProvider entityProvider,
    required EntityAttributeProvider attrProvider,
    required AnalyticalFieldProvider fieldProvider,
    required EntityTypeProvider entityTypeProvider,
    required RelationTypeProvider relationTypeProvider,
    required RelationProvider relationProvider,
    required UserProfileProvider userProfileProvider,
    required CardProvider cardProvider,
  }) async {
    await _loadContext(
      entityProvider: entityProvider,
      attrProvider: attrProvider,
      fieldProvider: fieldProvider,
      entityTypeProvider: entityTypeProvider,
      relationTypeProvider: relationTypeProvider,
      relationProvider: relationProvider,
      userProfileProvider: userProfileProvider,
    );

    final cache = _cache;
    if (cache == null || cache.meEntity == null) {
      return AnswerResult(
        answerText: 'Je n\'ai pas encore d\'identité configurée.',
        confidence: 'Faible',
      );
    }

    final matchedFields = _matchFieldInQuestion(question, cache.allFields);
    final matchedRelations = _matchRelationInQuestion(
        question, cache.relationTypesByCode);
    final matchedEntityTypes = _matchEntityTypeInQuestion(
        question, cache.entityTypesByCode);

    _log('PARSE', {
      'question': question,
      'fields': matchedFields.map((f) => f.name).join(', '),
      'relations': matchedRelations.map((r) => r.code).join(', '),
      'types': matchedEntityTypes.map((t) => t.code).join(', '),
    });

    // Stage 1: Pattern A — attribut direct de "Moi"
    if (matchedFields.isNotEmpty &&
        matchedRelations.isEmpty &&
        matchedEntityTypes.isEmpty) {
      final result = await _resolvePersonalAttribute(
          matchedFields, cache.meAttributes);
      _log('STAGE1', {
        'pattern': 'A',
        'found': result != null,
        'confidence': result?.confidence ?? 'N/A',
        'result': result?.answerText ?? 'aucun',
      });
      if (result != null) return result;
    }

    // Stage 2: Pattern B/D — relation
    if (matchedRelations.isNotEmpty) {
      final result = await _resolveRelationAttribute(
        matchedRelations: matchedRelations,
        matchedFields: matchedFields,
        meRelations: cache.meRelations,
        allFields: cache.allFields,
        attrProvider: attrProvider,
      );
      final pattern = matchedFields.isEmpty ? 'D' : 'B';
      _log('STAGE2', {
        'pattern': pattern,
        'relationCode': matchedRelations.first.code,
        'found': result != null,
        'confidence': result?.confidence ?? 'N/A',
        'ambiguity': result?.confidence == 'Moyen',
        'result': result?.answerText ?? 'aucun',
      });
      if (result != null) return result;
    }

    // Stage 3: Pattern C/D — type d'entité
    if (matchedEntityTypes.isNotEmpty) {
      final result = await _resolveEntitiesByType(
        matchedEntityTypes: matchedEntityTypes,
        matchedFields: matchedFields,
        allEntities: cache.allEntities,
        entityTypesByCode: cache.entityTypesByCode,
        allFields: cache.allFields,
        attrProvider: attrProvider,
        meEntityId: cache.meEntity!.id,
      );
      final pattern = matchedFields.isEmpty ? 'D' : 'C';
      _log('STAGE3', {
        'pattern': pattern,
        'typeCode': matchedEntityTypes.first.code,
        'found': result != null,
        'confidence': result?.confidence ?? 'N/A',
        'ambiguity': result?.confidence == 'Moyen',
        'result': result?.answerText ?? 'aucun',
      });
      if (result != null) return result;
    }

    _log('STAGE4', {
      'pattern': 'FALLBACK',
      'reason': 'Aucun pattern n\'a matche',
    });
    return AnswerResult(
      answerText:
          'Je n\'ai pas trouvé cette information dans vos données personnelles.',
      confidence: 'Faible',
    );
  }
}
