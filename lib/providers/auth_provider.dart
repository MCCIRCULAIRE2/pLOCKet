import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated, loading }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  AuthStatus _status = AuthStatus.unknown;
  String? _error;
  StreamSubscription<AuthState>? _authSubscription;

  AuthProvider() {
    _init();
  }

  AuthStatus get status => _status;
  String? get error => _error;
  String? get userId => _authService.currentUserId;
  String? get email => _authService.currentUserEmail;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;

  void _init() {
    if (_authService.isAuthenticated) {
      _status = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }

    _authSubscription = _authService.authStateChanges.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed) {
        _status = AuthStatus.authenticated;
        _error = null;
      } else if (event == AuthChangeEvent.signedOut) {
        _status = AuthStatus.unauthenticated;
        _error = null;
      }
      notifyListeners();
    });
  }

  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    _status = AuthStatus.loading;
    _error = null;
    notifyListeners();

    try {
      await _authService.signUpWithEmail(
        email: email,
        password: password,
      );
      _status = AuthStatus.authenticated;
    } catch (e) {
      _error = _parseError(e);
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    _status = AuthStatus.loading;
    _error = null;
    notifyListeners();

    try {
      await _authService.signInWithEmail(
        email: email,
        password: password,
      );
      _status = AuthStatus.authenticated;
    } catch (e) {
      _error = _parseError(e);
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> sendMagicLink({required String email}) async {
    _status = AuthStatus.loading;
    _error = null;
    notifyListeners();

    try {
      await _authService.signInWithMagicLink(email: email);
      _status = AuthStatus.unauthenticated;
    } catch (e) {
      _error = _parseError(e);
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      await _authService.signOut();
      _status = AuthStatus.unauthenticated;
    } catch (e) {
      _error = _parseError(e);
    }
    notifyListeners();
  }

  Future<void> resetPassword({required String email}) async {
    _error = null;
    notifyListeners();

    try {
      await _authService.resetPassword(email: email);
    } catch (e) {
      _error = _parseError(e);
    }
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _parseError(dynamic e) {
    if (e is AuthException) {
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid login credentials')) {
        return 'Email ou mot de passe incorrect';
      }
      if (msg.contains('email not confirmed')) {
        return 'Veuillez confirmer votre email';
      }
      if (msg.contains('user already registered')) {
        return 'Un compte existe déjà avec cet email';
      }
      if (msg.contains('password')) {
        return 'Le mot de passe doit contenir au moins 6 caractères';
      }
      return e.message;
    }
    return 'Erreur de connexion : $e';
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
