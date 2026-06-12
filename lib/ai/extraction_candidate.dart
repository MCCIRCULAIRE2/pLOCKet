/// Generic candidate for extracted field values with scoring.
class ExtractionCandidate {
  final String id;
  final String value;
  final double numericValue;
  final String label;
  final String category;
  final int lineIndex;
  final String sourceLine;
  final int score;
  final String reason;
  final Map<String, dynamic> metadata;

  ExtractionCandidate({
    required this.id,
    required this.value,
    required this.numericValue,
    required this.label,
    required this.category,
    this.lineIndex = -1,
    this.sourceLine = '',
    this.score = 0,
    this.reason = '',
    this.metadata = const {},
  });

  @override
  String toString() =>
      '[CANDIDATE] valeur=$value  label="$label"  score=$score  raison=$reason\n'
      '           ligne="${sourceLine.length > 80 ? '${sourceLine.substring(0, 80)}...' : sourceLine}"';
}

/// Classification métier d'une ligne contenant un nombre.
enum LigneCategorie {
  montantTotal,
  sousTotal,
  resteAPayer,
  acompte,
  tva,
  numeroFacture,
  numeroCheque,
  telephone,
  codePostal,
  siret,
  date,
  quantite,
  page,
  ligneTableau,
  inconnu,
}

/// Résultat de l'analyse métier d'une ligne.
class AnalyseLigne {
  final LigneCategorie categorie;
  final int score;
  final String motCle;
  final List<String> logs;

  AnalyseLigne({
    required this.categorie,
    required this.score,
    required this.motCle,
    required this.logs,
  });

  bool get estExclu => score < 0;
}

/// Moteur de scoring métier pour l'extraction des montants.
class MontantScorer {
  // ─── Mots-clés classés par catégorie métier ─────────────────────────────────

  static const Map<String, int> _motsClesTotal = {
    'montant total en euro': 100,
    'montant total en euros': 100,
    'montant total': 98,
    'total ttc': 97,
    'total à payer': 97,
    'total a payer': 97,
    'montant à payer': 96,
    'montant a payer': 96,
    'montant dû': 96,
    'montant du': 96,
    'net à payer': 95,
    'net a payer': 95,
    'total facture': 95,
    'total général': 95,
    'total general': 95,
    'total en euro': 94,
    'total en euros': 94,
    'somme due': 90,
    'montant global': 90,
    'total': 50,
    'montant': 30,
  };

  static const Map<String, int> _motsClesReste = {
    'montant restant dû': 80,
    'montant restant du': 80,
    'reste à payer': 75,
    'reste a payer': 75,
    'reste dû': 75,
    'reste du': 75,
    'solde restant': 72,
    'solde à payer': 70,
    'solde a payer': 70,
    'reliquat': 68,
    'solde': 65,
  };

  static const Map<String, int> _motsClesAcompte = {
    'acompte': 50,
    'accompte': 50,
    'versement': 48,
    'déjà réglé': 48,
    'deja regle': 48,
    'déjà versé': 48,
    'deja verse': 48,
    'déjà payé': 48,
    'deja paye': 48,
    'paiement effectué': 46,
    'avance': 45,
    'règlement': 45,
    'reglement': 45,
  };

  static const Map<String, int> _motsClesSousTotal = {
    'sous-total': 25,
    'sous total': 25,
    'total ht': 20,
    'total h.t': 20,
    'total h.t.': 20,
  };

  // ─── Patterns d'exclusion (ne sont PAS des montants) ────────────────────────

  static const List<String> _patternsExclusion = [
    'facture n°', 'facture n', 'n° facture', 'n° de facture',
    'numéro de facture', 'numero de facture', 'num facture',
    'chèque n°', 'cheque n', 'n° chèque',
    'tva intracommunautaire', 'tva intra',
    'code postal', 'siret', 'siren', 'iban', 'rib',
    'tél', 'fax', 'mobile',
    'page', 'pages',
    'quantité', 'qte', 'qté',
    'superficie', 'surface', 'm²', 'm2',
    'kg', 'cm', 'mm', 'm3',
    'adresse', 'rue ', 'avenue', 'boulevard', 'route', 'chemin',
    'impasse', 'allée', 'place', 'square', 'lotissement',
  ];

  // ─── Méthode principale : analyse complète d'une ligne ──────────────────────

  static AnalyseLigne analyser(String ligneLower, String nombreBrut) {
    final logs = <String>[];
    logs.add('[ANALYSE] Ligne: "$ligneLower"');
    logs.add('[ANALYSE] Nombre: $nombreBrut');

    // Étape 1 : Vérifier les exclusions fortes
    for (final pattern in _patternsExclusion) {
      if (ligneLower.contains(pattern)) {
        logs.add('[ANALYSE] ❌ EXCLU — pattern "$pattern" détecté');
        return AnalyseLigne(
          categorie: _categoriserExclusion(pattern),
          score: -999,
          motCle: pattern,
          logs: logs,
        );
      }
    }

    // Étape 2 : Vérifier les patterns numériques exclus (code postal, téléphone, siret)
    final exclusionNum = _verifierExclusionNumerique(nombreBrut, ligneLower);
    if (exclusionNum != null) {
      logs.add('[ANALYSE] ❌ EXCLU — $exclusionNum');
      return AnalyseLigne(
        categorie: _categoriserExclusion(exclusionNum),
        score: -999,
        motCle: exclusionNum,
        logs: logs,
      );
    }

    // Étape 3 : Vérifier si c'est une ligne TVA
    if (ligneLower.contains('tva') || ligneLower.contains('taxe')) {
      logs.add('[ANALYSE] ❌ EXCLU — ligne TVA/taxe');
      return AnalyseLigne(
        categorie: LigneCategorie.tva,
        score: -500,
        motCle: 'tva',
        logs: logs,
      );
    }

    // Étape 4 : Classifier par catégorie métier (ordre de priorité)

    // 4a — Montant total (AVANT reste car "montant total en euro" doit être prioritaire)
    String? meilleurMotCle;
    int meilleurScore = 0;
    for (final entry in _motsClesTotal.entries) {
      if (ligneLower.contains(entry.key) && entry.key.length > (meilleurMotCle?.length ?? 0)) {
        meilleurMotCle = entry.key;
        meilleurScore = entry.value;
      }
    }
    if (meilleurMotCle != null) {
      logs.add('[ANALYSE] ✓ Catégorie: montant_total — mot-clé "$meilleurMotCle" → score $meilleurScore');
      return AnalyseLigne(
        categorie: LigneCategorie.montantTotal,
        score: meilleurScore,
        motCle: meilleurMotCle,
        logs: logs,
      );
    }

    // 4b — Reste à payer
    meilleurMotCle = null;
    meilleurScore = 0;
    for (final entry in _motsClesReste.entries) {
      if (ligneLower.contains(entry.key) && entry.key.length > (meilleurMotCle?.length ?? 0)) {
        meilleurMotCle = entry.key;
        meilleurScore = entry.value;
      }
    }
    if (meilleurMotCle != null) {
      logs.add('[ANALYSE] ✓ Catégorie: reste_a_payer — mot-clé "$meilleurMotCle" → score $meilleurScore');
      return AnalyseLigne(
        categorie: LigneCategorie.resteAPayer,
        score: meilleurScore,
        motCle: meilleurMotCle,
        logs: logs,
      );
    }

    // 4c — Acompte
    meilleurMotCle = null;
    meilleurScore = 0;
    for (final entry in _motsClesAcompte.entries) {
      if (ligneLower.contains(entry.key) && entry.key.length > (meilleurMotCle?.length ?? 0)) {
        meilleurMotCle = entry.key;
        meilleurScore = entry.value;
      }
    }
    if (meilleurMotCle != null) {
      logs.add('[ANALYSE] ✓ Catégorie: acompte — mot-clé "$meilleurMotCle" → score $meilleurScore');
      return AnalyseLigne(
        categorie: LigneCategorie.acompte,
        score: meilleurScore,
        motCle: meilleurMotCle,
        logs: logs,
      );
    }

    // 4d — Sous-total
    meilleurMotCle = null;
    meilleurScore = 0;
    for (final entry in _motsClesSousTotal.entries) {
      if (ligneLower.contains(entry.key) && entry.key.length > (meilleurMotCle?.length ?? 0)) {
        meilleurMotCle = entry.key;
        meilleurScore = entry.value;
      }
    }
    if (meilleurMotCle != null) {
      logs.add('[ANALYSE] ✓ Catégorie: sous_total — mot-clé "$meilleurMotCle" → score $meilleurScore');
      return AnalyseLigne(
        categorie: LigneCategorie.sousTotal,
        score: meilleurScore,
        motCle: meilleurMotCle,
        logs: logs,
      );
    }

    // Étape 5 : Pas de mot-clé métier → ligne de tableau ou inconnu
    final aSymboleEuro = ligneLower.contains('€') || ligneLower.contains('euro');
    if (aSymboleEuro) {
      logs.add('[ANALYSE] ✓ Catégorie: ligne_tableau — symbole € présent → score 8');
      return AnalyseLigne(
        categorie: LigneCategorie.ligneTableau,
        score: 8,
        motCle: 'symbole_euro',
        logs: logs,
      );
    }

    logs.add('[ANALYSE] ✓ Catégorie: inconnu — aucun mot-clé ni € → score 3');
    return AnalyseLigne(
      categorie: LigneCategorie.inconnu,
      score: 3,
      motCle: 'aucun',
      logs: logs,
    );
  }

  // ─── Vérification des exclusions numériques ─────────────────────────────────

  static String? _verifierExclusionNumerique(String nombre, String ligneLower) {
    final chiffres = nombre.replaceAll(RegExp(r'[^\d]'), '');

    // Code postal : exactement 5 chiffres, souvent suivi d'une ville
    if (chiffres.length == 5 && RegExp(r'\b\d{5}\s+[A-ZÀ-Ÿ]').hasMatch(ligneLower)) {
      return 'code_postal';
    }

    // Téléphone : 10 chiffres ou plus
    if (chiffres.length >= 10) {
      return 'telephone';
    }

    // SIRET : 14 chiffres
    if (chiffres.length == 14) {
      return 'siret';
    }

    // SIREN : 9 chiffres
    if (chiffres.length == 9 && !ligneLower.contains('€') && !ligneLower.contains('euro')) {
      return 'siret';
    }

    return null;
  }

  // ─── Catégorisation des exclusions ──────────────────────────────────────────

  static LigneCategorie _categoriserExclusion(String pattern) {
    if (pattern.contains('facture') || pattern.contains('numéro') || pattern.contains('numero')) {
      return LigneCategorie.numeroFacture;
    }
    if (pattern.contains('chèque') || pattern.contains('cheque')) {
      return LigneCategorie.numeroCheque;
    }
    if (pattern.contains('code postal')) return LigneCategorie.codePostal;
    if (pattern.contains('tél') || pattern.contains('tel') || pattern.contains('fax') || pattern.contains('mobile')) {
      return LigneCategorie.telephone;
    }
    if (pattern.contains('siret') || pattern.contains('siren')) return LigneCategorie.siret;
    if (pattern.contains('page')) return LigneCategorie.page;
    if (pattern.contains('quantité') || pattern.contains('qte') || pattern.contains('qté')) {
      return LigneCategorie.quantite;
    }
    return LigneCategorie.inconnu;
  }

  // ─── Compatibilité ascendante ───────────────────────────────────────────────

  static int score(String lowerLine) {
    final analyse = analyser(lowerLine, '');
    return analyse.score;
  }

  static String reason(String lowerLine) {
    final analyse = analyser(lowerLine, '');
    return analyse.motCle;
  }
}

/// Scorer for address extraction.
class AddressScorer {
  static int score(String street) {
    if (street.length < 6) return 0;
    if (street.length > 100) return 30;
    return 50;
  }

  static String reason(String street) {
    return 'adresse_structuree';
  }
}
