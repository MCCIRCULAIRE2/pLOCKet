import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../ai/ai_service.dart';
import '../ai/fallback_ai_service.dart';
import '../models/card_model.dart';
import '../database/daos/card_dao.dart';
import '../database/daos/document_dao.dart';
import '../models/document.dart';
import 'step_logger.dart';

class ContentPipeline {
  final AIService _ai;
  final CardDao _cardDao = CardDao();
  final DocumentDao _documentDao = DocumentDao();
  final Uuid _uuid = Uuid();

  ContentPipeline({AIService? ai}) : _ai = ai ?? FallbackAIService();

  Future<CardModel> processText(String rawText,
      {String? filePath, String? mimeType}) async {
    final sw6 = Stopwatch()..start();
    debugPrint('[PIPELINE] ÉTAPE 6 - Analyse contenu : début (${rawText.length} car.)');
    final analysis = await _ai.analyzeContent(rawText);
    StepLogger.log('ÉTAPE 6 - Analyse contenu', true, sw6.elapsedMilliseconds,
        error: 'type=${analysis.type} subType=${analysis.subType}');

    StepLogger.log('ÉTAPE 7 - Classification', true, 0,
        error: '${analysis.type} / ${analysis.subType}');

    final sw8 = Stopwatch()..start();
    final fields = await _ai.extractFields(rawText, analysis.type, analysis.subType);

    final allFields = {
      ...analysis.fields,
      ...fields,
    };

    final card = CardModel(
      id: _uuid.v4(),
      title: analysis.title,
      type: analysis.type,
      subType: analysis.subType,
      rawText: rawText,
      value: analysis.value,
      date: analysis.date,
      fields: allFields,
      tags: _enrichTags(analysis.tags, analysis.type, analysis.subType, analysis.value),
      filePath: filePath,
      mimeType: mimeType,
    );
    StepLogger.log('ÉTAPE 8 - Création fiche', true, sw8.elapsedMilliseconds,
        error: 'id=${card.id} title=${card.title}');

    final sw9 = Stopwatch()..start();
    await _cardDao.insert(card);
    debugPrint('[PIPELINE] ÉTAPE 9 - Sauvegarde fiche : SUCCÈS [${sw9.elapsedMilliseconds}ms]');

    if (filePath != null) {
      await _createLinkedDocument(card, rawText, filePath, mimeType);
    }

    return card;
  }

  /// Analyze text without persisting. Returns the AnalysisResult.
  Future<AnalysisResult> analyzeOnly(String rawText) async {
    final analysis = await _ai.analyzeContent(rawText);
    return analysis;
  }

  /// Extract fields without persisting.
  Future<Map<String, dynamic>> extractFieldsOnly(String rawText, CardType type, String subType) async {
    return await _ai.extractFields(rawText, type, subType);
  }

  Future<CardModel> processDocument({
    required String title,
    required String ocrText,
    String? filePath,
    String? mimeType,
    DateTime? documentDate,
  }) async {
    final sw6 = Stopwatch()..start();
    debugPrint('[PIPELINE] ÉTAPE 6 - Analyse contenu : début (${ocrText.length} car.)');
    final analysis = await _ai.analyzeContent(ocrText);
    StepLogger.log('ÉTAPE 6 - Analyse contenu', true, sw6.elapsedMilliseconds,
        error: 'type=${analysis.type} subType=${analysis.subType}');

    StepLogger.log('ÉTAPE 7 - Classification', true, 0,
        error: '${analysis.type} / ${analysis.subType}');

    final sw8 = Stopwatch()..start();
    final fields = await _ai.extractFields(ocrText, analysis.type, analysis.subType);
    final aiTitle = analysis.title != 'Information' ? analysis.title : title;

    final card = CardModel(
      id: _uuid.v4(),
      title: '$aiTitle - $title',
      type: analysis.type == CardType.information ? CardType.document : analysis.type,
      subType: analysis.subType,
      rawText: ocrText,
      value: analysis.value,
      date: documentDate ?? analysis.date,
      fields: fields,
      tags: analysis.tags,
      filePath: filePath,
      mimeType: mimeType,
    );
    StepLogger.log('ÉTAPE 8 - Création fiche', true, sw8.elapsedMilliseconds,
        error: 'id=${card.id} title=${card.title}');

    final sw9 = Stopwatch()..start();
    await _cardDao.insert(card);
    debugPrint('[PIPELINE] ÉTAPE 9 - Sauvegarde fiche : SUCCÈS [${sw9.elapsedMilliseconds}ms]');

    final swDoc = Stopwatch()..start();
    final doc = Document(
      id: _uuid.v4(),
      title: title,
      filePath: filePath,
      mimeType: mimeType,
      ocrText: ocrText,
      documentDate: documentDate,
    );
    await _documentDao.insert(doc);
    debugPrint('[PIPELINE] ÉTAPE 9 - Sauvegarde document lié : SUCCÈS [${swDoc.elapsedMilliseconds}ms]');

    return card;
  }

  Future<void> _createLinkedDocument(
      CardModel card, String rawText, String filePath, String? mimeType) async {
    final doc = Document(
      id: _uuid.v4(),
      title: card.title,
      filePath: filePath,
      mimeType: mimeType,
      ocrText: rawText,
    );
    await _documentDao.insert(doc);
  }

  List<String> _enrichTags(
      List<String> baseTags, CardType type, String subType, String? value) {
    final tags = List<String>.from(baseTags);

    switch (type) {
      case CardType.information:
        tags.add('information');
        if (subType != 'general') tags.add(subType.replaceAll('_', ' '));
        break;
      case CardType.event:
        tags.add('événement');
        break;
      case CardType.document:
        tags.add('document');
        break;
    }

    return tags.toSet().toList();
  }
}
