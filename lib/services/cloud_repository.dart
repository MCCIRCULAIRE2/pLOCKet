import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/card_model.dart';
import '../models/document.dart';
import '../models/analytical_field.dart';
import '../models/tag.dart';
import '../models/entity.dart';
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
  // ANALYTICAL FIELDS
  // ═══════════════════════════════════════════════════════════════════

  Future<List<AnalyticalField>> getAllAnalyticalFields() async {
    final data = await _client
        .from('analytical_fields')
        .select()
        .eq('user_id', _userId)
        .isFilter('deleted_at', null)
        .order('name');

    return data.map((m) => AnalyticalField.fromMap(m)).toList();
  }

  Future<AnalyticalField> insertAnalyticalField(AnalyticalField field) async {
    final data = await _client.from('analytical_fields').insert({
      'id': field.id,
      'user_id': _userId,
      'name': field.name,
      'icon': field.icon,
    }).select().single();

    return AnalyticalField.fromMap(data);
  }

  Future<void> updateAnalyticalField(AnalyticalField field) async {
    await _client.from('analytical_fields').update({
      'name': field.name,
      'icon': field.icon,
    }).eq('id', field.id).eq('user_id', _userId);
  }

  Future<void> deleteAnalyticalField(String id) async {
    await _client
        .from('analytical_fields')
        .update({'deleted_at': DateTime.now().toIso8601String()})
        .eq('id', id)
        .eq('user_id', _userId);
  }

  // ═══════════════════════════════════════════════════════════════════
  // ANALYTICAL VALUES
  // ═══════════════════════════════════════════════════════════════════

  Future<List<AnalyticalValue>> getAllAnalyticalValues() async {
    final data = await _client
        .from('analytical_values')
        .select()
        .eq('user_id', _userId)
        .isFilter('deleted_at', null)
        .order('label');

    return data.map((m) => AnalyticalValue.fromMap(m)).toList();
  }

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

  Future<void> deleteAnalyticalValue(String id) async {
    await _client
        .from('analytical_values')
        .update({'deleted_at': DateTime.now().toIso8601String()})
        .eq('id', id)
        .eq('user_id', _userId);
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAGS
  // ═══════════════════════════════════════════════════════════════════

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

  Future<List<Entity>> getAllEntities() async {
    final data = await _client
        .from('entities')
        .select()
        .eq('user_id', _userId)
        .isFilter('deleted_at', null)
        .order('name');

    return data.map((m) => _entityFromSupabase(m)).toList();
  }

  Future<Entity> insertEntity(Entity entity) async {
    final data = await _client.from('entities').insert({
      'id': entity.id,
      'user_id': _userId,
      'entity_type': entity.entityType,
      'name': entity.name,
      'metadata': entity.metadata,
    }).select().single();

    return _entityFromSupabase(data);
  }

  Future<void> updateEntity(Entity entity) async {
    await _client.from('entities').update({
      'entity_type': entity.entityType,
      'name': entity.name,
      'metadata': entity.metadata,
    }).eq('id', entity.id).eq('user_id', _userId);
  }

  Future<void> deleteEntity(String id) async {
    await _client
        .from('entities')
        .update({'deleted_at': DateTime.now().toIso8601String()})
        .eq('id', id)
        .eq('user_id', _userId);
  }

  Entity _entityFromSupabase(Map<String, dynamic> m) {
    return Entity(
      id: m['id'] as String,
      entityType: m['entity_type'] as String,
      name: m['name'] as String,
      metadata: m['metadata'] is Map
          ? Map<String, dynamic>.from(m['metadata'] as Map)
          : {},
    );
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
    final data = await _client
        .from('user_profiles')
        .select()
        .eq('user_id', _userId)
        .maybeSingle();

    if (data == null) return null;
    return _profileFromSupabase(data);
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    await _client.from('user_profiles').upsert({
      'user_id': _userId,
      'nom': profile.nom,
      'prenom': profile.prenom,
      'date_naissance': profile.dateNaissance?.toIso8601String(),
      'email': profile.email,
      'telephone': profile.telephone,
      'adresse_postale': profile.adressePostale,
      'numero_securite_sociale': profile.numeroSecuriteSociale,
      'iban': profile.iban,
      'informations_libres': profile.informationsLibres,
    });
  }

  UserProfile _profileFromSupabase(Map<String, dynamic> m) {
    return UserProfile(
      nom: m['nom'] as String?,
      prenom: m['prenom'] as String?,
      dateNaissance: m['date_naissance'] != null
          ? DateTime.parse(m['date_naissance'] as String)
          : null,
      email: m['email'] as String?,
      telephone: m['telephone'] as String?,
      adressePostale: m['adresse_postale'] as String?,
      numeroSecuriteSociale: m['numero_securite_sociale'] as String?,
      iban: m['iban'] as String?,
      informationsLibres: m['informations_libres'] as String?,
    );
  }
}
