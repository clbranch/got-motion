import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/deep_link_handler.dart';
import '../services/supabase_service.dart';
import 'create_account_screen.dart';
import 'login_screen.dart';
import 'main_nav.dart';
import 'reset_password_screen.dart';
import 'set_new_password_screen.dart';

/// Shows MainNav when user has a session; Set New Password when session came from reset link;
/// otherwise a Navigator with Login, Create Account, Reset Password screens.
/// Listens to Supabase auth state and deep links for auth-callback.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoggedIn = false;
  bool _initialized = false;
  bool _pendingPasswordSet = false;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    // Listen first so we never miss passwordRecovery when recoverSession runs.
    SupabaseService.client.auth.onAuthStateChange.listen(_onAuthStateChange);
    _linkSubscription = DeepLinkHandler.uriLinkStream.listen(_onLink);
    _checkSession();
  }

  void _onAuthStateChange(AuthState data) {
    final isRecovery = data.event == AuthChangeEvent.passwordRecovery;
    // ignore: avoid_print
    print('[Auth] onAuthStateChange: event=${data.event.name} session=${data.session != null} isRecovery=$isRecovery');
    if (mounted) {
      setState(() {
        _isLoggedIn = data.session != null;
        if (isRecovery) {
          _pendingPasswordSet = true;
          // ignore: avoid_print
          print('[Auth] onAuthStateChange: recovery callback -> SetNewPasswordScreen (not ForgotPasswordScreen)');
        }
      });
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  /// Returns true if the initial link was a recovery callback (so we must show SetNewPasswordScreen).
  Future<bool> _handleInitialLink() async {
    Uri? uri = await DeepLinkHandler.getInitialUri();
    // ignore: avoid_print
    print('[Auth] getInitialUri: ${uri != null ? "got uri (${uri.toString().length} chars)" : "null"}');
    if (uri == null) {
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return false;
      uri = await DeepLinkHandler.getInitialUri();
      // ignore: avoid_print
      print('[Auth] getInitialUri after delay: ${uri != null ? "got uri" : "still null"}');
    }
    if (uri == null) return false;
    final isRecoveryHandled = await DeepLinkHandler.handleAuthCallback(uri);
    // ignore: avoid_print
    print('[Auth] _handleInitialLink: isRecoveryHandled=$isRecoveryHandled');
    return isRecoveryHandled;
  }

  Future<void> _onLink(Uri uri) async {
    // ignore: avoid_print
    print('[Auth] _onLink (warm): ${uri.toString().length > 60 ? "uri received" : uri}');
    final isRecoveryHandled = await DeepLinkHandler.handleAuthCallback(uri);
    if (mounted && isRecoveryHandled) {
      setState(() => _pendingPasswordSet = true);
      // ignore: avoid_print
      print('[Auth] _onLink: set _pendingPasswordSet=true, navigating to SetNewPasswordScreen');
    }
  }

  Future<void> _checkSession() async {
    final wasRecoveryFromLink = await _handleInitialLink();
    if (!mounted) return;
    final session = SupabaseService.client.auth.currentSession;
    setState(() {
      _isLoggedIn = session != null;
      _initialized = true;
      // Never clear _pendingPasswordSet if already set by onAuthStateChange (passwordRecovery).
      _pendingPasswordSet = _pendingPasswordSet || wasRecoveryFromLink;
    });
    // ignore: avoid_print
    print('[Auth] _checkSession: session=${session != null}, wasRecoveryFromLink=$wasRecoveryFromLink -> _pendingPasswordSet=${_pendingPasswordSet}');
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B0B0F),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
        ),
      );
    }
    if (_pendingPasswordSet) {
      // Recovery email callback: always go to Set New Password (enter new + confirm), never to request/success screen.
      // ignore: avoid_print
      print('[Auth] build: recovery flow -> SetNewPasswordScreen (source: recovery email callback)');
      return SetNewPasswordScreen(
        // Called after user taps Continue on success. SetNewPasswordScreen signs out first, then calls this.
        // Navigation to Login: we clear _pendingPasswordSet here; signOut makes _isLoggedIn false -> build shows Login.
        // Previously we only cleared _pendingPasswordSet, so _isLoggedIn stayed true -> we fell through to MainNav.
        onPasswordSet: () {
          setState(() => _pendingPasswordSet = false);
          // ignore: avoid_print
          print('[Auth] build: after reset complete -> route to Login (user signs in with new password)');
        },
      );
    }
    if (_isLoggedIn) {
      // ignore: avoid_print
      print('[Auth] build: normal session -> MainNav');
      return const MainNav();
    }
    // Manual flow: Login first; ForgotPasswordScreen only via "Forgot password?" tap.
    // ignore: avoid_print
    print('[Auth] build: no session -> Login; ForgotPasswordScreen only via manual "Forgot password?"');
    return Navigator(
      initialRoute: '/login',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute<void>(
              builder: (_) => const LoginScreen(),
              settings: settings,
            );
          case '/create-account':
            return MaterialPageRoute<void>(
              builder: (_) => const CreateAccountScreen(),
              settings: settings,
            );
          case '/reset-password':
            // ForgotPasswordScreen = request reset email + "Check your email" success. Only reached from Login "Forgot password?".
            // ignore: avoid_print
            print('[Auth] Navigator: opening ForgotPasswordScreen (request/success) - manual flow only');
            return MaterialPageRoute<void>(
              builder: (_) => const ResetPasswordScreen(),
              settings: settings,
            );
          default:
            return MaterialPageRoute<void>(
              builder: (_) => const LoginScreen(),
              settings: settings,
            );
        }
      },
    );
  }
}
