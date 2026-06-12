import '../models/document.dart';
import '../database/daos/document_dao.dart';
import 'search_engine.dart';
import 'question_analyzer.dart';
import 'data_extraction_service.dart';

class AnswerResult {
  final String answerText;
  final String confidence;
  final Document? sourceDocument;
  final String? extractedValue;
  final String? justification;

  AnswerResult({
    required this.answerText,
    required this.confidence,
    this.sourceDocument,
    this.extractedValue,
    this.justification,
  });
}

class IntelligentSearch {
  final DocumentDao _documentDao = DocumentDao();
  final SearchEngine _searchEngine = SearchEngine();
  final QuestionAnalyzer _analyzer = QuestionAnalyzer();
  final DataExtractionService _extractor = DataExtractionService();

  Future<List<AnswerResult>> search(String query) async {
    final analyzed = _analyzer.analyze(query);

    if (analyzed.intent == 'general') {
      return _fallbackSearch(query);
    }

    final docs = await _documentDao.getAll();
    final results = <AnswerResult>[];
    final fieldLabel = QuestionAnalyzer.intentLabel(analyzed.intent);

    for (final doc in docs) {
      final text = '${doc.title} ${doc.ocrText ?? ''}';
      final value = _extractSpecificValue(text, analyzed.intent);

      if (value != null) {
        results.add(AnswerResult(
          answerText: _formatAnswer(analyzed, value, fieldLabel),
          confidence: 'Fort',
          sourceDocument: doc,
          extractedValue: value,
          justification: 'Valeur trouvée dans : ${doc.title}',
        ));
      }
    }

    results.sort((a, b) => _confidenceScore(b.confidence) - _confidenceScore(a.confidence));

    if (results.isEmpty) {
      return _fallbackSearch(query);
    }

    return results;
  }

  String? _extractSpecificValue(String text, String intent) {
    final lower = text.toLowerCase();

    switch (intent) {
      case 'social_security':
        return _extractSocialSecurity(text);
      case 'phone':
        return _extractPhone(text);
      case 'email':
        return _extractEmail(text);
      case 'address':
        return _extractAddress(lower);
      case 'iban':
        return _extractIban(text);
      case 'contract':
        return _extractContract(text);
      case 'birth_date':
        return _extractDate(text);
      default:
        return null;
    }
  }

  String? _extractSocialSecurity(String text) {
    final ssnPattern = RegExp(r'(?:num[eé]ro\s+de\s+s[eé]curit[eé]\s+sociale|n[°o]\s*s[eé]cu|s[eé]curit[eé]\s+sociale)\s*(?:est\s+le\s+)?[:\s]*((?:\d[\s-]?){13,15}\d)', caseSensitive: false);
    final match = ssnPattern.firstMatch(text);
    if (match != null) {
      return match.group(1)!.replaceAll(RegExp(r'[\s-]'), '');
    }
    final digitsPattern = RegExp(r'\b((?:1|2)\s?\d{2}\s?\d{2}\s?\d{2}\s?\d{3}\s?\d{3}\s?\d{2})\b');
    final digitMatch = digitsPattern.firstMatch(text);
    if (digitMatch != null) {
      return digitMatch.group(1)!.replaceAll(RegExp(r'[\s-]'), '');
    }
    return null;
  }

  String? _extractPhone(String text) {
    final patterns = _extractor.extractAll(text);
    return patterns.phones.isNotEmpty ? patterns.phones.first : null;
  }

  String? _extractEmail(String text) {
    final patterns = _extractor.extractAll(text);
    return patterns.emails.isNotEmpty ? patterns.emails.first : null;
  }

  String? _extractAddress(String lower) {
    final addrPattern = RegExp(r'(?:adresse|habite?\s+au|r[ée]side)\s*(?:est\s+)?[:\s]*((?:\d+\s+)?(?:rue|avenue|boulevard|place|chemin|impasse|allée|route|lotissement)\s+[^,\n]+)', caseSensitive: false);
    final match = addrPattern.firstMatch(lower);
    if (match != null) return match.group(1)!.trim();

    final fullAddr = RegExp(r'\d{1,4}\s+(?:rue|avenue|boulevard|place|chemin|impasse|allée|route)\s+.+?(?:\d{5})', caseSensitive: false);
    final addrMatch = fullAddr.firstMatch(lower);
    return addrMatch?.group(0)?.trim();
  }

  String? _extractIban(String text) {
    final patterns = _extractor.extractAll(text);
    return patterns.ibans.isNotEmpty ? patterns.ibans.first : null;
  }

  String? _extractContract(String text) {
    final patterns = _extractor.extractAll(text);
    return patterns.contractNumbers.isNotEmpty ? patterns.contractNumbers.first : null;
  }

  String? _extractDate(String text) {
    final patterns = _extractor.extractAll(text);
    return patterns.dates.isNotEmpty ? patterns.dates.first : null;
  }

  String _formatAnswer(AnalyzedQuestion q, String value, String fieldLabel) {
    final prefix = _subjectPrefix(q.subject);
    return '$prefix $fieldLabel est le : $value';
  }

  String _subjectPrefix(String subject) {
    switch (subject) {
      case 'Moi':
        return 'Ton';
      case 'Conjoint':
        return 'Le';
      case 'Enfant':
        return "L'";
      default:
        return 'Le';
    }
  }

  Future<List<AnswerResult>> _fallbackSearch(String query) async {
    final results = await _searchEngine.search(query);
    return results.map((r) => AnswerResult(
      answerText: r.document.title,
      confidence: r.relevance,
      sourceDocument: r.document,
      justification: r.justification,
    )).toList();
  }

  int _confidenceScore(String confidence) {
    switch (confidence) {
      case 'Fort': return 3;
      case 'Moyen': return 2;
      default: return 1;
    }
  }
}
