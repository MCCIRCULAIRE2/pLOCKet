import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/card_model.dart';
import '../models/document.dart';
import '../models/analytical_field.dart';
import '../models/tag.dart';
import '../models/entity.dart';
import '../models/entity_type.dart';
import '../models/relation_type.dart';
import '../models/entity_attribute.dart';
import '../models/analytical_relation.dart';
import '../models/event.dart';
import '../models/procedure.dart';
import '../models/user_profile.dart';
import 'supabase_service.dart';

class CloudRepository {
  SupabaseClient get _client => SupabaseService.client;

  String get _userId {
    final id = SupabaseService.currentUserId;
    if (id == null) throw Exception('Utilisateur non authentifié');
    return id;
  }

  // ═══════════════════════════════════════════════════════════════════
  // CARDS
  // ═══════════════════════════════════════════════════════════════════

  Future<List<CardModel>> getAllCards() async {
    final data = await _client
        .from('cards')
        .select()
        .eq('user_id', _userId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);

    return data.map((m) => _cardFromSupabase(m)).toList();
  }

  Future<CardModel?> getCardById(String id) async {
    final data = await _client
        .from('cards')
        .select()
        .eq('id', id)
        .eq('user_id', _userId)
        .isFilter('deleted_at', null)
        .maybeSingle();

    if (data == null) return null;
    return _cardFromSupabase(data);
  }

  Future<CardModel> insertCard(CardModel card) async {
    final data = await _client.from('cards').insert({
      'id': card.id,
      'user_id': _userId,
      'title': card.title,
      'type': card.type.name,
      'sub_type': card.subType,
      'raw_text': card.rawText,
      'value': card.value,
      'date': card.date?.toIso8601String(),
      'fields': card.fields,
      'tags': card.tags,
      'source_document_id': card.sourceDocumentId,
      'file_path': card.filePath,
      'mime_type': card.mimeType,
    }).select().single();

    return _cardFromSupabase(data);
  }

  Future<void> updateCard(CardModel card) async {
    await _client.from('cards').update({
      'title': card.title,
      'type': card.type.name,
      'sub_type': card.subType,
      'raw_text': card.rawText,
      'value': card.value,
      'date': card.date?.toIso8601String(),
      'fields': card.fields,
      'tags': card.tags,
      'source_document_id': card.sourceDocumentId,
      'file_path': card.filePath,
      'mime_type': card.mimeType,
    }).eq('id', card.id).eq('user_id', _userId);
  }

  Future<void> deleteCard(String id) async {
    await _client
        .from('cards')
        .update({'deleted_at': DateTime.now().toIso8601String()})
        .eq('id', id)
        .eq('user_id', _userId);
  }

  Future<List<CardModel>> searchCards(String query) async {
    final data = await _client
        .from('cards')
        .select()
        .eq('user_id', _userId)
        .isFilter('deleted_at', null)
        .or('title.ilike.%$query%,raw_text.ilike.%$query%')
        .order('created_at', ascending: false);

    return data.map((m) => _cardFromSupabase(m)).toList();
  }

  CardModel _cardFromSupabase(Map<String, dynamic> m) {
    return CardModel(
      id: m['id'] as String,
      title: m['title'] as String,
      type: CardType.values.firstWhere(
        (t) => t.name == m['type'],
        orElse: () => CardType.information,
      ),
      subType: m['sub_type'] as String? ?? 'general',
      rawText: m['raw_text'] as String? ?? '',
      value: m['value'] as String?,
      date: m['date'] != null ? DateTime.parse(m['date'] as String) : null,
      fields: m['fields'] is Map
          ? Map<String, dynamic>.from(m['fields'] as Map)
          : {},
      tags: m['tags'] is List
          ? List<String>.from(m['tags'] as List)
          : [],
      sourceDocumentId: m['source_document_id'] as String?,
      filePath: m['file_path'] as String?,
      mimeType: m['mime_type'] as String?,
      createdAt: m['created_at'] != null
          ? DateTime.parse(m['created_at'] as String)
          : DateTime.now(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // DOCUMENTS
  // ═══════════════════════════════════════════════════════════════════

  Future<List<Document>> getAllDocuments() async {
    final data = await _client
        .from('documents')
        .select()
        .eq('user_id', _userId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);

    return data.map((m) => _documentFromSupabase(m)).toList();
  }

  Future<Document?> getDocumentById(String id) async {
    final data = await _client
        .from('documents')
        .select()
        .eq('id', id)
        .eq('user_id', _userId)
        .isFilter('deleted_at', null)
        .maybeSingle();

    if (data == null) return null;
    return _documentFromSupabase(data);
  }

  Future<Document> insertDocument(Document doc) async {
    final data = await _client.from('documents').insert({
      'id': doc.id,
      'user_id': _userId,
      'title': doc.title,
      'file_path': doc.filePath,
      'mime_type': doc.mimeType,
      'ocr_text': doc.ocrText,
      'document_date': doc.documentDate?.toIso8601String(),
    }).select().single();

    return _documentFromSupabase(data);
  }

  Future<void> updateDocument(Document doc) async {
    await _client.from('documents').update({
      'title': doc.title,
      'file_path': doc.filePath,
      'mime_type': doc.mimeType,
      'ocr_text': doc.ocrText,
      'document_date': doc.documentDate?.toIso8601String(),
    }).eq('id', doc.id).eq('user_id', _userId);
  }

  Future<void> deleteDocument(String id) async {
    await _client
        .from('documents')
        .update({'deleted_at': DateTime.now().toIso8601String()})
        .eq('id', id)
        .eq('user_id', _userId);
  }

  Future<String> uploadDocumentFile(
    String documentId,
    Uint8List bytes,
    String fileName,
  ) async {
    final storagePath = '$_userId/$documentId/$fileName';
    await _client.storage.from('documents').uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    await _client
        .from('documents')
        .update({
          'storage_path': storagePath,
          'file_size': bytes.length,
        })
        .eq('id', documentId)
        .eq('user_id', _userId);
    return storagePath;
  }

  Future<Uint8List?> downloadDocumentFile(String storagePath) async {
    try {
      final bytes =
          await _client.storage.from('documents').download(storagePath);
      return bytes;
    } catch (e) {
      debugPrint('[CloudRepo] Download error: $e');
      return null;
    }
  }

  Future<void> deleteDocumentFile(String storagePath) async {
    try {
      await _client.storage.from('documents').remove([storagePath]);
    } catch (e) {
      debugPrint('[CloudRepo] Delete file error: $e');
    }
  }

  Document _documentFromSupabase(Map<String, dynamic> m) {
    return Document(
      id: m['id'] as String,
      title: m['title'] as String,
      filePath: m['file_path'] as String?,
      mimeType: m['mime_type'] as String?,
      ocrText: m['ocr_text'] as String?,
      createdAt: m['created_at'] != null
          ? DateTime.parse(m['created_at'] as String)
          : DateTime.now(),
      documentDate: m['document_date'] != null
          ? DateTime.parse(m['document_date'] as String)
          : null,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ENTITY TYPES (lecture seule - types système)
  // ═══════════════════════════════════════════════════════════════════

  Future<List<EntityType>> getEntityTypes() async {
    try {
      final data = await _client
          .from('entity_types')
          .select()
          .order('label');

      return data.map((m) => EntityType.fromMap(m)).toList();
    } catch (e) {
      debugPrint('[CloudRepo] getEntityTypes error: $e');
      rethrow;
    }
  }

  Future<EntityType?> getEntityTypeById(String id) async {
    try {
      final data = await _client
          .from('entity_types')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (data == null) return null;
      return EntityType.fromMap(data);
    } catch (e) {
      debugPrint('[CloudRepo] getEntityTypeById error: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // RELATION TYPES (lecture seule - types système)
  // ═══════════════════════════════════════════════════════════════════

  Future<List<RelationType>> getRelationTypes() async {
    try {
      final data = await _client
          .from('relation_types')
          .select()
          .order('label');

      return data.map((m) => RelationType.fromMap(m)).toList();
    } catch (e) {
      debugPrint('[CloudRepo] getRelationTypes error: $e');
      rethrow;
    }
  }

  Future<RelationType?> getRelationTypeById(String id) async {
    try {
      final data = await _client
          .from('relation_types')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (data == null) return null;
      return RelationType.fromMap(data);
    } catch (e) {
      debugPrint('[CloudRepo] getRelationTypeById error: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // RELATION INVERSES (lecture seule)
  // ═══════════════════════════════════════════════════════════════════

  Future<String?> getInverseRelationType(String relationTypeId) async {
    try {
      final data = await _client
          .from('relation_inverses')
          .select('inverse_type_id')
          .eq('relation_type_id', relationTypeId)
          .maybeSingle();

      if (data == null) return null;
      return data['inverse_type_id'] as String?;
    } catch (e) {
      debugPrint('[CloudRepo] getInverseRelationType error: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // RELATION SYNONYMS (lecture seule)
  // ═══════════════════════════════════════════════════════════════════

  Future<List<String>> getRelationSynonyms(String relationTypeId) async {
    try {
      final data = await _client
          .from('relation_synonyms')
          .select('synonym')
          .eq('relation_type_id', relationTypeId);

      return data.map((m) => m['synonym'] as String).toList();
    } catch (e) {
      debugPrint('[CloudRepo] getRelationSynonyms error: $e');
      rethrow;
    }
  }

  Future<String?> getRelationTypeBySynonym(String synonym) async {
    try {
      final data = await _client
          .from('relation_synonyms')
          .select('relation_type_id')
          .eq('synonym', synonym)
          .maybeSingle();

      if (data == null) return null;
      return data['relation_type_id'] as String?;
    } catch (e) {
      debugPrint('[CloudRepo] getRelationTypeBySynonym error: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // ANALYTICAL FIELDS
  // ═══════════════════════════════════════════════════════════════════

  Future<List<AnalyticalField>> getAllAnalyticalFields() async {
    try {
      final data = await _client
          .from('analytical_fields')
          .select()
          .eq('user_id', _userId)
          .isFilter('deleted_at', null)
          .order('name');

      return data.map((m) => AnalyticalField.fromMap(m)).toList();
    } catch (e) {
      debugPrint('[CloudRepo] getAllAnalyticalFields error: $e');
      rethrow;
    }
  }

  Future<AnalyticalField?> getAnalyticalFieldById(String id) async {
    try {
      final data = await _client
          .from('analytical_fields')
          .select()
          .eq('id', id)
          .eq('user_id', _userId)
          .isFilter('deleted_at', null)
          .maybeSingle();

      if (data == null) return null;
      return AnalyticalField.fromMap(data);
    } catch (e) {
      debugPrint('[CloudRepo] getAnalyticalFieldById error: $e');
      rethrow;
    }
  }

  Future<List<AnalyticalField>> getAnalyticalFieldsByEntityType(String entityTypeId) async {
    try {
      final data = await _client
          .from('analytical_fields')
          .select()
          .eq('user_id', _userId)
          .eq('entity_type_id', entityTypeId)
          .isFilter('deleted_at', null)
          .order('name');

      return data.map((m) => AnalyticalField.fromMap(m)).toList();
    } catch (e) {
      debugPrint('[CloudRepo] getAnalyticalFieldsByEntityType error: $e');
      rethrow;
    }
  }

  Future<AnalyticalField> insertAnalyticalField(AnalyticalField field) async {
    try {
      final data = await _client.from('analytical_fields').insert({
        'id': field.id,
        'user_id': _userId,
        'name': field.name,
        'category': field.category,
        'entity_type_id': field.entityTypeId,
        'is_sensitive': field.isSensitive,
      }).select().single();

      return AnalyticalField.fromMap(data);
    } catch (e) {
      debugPrint('[CloudRepo] insertAnalyticalField error: $e');
      rethrow;
    }
  }

  Future<void> updateAnalyticalField(AnalyticalField field) async {
    try {
      await _client.from('analytical_fields').update({
        'name': field.name,
        'category': field.category,
        'entity_type_id': field.entityTypeId,
        'is_sensitive': field.isSensitive,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', field.id).eq('user_id', _userId);
    } catch (e) {
      debugPrint('[CloudRepo] updateAnalyticalField error: $e');
      rethrow;
    }
  }

  Future<void> deleteAnalyticalField(String id) async {
    try {
      await _client
          .from('analytical_fields')
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', id)
          .eq('user_id', _userId);
    } catch (e) {
      debugPrint('[CloudRepo] deleteAnalyticalField error: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // ANALYTICAL VALUES (DÉPRÉCIÉ - utiliser Entity Attributes)
  // ═══════════════════════════════════════════════════════════════════

  /// @deprecated Utiliser Entity Attributes à la place
  @Deprecated('Utiliser Entity Attributes à la place')
  Future<List<AnalyticalValue>> getAllAnalyticalValues() async {
    final data = await _client
        .from('analytical_values')
        .select()
        .eq('user_id', _userId)
        .isFilter('deleted_at', null)
        .order('label');

    return data.map((m) => AnalyticalValue.fromMap(m)).toList();
  }

  /// @deprecated Utiliser Entity Attributes à la place
  @Deprecated('Utiliser Entity Attributes à la place')
  Future<List<AnalyticalValue>> getAnalyticalValuesForField(
      String fieldId) async {
    final data = await _client
        .from('analytical_values')
        .select()
        .eq('field_id', fieldId)
        .eq('user_id', _userId)
        .isFilter('deleted_at', null)
        .order('label');

    return data.map((m) => AnalyticalValue.fromMap(m)).toList();
  }

  /// @deprecated Utiliser Entity Attributes à la place
  @Deprecated('Utiliser Entity Attributes à la place')
  Future<AnalyticalValue> insertAnalyticalValue(
      AnalyticalValue value) async {
    final data = await _client.from('analytical_values').insert({
      'id': value.id,
      'user_id': _userId,
      'field_id': value.fieldId,
      'label': value.label,
      'aliases': value.aliases,
      'identifiers': value.identifiers,
      'role': value.role,
      'category': value.category,
      'relation': value.relation,
    }).select().single();

    return AnalyticalValue.fromMap(data);
  }

  /// @deprecated Utiliser Entity Attributes à la place
  @Deprecated('Utiliser Entity Attributes à la place')
  Future<void> updateAnalyticalValue(AnalyticalValue value) async {
    await _client.from('analytical_values').update({
      'label': value.label,
      'aliases': value.aliases,
      'identifiers': value.identifiers,
      'role': value.role,
      'category': value.category,
      'relation': value.relation,
    }).eq('id', value.id).eq('user_id', _userId);
  }

  /// @deprecated Utiliser Entity Attributes à la place
  @Deprecated('Utiliser Entity Attributes à la place')
  Future<void> deleteAnalyticalValue(String id) async {
    await _client
        .from('analytical_values')
        .update({'deleted_at': DateTime.now().toIso8601String()})
        .eq('id', id)
        .eq('user_id', _userId);
  }

  // ═══════════════════════════════════════════════════════════════════
  // ENTITY ATTRIBUTES
  // ═══════════════════════════════════════════════════════════════════

  Future<List<EntityAttribute>> getEntityAttributes(String entityId) async {
    try {
      final data = await _client
          .from('entity_attributes')
          .select()
          .eq('entity_id', entityId)
          .order('created_at', ascending: false);

      return data.map((m) => EntityAttribute.fromMap(m)).toList();
    } catch (e) {
      debugPrint('[CloudRepo] getEntityAttributes error: $e');
      rethrow;
    }
  }

  Future<EntityAttribute?> getEntityAttributeById(String id) async {
    try {
      final data = await _client
          .from('entity_attributes')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (data == null) return null;
      return EntityAttribute.fromMap(data);
    } catch (e) {
      debugPrint('[CloudRepo] getEntityAttributeById error: $e');
      rethrow;
    }
  }

  Future<EntityAttribute> createEntityAttribute(EntityAttribute attribute) async {
    try {
      final data = await _client.from('entity_attributes').insert({
        'id': attribute.id,
        'entity_id': attribute.entityId,
        'field_id': attribute.fieldId,
        'attribute_value': attribute.attributeValue,
        'provenance': attribute.provenance,
      }).select().single();

      return EntityAttribute.fromMap(data);
    } catch (e) {
      debugPrint('[CloudRepo] createEntityAttribute error: $e');
      rethrow;
    }
  }

  Future<void> updateEntityAttribute(EntityAttribute attribute) async {
    try {
      await _client.from('entity_attributes').update({
        'attribute_value': attribute.attributeValue,
        'provenance': attribute.provenance,
      }).eq('id', attribute.id);
    } catch (e) {
      debugPrint('[CloudRepo] updateEntityAttribute error: $e');
      rethrow;
    }
  }

  Future<void> deleteEntityAttribute(String id) async {
    try {
      await _client
          .from('entity_attributes')
          .delete()
          .eq('id', id);
    } catch (e) {
      debugPrint('[CloudRepo] deleteEntityAttribute error: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // ANALYTICAL RELATIONS
  // ═══════════════════════════════════════════════════════════════════

  Future<List<AnalyticalRelation>> getRelationsBySourceEntity(String entityId) async {
    try {
      final data = await _client
          .from('analytical_relations')
          .select()
          .eq('source_entity_id', entityId)
          .eq('user_id', _userId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);

      return data.map((m) => AnalyticalRelation.fromMap(m)).toList();
    } catch (e) {
      debugPrint('[CloudRepo] getRelationsBySourceEntity error: $e');
      rethrow;
    }
  }

  Future<List<AnalyticalRelation>> getRelationsByTargetEntity(String entityId) async {
    try {
      final data = await _client
          .from('analytical_relations')
          .select()
          .eq('target_entity_id', entityId)
          .eq('user_id', _userId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);

      return data.map((m) => AnalyticalRelation.fromMap(m)).toList();
    } catch (e) {
      debugPrint('[CloudRepo] getRelationsByTargetEntity error: $e');
      rethrow;
    }
  }

  Future<List<AnalyticalRelation>> getRelationsByType(String relationTypeId) async {
    try {
      final data = await _client
          .from('analytical_relations')
          .select()
          .eq('relation_type_id', relationTypeId)
          .eq('user_id', _userId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);

      return data.map((m) => AnalyticalRelation.fromMap(m)).toList();
    } catch (e) {
      debugPrint('[CloudRepo] getRelationsByType error: $e');
      rethrow;
    }
  }

  Future<AnalyticalRelation> createRelation(AnalyticalRelation relation) async {
    try {
      final data = await _client.from('analytical_relations').insert({
        'id': relation.id,
        'user_id': _userId,
        'source_entity_id': relation.sourceEntityId,
        'target_entity_id': relation.targetEntityId,
        'relation_type_id': relation.relationTypeId,
      }).select().single();

      return AnalyticalRelation.fromMap(data);
    } catch (e) {
      debugPrint('[CloudRepo] createRelation error: $e');
      rethrow;
    }
  }

  Future<void> updateRelation(AnalyticalRelation relation) async {
    try {
      await _client.from('analytical_relations').update({
        'source_entity_id': relation.sourceEntityId,
        'target_entity_id': relation.targetEntityId,
        'relation_type_id': relation.relationTypeId,
      }).eq('id', relation.id).eq('user_id', _userId);
    } catch (e) {
      debugPrint('[CloudRepo] updateRelation error: $e');
      rethrow;
    }
  }

  Future<void> deleteRelation(String id) async {
    try {
      await _client
          .from('analytical_relations')
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', id)
          .eq('user_id', _userId);
    } catch (e) {
      debugPrint('[CloudRepo] deleteRelation error: $e');
      rethrow;
    }
  }

  Future<List<Tag>> getAllTags() async {
    final data = await _client
        .from('tags')
        .select()
        .eq('user_id', _userId)
        .order('label');

    return data.map((m) => Tag.fromMap(m)).toList();
  }

  Future<void> insertTag(Tag tag) async {
    await _client.from('tags').insert({
      'id': tag.id,
      'user_id': _userId,
      'label': tag.label,
      'category': tag.category.name,
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  // ENTITIES
  // ═══════════════════════════════════════════════════════════════════

  Future<List<Entity>> getEntities() async {
    try {
      final data = await _client
          .from('entities')
          .select()
          .eq('user_id', _userId)
          .isFilter('deleted_at', null)
          .order('label');

      return data.map((m) => Entity.fromMap(m)).toList();
    } catch (e) {
      debugPrint('[CloudRepo] getEntities error: $e');
      rethrow;
    }
  }

  Future<Entity?> getEntityById(String id) async {
    try {
      final data = await _client
          .from('entities')
          .select()
          .eq('id', id)
          .eq('user_id', _userId)
          .isFilter('deleted_at', null)
          .maybeSingle();

      if (data == null) return null;
      return Entity.fromMap(data);
    } catch (e) {
      debugPrint('[CloudRepo] getEntityById error: $e');
      rethrow;
    }
  }

  Future<List<Entity>> getEntitiesByType(String entityTypeId) async {
    try {
      final data = await _client
          .from('entities')
          .select()
          .eq('user_id', _userId)
          .eq('entity_type_id', entityTypeId)
          .isFilter('deleted_at', null)
          .order('label');

      return data.map((m) => Entity.fromMap(m)).toList();
    } catch (e) {
      debugPrint('[CloudRepo] getEntitiesByType error: $e');
      rethrow;
    }
  }

  Future<Entity> createEntity(Entity entity) async {
    try {
      final data = await _client.from('entities').insert({
        'id': entity.id,
        'user_id': _userId,
        'entity_type_id': entity.entityTypeId,
        'label': entity.label,
      }).select().single();

      return Entity.fromMap(data);
    } catch (e) {
      debugPrint('[CloudRepo] createEntity error: $e');
      rethrow;
    }
  }

  Future<void> updateEntity(Entity entity) async {
    try {
      await _client.from('entities').update({
        'entity_type_id': entity.entityTypeId,
        'label': entity.label,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', entity.id).eq('user_id', _userId);
    } catch (e) {
      debugPrint('[CloudRepo] updateEntity error: $e');
      rethrow;
    }
  }

  Future<void> deleteEntity(String id) async {
    try {
      await _client
          .from('entities')
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', id)
          .eq('user_id', _userId);
    } catch (e) {
      debugPrint('[CloudRepo] deleteEntity error: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // EVENTS
  // ═══════════════════════════════════════════════════════════════════

  Future<List<Event>> getAllEvents() async {
    final data = await _client
        .from('events')
        .select()
        .eq('user_id', _userId)
        .isFilter('deleted_at', null)
        .order('date', ascending: false);

    return data.map((m) => _eventFromSupabase(m)).toList();
  }

  Future<Event> insertEvent(Event event) async {
    final data = await _client.from('events').insert({
      'id': event.id,
      'user_id': _userId,
      'event_type': event.eventType,
      'entity_id': event.entityId,
      'date': event.date.toIso8601String(),
      'description': event.description,
      'metadata': event.metadata,
      'document_id': event.documentId,
    }).select().single();

    return _eventFromSupabase(data);
  }

  Future<void> updateEvent(Event event) async {
    await _client.from('events').update({
      'event_type': event.eventType,
      'entity_id': event.entityId,
      'date': event.date.toIso8601String(),
      'description': event.description,
      'metadata': event.metadata,
      'document_id': event.documentId,
    }).eq('id', event.id).eq('user_id', _userId);
  }

  Future<void> deleteEvent(String id) async {
    await _client
        .from('events')
        .update({'deleted_at': DateTime.now().toIso8601String()})
        .eq('id', id)
        .eq('user_id', _userId);
  }

  Event _eventFromSupabase(Map<String, dynamic> m) {
    return Event(
      id: m['id'] as String,
      eventType: m['event_type'] as String,
      entityId: m['entity_id'] as String?,
      date: DateTime.parse(m['date'] as String),
      description: m['description'] as String,
      metadata: m['metadata'] is Map
          ? Map<String, dynamic>.from(m['metadata'] as Map)
          : {},
      documentId: m['document_id'] as String?,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // PROCEDURES
  // ═══════════════════════════════════════════════════════════════════

  Future<List<Procedure>> getAllProcedures() async {
    final data = await _client
        .from('procedures')
        .select()
        .eq('user_id', _userId)
        .isFilter('deleted_at', null)
        .order('title');

    return data.map((m) => _procedureFromSupabase(m)).toList();
  }

  Future<Procedure> insertProcedure(Procedure procedure) async {
    final data = await _client.from('procedures').insert({
      'id': procedure.id,
      'user_id': _userId,
      'title': procedure.title,
      'description': procedure.description,
      'metadata': procedure.metadata,
    }).select().single();

    return _procedureFromSupabase(data);
  }

  Future<void> updateProcedure(Procedure procedure) async {
    await _client.from('procedures').update({
      'title': procedure.title,
      'description': procedure.description,
      'metadata': procedure.metadata,
    }).eq('id', procedure.id).eq('user_id', _userId);
  }

  Future<void> deleteProcedure(String id) async {
    await _client
        .from('procedures')
        .update({'deleted_at': DateTime.now().toIso8601String()})
        .eq('id', id)
        .eq('user_id', _userId);
  }

  Procedure _procedureFromSupabase(Map<String, dynamic> m) {
    return Procedure(
      id: m['id'] as String,
      title: m['title'] as String,
      description: m['description'] as String,
      metadata: m['metadata'] is Map
          ? Map<String, dynamic>.from(m['metadata'] as Map)
          : {},
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // USER PROFILE
  // ═══════════════════════════════════════════════════════════════════

  Future<UserProfile?> getUserProfile() async {
    try {
      final data = await _client
          .from('user_profiles')
          .select()
          .eq('user_id', _userId)
          .maybeSingle();

      if (data == null) return null;
      return UserProfile.fromMap(data);
    } catch (e) {
      debugPrint('[CloudRepo] getUserProfile error: $e');
      rethrow;
    }
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    try {
      await _client.from('user_profiles').upsert({
        'user_id': _userId,
        'first_name': profile.firstName,
        'last_name': profile.lastName,
        'phone': profile.phone,
        'birth_date': profile.birthDate?.toIso8601String(),
        'onboarding_completed': profile.onboardingCompleted,
        // Anciennes colonnes conservées pour migration applicative
        'email': profile.email,
        'adresse_postale': profile.adressePostale,
        'numero_securite_sociale': profile.numeroSecuriteSociale,
        'iban': profile.iban,
        'informations_libres': profile.informationsLibres,
      });
    } catch (e) {
      debugPrint('[CloudRepo] saveUserProfile error: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // MÉTHODES AUXILIAIRES BATCH (privées)
  // ═══════════════════════════════════════════════════════════════════

  Future<List<AnalyticalField>> _getAnalyticalFieldsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    
    try {
      final data = await _client
          .from('analytical_fields')
          .select()
          .inFilter('id', ids)
          .eq('user_id', _userId)
          .isFilter('deleted_at', null);

      return data.map((m) => AnalyticalField.fromMap(m)).toList();
    } catch (e) {
      debugPrint('[CloudRepo] _getAnalyticalFieldsByIds error: $e');
      rethrow;
    }
  }

  Future<List<Entity>> _getEntitiesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    
    try {
      final data = await _client
          .from('entities')
          .select()
          .inFilter('id', ids)
          .eq('user_id', _userId)
          .isFilter('deleted_at', null);

      return data.map((m) => Entity.fromMap(m)).toList();
    } catch (e) {
      debugPrint('[CloudRepo] _getEntitiesByIds error: $e');
      rethrow;
    }
  }

  Future<List<RelationType>> _getRelationTypesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    
    try {
      final data = await _client
          .from('relation_types')
          .select()
          .inFilter('id', ids);

      return data.map((m) => RelationType.fromMap(m)).toList();
    } catch (e) {
      debugPrint('[CloudRepo] _getRelationTypesByIds error: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // MÉTHODES DE HAUT NIVEAU
  // ═══════════════════════════════════════════════════════════════════

  Future<EntityWithDetails?> getEntityWithDetails(String entityId) async {
    try {
      // 1. Récupérer l'entité
      final entity = await getEntityById(entityId);
      if (entity == null) return null;

      // 2. Récupérer les attributs avec leurs définitions
      final attributes = await _getEntityAttributesWithFields(entityId);

      // 3. Récupérer toutes les relations
      final relations = await getAllEntityRelations(entityId);

      return EntityWithDetails(
        entity: entity,
        attributes: attributes,
        relations: relations,
      );
    } catch (e) {
      debugPrint('[CloudRepo] getEntityWithDetails error: $e');
      rethrow;
    }
  }

  Future<List<EntityAttributeWithField>> _getEntityAttributesWithFields(String entityId) async {
    // Récupérer les attributs
    final attributes = await getEntityAttributes(entityId);
    
    if (attributes.isEmpty) return [];
    
    // Récupérer les définitions de champs (batch)
    final fieldIds = attributes.map((a) => a.fieldId).toSet().toList();
    final fields = await _getAnalyticalFieldsByIds(fieldIds);
    
    // Indexer les champs dans une Map
    final fieldMap = <String, AnalyticalField>{
      for (var f in fields) f.id: f,
    };
    
    // Combiner
    return attributes.map((attr) {
      final field = fieldMap[attr.fieldId];
      if (field == null) {
        throw Exception('Field not found for attribute ${attr.id}');
      }
      return EntityAttributeWithField(attribute: attr, field: field);
    }).toList();
  }

  Future<List<EntityRelationWithEntities>> getAllEntityRelations(String entityId) async {
    try {
      // 1. Récupérer les relations sortantes et entrantes (2 requêtes)
      final outgoingRelations = await getRelationsBySourceEntity(entityId);
      final incomingRelations = await getRelationsByTargetEntity(entityId);
      final allRelations = [...outgoingRelations, ...incomingRelations];
      
      if (allRelations.isEmpty) return [];
      
      // 2. Récupérer l'entité courante UNE SEULE FOIS (1 requête)
      final currentEntity = await getEntityById(entityId);
      if (currentEntity == null) return [];
      
      // 3. Récupérer les entités liées en batch (1 requête)
      final entityIds = allRelations
          .expand((r) => [r.sourceEntityId, r.targetEntityId])
          .where((id) => id != entityId)
          .toSet()
          .toList();
      
      final linkedEntities = await _getEntitiesByIds(entityIds);
      
      // 4. Indexer les entités dans une Map pour accès O(1)
      final entityMap = <String, Entity>{
        entityId: currentEntity,
        for (var e in linkedEntities) e.id: e,
      };
      
      // 5. Récupérer les relation_types en batch (1 requête)
      final relationTypeIds = allRelations.map((r) => r.relationTypeId).toSet().toList();
      final relationTypes = await _getRelationTypesByIds(relationTypeIds);
      
      // 6. Indexer les relation_types dans une Map pour accès O(1)
      final relationTypeMap = <String, RelationType>{
        for (var t in relationTypes) t.id: t,
      };
      
      // 7. Construire les résultats SANS appels dans la boucle
      return allRelations.map((relation) {
        final sourceEntity = entityMap[relation.sourceEntityId];
        final targetEntity = entityMap[relation.targetEntityId];
        final relationType = relationTypeMap[relation.relationTypeId];
        
        if (sourceEntity == null || targetEntity == null || relationType == null) {
          throw Exception('Missing entity or relation type for relation ${relation.id}');
        }
        
        return EntityRelationWithEntities(
          relation: relation,
          sourceEntity: sourceEntity,
          targetEntity: targetEntity,
          relationType: relationType,
          isOutgoing: relation.sourceEntityId == entityId,
        );
      }).toList();
    } catch (e) {
      debugPrint('[CloudRepo] getAllEntityRelations error: $e');
      rethrow;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// MODÈLES COMPOSITES POUR MÉTHODES DE HAUT NIVEAU
// ═══════════════════════════════════════════════════════════════════

class EntityWithDetails {
  final Entity entity;
  final List<EntityAttributeWithField> attributes;
  final List<EntityRelationWithEntities> relations;

  EntityWithDetails({
    required this.entity,
    required this.attributes,
    required this.relations,
  });
}

class EntityAttributeWithField {
  final EntityAttribute attribute;
  final AnalyticalField field;

  EntityAttributeWithField({
    required this.attribute,
    required this.field,
  });
}

class EntityRelationWithEntities {
  final AnalyticalRelation relation;
  final Entity sourceEntity;
  final Entity targetEntity;
  final RelationType relationType;
  final bool isOutgoing;

  EntityRelationWithEntities({
    required this.relation,
    required this.sourceEntity,
    required this.targetEntity,
    required this.relationType,
    required this.isOutgoing,
  });
}
