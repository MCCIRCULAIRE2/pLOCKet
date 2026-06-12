import '../models/card_model.dart';
import '../services/question_analyzer.dart';
import 'ai_service.dart';
import 'extraction_candidate.dart';

class _Address {
  final String street;
  final String? postalCode;
  final String? city;
  String get full => postalCode != null && city != null
      ? '$street, $postalCode $city'
      : street;
  _Address(this.street, this.postalCode, this.city);
}

class FallbackAIService implements AIService {
  static final Map<String, List<String>> _documentPatterns = {
    'facture': ['facture', 'invoice', 'devis', 'quote', 'estimate'],
    'courrier': ['courrier', 'lettre', 'letter', 'objet', 'réf'],
    'contrat': ['contrat', 'contract', 'convention'],
    'formulaire': ['formulaire', 'form', 'cerfa'],
  };

  static final Map<String, String> _documentLabels = {
    'facture': 'Facture',
    'courrier': 'Courrier',
    'contrat': 'Contrat',
    'formulaire': 'Formulaire',
  };

  static final Map<String, List<String>> _typePatterns = {
    'numero_securite_sociale': [
      'sécurité sociale', 'sécu', 'securite sociale', 'numéro de sécu',
      'n° sécu', 'numero securite',
    ],
    'telephone': ['téléphone', 'telephone', 'portable', 'mobile', 'numéro de tel', 'n° tel'],
    'email': ['email', 'e-mail', 'mail', 'courriel', 'adresse mail', 'adresse email'],
    'adresse': ['adresse', 'habite', 'habite au', 'domicile', 'résidence', 'réside'],
    'iban': ['iban', 'rib', 'compte bancaire', 'relevé bancaire'],
    'date_naissance': ['date de naissance', 'né le', 'née le', 'anniversaire'],
    'numero_passeport': ['passeport', 'numéro de passeport', 'n° passeport'],
    'numero_permis': ['permis de conduire', 'numéro de permis', 'n° permis'],
  };

  static final Map<String, List<String>> _eventPatterns = {
    'controle_technique': ['contrôle technique', 'controle technique'],
    'revision': ['révision', 'revision', 'entretien', 'vidange'],
    'changement_moteur': ['changement moteur', 'remplacement moteur', 'moteur changé'],
    'demenagement': ['déménagement', 'demenagement', 'emménagement', 'emmenagement'],
    'achat_vehicule': ['achat véhicule', 'achat voiture', 'achat auto', "j'ai acheté"],
    'vente_vehicule': ['vente véhicule', 'vente voiture', "j'ai vendu"],
    'nouveau_contrat': ['nouveau contrat', 'signature contrat', 'contrat signé'],
    'accident': ['accident', 'sinistre', 'collision', 'panne'],
  };

  static final Map<String, String> _subTypeLabels = {
    'numero_securite_sociale': 'Numéro de sécurité sociale',
    'telephone': 'Numéro de téléphone',
    'email': 'Adresse email',
    'adresse': 'Adresse',
    'iban': 'IBAN',
    'date_naissance': 'Date de naissance',
    'numero_passeport': 'Numéro de passeport',
    'numero_permis': 'Numéro de permis de conduire',
    'controle_technique': 'Contrôle technique',
    'revision': 'Révision',
    'changement_moteur': 'Changement moteur',
    'demenagement': 'Déménagement',
    'achat_vehicule': 'Achat véhicule',
    'vente_vehicule': 'Vente véhicule',
    'nouveau_contrat': 'Nouveau contrat',
    'accident': 'Accident',
  };

  static final Map<String, List<String>> _subTypeFieldKeys = {
    'numero_securite_sociale': ['numero_securite_sociale', 'SSN', 'NIR', 'Numéro'],
    'telephone': ['Téléphone', 'Portable'],
    'email': ['Email', 'Adresse email', 'Courriel'],
    'adresse': ['Adresse', 'Domicile'],
    'iban': ['IBAN', 'RIB'],
    'date_naissance': ['Date de naissance', 'Né le'],
    'numero_passeport': ['Numéro passeport'],
    'numero_permis': ['Numéro permis'],
    'controle_technique': ['Véhicule'],
    'revision': ['Véhicule'],
    'changement_moteur': ['Véhicule'],
    'achat_vehicule': ['Véhicule', 'Montant'],
    'vente_vehicule': ['Véhicule', 'Montant'],
    'nouveau_contrat': ['Assureur', 'Type de contrat'],
    'accident': ['Véhicule'],
  };

  @override
  Future<AnalysisResult> analyzeContent(String rawText, {List<Map<String, dynamic>> analyticalData = const []}) async {
    final lower = rawText.toLowerCase();

    print('[CLASSIFICATION] ═══════════════════════════════════════════════════════════');
    print('[CLASSIFICATION] Début classification du document');
    print('[CLASSIFICATION] Longueur texte: ${rawText.length} caractères');
    print('[CLASSIFICATION] ═══════════════════════════════════════════════════════════');

    // ÉTAPE 1: Vérifier les événements (priorité haute)
    for (final entry in _eventPatterns.entries) {
      final matchedPattern = entry.value.firstWhere(
        (p) => lower.contains(p),
        orElse: () => '',
      );
      if (matchedPattern.isNotEmpty) {
        print('[CLASSIFICATION] ✓ Événement détecté: ${entry.key}');
        print('[CLASSIFICATION]   Mot-clé trouvé: "$matchedPattern"');
        print('[CLASSIFICATION] ═══════════════════════════════════════════════════════════');
        return _analyzeEvent(rawText, entry.key);
      }
    }

    // ÉTAPE 2: Vérifier les documents (AVANT les informations personnelles)
    // Car une facture peut contenir "email" ou "tel" mais reste une facture
    for (final entry in _documentPatterns.entries) {
      final matchedPattern = entry.value.firstWhere(
        (p) => lower.contains(p),
        orElse: () => '',
      );
      if (matchedPattern.isNotEmpty) {
        print('[CLASSIFICATION] ✓ Document détecté: ${entry.key}');
        print('[CLASSIFICATION]   Mot-clé trouvé: "$matchedPattern"');
        print('[CLASSIFICATION] ═══════════════════════════════════════════════════════════');
        return _analyzeDocument(rawText, entry.key, analyticalData);
      }
    }

    // ÉTAPE 3: Vérifier les informations personnelles (email, téléphone, etc.)
    for (final entry in _typePatterns.entries) {
      final matchedPattern = entry.value.firstWhere(
        (p) => lower.contains(p),
        orElse: () => '',
      );
      if (matchedPattern.isNotEmpty) {
        print('[CLASSIFICATION] ✓ Information personnelle détectée: ${entry.key}');
        print('[CLASSIFICATION]   Mot-clé trouvé: "$matchedPattern"');
        print('[CLASSIFICATION] ═══════════════════════════════════════════════════════════');
        return _analyzeInformation(rawText, entry.key);
      }
    }

    // ÉTAPE 4: Document générique
    print('[CLASSIFICATION] ⚠ Aucun pattern spécifique détecté');
    print('[CLASSIFICATION]   Classification comme document général');
    print('[CLASSIFICATION] ═══════════════════════════════════════════════════════════');
    return _analyzeDocument(rawText, 'general', analyticalData);
  }

  AnalysisResult _analyzeEvent(String rawText, String subType) {
    final title = _buildEventTitle(rawText, subType);
    final date = _extractDate(rawText);
    final vehicle = _extractVehicle(rawText);
    final fields = <String, dynamic>{};
    final suggestedFields = <String>[];

    if (vehicle != null) {
      fields['Véhicule'] = vehicle;
    } else if (_isVehicleEvent(subType)) {
      suggestedFields.add('Véhicule');
    }

    if (date != null) {
      fields['Date'] = _formatDate(date);
    } else {
      suggestedFields.add('Date');
    }

    if (subType == 'nouveau_contrat') {
      final assureur = _extractAfter(rawText, ['assureur', 'chez', 'auprès de']);
      if (assureur != null) {
        fields['Assureur'] = assureur;
      } else {
        suggestedFields.add('Assureur');
      }
      
      final typeContrat = _extractAfter(rawText, ['contrat', 'assurance']);
      if (typeContrat != null) {
        fields['Type de contrat'] = typeContrat;
      } else {
        suggestedFields.add('Type de contrat');
      }
    }

    if (subType == 'accident') {
      fields['Description'] = rawText.length > 80
          ? '${rawText.substring(0, 80)}...'
          : rawText;
      suggestedFields.add('Lieu');
      suggestedFields.add('Tiers impliqué');
    }

    if (subType == 'achat_vehicule' || subType == 'vente_vehicule') {
      final montant = _extractMontant(rawText);
      if (montant != null) {
        fields['Montant'] = montant;
      } else {
        suggestedFields.add('Montant');
      }
      
      if (vehicle == null) {
        suggestedFields.add('Immatriculation');
      }
    }

    if (subType == 'controle_technique' || subType == 'revision') {
      if (vehicle == null) {
        suggestedFields.add('Immatriculation');
      }
      suggestedFields.add('Kilométrage');
      suggestedFields.add('Centre/Garage');
      
      final km = _extractKilometrage(rawText);
      if (km != null) {
        fields['Kilométrage'] = km;
        suggestedFields.remove('Kilométrage');
      }
      
      final centre = _extractAfter(rawText, ['chez', 'au garage', 'centre', 'garage']);
      if (centre != null) {
        fields['Centre/Garage'] = centre;
        suggestedFields.remove('Centre/Garage');
      }
    }

    if (subType == 'demenagement') {
      fields['Type'] = rawText.toLowerCase().contains('emménagement') ||
              rawText.toLowerCase().contains('emmenagement')
          ? 'Emménagement'
          : 'Déménagement';
      suggestedFields.add('Ancienne adresse');
      suggestedFields.add('Nouvelle adresse');
    }

    final tags = <String>['événement', _subTypeLabels[subType]?.toLowerCase() ?? subType];
    if (vehicle != null) tags.add(vehicle);
    final domainTags = _inferDomainTags(subType, vehicle);
    tags.addAll(domainTags);

    print('[EVENT] ═══════════════════════════════════════════════════════════');
    print('[EVENT] Champs extraits: ${fields.length}');
    for (final entry in fields.entries) {
      print('[EVENT]   ✓ ${entry.key} = ${entry.value}');
    }
    print('[EVENT] Champs suggérés: ${suggestedFields.length}');
    for (final field in suggestedFields) {
      print('[EVENT]   ⚠ $field (valeur non détectée)');
    }
    print('[EVENT] ═══════════════════════════════════════════════════════════');

    return AnalysisResult(
      type: CardType.event,
      subType: subType,
      title: title,
      date: date,
      fields: fields,
      tags: tags.toSet().toList(),
      suggestedFields: suggestedFields,
    );
  }

  bool _isVehicleEvent(String subType) {
    return [
      'controle_technique',
      'revision',
      'changement_moteur',
      'achat_vehicule',
      'vente_vehicule',
      'accident',
    ].contains(subType);
  }

  String? _extractKilometrage(String text) {
    final kmPattern = RegExp(
      r'(\d{1,3}(?:[\s.]?\d{3})*(?:[,.]\d+)?)\s*(?:km|kilomètres|kilometres)',
      caseSensitive: false,
    );
    final match = kmPattern.firstMatch(text);
    if (match != null) {
      return '${match.group(1)} km';
    }
    return null;
  }

  AnalysisResult _analyzeInformation(String rawText, String subType) {
    final value = _extractValue(rawText, subType);
    final title = _subTypeLabels[subType] ?? subType;
    final fields = <String, dynamic>{};

    if (value != null) {
      switch (subType) {
        case 'numero_securite_sociale':
          fields['numero_securite_sociale'] = value;
        case 'telephone':
          fields['Téléphone'] = value;
        case 'email':
          fields['Email'] = value;
        case 'adresse':
          fields['Adresse'] = value;
        case 'iban':
          fields['IBAN'] = value;
        case 'date_naissance':
          fields['Date de naissance'] = value;
        case 'numero_passeport':
          fields['Numéro passeport'] = value;
        case 'numero_permis':
          fields['Numéro permis'] = value;
      }
    }

    final tags = <String>['information', subType.replaceAll('_', ' ')];
    if (subType == 'numero_securite_sociale') {
      tags.addAll(['identité', 'information personnelle']);
    } else if (subType == 'adresse') {
      tags.addAll(['domicile', 'information personnelle']);
    } else if (subType == 'telephone' || subType == 'email') {
      tags.add('coordonnées');
    }

    return AnalysisResult(
      type: CardType.information,
      subType: subType,
      title: title,
      value: value,
      fields: fields,
      tags: tags,
    );
  }

  // ─── Domain keywords with multi-word expressions for frequency-based tagging ───
  static final Map<String, List<String>> _domainKeywords = {
    'travaux': ['travaux', 'chantier', 'rénovation', 'construction', 'bâtiment', 'artisan'],
    'peinture': ['peinture', 'peintre', 'enduit', 'revêtement mural', 'peint'],
    'plomberie': ['plomberie', 'plombier', 'chauffe-eau', 'sanitaire', 'ballon eau'],
    'électricité': ['électricité', 'électricien', 'électrique', 'tableau électrique', 'installation électrique'],
    'maçonnerie': ['maçonnerie', 'maçon', 'parpaing', 'ciment', 'béton', 'mur'],
    'menuiserie': ['menuiserie', 'menuisier', 'fenêtre', 'porte', 'bois', 'encadrement'],
    'carrelage': ['carrelage', 'carreleur', 'faïence', 'joint', 'sol carrelé'],
    'jardinage': ['jardin', 'jardinage', 'jardinier', 'élagage', 'terrasse', 'espaces verts'],
    'informatique': ['informatique', 'ordinateur', 'logiciel', 'serveur', 'web', 'site internet'],
    'assurance': ['assurance', 'assureur', 'contrat', 'prime', 'garantie'],
    'banque': ['banque', 'bancaire', 'compte', 'virement', 'crédit', 'prêt'],
    'habitation': ['habitation', 'maison', 'appartement', 'logement', 'résidence', 'domicile'],
  };

  // ─── Address patterns ──────────────────────────────────────────────────────
  static final RegExp _addressStartRegex = RegExp(
    r'^\s*\d{1,4}\s+(?:rue|avenue|boulevard|route|chemin|impasse|allée|place|square|lotissement|résidence|hameau|lieu.dit|rte|roche|rocade|cours|promenade|quai|voie|allée)',
    caseSensitive: false,
  );

  /// Full French address regex (street number + street type + name + optional postal code + city)
  /// Uses double-quoted raw string so \' inside character class is literal.
  static final RegExp _fullAddressRegex = RegExp(
    r"(\d{1,4})\s+(rue|avenue|boulevard|route|chemin|impasse|allée|place|square|lotissement|résidence|hameau|lieu[-.]?dit|rte|roche|rocade|cours|promenade|quai|voie)\s+([A-Za-zÀ-ÿ0-9'\-\s.]{3,60})(?:\s*[,;:\-]?\s*(\d{4,5})\s*([A-Za-zÀ-ÿ\s\-]{2,40}))?",
    caseSensitive: false,
  );

  /// Postal-code + city extraction (standalone)
  static final RegExp _postalCodeRegex = RegExp(
    r"\b(\d{4,5})\s+([A-Za-zÀ-ÿ\s\-]{2,40})\b",
  );

  // ─── Stop words for tag frequency analysis ───
  static final Set<String> _stopWords = {
    'le', 'la', 'les', 'des', 'de', 'du', 'un', 'une', 'ce', 'cet', 'cette',
    'ces', 'mon', 'ton', 'son', 'ma', 'ta', 'sa', 'mes', 'tes', 'ses',
    'nos', 'vos', 'leur', 'leurs', 'notre', 'votre',
    'et', 'ou', 'mais', 'donc', 'car', 'ni', 'que', 'qui', 'quoi',
    'dans', 'sur', 'sous', 'avec', 'pour', 'par', 'sans', 'chez',
    'est', 'sont', 'été', 'être', 'avoir',
    'nous', 'vous', 'ils', 'elles', 'je', 'tu', 'il', 'elle',
    'au', 'aux', 'en', 'y', 'à', 'là', 'lors', 'plus',
    'fait', 'faire', 'sera', 'peut', 'peuvent',
    'tout', 'tous', 'toute', 'toutes', 'très', 'bien',
    'doi', 'doit', 'doivent',
    'montant', 'total', 'facture', 'numéro', 'date', 'prix',
    'quantité', 'désignation', 'référence', 'remise',
    'page', 'siret', 'tva', 'code', 'ape',
  };

  Map<String, String> _extractIdentifiers(String text) {
    final results = <String, String>{};
    print('[IDENTIFIERS] ─── Extraction des identifiants ───');

    // Numéro de sécurité sociale - TOUJOURS extraire si détecté
    // Pattern très flexible : accepte "numéro", "n°", "n", "no" et jusqu'à 80 caractères entre les mots-clés et le numéro
    final ssnMatch = RegExp(
            r'(?:num[eé]ro\s*(?:de\s+)?(?:s[ée]curit[ée]\s*sociale|ss|s[ée]cu)|n[°o]?\s*(?:de\s+)?(?:s[ée]curit[ée]\s*sociale|ss|s[ée]cu)|s[ée]curit[ée]\s*sociale|NIR)[^0-9]{0,80}?(\d[\d\s-]*\d)',
            caseSensitive: false)
        .firstMatch(text);
    if (ssnMatch != null) {
      final raw = ssnMatch.group(1)!.replaceAll(RegExp(r'[\s-]'), '');
      results['numero_securite_sociale'] = raw;
      print('[IDENTIFIERS] ✓ numero_securite_sociale = $raw (extraction sans validation)');
    }

    // Détection directe SSN - TOUJOURS extraire si pattern détecté
    final ssnDirect = RegExp(r'\b([12]\s*\d{2}\s*\d{2}\s*\d{2}\s*\d{3}\s*\d{3}\s*\d{2})\b')
        .firstMatch(text);
    if (ssnDirect != null && !results.containsKey('numero_securite_sociale')) {
      final raw = ssnDirect.group(1)!.replaceAll(RegExp(r'[\s-]'), '');
      results['numero_securite_sociale'] = raw;
      print('[IDENTIFIERS] ✓ numero_securite_sociale = $raw (détection directe)');
    }

    // Numéro de contrat - TOUJOURS extraire
    final contratMatch = RegExp(
            r'(?:contrat|n[°o]?\s*(?:de\s+)?contrat|police)[:\s]*([A-Za-z0-9\-/]{4,20})',
            caseSensitive: false)
        .firstMatch(text);
    if (contratMatch != null) {
      final raw = contratMatch.group(1)!.trim();
      results['numero_contrat'] = raw;
      print('[IDENTIFIERS] ✓ numero_contrat = $raw');
    }

    // Numéro client - TOUJOURS extraire
    final clientMatch = RegExp(
            r'(?:n[°o]?\s*(?:de\s+)?client|client\s*n[°o]?|code\s*client)[:\s]*([A-Za-z0-9\-/]{3,20})',
            caseSensitive: false)
        .firstMatch(text);
    if (clientMatch != null) {
      final raw = clientMatch.group(1)!.trim();
      results['numero_client'] = raw;
      print('[IDENTIFIERS] ✓ numero_client = $raw');
    }

    // Numéro de permis - TOUJOURS extraire
    final permisMatch = RegExp(
            r'(?:permis\s*(?:de\s*conduire)?|n[°o]?\s*(?:de\s+)?permis)[:\s]*([A-Za-z0-9\-/]{6,20})',
            caseSensitive: false)
        .firstMatch(text);
    if (permisMatch != null) {
      final raw = permisMatch.group(1)!.trim();
      results['numero_permis'] = raw;
      print('[IDENTIFIERS] ✓ numero_permis = $raw');
    }

    print('[IDENTIFIERS] ${results.length} identifiant(s) extrait(s) (validation différée)');
    return results;
  }

  Map<String, String> _detectEntities(
      String text, List<Map<String, dynamic>> analyticalData) {
    final detected = <String, String>{};
    if (analyticalData.isEmpty) return detected;

    print('[ENTITY] ═══════════════════════════════════════════════════════════');
    print('[ENTITY] Détection automatique des entités analytiques');
    print('[ENTITY] ${analyticalData.length} référentiel(s) à analyser');
    print('[ENTITY] ═══════════════════════════════════════════════════════════');

    final textLower = text.toLowerCase();

    for (final fieldData in analyticalData) {
      final fieldName = fieldData['name'] as String;
      final values = fieldData['values'] as List<Map<String, dynamic>>;

      for (final valueData in values) {
        final label = valueData['label'] as String;
        final aliases = (valueData['aliases'] as List?)?.cast<String>() ?? [];

        if (textLower.contains(label.toLowerCase())) {
          final key = fieldName.toLowerCase().replaceAll(' ', '_');
          if (!detected.containsKey(key)) {
            detected[key] = label;
            print('[ENTITY] ✓ "$label" détecté dans le texte');
            print('[ENTITY]   Référentiel: $fieldName');
            print('[ENTITY]   Liaison automatique effectuée');
          }
          continue;
        }

        for (final alias in aliases) {
          if (alias.isNotEmpty && textLower.contains(alias.toLowerCase())) {
            final key = fieldName.toLowerCase().replaceAll(' ', '_');
            if (!detected.containsKey(key)) {
              detected[key] = label;
              print('[ALIAS] ✓ "$alias" détecté dans le texte');
              print('[ALIAS]   Résolu vers: $label');
              print('[ALIAS]   Référentiel: $fieldName');
            }
            break;
          }
        }
      }
    }

    print('[ENTITY] ${detected.length} entité(s) détectée(s) automatiquement');
    return detected;
  }

  AnalysisResult _analyzeDocument(String rawText, String subType, List<Map<String, dynamic>> analyticalData) {
    print('[EXTRACT] ═══════════════════════════════════════════════════════════');
    print('[EXTRACT] Début analyse document — sous-type: $subType');
    print('[EXTRACT] ═══════════════════════════════════════════════════════════');
    
    final fournisseur = _extractFournisseur(rawText);
    final client = _extractClient(rawText);
    final date = _extractDate(rawText);
    final fields = <String, dynamic>{};
    final address = _extractAddress(rawText);
    final chantier = _extractChantierAddress(rawText, subType);

    // Collect all candidates
    final allCandidates = <ExtractionCandidate>[];

    final isMontantDoc = subType == 'general' || subType == 'courrier' || subType == 'facture';
    List<ExtractionCandidate> montantCandidates = [];
    Map<String, String?> montants = {};
    if (isMontantDoc) {
      montantCandidates = _extractMontantCandidates(rawText);
      montants = _selectBestMontant(montantCandidates);
      allCandidates.addAll(montantCandidates);
    }

    // Address candidates & structured fields
    final addrCandidates = _extractAddressCandidates(rawText);
    allCandidates.addAll(addrCandidates);

    // Populate structured address fields from best candidate
    final bestAddr = addrCandidates.isNotEmpty ? addrCandidates.first : null;
    final hasStructuredAddr = bestAddr != null && bestAddr.metadata['street'] is String
        && (bestAddr.metadata['street'] as String).isNotEmpty;

    if (chantier != null) {
      allCandidates.add(ExtractionCandidate(
        id: 'chantier_1',
        value: chantier.full,
        numericValue: 0,
        label: 'Adresse chantier',
        category: 'adresse_chantier',
        sourceLine: chantier.full,
        score: 50,
        reason: 'adresse_chantier',
      ));
    }

    String? invoiceNum;
    if (subType == 'facture') {
      invoiceNum = _extractInvoiceNumber(rawText);
    }

    // ── Insert fields in display order (RÈGLE 4) ──
    print('[EXTRACT] ─── Création des champs ───');
    fields['type_document'] = _documentLabels[subType] ?? 'Document';
    print('[EXTRACT] ✓ type_document = ${fields['type_document']}');

    if (date != null) {
      fields['date_facture'] = _formatDate(date);
      print('[EXTRACT] ✓ date_facture = ${fields['date_facture']}');
    }
    if (invoiceNum != null) {
      fields['numero_facture'] = invoiceNum;
      print('[EXTRACT] ✓ numero_facture = $invoiceNum');
    }
    if (fournisseur != null) {
      fields['fournisseur'] = fournisseur;
      print('[EXTRACT] ✓ fournisseur = $fournisseur');
    }
    if (client != null) {
      fields['client'] = client;
      print('[EXTRACT] ✓ client = $client');
    }

    // Always create montant fields when isMontantDoc && candidates exist
    // (never silently drop — user will disambiguate in verification screen)
    if (isMontantDoc && montantCandidates.isNotEmpty) {
      fields['montant_total'] = montants['total'] ?? '';
      print('[EXTRACT] ✓ montant_total = ${fields['montant_total']} (total=${montants['total']})');
      if (montants['acompte'] != null) {
        fields['acompte'] = montants['acompte'];
        print('[EXTRACT] ✓ acompte = ${fields['acompte']}');
      }
      if (montants['reste'] != null) {
        fields['reste_a_payer'] = montants['reste'];
        print('[EXTRACT] ✓ reste_a_payer = ${fields['reste_a_payer']}');
      }
      if (montants['total'] == null) {
        print('[EXTRACT] ⚠ montant_total créé VIDE — ${montantCandidates.length} candidat(s) disponibles pour correction');
      }
    }
    // Structured address from best candidate or fallback
    if (hasStructuredAddr) {
      fields['adresse'] = bestAddr.value;
      fields['adresse_rue'] = bestAddr.metadata['street'];
      print('[EXTRACT] ✓ adresse = ${fields['adresse']}');
      print('[EXTRACT] ✓ adresse_rue = ${fields['adresse_rue']}');
      final pc = bestAddr.metadata['postalCode'];
      final city = bestAddr.metadata['city'];
      if (pc is String && pc.isNotEmpty) {
        fields['adresse_code_postal'] = pc;
        print('[EXTRACT] ✓ adresse_code_postal = $pc');
      }
      if (city is String && city.isNotEmpty) {
        fields['adresse_ville'] = city;
        print('[EXTRACT] ✓ adresse_ville = $city');
      }
    } else if (address != null) {
      fields['adresse'] = address.full;
      print('[EXTRACT] ✓ adresse = ${fields['adresse']}');
    } else if (addrCandidates.isNotEmpty) {
      // Address candidates exist but none was strong enough — create empty field
      fields['adresse'] = '';
      print('[EXTRACT] ⚠ adresse créé VIDE — ${addrCandidates.length} candidat(s) disponibles pour correction');
    }
    if (chantier != null) {
      fields['adresse_bien'] = chantier.full;
      print('[EXTRACT] ✓ adresse_bien = ${fields['adresse_bien']}');
    }

    // ── Extraction des identifiants (SS, permis, contrat, client) ──
    final identifiers = _extractIdentifiers(rawText);
    for (final entry in identifiers.entries) {
      if (!fields.containsKey(entry.key)) {
        fields[entry.key] = entry.value;
        print('[EXTRACT] ✓ ${entry.key} = ${entry.value}');
      }
    }

    // ── Extraction nom/prénom (tolérant aux erreurs OCR) ──
    final nomPrenom = _extractNomPrenom(rawText);
    if (nomPrenom != null) {
      if (nomPrenom['nom'] != null && !fields.containsKey('nom')) {
        fields['nom'] = nomPrenom['nom'];
        print('[EXTRACT] ✓ nom = ${nomPrenom['nom']}');
      }
      if (nomPrenom['prenom'] != null && !fields.containsKey('prenom')) {
        fields['prenom'] = nomPrenom['prenom'];
        print('[EXTRACT] ✓ prenom = ${nomPrenom['prenom']}');
      }
    }

    // ── Extraction téléphone (tolérant aux erreurs OCR) ──
    final telephone = _extractTelephone(rawText);
    if (telephone != null && !fields.containsKey('telephone')) {
      fields['telephone'] = telephone;
      print('[EXTRACT] ✓ telephone = $telephone');
    }

    // ── Extraction adresse email (si présente) ──
    final email = _extractEmail(rawText);
    if (email != null && !fields.containsKey('email')) {
      fields['email'] = email;
      print('[EXTRACT] ✓ email = $email');
    }

    // ── Détection automatique des entités analytiques ──
    final detectedEntities = _detectEntities(rawText, analyticalData);
    for (final entry in detectedEntities.entries) {
      if (!fields.containsKey(entry.key)) {
        fields[entry.key] = entry.value;
        print('[EXTRACT] ✓ ${entry.key} = ${entry.value} (entité détectée)');
      }
    }

    // ── Fusion des doublons adresse/adresse_rue ──
    if (fields.containsKey('adresse') && fields.containsKey('adresse_rue')) {
      final addr = fields['adresse'] as String? ?? '';
      final addrRue = fields['adresse_rue'] as String? ?? '';
      if (addr == addrRue && addr.isNotEmpty) {
        print('[EXTRACT] 🔧 Fusion doublon: adresse == adresse_rue → suppression de adresse_rue');
        fields.remove('adresse_rue');
      }
    }

    if (subType == 'courrier') {
      final objetMatch = RegExp(r'(?:objet|subject|réf[.])[:\s]+([^\n]{2,80})', caseSensitive: false).firstMatch(rawText);
      if (objetMatch != null) fields['Objet'] = objetMatch.group(1)!.trim();
    }

    final description = _extractDescription(rawText);
    if (description != null) fields['description'] = description;

    final title = _buildDocumentTitle(fields, subType);
    final tags = _buildDocumentTags(rawText, subType, fields);

    return AnalysisResult(
      type: CardType.document,
      subType: subType,
      title: title,
      value: null,
      date: date,
      fields: fields,
      tags: tags,
      candidates: allCandidates,
      detectedEntities: detectedEntities,
    );
  }

  // ─── Address extraction (RÈGLE 2) ─────────────────────────────────────────
  /// Extract a structured French address from the text.
  /// Returns [_Address] with street, postalCode, city; null if nothing found.
  _Address? _extractAddress(String text) {
    // Strategy 1: full address pattern (number + street type + name + postal code + city)
    final fullMatch = _fullAddressRegex.firstMatch(text);
    if (fullMatch != null) {
      final num = fullMatch.group(1)!;
      final streetType = fullMatch.group(2)!;
      final streetName = fullMatch.group(3)!.trim();
      final postalCode = fullMatch.group(4);
      final city = fullMatch.group(5);
      final street = '$num $streetType $streetName';
      return _Address(street, postalCode, city?.trim());
    }

    // Strategy 2: find lines starting with house number + street type
    final lines = text.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      final startMatch = _addressStartRegex.firstMatch(trimmed);
      if (startMatch != null) {
        // Extract full line, clean up
        String street = trimmed;
        // Look for postal code later in the line
        final pcMatch = _postalCodeRegex.firstMatch(trimmed);
        if (pcMatch != null) {
          // Keep only text before postal code for street
          street = trimmed.substring(0, pcMatch.start).trim();
          // Remove trailing punctuation
          street = street.replaceAll(RegExp(r'[\s,;-]+$'), '');
          return _Address(street, pcMatch.group(1), pcMatch.group(2)!.trim());
        }
        return _Address(street, null, null);
      }
    }

    return null;
  }

  /// Extract all address candidates with logging.
  List<ExtractionCandidate> _extractAddressCandidates(String text) {
    final candidates = <ExtractionCandidate>[];
    final lines = text.split('\n');
    print('[ADDRESS] Début extraction — ${lines.length} lignes dans le texte');

    for (int li = 0; li < lines.length; li++) {
      final trimmed = lines[li].trim();
      if (trimmed.isEmpty) continue;

      // Strategy 1: full address pattern
      final fullMatch = _fullAddressRegex.firstMatch(trimmed);
      if (fullMatch != null) {
        final num = fullMatch.group(1)!;
        final streetType = fullMatch.group(2)!;
        final streetName = fullMatch.group(3)!.trim();
        final postalCode = fullMatch.group(4);
        final city = fullMatch.group(5);
        print('[ADDRESS] Regex capturé: num=$num type=$streetType nom="$streetName" cp=$postalCode ville=${city?.trim()}');
        final street = '$num $streetType $streetName';
        final fullAddr = postalCode != null && city != null
            ? '$street, $postalCode ${city.trim()}'
            : street;
        final score = AddressScorer.score(fullAddr);
        print('[ADDRESS] Candidat brut="${trimmed.length > 100 ? '${trimmed.substring(0, 100)}...' : trimmed}"');
        print('[ADDRESS] Candidat nettoyé="$fullAddr"');
        print('[ADDRESS] score=$score');
        candidates.add(ExtractionCandidate(
          id: 'addr_${candidates.length + 1}',
          value: fullAddr,
          numericValue: 0,
          label: 'Adresse complète',
          category: 'adresse',
          lineIndex: li,
          sourceLine: trimmed,
          score: score,
          reason: AddressScorer.reason(fullAddr),
          metadata: {
            'street': street,
            'postalCode': postalCode ?? '',
            'city': city?.trim() ?? '',
          },
        ));
        continue;
      }

      // Strategy 2: starts with house number + street type
      final startMatch = _addressStartRegex.firstMatch(trimmed);
      if (startMatch != null) {
        print('[ADDRESS] Stratégie 2 — ligne correspond: "${trimmed.length > 100 ? '${trimmed.substring(0, 100)}...' : trimmed}"');
        // First try: postal code on same line
        var pcMatch = _postalCodeRegex.firstMatch(trimmed);
        String street = trimmed;
        String? pc;
        String? ville;

        // Second try: postal code on NEXT line (multi-line address like "53 Route d'Espagne\n31100 Toulouse")
        if (pcMatch == null && li + 1 < lines.length) {
          final nextLine = lines[li + 1].trim();
          pcMatch = _postalCodeRegex.firstMatch(nextLine);
          if (pcMatch != null) {
            print('[ADDRESS] Code postal trouvé sur la ligne suivante: "$nextLine"');
          } else {
            print('[ADDRESS] Pas de code postal sur la ligne suivante: "$nextLine"');
          }
        }

        if (pcMatch != null) {
          // When pcMatch is from nextLine, use the full original street line
          if (!_postalCodeRegex.hasMatch(trimmed)) {
            // pcMatch came from next line — keep full trimmed as street
            street = trimmed;
            street = street.replaceAll(RegExp(r'[\s,;-]+$'), '');
          } else {
            // pcMatch from same line — extract street before postal code
            street = trimmed.substring(0, pcMatch.start).trim();
            street = street.replaceAll(RegExp(r'[\s,;-]+$'), '');
          }
          pc = pcMatch.group(1);
          ville = pcMatch.group(2)!.trim();
          print('[ADDRESS] Code postal trouvé: $pc  ville=$ville');
        }
        final fullAddr = pc != null && ville != null ? '$street, $pc $ville' : street;
        final score = AddressScorer.score(fullAddr);
        print('[ADDRESS] Candidat nettoyé="$fullAddr"  score=$score');
        candidates.add(ExtractionCandidate(
          id: 'addr_${candidates.length + 1}',
          value: fullAddr,
          numericValue: 0,
          label: 'Adresse',
          category: 'adresse',
          lineIndex: li,
          sourceLine: trimmed,
          score: score,
          reason: AddressScorer.reason(fullAddr),
          metadata: {
            'street': street,
            'postalCode': pc ?? '',
            'city': ville ?? '',
          },
        ));
      }
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));
    print('[ADDRESS] ${candidates.length} candidat(s) trouvé(s) au total');
    if (candidates.isNotEmpty) {
      print('[ADDRESS] RETENUE="${candidates.first.value}"  score=${candidates.first.score}');
    } else {
      print('[ADDRESS] Aucune adresse trouvée');
    }
    return candidates;
  }

  // ─── Chantier / worksite address extraction (RÈGLE 3) ─────────────────────
  /// For invoices related to housing works, detect the worksite address
  /// (which may differ from the sender's address).
  _Address? _extractChantierAddress(String text, String subType) {
    final lower = text.toLowerCase();

    // Only applicable for domains with travaux/rénovation keywords
    final hasWorkKeywords = _lineMatchesAny(lower, [
      'travaux', 'rénovation', 'renovation', 'chantier', 'réparation',
      'reparation', 'installation', 'pose ', 'plomberie', 'électricité',
      'electricite', 'peinture', 'plafond', 'cloisons', 'isolation',
      'carrelage', 'parquet', 'revêtement', 'ravalement', 'toiture',
      'couverture', 'menuiserie', 'chauffage', 'climatisation',
    ]);
    if (!hasWorkKeywords) return null;

    // Try to find a second distinct address in the text (different from the sender address)
    final lines = text.split('\n');
    final fullMatches = _fullAddressRegex.allMatches(text);
    final addresses = <_Address>[];

    for (final m in fullMatches) {
      final num = m.group(1)!;
      final streetType = m.group(2)!;
      final streetName = m.group(3)!.trim();
      final postalCode = m.group(4);
      final city = m.group(5);
      final street = '$num $streetType $streetName';
      addresses.add(_Address(street, postalCode, city?.trim()));
    }

    if (addresses.length >= 2) {
      // If there are multiple addresses, the last one is likely the worksite
      return addresses.last;
    }

    // Strategy: look for explicit "chantier" / "adresse du chantier" label
    for (int i = 0; i < lines.length; i++) {
      final l = lines[i].toLowerCase();
      if (RegExp(r'(?:chantier|adresse\s+du\s+chantier|lieu\s+de\s+l[aa]?\s*intervention|intervention\s+au|adresse\s+de\s+l[aa]?\s*intervention)\s*[:\s]', caseSensitive: false).hasMatch(l)) {
        // Next line might be the address
        if (i + 1 < lines.length) {
          final next = lines[i + 1].trim();
          final addr = _extractAddress(next);
          if (addr != null) return addr;
          // Or the address starts on the same line after the label
          final afterLabel = l.split(RegExp(r'[:\s]+')).skip(1).join(' ').trim();
          if (afterLabel.length > 5) return _Address(afterLabel, null, null);
        }
      }
    }

    // If exactly one address found and it doesn't look like a sender address,
    // it might be the worksite address
    if (addresses.length == 1) {
      // If no sender address was extracted, assume this is the main address, not chantier
      return null;
    }

    return addresses.isNotEmpty ? addresses.first : null;
  }

  String _buildDocumentTitle(Map<String, dynamic> fields, String subType) {
    final base = _documentLabels[subType] ?? 'Document';
    final f = fields['fournisseur'] as String?;
    final n = fields['numero_facture'] as String?;
    if (f != null && n != null) return '$base $f n°$n';
    if (f != null) return '$base $f';
    if (n != null) return '$base n°$n';
    return base;
  }

  // ─── Invoice number extraction ──────────────────────────────────────────────
  String? _extractInvoiceNumber(String text) {
    final patterns = [
      RegExp(r'(?:facture|n°|numéro|no|référence)\s*[:.\s]*([A-Z0-9][-A-Z0-9/]{2,20})', caseSensitive: false),
      RegExp(r'(?:n°\s*facture|numéro\s+de\s+facture|réf\s*facture)\s*[:.\s]*([A-Z0-9][-A-Z0-9/]{2,20})', caseSensitive: false),
    ];

    for (final p in patterns) {
      final match = p.firstMatch(text);
      if (match != null) {
        final raw = match.group(1)!.trim();
        // Reject single-character results
        if (raw.length < 2) continue;
        if (raw == 'n' || raw == 'N' || raw == '#' || raw == '') continue;
        // Reject if it's just the letter before a space+digit (partial match)
        if (raw.length == 1 && RegExp(r'[A-Za-z#]').hasMatch(raw)) continue;
        return raw;
      }
    }

    // Fallback: standalone number (5+ digits) near "facture"
    final fallback = RegExp(r'facture[^0-9]*(\d{4,10})', caseSensitive: false).firstMatch(text);
    if (fallback != null) return fallback.group(1);

    return null;
  }

  // ─── Montant extraction ────────────────────────────────────────────────────
  String? _extractMontant(String text) {
    final m = RegExp(r'(\d[\d\s]*[,.]?\d*)\s*(?:€|euros?|EUR)', caseSensitive: false).firstMatch(text);
    return m?.group(0);
  }

  /// Extract all amount candidates with scoring and logging.
  /// Returns candidates sorted by score descending.
  List<ExtractionCandidate> _extractMontantCandidates(String text) {
    final lines = text.split('\n');
    final candidates = <ExtractionCandidate>[];
    int seq = 0;
    print('[MONTANT] ═══════════════════════════════════════════════════════════');
    print('[MONTANT] Début extraction — ${lines.length} lignes dans le texte');
    print('[MONTANT] ═══════════════════════════════════════════════════════════');

    for (int li = 0; li < lines.length; li++) {
      final trimmed = lines[li].trim();
      if (trimmed.isEmpty) continue;

      final numbers = RegExp(r'(\d+(?:[,.]\d+)?)\s*(?:€|euros?|EUR)?', caseSensitive: false).allMatches(trimmed);
      if (numbers.isEmpty) continue;

      for (final m in numbers) {
        final rawNum = m.group(1)?.trim() ?? '';
        final val = _parseNumber(rawNum);
        if (val == null || val <= 0) continue;

        final fullMatch = m.group(0) ?? rawNum;
        final hasEuro = fullMatch.contains('€') || fullMatch.contains('euro') || fullMatch.contains('EUR');
        final rawValue = hasEuro ? fullMatch : '$rawNum €';

        final ctxStart = (m.start - 40).clamp(0, trimmed.length);
        final ctxEnd = (m.end + 40).clamp(0, trimmed.length);
        final context = trimmed.substring(ctxStart, ctxEnd);
        final contextLower = context.toLowerCase();
        final analyse = MontantScorer.analyser(contextLower, rawNum);

        print('[MONTANT] ─── Ligne ${li + 1} ───');
        print('[MONTANT] Nombre trouvé: $rawNum (valeur=$val, €=$hasEuro)');
        print('[MONTANT] Contexte local: "$context"');
        for (final log in analyse.logs) {
          print(log);
        }

        if (analyse.estExclu) {
          print('[MONTANT] ⛔ IGNORÉ — catégorie exclue (${analyse.categorie.name})');
          continue;
        }

        if (!hasEuro && val < 20 && analyse.categorie == LigneCategorie.inconnu) {
          print('[MONTANT] ⛔ IGNORÉ — valeur < 20 sans € et aucun mot-clé');
          continue;
        }

        seq++;
        final candidate = ExtractionCandidate(
          id: 'montant_$seq',
          value: rawValue,
          numericValue: val,
          label: analyse.motCle.isNotEmpty ? analyse.motCle : 'montant_détecté',
          category: 'montant',
          lineIndex: li,
          sourceLine: context,
          score: analyse.score,
          reason: analyse.motCle,
          metadata: {
            'hasEuro': hasEuro,
            'categorie': analyse.categorie.name,
          },
        );
        candidates.add(candidate);
        print('[MONTANT] ✓ CANDIDAT #$seq  valeur=$rawValue  score=${analyse.score}%  catégorie=${analyse.categorie.name}');
      }
    }

    candidates.sort((a, b) {
      final sc = b.score.compareTo(a.score);
      if (sc != 0) return sc;
      return b.numericValue.compareTo(a.numericValue);
    });

    print('[MONTANT] ═══════════════════════════════════════════════════════════');
    print('[MONTANT] ${candidates.length} candidat(s) retenu(s) après filtrage');
    if (candidates.isNotEmpty) {
      print('[MONTANT] Classement final:');
      for (int i = 0; i < candidates.length; i++) {
        final c = candidates[i];
        final cat = c.metadata['categorie'] ?? '?';
        print('[MONTANT]   #${i + 1} ${c.value.padRight(15)} score=${c.score.toString().padLeft(3)}%  catégorie=$cat');
      }
    } else {
      print('[MONTANT] Aucun candidat montant trouvé !');
    }
    print('[MONTANT] ═══════════════════════════════════════════════════════════');
    return candidates;
  }

  /// Select the best montant from candidates. Returns {total, acompte, reste}.
  Map<String, String?> _selectBestMontant(List<ExtractionCandidate> candidates) {
    String? total;
    String? acompte;
    String? reste;

    if (candidates.isEmpty) {
      print('[MONTANT] _selectBestMontant: 0 candidat → aucun montant !');
      return {'total': null, 'acompte': null, 'reste': null};
    }

    print('[MONTANT] ─── Sélection des meilleurs montants ───');
    print('[MONTANT] ${candidates.length} candidat(s) à évaluer:');
    for (int i = 0; i < candidates.length && i < 10; i++) {
      final c = candidates[i];
      final cat = c.metadata['categorie'] ?? '?';
      print('[MONTANT]   #${i + 1} ${c.value.padRight(15)} score=${c.score}%  catégorie=$cat  valeur=${c.numericValue}');
    }

    // Collecter les candidats pour le total (montantTotal, ligneTableau, inconnu)
    final totalCandidates = <ExtractionCandidate>[];
    
    for (final c in candidates) {
      final cat = c.metadata['categorie'] as String? ?? '';

      if (cat == 'acompte' && acompte == null) {
        print('[MONTANT] → acompte = ${c.value} (catégorie=$cat, score=${c.score})');
        acompte = c.value;
      } else if (cat == 'resteAPayer' && reste == null) {
        print('[MONTANT] → reste   = ${c.value} (catégorie=$cat, score=${c.score})');
        reste = c.value;
      } else if (cat == 'montantTotal' || cat == 'ligneTableau' || cat == 'inconnu') {
        totalCandidates.add(c);
      } else {
        print('[MONTANT] ignoré ${c.value} — catégorie=$cat non prioritaire');
      }
    }

    // Sélectionner le meilleur total
    if (totalCandidates.isNotEmpty) {
      print('[MONTANT] ─── Sélection du total parmi ${totalCandidates.length} candidat(s) ───');
      
      // Trier par score décroissant, puis par valeur décroissante
      totalCandidates.sort((a, b) {
        final scoreDiff = b.score.compareTo(a.score);
        if (scoreDiff != 0) return scoreDiff;
        return b.numericValue.compareTo(a.numericValue);
      });

      // Si le meilleur score est proche du deuxième (différence < 10 points),
      // prendre le plus grand montant
      if (totalCandidates.length >= 2) {
        final best = totalCandidates[0];
        final second = totalCandidates[1];
        final scoreDiff = best.score - second.score;
        
        print('[MONTANT] Meilleur: ${best.value} (score=${best.score}, val=${best.numericValue})');
        print('[MONTANT] Deuxième: ${second.value} (score=${second.score}, val=${second.numericValue})');
        print('[MONTANT] Différence de score: $scoreDiff points');
        
        if (scoreDiff <= 10 && second.numericValue > best.numericValue) {
          print('[MONTANT] → total   = ${second.value} (scores proches, valeur plus grande)');
          total = second.value;
        } else {
          print('[MONTANT] → total   = ${best.value} (meilleur score)');
          total = best.value;
        }
      } else {
        print('[MONTANT] → total   = ${totalCandidates[0].value} (seul candidat)');
        total = totalCandidates[0].value;
      }
    }

    print('[MONTANT] ─── Résultat final ───');
    print('[MONTANT]   total   = $total');
    print('[MONTANT]   acompte = $acompte');
    print('[MONTANT]   reste   = $reste');
    return {'total': total, 'acompte': acompte, 'reste': reste};
  }

  double? _parseNumber(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^\d,.]'), '').replaceAll(',', '.');
    final val = double.tryParse(cleaned);
    if (val == null || val.isNaN || val.isInfinite) return null;
    return val;
  }

  bool _lineMatchesAny(String lower, List<String> keywords) {
    return keywords.any((k) => lower.contains(k));
  }

  // ─── Fournisseur (sender company) extraction ───────────────────────────────
  String? _extractFournisseur(String text) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) return null;

    String? candidate;

    // Strategy 1: first line that contains a company legal form
    final legalFormRegex = RegExp(r'\b(SARL|SAS|SA|EURL|SASU|SCI|SNC|EI|auto-entrepreneur)\b', caseSensitive: false);
    for (int i = 0; i < lines.length && i < 8; i++) {
      if (legalFormRegex.hasMatch(lines[i])) {
        candidate = lines[i];
        break;
      }
    }

    // Strategy 2: line containing SIRET number (first header line with it)
    if (candidate == null) {
      final siretRegex = RegExp(r'(\d{14})');
      for (int i = 0; i < lines.length && i < 6; i++) {
        if (siretRegex.hasMatch(lines[i])) {
          final prevLine = i > 0 ? lines[i - 1] : null;
          if (prevLine != null && prevLine.length > 2 && prevLine.length < 60) {
            candidate = prevLine;
          } else {
            // Try to get text before SIRET on same line
            final siretMatch = siretRegex.firstMatch(lines[i]);
            if (siretMatch != null && siretMatch.start > 2) {
              candidate = lines[i].substring(0, siretMatch.start).trim();
            }
          }
          break;
        }
      }
    }

    // Strategy 3: header block — the first substantial line that looks like a name
    if (candidate == null) {
      for (int i = 0; i < lines.length && i < 5; i++) {
        final l = lines[i];
        if (l.length < 2 || l.length > 50) continue;
        if (RegExp(r'^(facture|devis|contrat|objet|date|réf|ref|tel|email|http|www)', caseSensitive: false).hasMatch(l)) break;
        if (RegExp(r'^\d{1,3}\s', caseSensitive: false).hasMatch(l)) continue; // address line
        candidate = l;
        break;
      }
    }

    if (candidate == null) return null;

    // Clean: remove leading/trailing punctuation, limit length
    candidate = candidate.replaceAll(RegExp(r'^[.\s,;:-]+|[.\s,;:-]+$'), '');
    if (candidate.length < 3 || candidate.length > 60) return null;

    return candidate;
  }

  // ─── Client extraction ──────────────────────────────────────────────────────
  String? _extractClient(String text) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    // Look for explicit "client" label
    for (int i = 0; i < lines.length; i++) {
      if (RegExp(r"^(client|factur. |destinataire|. l'attention\s*de)\s*[:\s]", caseSensitive: false).hasMatch(lines[i])) {
        final parts = lines[i].split(RegExp(r'[:\s]+'));
        final clientLine = parts.length > 1 ? parts.sublist(1).join(' ').trim() : '';
        if (clientLine.length >= 3 && clientLine.length < 60) return clientLine;
        // Next line might be the client name
        if (i + 1 < lines.length && lines[i + 1].length < 60) return lines[i + 1];
      }
    }

    // Look for M./Mme pattern after "client" section
    final mmMatch = RegExp(r'(?:client|destinataire)[^\n]*\n([\s]*M(?:me)?[\.]?\s*[A-Z][a-zéèêëàâùûôö]+(?:\s+[A-Z][a-zéèêëàâùûôö-]+)*)', caseSensitive: false).firstMatch(text);
    if (mmMatch != null) return mmMatch.group(1)!.trim();

    return null;
  }

  // ─── Description extraction ─────────────────────────────────────────────────
  String? _extractDescription(String text) {
    final lines = text.split('\n');

    // Look for explicit "description/objet" line
    for (int i = 0; i < lines.length; i++) {
      if (RegExp(r'^(?:description|objet|désignation|prestation|travaux)\s*[:\s]', caseSensitive: false).hasMatch(lines[i])) {
        final parts = lines[i].split(RegExp(r'[:\s]+'));
        final desc = parts.length > 1 ? parts.sublist(1).join(' ').trim() : '';
        if (desc.length >= 5) return desc;
        // Check next line
        if (i + 1 < lines.length && lines[i + 1].length >= 5 && lines[i + 1].length < 100) {
          return lines[i + 1].trim();
        }
      }
    }

    // Fallback: first line-item description (starts with a digit, not a price line)
    for (int i = 0; i < lines.length && i < 40; i++) {
      final l = lines[i];
      if (RegExp(r'^\d+\s{2,}', caseSensitive: false).hasMatch(l)) {
        final item = l.replaceFirst(RegExp(r'^\d+\s{2,}'), '').trim();
        if (item.length >= 5 && item.length < 100) return item;
      }
    }

    return null;
  }

  // ─── Tag engine: frequency-based, context-aware ─────────────────────────────
  List<String> _buildDocumentTags(String rawText, String subType, Map<String, dynamic> fields) {
    final tags = <String>{};
    tags.add('document');
    tags.add(_documentLabels[subType]?.toLowerCase() ?? subType);

    // 1. Build word-frequency map from raw text (excl. stop words, short words)
    final lower = rawText.toLowerCase();
    final words = lower.split(RegExp(r'[^\p{L}0-9]+'));
    final freq = <String, int>{};
    for (final w in words) {
      if (w.length < 4) continue;
      if (_stopWords.contains(w)) continue;
      freq[w] = (freq[w] ?? 0) + 1;
    }

    // 2. Score each domain by its cumulative keyword frequency in the document
    final domainScores = <String, int>{};
    for (final entry in _domainKeywords.entries) {
      int score = 0;
      for (final kw in entry.value) {
        final kwLower = kw.toLowerCase();
        int count = _countOccurrences(lower, kwLower);
        if (count > 0) {
          score += count * (kwLower.split(' ').length); // multi-word = higher weight
        }
      }
      if (score > 0) {
        domainScores[entry.key] = score;
      }
    }

    // 3. Also check field values (e.g. description, objet) with boosted weight
    for (final field in fields.entries) {
      if (field.value is String && (field.key == 'description' || field.key == 'Objet')) {
        final fv = (field.value as String).toLowerCase();
        for (final entry in _domainKeywords.entries) {
          if (entry.value.any((kw) => fv.contains(kw))) {
            domainScores[entry.key] = (domainScores[entry.key] ?? 0) + 3;
          }
        }
      }
    }

    // 4. Filter domains: require score >= 3, or >= 2 if keyword is in the header/title
    final topLines = lower.split('\n').take(5).join(' ');
    final titleField = (fields['description']?.toString() ?? '').toLowerCase();
    final combinedHeader = '$topLines $titleField';

    for (final entry in domainScores.entries) {
      final score = entry.value;
      final inHeader = _domainKeywords[entry.key]!.any((kw) => combinedHeader.contains(kw));
      final threshold = inHeader ? 2 : 3;
      if (score >= threshold) {
        tags.add(entry.key);
      }
    }

    // 5. Enforce: min 3, max 8
    if (tags.length < 3) {
      final fallbackDomains = ['administratif', 'professionnel'];
      for (final d in fallbackDomains) {
        if (tags.length >= 3) break;
        tags.add(d);
      }
    }

    return tags.toList().take(8).toList();
  }

  int _countOccurrences(String text, String word) {
    int count = 0;
    int start = 0;
    while (true) {
      final idx = text.indexOf(word, start);
      if (idx < 0) break;
      count++;
      start = idx + word.length;
    }
    return count;
  }

  String? _extractValue(String text, String subType) {
    switch (subType) {
      case 'numero_securite_sociale':
        // Extraction permissive : accepte "numéro", "n°", "n", "no" et jusqu'à 80 caractères entre les mots-clés et le numéro
        final ssnMatch = RegExp(
                r'(?:num[eé]ro\s*(?:de\s+)?(?:s[ée]curit[ée]\s*sociale|ss|s[ée]cu)|n[°o]?\s*(?:de\s+)?(?:s[ée]curit[ée]\s*sociale|ss|s[ée]cu)|s[ée]curit[ée]\s*sociale|NIR)[^0-9]{0,80}?(\d[\d\s-]*\d)',
                caseSensitive: false)
            .firstMatch(text);
        if (ssnMatch != null) {
          final raw = ssnMatch.group(1)!.replaceAll(RegExp(r'[\s-]'), '');
          print('[EXTRACT] ✓ numero_securite_sociale = $raw (extraction sans validation)');
          return raw;
        }
        // Fallback : pattern standard 15 chiffres
        final digitsMatch = RegExp(r'\b((?:1|2)\s?\d{2}\s?\d{2}\s?\d{2}\s?\d{3}\s?\d{3}\s?\d{2})\b').firstMatch(text);
        if (digitsMatch != null) {
          final raw = digitsMatch.group(1)!.replaceAll(RegExp(r'[\s-]'), '');
          print('[EXTRACT] ✓ numero_securite_sociale = $raw (détection directe)');
          return raw;
        }
        return null;

      case 'telephone':
        final phoneMatch = RegExp(r'\b((?:0|\+33)[1-9](?:[\s.-]?\d{2}){4})\b').firstMatch(text);
        return phoneMatch?.group(1)?.replaceAll(RegExp(r'[\s.-]'), '');

      case 'email':
        final emailMatch = RegExp(r'\b[\w.%+-]+@[\w.-]+\.[A-Za-z]{2,}\b').firstMatch(text);
        return emailMatch?.group(0);

      case 'adresse':
        final addrMatch = RegExp(
                r'(?:adresse|habite\s+(?:au|à)\s+|r[ée]side\s+(?:au|à)\s+)[:\s]*((?:\d+\s+)?(?:rue|avenue|boulevard|place|chemin|impasse|allée|route|lotissement)\s+[^,\n]+(?:\d{5})?)',
                caseSensitive: false)
            .firstMatch(text);
        return addrMatch?.group(1)?.trim();

      case 'iban':
        final ibanMatch =
            RegExp(r'\b([A-Z]{2}\d{2}[ ]?\d{4}[ ]?\d{4}[ ]?\d{4}[ ]?\d{4}[ ]?\d{0,4})\b')
                .firstMatch(text);
        return ibanMatch?.group(1);

      default:
        return null;
    }
  }

  String? _extractAfter(String text, List<String> keywords) {
    final lower = text.toLowerCase();
    for (final kw in keywords) {
      final idx = lower.indexOf(kw);
      if (idx >= 0) {
        final after = text.substring(idx + kw.length).trim();
        final lines = after.split(RegExp(r'[,\n.]'));
        if (lines.isNotEmpty && lines.first.length > 1) {
          return lines.first.trim();
        }
      }
    }
    return null;
  }

  String _buildEventTitle(String rawText, String subType) {
    final label = _subTypeLabels[subType] ?? subType;
    final vehicle = _extractVehicle(rawText);
    if (vehicle != null) return '$label $vehicle';
    return label;
  }

  String? _extractVehicle(String text) {
    // Pattern 1: Marques connues (priorité haute)
    final knownBrandsPattern = RegExp(
      r'(?:ma\s+|mon\s+)?(Peugeot\s*\d+\s*\w*|Renault\s*\w*\s*\d*|Citro[eë]n\s*\w*\s*\d*|DS\s*\w*\s*\d*|BMW\s*\w*\s*\d*|Mercedes\s*\w*\s*\d*|Audi\s*\w*\s*\d*|Volkswagen\s*\w*\s*\d*|Toyota\s*\w*\s*\d*|Honda\s*\w*\s*\d*|Nissan\s*\w*\s*\d*|Ford\s*\w*\s*\d*|Fiat\s*\w*\s*\d*|Opel\s*\w*\s*\d*|Volvo\s*\w*\s*\d*|Hyundai\s*\w*\s*\d*|Kia\s*\w*\s*\d*|Mazda\s*\w*\s*\d*|Seat\s*\w*\s*\d*|Skoda\s*\w*\s*\d*)',
      caseSensitive: false,
    );
    
    var match = knownBrandsPattern.firstMatch(text);
    if (match != null) {
      final vehicle = match.group(1)!.trim();
      print('[VEHICLE] ✓ Marque connue détectée: $vehicle');
      return vehicle;
    }

    // Pattern 2: Modèles spécifiques (Sharan, Golf, Polo, etc.)
    final modelPattern = RegExp(
      r'(?:mon\s+|ma\s+)?(Sharan|Golf|Polo|Passat|Tiguan|Touareg|Caddy|Touran|Scirocco|Arteon|T-Roc|T-Cross|ID\.3|ID\.4|ID\.5|Clio|Mégane|Megane|Captur|Kadjar|Koleos|Twingo|Zoé|Zoe|Scénic|Scenic|208|2008|308|3008|508|5008|Partner|Rifter|Expert|A1|A3|A4|A5|A6|A7|A8|Q2|Q3|Q5|Q7|Q8|TT|RS|Classe\s*[A-Z]|Série\s*\d)',
      caseSensitive: false,
    );
    
    match = modelPattern.firstMatch(text);
    if (match != null) {
      final vehicle = match.group(1)!.trim();
      print('[VEHICLE] ✓ Modèle détecté: $vehicle');
      return vehicle;
    }

    // Pattern 3: Immatriculation française (AA-123-BB ou 1234 AB 56)
    final platePattern = RegExp(
      r'\b([A-Z]{2}-\d{3}-[A-Z]{2}|\d{1,4}\s*[A-Z]{1,3}\s*\d{2,3})\b',
      caseSensitive: false,
    );
    
    match = platePattern.firstMatch(text);
    if (match != null) {
      final plate = match.group(1)!.trim();
      print('[VEHICLE] ✓ Immatriculation détectée: $plate');
      return plate;
    }

    print('[VEHICLE] Aucun véhicule détecté (validation contextuelle)');
    return null;
  }

  DateTime? _extractDate(String text) {
    final dateMatch =
        RegExp(r'(\d{2})/(\d{2})/(\d{4})').firstMatch(text);
    if (dateMatch != null) {
      return DateTime.tryParse(
          '${dateMatch.group(3)}-${dateMatch.group(2)}-${dateMatch.group(1)}');
    }
    
    final lower = text.toLowerCase();
    final now = DateTime.now();
    
    if (lower.contains("aujourd'hui") || lower.contains('today') || lower.contains('à l\'instant') || lower.contains('a l\'instant')) {
      return now;
    }
    
    if (lower.contains('hier') || lower.contains('yesterday')) {
      return now.subtract(const Duration(days: 1));
    }
    
    if (lower.contains('avant-hier') || lower.contains('avant hier')) {
      return now.subtract(const Duration(days: 2));
    }
    
    if (lower.contains('ce matin')) {
      return DateTime(now.year, now.month, now.day, 8, 0);
    }
    
    if (lower.contains('cet après-midi') || lower.contains('cet apres-midi') || lower.contains('cet aprèm')) {
      return DateTime(now.year, now.month, now.day, 14, 0);
    }
    
    if (lower.contains('ce soir')) {
      return DateTime(now.year, now.month, now.day, 18, 0);
    }
    
    if (lower.contains('la semaine dernière') || lower.contains('la semaine derniere') || lower.contains('semaine dernière')) {
      return now.subtract(const Duration(days: 7));
    }
    
    if (lower.contains('le mois dernier') || lower.contains('mois dernier')) {
      return DateTime(now.year, now.month - 1, now.day);
    }
    
    if (lower.contains('il y a 2 semaines') || lower.contains('il y a deux semaines')) {
      return now.subtract(const Duration(days: 14));
    }
    
    if (lower.contains('il y a 3 semaines') || lower.contains('il y a trois semaines')) {
      return now.subtract(const Duration(days: 21));
    }
    
    return null;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  List<String> _inferDomainTags(String subType, String? vehicle) {
    final eventDomains = <String, List<String>>{
      'controle_technique': ['automobile', 'entretien'],
      'revision': ['automobile', 'entretien'],
      'changement_moteur': ['automobile', 'réparation'],
      'achat_vehicule': ['automobile'],
      'vente_vehicule': ['automobile'],
      'demenagement': ['habitation'],
      'nouveau_contrat': ['assurance', 'banque'],
    };
    return eventDomains[subType] ?? [];
  }

  @override
  Future<List<String>> generateTags(String rawText, CardType type, String subType) async {
    final result = await analyzeContent(rawText);
    return result.tags;
  }

  @override
  Future<Map<String, dynamic>> extractFields(
      String rawText, CardType type, String subType) async {
    final result = await analyzeContent(rawText);
    return result.fields;
  }

  @override
  Future<String> generateTitle(String rawText, CardType type, String subType) async {
    final result = await analyzeContent(rawText);
    return result.title;
  }

  @override
  Future<AnswerResult> answerQuestion(
    String question, 
    List<CardModel> cards, {
    List<Map<String, dynamic>> analyticalData = const [],
  }) async {
    final lower = question.toLowerCase();
    
    print('[QUERY] ═══════════════════════════════════════════════════════════');
    print('[QUERY] Question: $question');
    print('[QUERY] Fiches disponibles: ${cards.length}');
    print('[QUERY] Référentiels analytiques: ${analyticalData.length}');
    print('[QUERY] ═══════════════════════════════════════════════════════════');

    // Stage 1: Analyser la question
    final analyzer = QuestionAnalyzer();
    final analyzed = analyzer.analyze(question);
    
    print('[QUERY] Intent: ${analyzed.intent}');
    print('[QUERY] Subject: ${analyzed.subject}');
    print('[QUERY] Target: ${analyzed.targetName ?? "aucun"}');
    print('[QUERY] Plural: ${analyzed.isPlural}');
    print('[QUERY] GroupType: ${analyzed.groupType ?? "aucun"}');

    // Stage 2: Résoudre les groupes analytiques
    if (analyzed.isPlural && analyzed.groupType != null) {
      final groupAnswer = await _answerGroupQuestion(
        analyzed, 
        cards, 
        analyticalData,
      );
      if (groupAnswer != null) {
        print('[ANSWER GENERATED] Réponse de groupe construite');
        print('[QUERY] ═══════════════════════════════════════════════════════════');
        return groupAnswer;
      }
    }

    // Stage 3: Questions sur les échéances
    if (_isNextDeadlineQuestion(lower)) {
      final eventType = _detectEventType(lower);
      final answer = _answerNextDeadline(question, cards, eventType);
      if (answer != null) {
        print('[ANSWER GENERATED] Réponse échéance construite');
        print('[QUERY] ═══════════════════════════════════════════════════════════');
        return answer;
      }
    }

    // Stage 4: Questions sur les informations personnelles (SSN, téléphone, etc.)
    for (final entry in _typePatterns.entries) {
      if (entry.value.any((p) => lower.contains(p))) {
        final matching = cards.where((c) => c.subType == entry.key).toList();
        if (matching.isNotEmpty) {
          final card = matching.first;
          final label = _subTypeLabels[entry.key] ?? entry.key;
          final subject = _subjectFromQuestion(question);
          final fieldValue = _findFieldValueBySubType(card, entry.key);
          if (fieldValue != null) {
            print('[DOCUMENT MATCH] Fiche trouvée: ${card.title}');
            print('[ANSWER GENERATED] Réponse information personnelle construite');
            print('[QUERY] ═══════════════════════════════════════════════════════════');
            return AnswerResult(
              answerText: '$subject $label est :\n$fieldValue',
              confidence: 'Fort',
              sourceCardId: card.id,
              sourceTitle: card.title,
              extractedValue: fieldValue,
            );
          }
        }
      }
    }

    // Stage 5: Questions sur les factures
    if (lower.contains('facture') || lower.contains('montant') ||
        lower.contains('total') || lower.contains('fournisseur') ||
        lower.contains('acompte') || lower.contains('reste')) {
      final docCards = cards.where((c) => c.type == CardType.document).toList();
      if (docCards.isNotEmpty) {
        CardModel? matched;
        for (final c in docCards) {
          final f = c.fields['fournisseur'] as String?;
          if (f != null && lower.contains(f.toLowerCase())) {
            matched = c;
            break;
          }
        }
        matched ??= docCards.first;

        final parts = <String>[];
        final total = matched.fields['montant_total'] as String?;
        final acompte = matched.fields['acompte'] as String?;
        final reste = matched.fields['reste_a_payer'] as String?;
        final numero = matched.fields['numero_facture'] as String?;
        final fournisseur = matched.fields['fournisseur'] as String?;
        final client = matched.fields['client'] as String?;
        final date = matched.fields['date_facture'] as String?;

        if (fournisseur != null) parts.add('Fournisseur : $fournisseur');
        if (client != null) parts.add('Client : $client');
        if (date != null) parts.add('Date : $date');
        if (numero != null) parts.add('Facture n°$numero');
        if (total != null) parts.add('Montant total : $total');
        if (acompte != null) parts.add('Acompte versé : $acompte');
        if (reste != null) parts.add('Reste à payer : $reste');

        if (parts.isNotEmpty) {
          print('[DOCUMENT MATCH] Facture trouvée: ${matched.title}');
          print('[ANSWER GENERATED] Réponse facture construite');
          print('[QUERY] ═══════════════════════════════════════════════════════════');
          return AnswerResult(
            answerText: parts.join('\n'),
            confidence: 'Fort',
            sourceCardId: matched.id,
            sourceTitle: matched.title,
          );
        }
      }
    }

    // Stage 6: Questions sur les événements
    for (final entry in _eventPatterns.entries) {
      if (entry.value.any((p) => lower.contains(p))) {
        final matching = cards.where((c) => c.subType == entry.key).toList();
        if (matching.isNotEmpty) {
          final card = matching.first;
          final subject = _subjectFromQuestion(question);
          final dateStr = card.date != null
              ? _formatDate(card.date!)
              : 'date non spécifiée';
          final vehicle = _findFieldValue(card, 'Véhicule');
          final vehicleStr = vehicle != null ? ' pour $vehicle' : '';
          print('[DOCUMENT MATCH] Événement trouvé: ${card.title}');
          print('[ANSWER GENERATED] Réponse événement construite');
          print('[QUERY] ═══════════════════════════════════════════════════════════');
          return AnswerResult(
            answerText: '$subject ${card.title} a été effectué le $dateStr$vehicleStr.',
            confidence: 'Fort',
            sourceCardId: card.id,
            sourceTitle: card.title,
            justification: card.fields.isNotEmpty
                ? 'Champs : ${card.displayFields.entries.map((e) => '${e.key}: ${e.value}').join(', ')}'
                : null,
          );
        }
      }
    }

    // Stage 7: Questions sur les échéances/expiration
    if (lower.contains('échéance') || lower.contains('echeance') || lower.contains('expiration')) {
      final eventCards = cards.where((c) => c.type == CardType.event).toList();
      if (eventCards.isNotEmpty) {
        final last = eventCards.first;
        final dateStr = last.date != null ? _formatDate(last.date!) : 'date non spécifiée';
        final vehicle = _findFieldValue(last, 'Véhicule');
        final vehicleStr = vehicle != null ? ' pour $vehicle' : '';
        print('[DOCUMENT MATCH] Dernier événement: ${last.title}');
        print('[ANSWER GENERATED] Réponse échéance construite');
        print('[QUERY] ═══════════════════════════════════════════════════════════');
        return AnswerResult(
          answerText: 'Je ne dispose pas encore de la règle métier permettant de calculer '
              'automatiquement la prochaine échéance.\n\n'
              'En revanche, le dernier événement enregistré est "${last.title}"$vehicleStr '
              'effectué le $dateStr.',
          confidence: 'Moyen',
          sourceCardId: last.id,
          sourceTitle: last.title,
        );
      }
    }

    // Stage 8: Recherche par mots-clés
    final words = lower.split(RegExp(r'\s+')).where((w) => w.length > 3).toList();
    final matching = cards.where((c) {
      final text = '${c.title} ${c.rawText} ${c.tags.join(' ')}'.toLowerCase();
      return words.any((w) => text.contains(w));
    }).toList();

    if (matching.isNotEmpty) {
      final card = matching.first;
      final answerParts = <String>[card.title];
      if (card.fields.isNotEmpty) {
        for (final f in card.fields.entries) {
          answerParts.add('${f.key} : ${f.value}');
        }
      }
      print('[DOCUMENT MATCH] Fiche trouvée par mots-clés: ${card.title}');
      print('[ANSWER GENERATED] Réponse mots-clés construite');
      print('[QUERY] ═══════════════════════════════════════════════════════════');
      return AnswerResult(
        answerText: answerParts.join('\n'),
        confidence: 'Moyen',
        sourceCardId: card.id,
        sourceTitle: card.title,
        extractedValue: card.value,
      );
    }

    print('[ANSWER GENERATED] Aucune réponse trouvée');
    print('[QUERY] ═══════════════════════════════════════════════════════════');
    return AnswerResult(
      answerText: 'Je n\'ai pas trouvé d\'information correspondant à votre question.\n\n'
          'Essayez d\'ajouter l\'information via la saisie manuelle ou la dictée.',
      confidence: 'Faible',
    );
  }

  Future<AnswerResult?> _answerGroupQuestion(
    AnalyzedQuestion analyzed,
    List<CardModel> cards,
    List<Map<String, dynamic>> analyticalData,
  ) async {
    print('[ANALYTIC MATCH] Résolution de groupe: ${analyzed.groupType}');
    
    // Trouver toutes les entités du groupe via les alias
    final groupEntities = <String>[];
    
    for (final fieldData in analyticalData) {
      final values = fieldData['values'] as List<Map<String, dynamic>>;
      
      for (final valueData in values) {
        final label = valueData['label'] as String;
        final aliases = (valueData['aliases'] as List?)?.cast<String>() ?? [];
        
        // Vérifier si cette entité appartient au groupe
        final allNames = [label, ...aliases].map((n) => n.toLowerCase()).toList();
        
        for (final name in allNames) {
          if (name.contains(analyzed.groupType!) || 
              (analyzed.groupType == 'enfant' && 
               (name.contains('fils') || name.contains('fille') || name.contains('enfant')))) {
            if (!groupEntities.contains(label)) {
              groupEntities.add(label);
              print('[ANALYTIC MATCH] Entité du groupe: $label (via "$name")');
            }
            break;
          }
        }
      }
    }
    
    if (groupEntities.isEmpty) {
      print('[ANALYTIC MATCH] Aucune entité trouvée pour le groupe');
      return null;
    }
    
    print('[ANALYTIC MATCH] ${groupEntities.length} entité(s) dans le groupe');
    
    // Chercher les fiches correspondantes
    final matchingCards = <CardModel>[];
    final results = <String>[];
    final answerValues = <AnswerValue>[];
    
    for (final entity in groupEntities) {
      final entityLower = entity.toLowerCase();
      
      // Chercher dans les champs analytiques des fiches
      for (final card in cards) {
        bool found = false;
        
        // Vérifier les champs analytiques
        for (final field in card.fields.entries) {
          final value = field.value.toString().toLowerCase();
          if (value == entityLower || value.contains(entityLower)) {
            found = true;
            break;
          }
        }
        
        // Vérifier aussi le titre et le texte brut
        if (!found) {
          final searchText = '${card.title} ${card.rawText}'.toLowerCase();
          if (searchText.contains(entityLower)) {
            found = true;
          }
        }
        
        if (found && !matchingCards.contains(card)) {
          matchingCards.add(card);
          print('[DOCUMENT MATCH] Fiche pour $entity: ${card.title}');
          
          // Extraire l'information demandée
          final fieldValue = _extractRequestedField(card, analyzed.intent);
          if (fieldValue != null) {
            results.add('• $entity : $fieldValue');
            answerValues.add(AnswerValue(
              label: entity,
              value: fieldValue,
              sourceCardId: card.id,
            ));
          } else {
            results.add('• $entity : information non disponible');
          }
        }
      }
    }
    
    if (results.isEmpty) {
      print('[ANSWER GENERATED] Aucune information trouvée pour le groupe');
      return null;
    }
    
    final intentLabel = QuestionAnalyzer.intentLabel(analyzed.intent);
    final answerText = '${intentLabel}s trouvés :\n\n${results.join('\n')}';
    
    print('[ANSWER GENERATED] Réponse de groupe construite avec ${results.length} résultat(s)');
    
    return AnswerResult(
      answerText: answerText,
      confidence: 'Fort',
      sourceCardIds: matchingCards.map((c) => c.id).toList(),
      sourceTitles: matchingCards.map((c) => c.title).toList(),
      values: answerValues,
    );
  }
  
  String? _extractRequestedField(CardModel card, String intent) {
    // Mapper l'intent vers les clés de champs
    final fieldKeys = <String, List<String>>{
      'social_security': ['numero_securite_sociale', 'SSN', 'NIR', 'Numéro'],
      'phone': ['Téléphone', 'Portable', 'telephone', 'phone'],
      'email': ['Email', 'email', 'Courriel'],
      'address': ['Adresse', 'address', 'Domicile'],
      'iban': ['IBAN', 'iban', 'RIB'],
      'contract': ['numero_contrat', 'Numéro contrat'],
      'birth_date': ['Date de naissance', 'birth_date'],
    };
    
    final keys = fieldKeys[intent];
    if (keys != null) {
      for (final key in keys) {
        if (card.fields.containsKey(key)) {
          return card.fields[key].toString();
        }
      }
    }
    
    // Fallback: chercher dans tous les champs
    for (final field in card.fields.entries) {
      final keyLower = field.key.toLowerCase();
      if (keyLower.contains(intent.replaceAll('_', ''))) {
        return field.value.toString();
      }
    }
    
    return card.value;
  }

  bool _isNextDeadlineQuestion(String lower) {
    return lower.contains('prochain') || lower.contains('prochaine') ||
           lower.contains('prochaine') || lower.contains('à venir') ||
           lower.contains('faut-il') || lower.contains('dois-je');
  }

  String? _detectEventType(String lower) {
    for (final entry in _eventPatterns.entries) {
      if (entry.value.any((p) => lower.contains(p))) {
        return entry.key;
      }
    }
    for (final entry in _typePatterns.entries) {
      if (entry.value.any((p) => lower.contains(p))) {
        return entry.key;
      }
    }
    return null;
  }

  AnswerResult? _answerNextDeadline(String question, List<CardModel> cards, String? eventType) {
    final subject = _subjectFromQuestion(question);

    if (eventType != null) {
      final matching = cards.where((c) => c.subType == eventType).toList();
      if (matching.isNotEmpty) {
        final card = matching.first;
        final label = _subTypeLabels[eventType]?.toLowerCase() ?? eventType;
        final dateStr = card.date != null ? _formatDate(card.date!) : 'date non spécifiée';
        final vehicle = _findFieldValue(card, 'Véhicule');
        final vehicleStr = vehicle != null ? ' pour $vehicle' : '';

        if (_isNextDeadlineQuestionFor(eventType)) {
          return AnswerResult(
            answerText: 'Je ne dispose pas actuellement des règles permettant de calculer '
                'automatiquement la prochaine échéance de $label.\n\n'
                'En revanche, le dernier $label enregistré$vehicleStr a été effectué le $dateStr.',
            confidence: 'Moyen',
            sourceCardId: card.id,
            sourceTitle: card.title,
          );
        }

        return AnswerResult(
          answerText: '$subject ${card.title} a été effectué le $dateStr$vehicleStr.',
          confidence: 'Fort',
          sourceCardId: card.id,
          sourceTitle: card.title,
        );
      }

      final label = _subTypeLabels[eventType]?.toLowerCase() ?? eventType;
      return AnswerResult(
        answerText: 'Je n\'ai trouvé aucun enregistrement concernant $label.',
        confidence: 'Faible',
      );
    }

    return null;
  }

  bool _isNextDeadlineQuestionFor(String eventType) {
    return ['controle_technique', 'revision', 'demenagement', 'changement_moteur'].contains(eventType);
  }

  String? _findFieldValue(CardModel card, String displayKey) {
    if (card.fields.containsKey(displayKey)) {
      return card.fields[displayKey].toString();
    }
    return null;
  }

  String? _findFieldValueBySubType(CardModel card, String subType) {
    final keys = _subTypeFieldKeys[subType];
    if (keys != null) {
      for (final key in keys) {
        if (card.fields.containsKey(key)) {
          return card.fields[key].toString();
        }
      }
    }
    if (card.value != null && card.value!.isNotEmpty) {
      return card.value;
    }
    return null;
  }

  String _subjectFromQuestion(String question) {
    final lower = question.toLowerCase();
    if (lower.contains('mon') || lower.contains('ma') || lower.contains('je')) {
      return 'Votre';
    }
    if (lower.contains('ton') || lower.contains('ta') || lower.contains('tu')) {
      return 'Ton';
    }
    return 'Le';
  }

  // ─── Extraction nom/prénom (tolérant aux erreurs OCR) ─────────────────────
  Map<String, String?>? _extractNomPrenom(String text) {
    final results = <String, String?>{};
    
    // Pattern 1: "nom: XXX" ou "nom XXX" (avec ou sans deux-points)
    final nomMatch = RegExp(
      r'(?:nom|name)[:\s]+([A-ZÀ-Ÿ][a-zà-ÿ]+(?:\s+[A-ZÀ-Ÿ][a-zà-ÿ]+)?)',
      caseSensitive: false,
    ).firstMatch(text);
    if (nomMatch != null) {
      results['nom'] = nomMatch.group(1)!.trim();
      print('[EXTRACT] nom trouvé via pattern "nom:": ${results['nom']}');
    }
    
    // Pattern 2: "prenom: XXX" ou "prenom XXX" ou "prénom XXX" (avec ou sans deux-points)
    final prenomMatch = RegExp(
      r'(?:pr[ée]nom|firstname)[:\s]+([A-ZÀ-Ÿ][a-zà-ÿ]+(?:\s+[A-ZÀ-Ÿ][a-zà-ÿ]+)?)',
      caseSensitive: false,
    ).firstMatch(text);
    if (prenomMatch != null) {
      results['prenom'] = prenomMatch.group(1)!.trim();
      print('[EXTRACT] prenom trouvé via pattern "prenom:": ${results['prenom']}');
    }
    
    // Pattern 3: "M. XXX YYY" ou "Mme XXX YYY"
    if (results.isEmpty) {
      final civiliteMatch = RegExp(
        r'(?:M\.?|Mme|Mr\.?)\s+([A-ZÀ-Ÿ][a-zà-ÿ]+)\s+([A-ZÀ-Ÿ][a-zà-ÿ]+)',
        caseSensitive: false,
      ).firstMatch(text);
      if (civiliteMatch != null) {
        results['prenom'] = civiliteMatch.group(1)!.trim();
        results['nom'] = civiliteMatch.group(2)!.trim();
        print('[EXTRACT] nom/prenom trouvés via pattern "M./Mme": ${results['prenom']} ${results['nom']}');
      }
    }
    
    // Pattern 4: Extraction directe "nom XXX prenom YYY" ou "prenom XXX nom YYY"
    if (results['nom'] == null) {
      final directNomMatch = RegExp(
        r'\bnom\s+([A-ZÀ-Ÿ][a-zà-ÿ]+)\b',
        caseSensitive: false,
      ).firstMatch(text);
      if (directNomMatch != null) {
        results['nom'] = directNomMatch.group(1)!.trim();
        print('[EXTRACT] nom trouvé via pattern direct "nom XXX": ${results['nom']}');
      }
    }
    
    if (results['prenom'] == null) {
      final directPrenomMatch = RegExp(
        r'\bpr[ée]nom\s+([A-ZÀ-Ÿ][a-zà-ÿ]+)\b',
        caseSensitive: false,
      ).firstMatch(text);
      if (directPrenomMatch != null) {
        results['prenom'] = directPrenomMatch.group(1)!.trim();
        print('[EXTRACT] prenom trouvé via pattern direct "prenom XXX": ${results['prenom']}');
      }
    }
    
    return results.isEmpty ? null : results;
  }

  // ─── Extraction téléphone (tolérant aux erreurs OCR) ──────────────────────
  String? _extractTelephone(String text) {
    // Pattern 1: "tel: XXX" ou "tél: XXX" ou "portable: XXX"
    final labelMatch = RegExp(
      r'(?:t[ée]l(?:[ée]phone)?|portable|mobile|phone)[:\s]+([0-9\s.\-()]{8,20})',
      caseSensitive: false,
    ).firstMatch(text);
    if (labelMatch != null) {
      final raw = labelMatch.group(1)!;
      final normalized = _normalizePhone(raw);
      print('[EXTRACT] telephone trouvé via pattern "tel:": $normalized');
      return normalized;
    }
    
    // Pattern 2: Numéro français avec parenthèses "(0X XX XX XX XX)"
    final parenMatch = RegExp(
      r'\((0[1-9])(?:[\s.-]?(\d{2})){4}\)',
    ).firstMatch(text);
    if (parenMatch != null) {
      final normalized = _normalizePhone(parenMatch.group(0)!);
      print('[EXTRACT] telephone trouvé via pattern parenthèses: $normalized');
      return normalized;
    }
    
    // Pattern 3: Numéro français standard "0X XX XX XX XX" (avec séparateurs)
    final standardMatch = RegExp(
      r'\b(0[1-9])(?:[\s.-]?\d{2}){4}\b',
    ).firstMatch(text);
    if (standardMatch != null) {
      final normalized = _normalizePhone(standardMatch.group(0)!);
      print('[EXTRACT] telephone trouvé via pattern standard: $normalized');
      return normalized;
    }
    
    // Pattern 4: Numéro français compact "0XXXXXXXXX" (10 chiffres sans séparateurs)
    final compactMatch = RegExp(
      r'\b(0[1-9]\d{8})\b',
    ).firstMatch(text);
    if (compactMatch != null) {
      final normalized = _normalizePhone(compactMatch.group(0)!);
      print('[EXTRACT] telephone trouvé via pattern compact: $normalized');
      return normalized;
    }
    
    return null;
  }
  
  String _normalizePhone(String raw) {
    // Supprimer tous les caractères non numériques
    final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
    // Formater en "0X XX XX XX XX"
    if (digits.length == 10) {
      return '${digits.substring(0, 2)} ${digits.substring(2, 4)} ${digits.substring(4, 6)} ${digits.substring(6, 8)} ${digits.substring(8, 10)}';
    }
    return digits;
  }

  // ─── Extraction email ─────────────────────────────────────────────────────
  String? _extractEmail(String text) {
    final emailMatch = RegExp(
      r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b',
    ).firstMatch(text);
    return emailMatch?.group(0);
  }
}
