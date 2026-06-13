import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static String? get currentUserId => client.auth.currentUser?.id;

  static bool get isAuthenticated => client.auth.currentUser != null;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: const String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'YOUR_SUPABASE_URL',
      ),
      anonKey: const String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue: 'YOUR_SUPABASE_ANON_KEY',
      ),
    );
  }
}
