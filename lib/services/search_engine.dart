import '../models/document.dart';
import '../database/daos/document_dao.dart';

class SearchResult {
  final Document document;
  final String relevance;
  final String justification;

  SearchResult({
    required this.document,
    required this.relevance,
    required this.justification,
  });
}

class SearchEngine {
  final DocumentDao _documentDao = DocumentDao();

  Future<List<SearchResult>> search(String query) async {
    final results = <SearchResult>[];
    final lowerQuery = query.toLowerCase();

    final filters = _parseNaturalLanguage(lowerQuery);
    final documents = await _documentDao.getAll();

    for (final doc in documents) {
      final score = _scoreDocument(doc, lowerQuery, filters);
      if (score > 0) {
        results.add(SearchResult(
          document: doc,
          relevance: score > 5
              ? 'Fort'
              : score > 2
                  ? 'Moyen'
                  : 'Faible',
          justification: _buildJustification(doc, lowerQuery, filters),
        ));
      }
    }

    results.sort((a, b) => _relevanceWeight(b.relevance) - _relevanceWeight(a.relevance));
    return results;
  }

  Future<List<SearchResult>> searchByFilters({
    String? type,
    String? domain,
    String? subdomain,
    String? status,
    int? year,
    String? entityName,
  }) async {
    final results = <SearchResult>[];
    final documents = await _documentDao.getAll();

    for (final doc in documents) {
      final docTags = await _documentDao.getTagsForDocument(doc.id);
      final tagLabels = docTags.map((t) => t['label']?.toString().toLowerCase() ?? '').toSet();

      bool matches = true;

      if (type != null && !tagLabels.contains(type.toLowerCase())) matches = false;
      if (domain != null && !tagLabels.contains(domain.toLowerCase())) matches = false;
      if (subdomain != null && !tagLabels.contains(subdomain.toLowerCase())) matches = false;
      if (status != null && !tagLabels.contains(status.toLowerCase())) matches = false;
      if (year != null) {
        if (doc.documentDate == null || doc.documentDate!.year != year) {
          if (doc.createdAt.year != year) matches = false;
        }
      }

      if (matches) {
        results.add(SearchResult(
          document: doc,
          relevance: 'Fort',
          justification: 'Correspond aux filtres sélectionnés',
        ));
      }
    }

    return results;
  }

  int _scoreDocument(Document doc, String query, Map<String, String> filters) {
    final text = '${doc.title} ${doc.ocrText ?? ''}'.toLowerCase();
    int score = 0;

    for (final keyword in query.split(RegExp(r'\s+'))) {
      if (keyword.length < 3) continue;
      if (text.contains(keyword)) score++;
    }

    if (filters.containsKey('type') && text.contains(filters['type']!)) score += 3;
    if (filters.containsKey('domaine') && text.contains(filters['domaine']!)) score += 2;
    if (filters.containsKey('annee')) {
      final yearStr = filters['annee']!;
      if (text.contains(yearStr)) score += 2;
    }

    return score;
  }

  String _buildJustification(Document doc, String query, Map<String, String> filters) {
    final parts = <String>[];
    if (filters.containsKey('type')) parts.add('Type: ${filters['type']}');
    if (filters.containsKey('domaine')) parts.add('Domaine: ${filters['domaine']}');
    if (filters.containsKey('annee')) parts.add('Année: ${filters['annee']}');
    if (parts.isEmpty) parts.add('Contient les termes recherchés');
    return parts.join(', ');
  }

  Map<String, String> _parseNaturalLanguage(String query) {
    final filters = <String, String>{};

    final typePatterns = ['facture', 'contrat', 'attestation', 'bulletin', 'courrier', 'identité'];
    for (final t in typePatterns) {
      if (query.contains(t)) {
        filters['type'] = t;
        break;
      }
    }

    final domainPatterns = {
      'automobile': ['auto', 'automobile', 'véhicule', 'voiture'],
      'habitation': ['logement', 'habitation', 'maison', 'appartement'],
      'santé': ['santé', 'médical', 'mutuelle'],
      'banque': ['banque', 'compte', 'rib'],
      'fiscalité': ['impôt', 'fiscal', 'déclaration'],
      'travail': ['travail', 'salaire', 'emploi'],
    };
    for (final entry in domainPatterns.entries) {
      if (entry.value.any((w) => query.contains(w))) {
        filters['domaine'] = entry.key;
        break;
      }
    }

    final yearMatch = RegExp(r'\b(20\d{2})\b').firstMatch(query);
    if (yearMatch != null) {
      filters['annee'] = yearMatch.group(1)!;
    }

    final statusPatterns = ['actif', 'expiré', 'résilié'];
    for (final s in statusPatterns) {
      if (query.contains(s)) {
        filters['statut'] = s;
        break;
      }
    }

    return filters;
  }

  int _relevanceWeight(String relevance) {
    switch (relevance) {
      case 'Fort':
        return 3;
      case 'Moyen':
        return 2;
      default:
        return 1;
    }
  }
}
