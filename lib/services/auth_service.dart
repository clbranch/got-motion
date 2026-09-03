import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'selected_group_service.dart';
import 'supabase_service.dart';

/// Handles Supabase auth: email/password, Google OAuth, and Sign in with Apple.
class AuthService {
  AuthService._();

  /// Mobile deep link for email confirmation callback. Add to Supabase Auth URL configuration.
  static const String authCallbackDeepLink = 'gotmotion://auth-callback';

  static GoTrueClient get _auth => SupabaseService.client.auth;

  /// Native Sign in with Apple (iOS). Meets App Store guideline 4.8 alongside Google.
  /// Enable Apple provider in Supabase and add bundle ID `com.brogrammers.gotmotionapp`.
  static Future<String?> signInWithApple() async {
    if (kIsWeb || (!Platform.isIOS && !Platform.isMacOS)) {
      return 'Sign in with Apple is only available on iPhone and Mac.';
    }
    try {
      final rawNonce = _auth.generateRawNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        return 'Could not complete Sign in with Apple.';
      }

      await _auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );

      // Apple only returns the name on the first authorization.
      final given = credential.givenName?.trim();
      final family = credential.familyName?.trim();
      final nameParts = <String>[
        if (given != null && given.isNotEmpty) given,
        if (family != null && family.isNotEmpty) family,
      ];
      if (nameParts.isNotEmpty) {
        final fullName = nameParts.join(' ');
        try {
          await _auth.updateUser(
            UserAttributes(
              data: {
                'full_name': fullName,
                'name': fullName,
                'display_name': fullName,
                if (given != null) 'given_name': given,
                if (family != null) 'family_name': family,
              },
            ),
          );
        } catch (_) {
          // Profile sync is best-effort; session is already established.
        }
      }
      return null;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      return e.message;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

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
