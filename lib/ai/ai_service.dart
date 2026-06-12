import '../models/card_model.dart';
import 'extraction_candidate.dart';

class AnalysisResult {
  final CardType type;
  final String subType;
  final String title;
  final String? value;
  final DateTime? date;
  final Map<String, dynamic> fields;
  final List<String> tags;
  final List<ExtractionCandidate> candidates;
  final Map<String, String> detectedEntities;
  final List<String> suggestedFields;

  AnalysisResult({
    required this.type,
    required this.subType,
    required this.title,
    this.value,
    this.date,
    this.fields = const {},
    this.tags = const [],
    this.candidates = const [],
    this.detectedEntities = const {},
    this.suggestedFields = const [],
  });
}

class AnswerResult {
  final String answerText;
  final String confidence;
  final String? sourceCardId;
  final String? sourceTitle;
  final String? extractedValue;
  final String? justification;
  final List<String> sourceCardIds;
  final List<String> sourceTitles;

  AnswerResult({
    required this.answerText,
    required this.confidence,
    this.sourceCardId,
    this.sourceTitle,
    this.extractedValue,
    this.justification,
    List<String>? sourceCardIds,
    List<String>? sourceTitles,
  })  : sourceCardIds = sourceCardIds ?? (sourceCardId != null ? [sourceCardId] : []),
        sourceTitles = sourceTitles ?? (sourceTitle != null ? [sourceTitle] : []);
}

abstract class AIService {
  Future<AnalysisResult> analyzeContent(String rawText, {List<Map<String, dynamic>> analyticalData = const []});
  Future<List<String>> generateTags(String rawText, CardType type, String subType);
  Future<Map<String, dynamic>> extractFields(String rawText, CardType type, String subType);
  Future<String> generateTitle(String rawText, CardType type, String subType);
  Future<AnswerResult> answerQuestion(
    String question, 
    List<CardModel> cards, {
    List<Map<String, dynamic>> analyticalData = const [],
  });
}
