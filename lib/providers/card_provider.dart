import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/card_model.dart';
import '../models/draft_card.dart';
import '../models/typed_field.dart';
import '../ai/ai_service.dart';
import '../ai/fallback_ai_service.dart';
import '../services/content_pipeline.dart';
import '../services/qa_engine.dart';
import '../database/daos/card_dao.dart';
import '../database/daos/document_dao.dart';
import '../models/document.dart';


class CardProvider extends ChangeNotifier {
  final CardDao _cardDao = CardDao();
  final DocumentDao _documentDao = DocumentDao();
  late final ContentPipeline _pipeline;
  late final QaEngine _qa;
  final Uuid _uuid = Uuid();

  CardProvider({AIService? ai}) {
    final service = ai ?? FallbackAIService();
    _pipeline = ContentPipeline(ai: service);
    _qa = QaEngine(ai: service);
  }

  List<CardModel> _cards = [];
  List<CardModel> get cards => _cards;

  CardModel? _selectedCard;
  CardModel? get selectedCard => _selectedCard;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  AnswerResult? _lastAnswer;
  AnswerResult? get lastAnswer => _lastAnswer;

  bool _isAnswering = false;
  bool get isAnswering => _isAnswering;

  String? _error;
  String? get error => _error;

  Future<void> loadCards() async {
    debugPrint('[CARDS LOAD] ═══════════════════════════════════════════════════════════');
    debugPrint('[CARDS LOAD] Début chargement des fiches');
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _cards = await _cardDao.getAll();
      debugPrint('[CARDS LOAD] ✓ ${_cards.length} fiche(s) chargée(s)');
      for (final card in _cards) {
        debugPrint('[CARDS LOAD]   - ${card.title} (id: ${card.id})');
      }
    } catch (e) {
      debugPrint('[CARDS LOAD] ❌ Erreur: $e');
      _error = 'Erreur chargement fiches: $e';
    }
    _isLoading = false;
    notifyListeners();
    debugPrint('[CARDS LOAD] ═══════════════════════════════════════════════════════════');
  }

  /// Met à jour toutes les fiches qui contiennent l'ancienne valeur analytique
  Future<void> updateCardsWithAnalyticalValue({
    required String fieldName,
    required String oldLabel,
    required String newLabel,
  }) async {
    debugPrint('[CARDS UPDATE] ═══════════════════════════════════════════════════════════');
    debugPrint('[CARDS UPDATE] Mise à jour des fiches pour $fieldName: "$oldLabel" → "$newLabel"');
    
    int updatedCount = 0;
    
    for (final card in _cards) {
      bool cardUpdated = false;
      final updatedFields = Map<String, dynamic>.from(card.fields);
      
      // Parcourir tous les champs de la fiche
      for (final entry in updatedFields.entries) {
        final key = entry.key;
        final value = entry.value;
        
        // Si le champ correspond au nom du champ analytique et contient l'ancien label
        if (key == fieldName) {
          if (value is Map<String, dynamic>) {
            final currentValue = value['v'] as String?;
            if (currentValue == oldLabel) {
              updatedFields[key] = {
                ...value,
                'v': newLabel,
              };
              cardUpdated = true;
              debugPrint('[CARDS UPDATE]   ✓ Fiche "${card.title}": $fieldName mis à jour');
            }
          } else if (value is String && value == oldLabel) {
            updatedFields[key] = newLabel;
            cardUpdated = true;
            debugPrint('[CARDS UPDATE]   ✓ Fiche "${card.title}": $fieldName mis à jour');
          }
        }
      }
      
      // Si la fiche a été modifiée, la sauvegarder
      if (cardUpdated) {
        final updatedCard = card.copyWith(fields: updatedFields);
        await _cardDao.update(updatedCard);
        updatedCount++;
      }
    }
    
    debugPrint('[CARDS UPDATE] ✓ $updatedCount fiche(s) mise(s) à jour');
    debugPrint('[CARDS UPDATE] ═══════════════════════════════════════════════════════════');
    
    // Recharger les fiches pour refléter les changements
    await loadCards();
  }

  Future<CardModel?> processText(String rawText,
      {String? filePath, String? mimeType}) async {
    _error = null;
    try {
      final card = await _pipeline.processText(rawText,
          filePath: filePath, mimeType: mimeType);
      await loadCards();
      return card;
    } catch (e) {
      _error = 'Erreur traitement: $e';
      notifyListeners();
      return null;
    }
  }

  /// Analyze text without saving. Returns a DraftCard for the verification screen.
  Future<DraftCard?> analyzeText(String rawText,
      {String? filePath, String? mimeType, String? sourceFileName, String? sourceFileExtension, Uint8List? sourceBytes}) async {
    _error = null;
    try {
      debugPrint('[ANALYZE] ═══════════════════════════════════════════════════════════');
      debugPrint('[ANALYZE] Début analyse texte');
      debugPrint('[ANALYZE] ═══════════════════════════════════════════════════════════');
      
      final analysis = await _pipeline.analyzeOnly(rawText);
      debugPrint('[ANALYZE] ✓ Analyse IA terminée — ${analysis.fields.length} champ(s) extrait(s)');
      
      final extraFields = await _pipeline.extractFieldsOnly(rawText, analysis.type, analysis.subType);
      debugPrint('[ANALYZE] ✓ Extraction supplémentaire — ${extraFields.length} champ(s)');
      
      final allFields = {...analysis.fields, ...extraFields};
      debugPrint('[ANALYZE] ─── Tous les champs bruts (${allFields.length}) ───');
      for (final entry in allFields.entries) {
        debugPrint('[ANALYZE] ✓ ${entry.key} = ${entry.value}');
      }
      
      final typedFields = _convertToTypedFields(allFields);
      debugPrint('[ANALYZE] ─── Champs convertis en TypedField (${typedFields.length}) ───');
      for (final entry in typedFields.entries) {
        debugPrint('[ANALYZE] ✓ ${entry.key} = "${entry.value.rawValue}" (type=${entry.value.type.name})');
      }
      
      final draft = DraftCard(
        title: analysis.title,
        type: analysis.type,
        subType: analysis.subType,
        rawText: rawText,
        value: analysis.value,
        date: analysis.date,
        filePath: filePath,
        mimeType: mimeType,
        fields: typedFields,
        tags: List<String>.from(analysis.tags),
        sourceFileName: sourceFileName,
        sourceFileExtension: sourceFileExtension,
        sourceBytes: sourceBytes,
        candidates: analysis.candidates,
        suggestedFields: List<String>.from(analysis.suggestedFields),
      );
      
      debugPrint('[ANALYZE] ─── Validation des champs ───');
      draft.validate();
      debugPrint('[ANALYZE] ✓ Validation terminée — ${draft.warnings.length} avertissement(s)');
      for (final warning in draft.warnings) {
        debugPrint('[ANALYZE] ⚠ ${warning.fieldKey}: ${warning.message} (${warning.severity.name})');
      }
      
      draft.markAmbiguousFields();
      debugPrint('[ANALYZE] ✓ Marquage champs ambigus terminé');
      
      debugPrint('[ANALYZE] ═══════════════════════════════════════════════════════════');
      debugPrint('[ANALYZE] Fin analyse — ${typedFields.length} champ(s) dans le brouillon');
      if (draft.suggestedFields.isNotEmpty) {
        debugPrint('[ANALYZE] Champs suggérés: ${draft.suggestedFields.join(", ")}');
      }
      debugPrint('[ANALYZE] ═══════════════════════════════════════════════════════════');
      
      return draft;
    } catch (e) {
      _error = 'Erreur analyse: $e';
      notifyListeners();
      return null;
    }
  }

  /// Analyze document without saving. Returns a DraftCard for the verification screen.
  Future<DraftCard?> analyzeDocument({
    required String title,
    required String ocrText,
    String? filePath,
    String? mimeType,
    DateTime? documentDate,
    String? sourceFileName,
    String? sourceFileExtension,
    Uint8List? sourceBytes,
  }) async {
    _error = null;
    try {
      debugPrint('[ANALYZE] ═══════════════════════════════════════════════════════════');
      debugPrint('[ANALYZE] Début analyse document');
      debugPrint('[ANALYZE] ═══════════════════════════════════════════════════════════');
      
      final analysis = await _pipeline.analyzeOnly(ocrText);
      debugPrint('[ANALYZE] ✓ Analyse IA terminée — ${analysis.fields.length} champ(s) extrait(s)');
      
      final extraFields = await _pipeline.extractFieldsOnly(ocrText, analysis.type, analysis.subType);
      debugPrint('[ANALYZE] ✓ Extraction supplémentaire — ${extraFields.length} champ(s)');
      
      final allFields = {...analysis.fields, ...extraFields};
      debugPrint('[ANALYZE] ─── Tous les champs bruts (${allFields.length}) ───');
      for (final entry in allFields.entries) {
        debugPrint('[ANALYZE] ✓ ${entry.key} = ${entry.value}');
      }
      
      final aiTitle = analysis.title != 'Information' ? analysis.title : title;
      final safeBytes = sourceBytes != null ? Uint8List.fromList(sourceBytes!) : null;
      
      final typedFields = _convertToTypedFields(allFields);
      debugPrint('[ANALYZE] ─── Champs convertis en TypedField (${typedFields.length}) ───');
      for (final entry in typedFields.entries) {
        debugPrint('[ANALYZE] ✓ ${entry.key} = "${entry.value.rawValue}" (type=${entry.value.type.name})');
      }
      
      final draft = DraftCard(
        title: '$aiTitle - $title',
        type: analysis.type == CardType.information ? CardType.document : analysis.type,
        subType: analysis.subType,
        rawText: ocrText,
        value: analysis.value,
        date: documentDate ?? analysis.date,
        filePath: filePath,
        mimeType: mimeType,
        fields: typedFields,
        tags: List<String>.from(analysis.tags),
        sourceFileName: sourceFileName,
        sourceFileExtension: sourceFileExtension,
        sourceBytes: safeBytes,
        candidates: analysis.candidates,
        suggestedFields: List<String>.from(analysis.suggestedFields),
      );
      draft.validate();
      debugPrint('[ANALYZE] ✓ Validation terminée — ${draft.warnings.length} avertissement(s)');
      
      draft.markAmbiguousFields();
      debugPrint('[ANALYZE] ✓ Marquage champs ambigus terminé');
      
      debugPrint('[ANALYZE] ═══════════════════════════════════════════════════════════');
      debugPrint('[ANALYZE] Fin analyse — ${typedFields.length} champ(s) dans le brouillon');
      if (draft.suggestedFields.isNotEmpty) {
        debugPrint('[ANALYZE] Champs suggérés: ${draft.suggestedFields.join(", ")}');
      }
      debugPrint('[ANALYZE] ═══════════════════════════════════════════════════════════');
      
      return draft;
    } catch (e) {
      _error = 'Erreur analyse document: $e';
      debugPrint('[ANALYZE] ❌ Erreur: $e');
      notifyListeners();
      return null;
    }
  }

  /// Save a DraftCard (after user validation) as a permanent CardModel.
  Future<CardModel?> finalizeCard(DraftCard draft) async {
    _error = null;
    try {
      debugPrint('[SAVE] ═══════════════════════════════════════════════════════════');
      debugPrint('[SAVE] Début sauvegarde fiche');
      debugPrint('[SAVE] ═══════════════════════════════════════════════════════════');
      debugPrint('[SAVE] Génération UUIDs');
      final cardId = _uuid.v4();
      debugPrint('[SAVE] cardId = $cardId');
      final docId = _uuid.v4();
      debugPrint('[SAVE] docId = $docId');

      final allFields = {
        ...TypedField.encodeMap(draft.fields),
        ...TypedField.encodeMap(draft.customFields),
      };
      
      debugPrint('[SAVE] ─── Champs à sauvegarder (${allFields.length}) ───');
      for (final entry in allFields.entries) {
        final value = entry.value;
        final displayValue = value is Map<String, dynamic> ? value['v'] : value;
        debugPrint('[SAVE] ✓ ${entry.key} = $displayValue');
      }
      
      debugPrint('[SAVE] Sauvegarde fiche ($cardId)');
      debugPrint('[SAVE] draft.sourceBytes is null = ${draft.sourceBytes == null}');
      debugPrint('[SAVE] draft.sourceBytes length = ${draft.sourceBytes?.length ?? 0}');
      final rawBytes = draft.sourceBytes != null
          ? Uint8List.fromList(draft.sourceBytes!)
          : null;
      final sourceData = rawBytes != null ? base64Encode(rawBytes) : null;
      debugPrint('[SAVE] sourceData length = ${sourceData?.length ?? 0}');
      debugPrint('[SAVE] bytes length = ${rawBytes?.length ?? 0}');
      final card = CardModel(
        id: cardId,
        title: draft.title,
        type: draft.type,
        subType: draft.subType,
        rawText: draft.rawText,
        value: draft.value,
        date: draft.date,
        fields: allFields,
        tags: List<String>.from(draft.tags),
        filePath: draft.filePath,
        mimeType: draft.mimeType,
        sourceDocumentId: draft.filePath != null ? docId : null,
      );
      await _cardDao.insert(card);
      debugPrint('[SAVE] ✓ Fiche insérée en base de données');

      if (draft.filePath != null) {
        debugPrint('[SAVE] Sauvegarde document lié ($docId)');
        final doc = Document(
          id: docId,
          title: draft.title,
          filePath: draft.filePath,
          mimeType: draft.mimeType,
          ocrText: draft.rawText,
          sourceData: sourceData,
          documentDate: draft.date,
        );
        await _documentDao.insert(doc);
        debugPrint('[SAVE] ✓ Document lié inséré');

        // Verify: re-read immediately after insert
        final verifyDoc = await _documentDao.getById(docId);
        if (verifyDoc != null) {
          debugPrint('[VERIFY SAVE] sourceData length = ${verifyDoc.sourceData?.length ?? 0}');
          debugPrint('[VERIFY SAVE] bytes length = ${verifyDoc.decodedSourceData?.length ?? 0}');
        } else {
          debugPrint('[VERIFY SAVE] ⚠ Document NOT FOUND after insert!');
        }

        debugPrint('[SOURCE] documentPath=${draft.filePath}');
        debugPrint('[SOURCE] documentUrl=${draft.filePath}');
        debugPrint('[SOURCE] attachmentId=$docId');
      }

      debugPrint('[SAVE] Rechargement liste fiches');
      await loadCards();
      debugPrint('[SAVE] ═══════════════════════════════════════════════════════════');
      debugPrint('[SAVE] Fin sauvegarde — ${allFields.length} champ(s) sauvegardé(s)');
      debugPrint('[SAVE] ═══════════════════════════════════════════════════════════');
      return card;
    } catch (e) {
      _error = 'Erreur finalisation: $e';
      debugPrint('[SAVE] ❌ Erreur finalisation: $e');
      notifyListeners();
      return null;
    }
  }

  Future<CardModel?> processDocument({
    required String title,
    required String ocrText,
    String? filePath,
    String? mimeType,
    DateTime? documentDate,
  }) async {
    _error = null;
    try {
      final card = await _pipeline.processDocument(
        title: title,
        ocrText: ocrText,
        filePath: filePath,
        mimeType: mimeType,
        documentDate: documentDate,
      );
      await loadCards();
      return card;
    } catch (e) {
      _error = 'Erreur traitement document: $e';
      notifyListeners();
      return null;
    }
  }

  Future<AnswerResult> ask(String question) async {
    _isAnswering = true;
    _error = null;
    notifyListeners();

    try {
      _lastAnswer = await _qa.answer(question);
    } catch (e) {
      _error = 'Erreur réponse: $e';
      _lastAnswer = AnswerResult(
        answerText: 'Désolé, je n\'ai pas pu traiter votre question.',
        confidence: 'Faible',
      );
    }

    _isAnswering = false;
    notifyListeners();
    return _lastAnswer!;
  }

  Future<void> selectCard(String id) async {
    try {
      _selectedCard = await _cardDao.getById(id);
    } catch (e) {
      _error = 'Erreur sélection: $e';
    }
    notifyListeners();
  }

  Future<void> deleteCard(String id) async {
    try {
      await _cardDao.delete(id);
      await loadCards();
    } catch (e) {
      _error = 'Erreur suppression: $e';
      notifyListeners();
    }
  }

  Future<List<CardModel>> search(String query) async {
    try {
      return await _cardDao.search(query);
    } catch (e) {
      _error = 'Erreur recherche: $e';
      return [];
    }
  }

  /// Convert a raw Map<String, dynamic> (from AI) to Map<String, TypedField>
  Map<String, TypedField> _convertToTypedFields(Map<String, dynamic> raw) {
    return TypedField.fromLegacyMap(raw);
  }
}
