import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Handles Supabase email/password auth. Session persistence is handled by Supabase.
class AuthService {
  AuthService._();

  /// Mobile deep link for email confirmation callback. Add to Supabase Auth URL configuration.
  static const String authCallbackDeepLink = 'gotmotion://auth-callback';

  static GoTrueClient get _auth => SupabaseService.client.auth;

  static Session? get currentSession => _auth.currentSession;

  /// Sign up with email and password. Uses [authCallbackDeepLink] for email confirmation redirect.
  /// Returns error message on failure.
  static Future<String?> signUp({
    required String email,
    required String password,
    String? emailRedirectTo,
  }) async {
    try {
      await _auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: emailRedirectTo ?? authCallbackDeepLink,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  /// Sign in with email and password. Returns error message on failure.
  static Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithPassword(email: email, password: password);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  /// Sign out. Session is cleared; auth state listener will send user to Auth screen.
  static Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Sends a password reset email. Uses [authCallbackDeepLink] for redirect after reset.
  /// Returns error message on failure.
  static Future<String?> resetPasswordForEmail({
    required String email,
    String? redirectTo,
  }) async {
    try {
      await _auth.resetPasswordForEmail(
        email,
        redirectTo: redirectTo ?? authCallbackDeepLink,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  /// Updates the current user's password. Use after recovering session from reset link.
  /// Returns error message on failure.
  static Future<String?> updatePassword(String newPassword) async {
    try {
      await _auth.updateUser(UserAttributes(password: newPassword));
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }
}
