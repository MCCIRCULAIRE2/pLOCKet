import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_profile.dart';

class UserProfileDao {
  static const String _storageKey = 'user_profile';

  Future<UserProfile?> getProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_storageKey);
      
      if (data != null && data.isNotEmpty) {
        final map = jsonDecode(data) as Map<String, dynamic>;
        return UserProfile.fromMap(map);
      }
      
      return null;
    } catch (e) {
      print('[USER_PROFILE] Erreur chargement profil: $e');
      return null;
    }
  }

  Future<void> saveProfile(UserProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(profile.toMap());
      await prefs.setString(_storageKey, data);
      print('[USER_PROFILE] ✓ Profil sauvegardé');
    } catch (e) {
      print('[USER_PROFILE] Erreur sauvegarde profil: $e');
      throw Exception('Erreur lors de la sauvegarde du profil: $e');
    }
  }

  Future<void> deleteProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      print('[USER_PROFILE] ✓ Profil supprimé');
    } catch (e) {
      print('[USER_PROFILE] Erreur suppression profil: $e');
      throw Exception('Erreur lors de la suppression du profil: $e');
    }
  }
}
