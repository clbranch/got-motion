import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/profile_service.dart';

class SettingsAccountScreen extends StatefulWidget {
  const SettingsAccountScreen({super.key});

  @override
  State<SettingsAccountScreen> createState() => _SettingsAccountScreenState();
}

class _SettingsAccountScreenState extends State<SettingsAccountScreen> {
  static const Color _background = Color(0xFF0B0B0F);
  static const Color _cardBg = Color(0xFF14141A);
  static const Color _accent = Color(0xFF3B82F6);

  final ProfileService _profileService = ProfileService();
  ProfileData? _profile;
  bool _loading = true;
  bool _savingAvatar = false;
  bool _savingPassword = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }
    try {
      final profile = await _profileService.getCurrentProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 85);
    if (x == null || !mounted) return;
    setState(() => _savingAvatar = true);
    try {
      final file = File(x.path);
      final url = await _profileService.uploadAvatar(file);
      await _profileService.updateProfile(
        avatarUrl: url,
        avatarSource: 'custom',
      );
      if (!mounted) return;
      setState(() {
        _profile = _profile != null
            ? ProfileData(
                id: _profile!.id,
                email: _profile!.email,
                fullName: _profile!.fullName,
                displayName: _profile!.displayName,
                avatarUrl: url,
                googleAvatarUrl: _profile!.googleAvatarUrl,
                avatarSource: 'custom',
                googleAvatarLastSyncedAt: _profile!.googleAvatarLastSyncedAt,
                updatedAt: DateTime.now(),
              )
            : null;
        _savingAvatar = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couldn\'t update photo. Try again.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _changeDisplayName() async {
    final profile = _profile;
    if (profile == null) return;
    final controller = TextEditingController(text: profile.displayName ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text('Change Display Name', style: TextStyle(color: Colors.white.withValues(alpha: 0.95))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Display Name',
                labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3))),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: _accent)),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: _accent),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved != true || !mounted) return;
    try {
      final newName = controller.text.trim();
      if (newName.isEmpty) return;
      await _profileService.updateProfile(displayName: newName);
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couldn\'t update name. Try again.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _changeEmail() async {
    final currentEmail = Supabase.instance.client.auth.currentUser?.email ?? '';
    final controller = TextEditingController(text: currentEmail);

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text('Change Email', style: TextStyle(color: Colors.white.withValues(alpha: 0.95))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'A confirmation link will be sent to the new email address.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'New Email',
                labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3))),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: _accent)),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: _accent),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (saved != true || !mounted) return;
    try {
      final newEmail = controller.text.trim();
      if (newEmail.isEmpty || newEmail == currentEmail) return;

      await Supabase.instance.client.auth.updateUser(UserAttributes(email: newEmail));
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Confirmation link sent. Check your inbox.'),
          backgroundColor: Color(0xFF10B981), // green
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating email: ${e.toString()}'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _resetPassword() async {
    final email = Supabase.instance.client.auth.currentUser?.email;
    if (email == null || email.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text('Reset Password', style: TextStyle(color: Colors.white.withValues(alpha: 0.95))),
        content: Text(
          'We will send a password reset link to $email. Continue?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: _accent),
            child: const Text('Send Link'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset link sent.'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _setPasswordDirectly() async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text('Set Password', style: TextStyle(color: Colors.white.withValues(alpha: 0.95))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Set a password so you can sign in with email/password in addition to Google.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'New Password',
                labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3))),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: _accent)),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3))),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: _accent)),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: _accent),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved != true || !mounted) return;
    final password = passwordController.text;
    final confirm = confirmController.text;
    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 8 characters.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _savingPassword = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated successfully.'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update password: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _savingPassword = false);
      }
    }
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text('Delete Account', style: TextStyle(color: Colors.white.withValues(alpha: 0.95))),
        content: Text(
          'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently removed.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement full secure account deletion
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Account deletion is coming soon.'),
                  backgroundColor: Color(0xFFEF4444),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(String label) {
    return Center(
      child: Text(
        label.isNotEmpty ? label[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: _background,
        appBar: AppBar(backgroundColor: _background, elevation: 0),
        body: const Center(child: CircularProgressIndicator(color: _accent)),
      );
    }

    final displayLabel = _profile?.displayLabel ?? 'User';
    final avatarUrl = _profile?.avatarUrl;
    final email = _profile?.email ?? Supabase.instance.client.auth.currentUser?.email ?? '';
    final providers = _providerLabels(Supabase.instance.client.auth.currentUser);
    final providerSummary = providers.isEmpty ? 'Email' : providers.join(', ');

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        title: const Text('Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: GestureDetector(
                onTap: _savingAvatar ? null : _pickAndUploadAvatar,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: _cardBg,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
                      ),
                      child: ClipOval(
                        child: (avatarUrl != null && avatarUrl.isNotEmpty)
                            ? Image.network(
                                avatarUrl,
                                width: 88,
                                height: 88,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => _avatarFallback(displayLabel),
                              )
                            : _avatarFallback(displayLabel),
                      ),
                    ),
                    if (_savingAvatar)
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                          child: const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                          ),
                        ),
                      )
                    else
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: _background, width: 1.5),
                          ),
                          child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sign-in methods',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    providerSummary,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use the same verified email to sign in with either Google or email/password.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  _buildActionRow('Display Name', displayLabel, onTap: _changeDisplayName),
                  Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                  _buildActionRow('Email', email, onTap: _changeEmail),
                  Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                  _buildActionRow(
                    'Set / Change Password',
                    _savingPassword ? 'Saving...' : '',
                    onTap: _savingPassword ? () {} : _setPasswordDirectly,
                  ),
                  Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                  _buildActionRow('Send Password Reset Link', '', onTap: _resetPassword),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(16)),
              child: _buildActionRow('Delete Account', '', onTap: _showDeleteAccountDialog, isDestructive: true, showChevron: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow(String label, String value, {required VoidCallback onTap, bool isDestructive = false, bool showChevron = true}) {
    final labelColor = isDestructive ? const Color(0xFFEF4444) : Colors.white.withValues(alpha: 0.85);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: labelColor),
              ),
            ),
            if (value.isNotEmpty) ...[
              Text(
                value,
                style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.5)),
              ),
              const SizedBox(width: 8),
            ],
            if (showChevron)
              Icon(Icons.chevron_right_rounded, size: 20, color: Colors.white.withValues(alpha: 0.35)),
          ],
        ),
      ),
    );
  }

  List<String> _providerLabels(User? user) {
    if (user == null) return const [];
    final labels = <String>{};

    final appMeta = user.appMetadata;
    final providers = appMeta['providers'];
    if (providers is List) {
      for (final p in providers) {
        final lower = p.toString().toLowerCase();
        if (lower == 'google') labels.add('Google');
        if (lower == 'email') labels.add('Email');
      }
    }
    final provider = appMeta['provider']?.toString().toLowerCase();
    if (provider == 'google') labels.add('Google');
    if (provider == 'email') labels.add('Email');

    if ((user.email ?? '').isNotEmpty) labels.add('Email');
    return labels.toList();
  }
}
