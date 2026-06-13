import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class AuthService {
  SupabaseClient get _client => SupabaseService.client;

  String? get currentUserId => _client.auth.currentUser?.id;

  bool get isAuthenticated => _client.auth.currentUser != null;

  String? get currentUserEmail => _client.auth.currentUser?.email;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signInWithMagicLink({
    required String email,
  }) async {
    await _client.auth.signInWithOtp(
      email: email,
      emailRedirectTo: null,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> resetPassword({required String email}) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  Future<void> updatePassword({required String newPassword}) async {
    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  Future<void> refreshSession() async {
    await _client.auth.refreshSession();
  }
}
