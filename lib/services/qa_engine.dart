import '../ai/ai_service.dart';
import '../ai/fallback_ai_service.dart';
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
    
    return await _ai.answerQuestion(
      question, 
      allCards,
      analyticalData: _buildAnalyticalData(analyticalFields, analyticalValues),
    );
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
