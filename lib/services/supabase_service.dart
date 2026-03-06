import 'package:supabase_flutter/supabase_flutter.dart';

/// Exposes the Supabase client for the app. Supabase must be initialized in main() first.
class SupabaseService {
  SupabaseService._();

  static SupabaseClient get client => Supabase.instance.client;
}
