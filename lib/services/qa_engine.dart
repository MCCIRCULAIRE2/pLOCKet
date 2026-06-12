import '../ai/ai_service.dart';
import '../ai/fallback_ai_service.dart';
import '../ai/semantic_relation_engine.dart';
import '../models/card_model.dart';
import '../models/analytical_field.dart';
import '../database/daos/card_dao.dart';
import '../database/daos/analytical_field_dao.dart';

class QaEngine {
  final AIService _ai;
  final CardDao _cardDao = CardDao();
  final AnalyticalFieldDao _analyticalFieldDao = AnalyticalFieldDao();

  QaEngine({AIService? ai}) : _ai = ai ?? FallbackAIService();

  Future<AnswerResult> answer(String question) async {
    final allCards = await _cardDao.getAll();
    if (allCards.isEmpty) {
      return AnswerResult(
        answerText: 'Vous n\'avez encore enregistré aucune information.',
        confidence: 'Faible',
      );
    }
    
    // Charger les référentiels analytiques
    final analyticalFields = await _analyticalFieldDao.getAllFields();
    final analyticalValues = await _analyticalFieldDao.getAllValues();
    
    print('[QA] ═══════════════════════════════════════════════════════════');
    print('[QA] Question: $question');
    print('[QA] Fiches disponibles: ${allCards.length}');
    print('[QA] Référentiels analytiques: ${analyticalFields.length}');
    print('[QA] Valeurs analytiques: ${analyticalValues.length}');
    print('[QA] ═══════════════════════════════════════════════════════════');
    
    // Utiliser le moteur de relations sémantiques
    final semanticResults = SemanticRelationEngine.findEntitiesBySemanticQuery(
      question,
      analyticalFields,
      analyticalValues,
    );
    
    if (semanticResults.isNotEmpty) {
      print('[QA] ${semanticResults.length} entité(s) trouvée(s) par relation sémantique');
      
      // Construire la réponse
      final answerText = _buildSemanticAnswer(question, semanticResults);
      
      return AnswerResult(
        answerText: answerText,
        confidence: 'Fort',
        values: semanticResults.map((v) => AnswerValue(
          label: v.label,
          value: v.label,
        )).toList(),
      );
    }
    
    return await _ai.answerQuestion(
      question, 
      allCards,
      analyticalData: _buildAnalyticalData(analyticalFields, analyticalValues),
    );
  }

  String _buildSemanticAnswer(String question, List<AnalyticalValue> results) {
    final questionLower = question.toLowerCase();
    
    // Déterminer le type d'information demandée
    String infoType = 'information';
    if (questionLower.contains('numéro de sécurité sociale') || questionLower.contains('numéro de sécu')) {
      infoType = 'numéro de sécurité sociale';
    } else if (questionLower.contains('adresse')) {
      infoType = 'adresse';
    } else if (questionLower.contains('téléphone') || questionLower.contains('téléphone')) {
      infoType = 'téléphone';
    } else if (questionLower.contains('email') || questionLower.contains('e-mail')) {
      infoType = 'email';
    }
    
    final buffer = StringBuffer();
    buffer.writeln('${results.length} résultat(s) trouvé(s) :\n');
    
    for (final result in results) {
      buffer.writeln('• ${result.label}');
    }
    
    return buffer.toString();
  }

  Future<List<CardModel>> searchCards(String query) async {
    final results = await _cardDao.search(query);
    return results;
  }
  
  List<Map<String, dynamic>> _buildAnalyticalData(
    List<AnalyticalField> fields,
    List<AnalyticalValue> values,
  ) {
    final data = <Map<String, dynamic>>[];
    
    for (final field in fields) {
      final fieldValues = values.where((v) => v.fieldId == field.id).toList();
      data.add({
        'name': field.name,
        'values': fieldValues.map((v) => {
          'label': v.label,
          'aliases': v.aliases,
        }).toList(),
      });
    }
    
    return data;
  }
}
