import 'package:supabase_flutter/supabase_flutter.dart';

import 'selected_group_service.dart';
import 'supabase_service.dart';

/// Handles Supabase auth: email/password and Google OAuth. Session persistence is handled by Supabase.
class AuthService {
  AuthService._();

  /// Mobile deep link for email confirmation callback. Add to Supabase Auth URL configuration.
  static const String authCallbackDeepLink = 'gotmotion://auth-callback';

  static GoTrueClient get _auth => SupabaseService.client.auth;

  /// Sign in with Google (OAuth). Redirects to browser; on return session is set.
  /// Ensure Google provider is enabled and redirect URL configured in Supabase Dashboard.
  static Future<String?> signInWithGoogle() async {
    try {
      await _auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: authCallbackDeepLink,
        queryParams: const {
          // Always show Google account chooser so users can explicitly pick.
          'prompt': 'select_account',
        },
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  static Session? get currentSession => _auth.currentSession;

  /// Sign up with email and password. Uses [authCallbackDeepLink] for email confirmation redirect.
  /// Returns error message on failure.
  static Future<String?> signUp({
    required String email,
    required String password,
    required String displayName,
    String? emailRedirectTo,
  }) async {
    try {
      await _auth.signUp(
        email: email,
        password: password,
        data: {
          'display_name': displayName,
          'name':
              displayName, // Fallback for some auth providers or default mappings
        },
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

  /// Permanently deletes the current user via Edge Function (cascades app data).
  /// Returns error message on failure.
  static Future<String?> deleteAccount() async {
    try {
      final session = _auth.currentSession;
      if (session == null) return 'Not signed in';

      final response = await SupabaseService.client.functions.invoke(
        'delete-account',
      );
      final status = response.status;
      if (status >= 400) {
        final data = response.data;
        if (data is Map && data['error'] != null) {
          return data['error'].toString();
        }
        return 'Could not delete account ($status)';
      }

      selectedGroupService.clear();
      try {
        await _auth.signOut();
      } catch (_) {
        // Session may already be invalid after delete.
      }
      return null;
    } on FunctionException catch (e) {
      final details = e.details;
      if (details is Map && details['error'] != null) {
        return details['error'].toString();
      }
      return e.reasonPhrase ?? 'Could not delete account';
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  /// Sign out. Session is cleared; auth state listener will send user to Auth screen.
  static Future<void> signOut() async {
    selectedGroupService.clear();
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
