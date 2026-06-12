class AnalyzedQuestion {
  final String intent;
  final String subject;
  final String? targetName;
  final String rawQuery;
  final bool isPlural;
  final String? groupType;

  AnalyzedQuestion({
    required this.intent,
    required this.subject,
    this.targetName,
    required this.rawQuery,
    this.isPlural = false,
    this.groupType,
  });
}

class QuestionAnalyzer {
  static final Map<String, List<String>> _intentPatterns = {
    'social_security': [
      'sécurité sociale', 'sécu', 'securite sociale', 'numéro de sécu',
      'n° sécu', 'numero securite', 'carte vitale',
    ],
    'phone': [
      'téléphone', 'telephone', 'portable', 'tel', 'numéro de tel',
      'n° tel', 'mobile',
    ],
    'email': [
      'email', 'e-mail', 'mail', 'courriel', 'adresse mail',
      'adresse email',
    ],
    'address': [
      'adresse', 'domicile', 'habite', 'résidence', 'réside',
    ],
    'iban': [
      'iban', 'rib', 'compte bancaire', 'relevé bancaire',
    ],
    'contract': [
      'contrat', 'numéro de contrat', 'n° contrat', 'police',
    ],
    'birth_date': [
      'date de naissance', 'né le', 'née le', 'anniversaire',
    ],
  };

  static final Map<String, String> _subjectPronouns = {
    'mon': 'Moi',
    'ma': 'Moi',
    'mes': 'Moi',
    'moi': 'Moi',
    'je': 'Moi',
    'm\'': 'Moi',
  };

  static final Map<String, String> _groupPatterns = {
    'mes enfants': 'enfant',
    'mes fils': 'enfant',
    'mes filles': 'enfant',
    'mes frères': 'fratrie',
    'mes soeurs': 'fratrie',
    'mes parents': 'parent',
  };

  AnalyzedQuestion analyze(String query) {
    final lower = query.toLowerCase().trim();

    String intent = 'general';
    for (final entry in _intentPatterns.entries) {
      if (entry.value.any((p) => lower.contains(p))) {
        intent = entry.key;
        break;
      }
    }

    String subject = 'Moi';
    String? targetName;
    bool isPlural = false;
    String? groupType;

    for (final entry in _subjectPronouns.entries) {
      if (lower.contains(entry.key)) {
        subject = entry.value;
        break;
      }
    }

    // Détecter les groupes
    for (final entry in _groupPatterns.entries) {
      if (lower.contains(entry.key)) {
        isPlural = true;
        groupType = entry.value;
        subject = 'Groupe';
        targetName = entry.key;
        print('[QUERY] Groupe détecté: "${entry.key}" → type: ${entry.value}');
        break;
      }
    }

    if (lower.contains('ma femme') || lower.contains('mon épouse') || lower.contains('ma conjointe') || lower.contains('mon époux')) {
      subject = 'Conjoint';
      targetName = 'ma femme';
    } else if (!isPlural && (lower.contains('mon enfant') || lower.contains('mes enfants') || lower.contains('ma fille') || lower.contains('mon fils'))) {
      subject = 'Enfant';
      targetName = _extractNameAfter(lower, ['mon enfant', 'ma fille', 'mon fils', 'mes enfants']);
      if (lower.contains('mes enfants')) {
        isPlural = true;
        groupType = 'enfant';
      }
    }

    final nameMatch = RegExp(r'(?:de|pour|à)\s+(\p{L}+(?:\s+\p{L}+)?)', unicode: true).firstMatch(lower);
    if (nameMatch != null && subject == 'Moi') {
      targetName = nameMatch.group(1);
    }

    return AnalyzedQuestion(
      intent: intent,
      subject: subject,
      targetName: targetName,
      rawQuery: query,
      isPlural: isPlural,
      groupType: groupType,
    );
  }

  String? _extractNameAfter(String text, List<String> triggers) {
    for (final trigger in triggers) {
      final idx = text.indexOf(trigger);
      if (idx >= 0) {
        final after = text.substring(idx + trigger.length).trim();
        final words = after.split(RegExp(r'\s+'));
        if (words.isNotEmpty && !words.first.contains(RegExp(r'^(est|le|la|de|du|des)$'))) {
          return words.first;
        }
      }
    }
    return null;
  }

  static String intentLabel(String intent) {
    switch (intent) {
      case 'social_security':
        return 'numéro de sécurité sociale';
      case 'phone':
        return 'numéro de téléphone';
      case 'email':
        return 'adresse email';
      case 'address':
        return 'adresse';
      case 'iban':
        return 'IBAN';
      case 'contract':
        return 'numéro de contrat';
      case 'birth_date':
        return 'date de naissance';
      default:
        return 'information';
    }
  }
}
