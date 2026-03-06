import 'package:flutter/material.dart';

import '../services/auth_service.dart';

/// ForgotPasswordScreen: request reset email + "Check your email" success.
/// Only reached via Login "Forgot password?" (manual flow). Recovery email link opens SetNewPasswordScreen instead.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  static const Color _background = Color(0xFF0B0B0F);
  static const Color _cardBg = Color(0xFF14141A);
  static const Color _accent = Color(0xFF3B82F6);
  static const double _pagePadding = 24.0;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _loading = false;
  String? _errorMessage;
  bool _success = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    _clearError();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final error = await AuthService.resetPasswordForEmail(
      email: _emailController.text.trim(),
      redirectTo: AuthService.authCallbackDeepLink,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (error != null) {
        _errorMessage = error;
      } else {
        _success = true;
      }
    });
  }

  void _clearError() {
    if (_errorMessage != null) setState(() => _errorMessage = null);
  }

  @override
  Widget build(BuildContext context) {
    // ignore: avoid_print
    print('[Auth] ForgotPasswordScreen (request/success) visible - manual flow only');
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: Colors.white.withValues(alpha: 0.9)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Forgot password',
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
              Icons.mark_email_read_rounded,
              size: 64,
              color: _accent.withValues(alpha: 0.9),
            ),
            const SizedBox(height: 24),
            Text(
              'Check your email for a password reset link.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 32),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Back to login',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF3B82F6),
                  fontWeight: FontWeight.w600,
                ),
              ),
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
            Text(
              'Enter your email and we\'ll send you a reset link.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
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
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: _inputDecoration('Email'),
                    style: const TextStyle(color: Colors.white),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter your email';
                      if (!v.contains('@')) return 'Enter a valid email';
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
                    onPressed: _loading ? null : _sendResetLink,
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
                        : const Text('Send reset link'),
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
