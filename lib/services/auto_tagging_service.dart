import '../models/tag.dart';
import '../database/daos/tag_dao.dart';

class AutoTaggingService {
  final TagDao _tagDao = TagDao();

  Future<List<Tag>> generateTags(String title, String? ocrText) async {
    final text = '$title ${ocrText ?? ''}'.toLowerCase();
    final matchedTags = <Tag>[];
    final allTags = await _tagDao.getAll();

    for (final tag in allTags) {
      if (_matchesTag(text, tag)) {
        matchedTags.add(tag);
      }
    }

    return matchedTags;
  }

  bool _matchesTag(String text, Tag tag) {
    final keywords = _keywordsForTag(tag);
    return keywords.any((kw) => text.contains(kw));
  }

  List<String> _keywordsForTag(Tag tag) {
    final map = <String, List<String>>{
      'type_facture': ['facture', 'paiement', 'montant', 'somme', 'tva', 'htc'],
      'type_contrat': ['contrat', 'signature', 'engagement', 'convention'],
      'type_attestation': ['attestation', 'certificat', 'certification'],
      'type_identite': ['identité', 'passeport', 'carte nationale', 'permis'],
      'type_bulletin': ['bulletin', 'salaire', 'paye', 'rémunération', 'paie'],
      'type_courrier': ['courrier', 'lettre', 'notification'],
      'domaine_automobile': ['auto', 'automobile', 'véhicule', 'voiture', 'carte grise',
          'immatriculation', 'permis de conduire'],
      'domaine_habitation': ['logement', 'habitation', 'locataire', 'bail', 'propriétaire',
          'appartement', 'maison', 'résidence'],
      'domaine_sante': ['santé', 'médical', 'hôpital', 'médecin', 'mutuelle', 'sécurité sociale'],
      'domaine_banque': ['banque', 'compte', 'rib', 'iban', 'crédit', 'épargne', 'relevé'],
      'domaine_fiscalite': ['impôt', 'fiscal', 'déclaration', 'revenu', 'taxe', 'fisc'],
      'domaine_travail': ['travail', 'emploi', 'employeur', 'contrat travail', 'licenciement'],
      'sousdomaine_assurance': ['assurance', 'garantie', 'sinistre'],
      'sousdomaine_entretien': ['entretien', 'maintenance', 'révision', 'réparation'],
      'sousdomaine_credit': ['crédit', 'prêt', 'emprunt', 'échéance', 'amortissement'],
      'sousdomaine_garantie': ['garantie', 'sav', 'service après-vente'],
    };
    return map[tag.id] ?? [tag.label.toLowerCase()];
  }
}
