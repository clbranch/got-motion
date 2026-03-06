import 'package:flutter/material.dart';

import '../services/auth_service.dart';

/// SetNewPasswordScreen: enter new password + confirm + submit. Only shown when app is opened from recovery email link.
class SetNewPasswordScreen extends StatefulWidget {
  const SetNewPasswordScreen({
    super.key,
    required this.onPasswordSet,
  });

  final VoidCallback onPasswordSet;

  @override
  State<SetNewPasswordScreen> createState() => _SetNewPasswordScreenState();
}

class _SetNewPasswordScreenState extends State<SetNewPasswordScreen> {
  static const Color _background = Color(0xFF0B0B0F);
  static const Color _cardBg = Color(0xFF14141A);
  static const Color _accent = Color(0xFF3B82F6);
  static const double _pagePadding = 24.0;

  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;
  String? _errorMessage;
  bool _success = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    _clearError();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final error = await AuthService.updatePassword(_passwordController.text);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (error != null) {
        _errorMessage = error;
      } else {
        _success = true;
        // ignore: avoid_print
        print('[Auth] password reset success -> show success state, then Continue -> sign out -> Login');
      }
    });
  }

  /// Password-update success is handled in _submit() (sets _success = true). Here we handle "Continue":
  /// sign out (clear recovery session) then notify AuthGate so it routes to Login instead of MainNav.
  Future<void> _onContinueAfterSuccess() async {
    // ignore: avoid_print
    print('[Auth] signing out after password reset (do not auto-enter app)');
    await AuthService.signOut();
    if (!mounted) return;
    // ignore: avoid_print
    print('[Auth] final route after reset: Login screen');
    widget.onPasswordSet();
  }

  void _clearError() {
    if (_errorMessage != null) setState(() => _errorMessage = null);
  }

  @override
  Widget build(BuildContext context) {
    // ignore: avoid_print
    print('[Auth] SetNewPasswordScreen visible (recovery email callback only)');
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Set new password',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.95),
          ),
        ),
      ),
      body: SafeArea(
        child: _success ? _buildSuccessView() : _buildFormView(),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _pagePadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_rounded,
              size: 64,
              color: _accent.withValues(alpha: 0.9),
            ),
            const SizedBox(height: 24),
            Text(
              'Password updated.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _onContinueAfterSuccess,
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: _pagePadding),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    autocorrect: false,
                    decoration: _inputDecoration('New password'),
                    style: const TextStyle(color: Colors.white),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter a password';
                      if (v.length < 6) return 'Password must be at least 6 characters';
                      return null;
                    },
                    onChanged: (_) => _clearError(),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    autocorrect: false,
                    decoration: _inputDecoration('Confirm new password'),
                    style: const TextStyle(color: Colors.white),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Confirm your password';
                      if (v != _passwordController.text) return 'Passwords do not match';
                      return null;
                    },
                    onChanged: (_) => _clearError(),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Update password'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  static InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
    );
  }
}
