import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'supabase_service.dart';

/// Handles auth deep links (e.g. gotmotion://auth-callback for password reset)
/// and invite links (e.g. gotmotion://join/<code_here>).
class DeepLinkHandler {
  DeepLinkHandler._();

  static final AppLinks _appLinks = AppLinks();

  /// Scheme and host for auth callback. Must match [AuthService.authCallbackDeepLink].
  static const String authCallbackScheme = 'gotmotion';
  static const String authCallbackHost = 'auth-callback';
  
  /// Host for join group links.
  static const String joinHost = 'join';

  /// Supabase puts [type=recovery] in the redirect fragment for password reset links.
  static const String _recoveryType = 'recovery';

  /// Holds the pending invite code if the app was launched via an invite link.
  static final ValueNotifier<String?> pendingInviteCode = ValueNotifier(null);

  /// Extracts invite code from uri if present. (e.g. gotmotion://join/ABCDEF or gotmotion://join?code=ABCDEF)
  static String? extractInviteCode(Uri uri) {
    if (uri.scheme == authCallbackScheme && uri.host == joinHost) {
      String? code;
      if (uri.pathSegments.isNotEmpty) {
        code = uri.pathSegments.first;
      } else {
        code = uri.queryParameters['code'];
      }
      if (kDebugMode) {
        print('[DeepLinkHandler] extracted invite code: $code from uri: $uri');
      }
      return code;
    }
    return null;
  }

  /// Returns true if the URI fragment or query contains type=recovery (password reset flow).
  /// Supabase may put it in fragment (e.g. #access_token=...&type=recovery) or in path/query.
  static bool isRecoveryCallback(Uri uri) {
    final fragment = uri.fragment;
    if (fragment.isNotEmpty) {
      if (fragment.contains('type=recovery') || fragment.contains('type%3Drecovery')) {
        return true;
      }
      final params = Uri.splitQueryString(fragment);
      if (params['type'] == _recoveryType) return true;
    }
    if (uri.queryParameters['type'] == _recoveryType) return true;
    if (uri.toString().contains('type=recovery') || uri.toString().contains('type%3Drecovery')) {
      return true;
    }
    return false;
  }

  /// Call when the app is opened or resumed with a URI (e.g. from reset-password email link).
  /// Recovers session from the URL. Returns true only when the callback is a *recovery* flow
  /// so the auth gate routes to Set New Password; other callbacks (e.g. signup) recover session but return false.
  static Future<bool> handleAuthCallback(Uri uri) async {
    if (uri.scheme != authCallbackScheme || uri.host != authCallbackHost) {
      return false;
    }
    final isRecovery = isRecoveryCallback(uri);
    final hasOAuthCode = uri.queryParameters.containsKey('code');

    // OAuth callbacks (e.g. Google sign-in) often come back as ?code=...
    // supabase_flutter handles those automatically; calling recoverSession here
    // can throw a JSON parse error and cause blank-screen behavior.
    if (!isRecovery && hasOAuthCode) {
      // ignore: avoid_print
      print('[Auth] handleAuthCallback: oauth code callback detected, skipping recoverSession');
      return false;
    }

    // ignore: avoid_print
    print('[Auth] handleAuthCallback: recovery=${isRecovery} (recovery email callback -> SetNewPasswordScreen) uri=${uri.toString().length > 80 ? '${uri.toString().substring(0, 80)}...' : uri}');
    try {
      await SupabaseService.client.auth.recoverSession(uri.toString());
      // ignore: avoid_print
      print('[Auth] recoverSession done, returning isRecovery=$isRecovery');
      return isRecovery;
    } catch (e) {
      // ignore: avoid_print
      print('[Auth] recoverSession error: $e');
      return false;
    }
  }

  /// Gets the initial URI when the app was launched from a link (cold start).
  /// Call early (e.g. from AuthGate initState). Returns null if not launched from a link.
  static Future<Uri?> getInitialUri() async {
    try {
      return await _appLinks.getInitialLink();
    } catch (_) {
      return null;
    }
  }

  /// Stream of links when the app is opened from a link while running (warm start).
  /// Listen in AuthGate and call [handleAuthCallback] when a URI is received.
  static Stream<Uri> get uriLinkStream => _appLinks.uriLinkStream;
}
