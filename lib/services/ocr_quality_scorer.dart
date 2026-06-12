class OcrQualityResult {
  final double score;
  final String level;
  final List<String> warnings;
  final Map<String, dynamic> metrics;

  OcrQualityResult({
    required this.score,
    required this.level,
    required this.warnings,
    required this.metrics,
  });

  bool get isReliable => score >= 50;
  bool get isPoor => score < 30;
}

class OcrQualityScorer {
  static OcrQualityResult analyze(String text) {
    if (text.trim().isEmpty) {
      return OcrQualityResult(
        score: 0,
        level: 'vide',
        warnings: ['Aucun texte extrait'],
        metrics: {'length': 0},
      );
    }

    final warnings = <String>[];
    double score = 100;
    final metrics = <String, dynamic>{};

    final length = text.length;
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    metrics['length'] = length;
    metrics['lines'] = lines.length;
    metrics['words'] = words.length;

    if (length < 20) {
      score -= 50;
      warnings.add('Texte très court (${length} caractères)');
    } else if (length < 50) {
      score -= 30;
      warnings.add('Texte court (${length} caractères)');
    }

    final specialChars = RegExp(r'[^\w\sàâäéèêëïîôùûüÿçœæÀÂÄÉÈÊËÏÎÔÙÛÜŸÇŒÆ.,;:!?()\-/€%°&@+*=<>#|~^$]').allMatches(text);
    final specialRatio = length > 0 ? specialChars.length / length : 0;
    metrics['specialChars'] = specialChars.length;
    metrics['specialRatio'] = (specialRatio * 100).toStringAsFixed(1);

    if (specialRatio > 0.3) {
      score -= 40;
      warnings.add('Trop de caractères spéciaux (${(specialRatio * 100).toStringAsFixed(0)}%)');
    } else if (specialRatio > 0.15) {
      score -= 20;
      warnings.add('Caractères spéciaux élevés (${(specialRatio * 100).toStringAsFixed(0)}%)');
    }

    final singleCharWords = words.where((w) => w.length == 1 && !RegExp(r'[àâäéèêëïîôùûüÿçœæÀÂÄÉÈÊËÏÎÔÙÛÜŸÇŒÆ.,;:!?()\-/€%°&@+*=<>#|~^$]').hasMatch(w));
    final singleCharRatio = words.isNotEmpty ? singleCharWords.length / words.length : 0;
    metrics['singleCharWords'] = singleCharWords.length;

    if (singleCharRatio > 0.3) {
      score -= 30;
      warnings.add('Trop de mots d\'un seul caractère (${(singleCharRatio * 100).toStringAsFixed(0)}%)');
    }

    final consecutiveSpecials = RegExp(r'[^\w\s]{3,}').allMatches(text);
    if (consecutiveSpecials.length > 5) {
      score -= 20;
      warnings.add('Séquences de caractères incohérents détectées');
    }

    final frenchWords = ['le', 'la', 'les', 'de', 'du', 'des', 'un', 'une', 'et', 'ou', 'à', 'en', 'dans', 'sur', 'pour', 'par', 'avec', 'ce', 'cette', 'ces', 'mon', 'ton', 'son', 'notre', 'votre', 'leur', 'je', 'tu', 'il', 'elle', 'nous', 'vous', 'ils', 'elles', 'ne', 'pas', 'que', 'qui', 'quoi', 'dont', 'où', 'est', 'sont', 'a', 'ont', 'fait', 'être', 'avoir'];
    final textLower = text.toLowerCase();
    int frenchCount = 0;
    for (final word in frenchWords) {
      if (textLower.contains(RegExp('\\b$word\\b'))) frenchCount++;
    }
    final frenchRatio = frenchWords.length > 0 ? frenchCount / frenchWords.length : 0;
    metrics['frenchWords'] = frenchCount;
    metrics['frenchRatio'] = (frenchRatio * 100).toStringAsFixed(1);

    if (frenchRatio < 0.2 && words.length > 10) {
      score -= 25;
      warnings.add('Peu de mots français reconnus (${(frenchRatio * 100).toStringAsFixed(0)}%)');
    }

    final repeatedChars = RegExp(r'(.)\1{4,}').allMatches(text);
    if (repeatedChars.length > 2) {
      score -= 15;
      warnings.add('Caractères répétés anormalement');
    }

    score = score.clamp(0, 100);

    String level;
    if (score >= 80) {
      level = 'excellent';
    } else if (score >= 60) {
      level = 'bon';
    } else if (score >= 40) {
      level = 'moyen';
    } else if (score >= 20) {
      level = 'faible';
    } else {
      level = 'très faible';
    }

    return OcrQualityResult(
      score: score,
      level: level,
      warnings: warnings,
      metrics: metrics,
    );
  }
}
