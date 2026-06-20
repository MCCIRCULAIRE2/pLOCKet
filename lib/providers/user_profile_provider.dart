import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import '../services/cloud_repository.dart';

class UserProfileProvider extends ChangeNotifier {
  final CloudRepository _cloudRepo = CloudRepository();

  UserProfile? _profile;
  UserProfile? get profile => _profile;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> loadProfile() async {
    debugPrint('[USER_PROFILE] ═══════════════════════════════════════════════════════════');
    debugPrint('[USER_PROFILE] Chargement du profil utilisateur');
    debugPrint('[USER_PROFILE] ═══════════════════════════════════════════════════════════');

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _profile = await _cloudRepo.getUserProfile();

      if (_profile != null && _profile!.isNotEmpty) {
        debugPrint('[USER_PROFILE] ✓ Profil chargé avec succès');
        debugPrint('[USER_PROFILE]   Nom complet: ${_profile!.nomComplet}');
        if (_profile!.email != null) debugPrint('[USER_PROFILE]   Email: ${_profile!.email}');
        if (_profile!.phone != null) debugPrint('[USER_PROFILE]   Téléphone: ${_profile!.phone}');
        if (_profile!.adressePostale != null) debugPrint('[USER_PROFILE]   Adresse: ${_profile!.adressePostale}');
        if (_profile!.numeroSecuriteSociale != null) debugPrint('[USER_PROFILE]   N° SS: ${_profile!.numeroSecuriteSociale}');
      } else {
        debugPrint('[USER_PROFILE] ⚠ Aucun profil configuré');
      }

      debugPrint('[USER_PROFILE] ═══════════════════════════════════════════════════════════');
    } catch (e) {
      debugPrint('[USER_PROFILE] ❌ Erreur: $e');
      _error = 'Erreur lors du chargement du profil: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveProfile(UserProfile profile) async {
    debugPrint('[USER_PROFILE] ═══════════════════════════════════════════════════════════');
    debugPrint('[USER_PROFILE] Sauvegarde du profil utilisateur');
    debugPrint('[USER_PROFILE] ═══════════════════════════════════════════════════════════');

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _cloudRepo.saveUserProfile(profile);
      _profile = profile;

      debugPrint('[USER_PROFILE] ✓ Profil sauvegardé avec succès');
      if (profile.nomComplet.isNotEmpty) {
        debugPrint('[USER_PROFILE]   Nom complet: ${profile.nomComplet}');
      }
      if (profile.email != null) debugPrint('[USER_PROFILE]   Email: ${profile.email}');
      if (profile.phone != null) debugPrint('[USER_PROFILE]   Téléphone: ${profile.phone}');
      if (profile.adressePostale != null) debugPrint('[USER_PROFILE]   Adresse: ${profile.adressePostale}');
      if (profile.numeroSecuriteSociale != null) debugPrint('[USER_PROFILE]   N° SS: ${profile.numeroSecuriteSociale}');

      debugPrint('[USER_PROFILE] ═══════════════════════════════════════════════════════════');
    } catch (e) {
      debugPrint('[USER_PROFILE] ❌ Erreur: $e');
      _error = 'Erreur lors de la sauvegarde du profil: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> deleteProfile() async {
    debugPrint('[USER_PROFILE] ═══════════════════════════════════════════════════════════');
    debugPrint('[USER_PROFILE] Suppression du profil utilisateur');
    debugPrint('[USER_PROFILE] ═══════════════════════════════════════════════════════════');

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final emptyProfile = UserProfile(
        userId: _profile?.userId ?? '',
        onboardingCompleted: false,
      );
      await _cloudRepo.saveUserProfile(emptyProfile);
      _profile = null;

      debugPrint('[USER_PROFILE] ✓ Profil supprimé avec succès');
      debugPrint('[USER_PROFILE] ═══════════════════════════════════════════════════════════');
    } catch (e) {
      debugPrint('[USER_PROFILE] ❌ Erreur: $e');
      _error = 'Erreur lors de la suppression du profil: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> setPrimaryPersonEntity(String entityId) async {
    final currentProfile = _profile;
    if (currentProfile == null) return;

    final updated = currentProfile.copyWith(primaryPersonEntityId: entityId);
    await saveProfile(updated);
  }

  Map<String, String> detectProfileMatches(String text) {
    final matches = <String, String>{};
    final textLower = text.toLowerCase();

    if (_profile == null || _profile!.isEmpty) {
      return matches;
    }

    debugPrint('[USER_PROFILE] ═══════════════════════════════════════════════════════════');
    debugPrint('[USER_PROFILE] Détection des correspondances avec le profil utilisateur');
    debugPrint('[USER_PROFILE] ═══════════════════════════════════════════════════════════');

    if (_profile!.nomComplet.isNotEmpty &&
        textLower.contains(_profile!.nomComplet.toLowerCase())) {
      matches['nom_complet'] = _profile!.nomComplet;
      debugPrint('[USER_PROFILE] ✓ Nom complet détecté: ${_profile!.nomComplet}');
    }

    if (_profile!.firstName != null &&
        textLower.contains(_profile!.firstName!.toLowerCase())) {
      matches['prenom'] = _profile!.firstName!;
      debugPrint('[USER_PROFILE] ✓ Prénom détecté: ${_profile!.firstName}');
    }

    if (_profile!.lastName != null &&
        textLower.contains(_profile!.lastName!.toLowerCase())) {
      matches['nom'] = _profile!.lastName!;
      debugPrint('[USER_PROFILE] ✓ Nom détecté: ${_profile!.lastName}');
    }

    if (_profile!.email != null &&
        textLower.contains(_profile!.email!.toLowerCase())) {
      matches['email'] = _profile!.email!;
      debugPrint('[USER_PROFILE] ✓ Email détecté: ${_profile!.email}');
    }

    if (_profile!.phone != null) {
      final telNormalized = _profile!.phone!.replaceAll(RegExp(r'[^\d]'), '');
      final textNormalized = text.replaceAll(RegExp(r'[^\d]'), '');
      if (textNormalized.contains(telNormalized)) {
        matches['telephone'] = _profile!.phone!;
        debugPrint('[USER_PROFILE] ✓ Téléphone détecté: ${_profile!.phone}');
      }
    }

    if (_profile!.adressePostale != null &&
        _profile!.adressePostale!.length > 10) {
      final addrWords = _profile!.adressePostale!.toLowerCase().split(' ');
      final textLower = text.toLowerCase();
      int matchCount = 0;
      for (final word in addrWords) {
        if (word.length > 3 && textLower.contains(word)) {
          matchCount++;
        }
      }
      if (matchCount >= addrWords.length * 0.5) {
        matches['adresse'] = _profile!.adressePostale!;
        debugPrint('[USER_PROFILE] ✓ Adresse détectée: ${_profile!.adressePostale}');
      }
    }

    if (_profile!.numeroSecuriteSociale != null) {
      final ssNormalized = _profile!.numeroSecuriteSociale!.replaceAll(RegExp(r'[^\d]'), '');
      final textNormalized = text.replaceAll(RegExp(r'[^\d]'), '');
      if (textNormalized.contains(ssNormalized)) {
        matches['numero_securite_sociale'] = _profile!.numeroSecuriteSociale!;
        debugPrint('[USER_PROFILE] ✓ N° SS détecté: ${_profile!.numeroSecuriteSociale}');
      }
    }

    if (_profile!.iban != null) {
      final ibanNormalized = _profile!.iban!.replaceAll(RegExp(r'[^\w]'), '');
      final textNormalized = text.replaceAll(RegExp(r'[^\w]'), '');
      if (textNormalized.contains(ibanNormalized)) {
        matches['iban'] = _profile!.iban!;
        debugPrint('[USER_PROFILE] ✓ IBAN détecté: ${_profile!.iban}');
      }
    }

    debugPrint('[USER_PROFILE] ${matches.length} correspondance(s) détectée(s)');
    debugPrint('[USER_PROFILE] ═══════════════════════════════════════════════════════════');

    return matches;
  }

  String? answerProfileQuestion(String question) {
    final questionLower = question.toLowerCase();

    if (_profile == null || _profile!.isEmpty) {
      return null;
    }

    final isProfileQuery = questionLower.contains('moi') ||
        questionLower.contains('mon ') ||
        questionLower.contains('ma ') ||
        questionLower.contains('mes ') ||
        questionLower.contains('mon profil') ||
        questionLower.contains('mes informations');

    if (!isProfileQuery) {
      return null;
    }

    debugPrint('[USER_PROFILE] ═══════════════════════════════════════════════════════════');
    debugPrint('[USER_PROFILE] Réponse à une question sur le profil');
    debugPrint('[USER_PROFILE] Question: $question');
    debugPrint('[USER_PROFILE] ═══════════════════════════════════════════════════════════');

    if (questionLower.contains('téléphone') || questionLower.contains('telephone') || questionLower.contains('numéro')) {
      if (_profile!.phone != null) {
        debugPrint('[USER_PROFILE] ✓ Réponse: ${_profile!.phone}');
        return _profile!.phone;
      }
    }

    if (questionLower.contains('email') || questionLower.contains('mail')) {
      if (_profile!.email != null) {
        debugPrint('[USER_PROFILE] ✓ Réponse: ${_profile!.email}');
        return _profile!.email;
      }
    }

    if (questionLower.contains('adresse')) {
      if (_profile!.adressePostale != null) {
        debugPrint('[USER_PROFILE] ✓ Réponse: ${_profile!.adressePostale}');
        return _profile!.adressePostale;
      }
    }

    if (questionLower.contains('sécurité sociale') || questionLower.contains('securite sociale')) {
      if (_profile!.numeroSecuriteSociale != null) {
        debugPrint('[USER_PROFILE] ✓ Réponse: ${_profile!.numeroSecuriteSociale}');
        return _profile!.numeroSecuriteSociale;
      }
    }

    if (questionLower.contains('iban')) {
      if (_profile!.iban != null) {
        debugPrint('[USER_PROFILE] ✓ Réponse: ${_profile!.iban}');
        return _profile!.iban;
      }
    }

    if (questionLower.contains('nom')) {
      if (_profile!.nomComplet.isNotEmpty) {
        debugPrint('[USER_PROFILE] ✓ Réponse: ${_profile!.nomComplet}');
        return _profile!.nomComplet;
      }
    }

    debugPrint('[USER_PROFILE] ⚠ Aucune réponse trouvée');
    return null;
  }
}
