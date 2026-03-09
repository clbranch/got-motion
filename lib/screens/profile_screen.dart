import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/today_metrics.dart';
import '../services/daily_steps_service.dart';
import '../services/health_service.dart';
import '../services/profile_service.dart';

/// Profile: avatar, display name, today summary. Edit and avatar upload via ProfileService.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _background = Color(0xFF0B0B0F);
  static const Color _cardBg = Color(0xFF14141A);
  static const Color _accent = Color(0xFF3B82F6);
  static const double _pagePadding = 16.0;

  final ProfileService _profileService = ProfileService();
  final DailyStepsService _dailyStepsService = DailyStepsService();

  TodayMetrics? _today;
  ProfileData? _profile;
  bool _loading = true;
  bool _savingAvatar = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _profile = null;
        _today = TodayMetrics.zero;
        _loading = false;
      });
      return;
    }
    final results = await Future.wait([
      HealthService.getTodayMetrics(),
      _profileService.getCurrentProfile(),
    ]);
    if (!mounted) return;
    final today = results[0] as TodayMetrics;
    setState(() {
      _today = today;
      _profile = results[1] as ProfileData?;
      _loading = false;
    });
    // Sync today's stats to Supabase so group leaderboard has shared data (background).
    _syncTodayToSupabase(user.id, today);
  }

  void _syncTodayToSupabase(String userId, TodayMetrics today) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[DailySteps] Triggering sync from Profile');
    }
    Future(() async {
      try {
        await _dailyStepsService.upsertDailySteps(
          userId: userId,
          date: DateTime.now(),
          steps: today.steps,
          miles: today.distanceMiles,
          activeCalories: today.activeEnergyCalories.round(),
          exerciseMinutes: today.exerciseMinutes.round(),
        );
      } catch (e, stack) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('[DailySteps] Profile sync failed — exception: $e');
          // ignore: avoid_print
          print('[DailySteps] Profile sync failed — stack: $stack');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _accent))
            : RefreshIndicator(
                onRefresh: _load,
                color: _accent,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(_pagePadding, 16, _pagePadding, 24),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildAvatarAndName(),
                    const SizedBox(height: 24),
                    _buildTodaySummary(),
                    const SizedBox(height: 18),
                    _buildWeeklyPlaceholder(),
                    const SizedBox(height: 18),
                    _buildPersonalStatsPlaceholder(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        'Profile',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: 0.95),
        ),
      ),
    );
  }

  Widget _buildAvatarAndName() {
    final profile = _profile;
    final displayLabel = profile?.displayLabel ?? 'User';
    final avatarUrl = profile?.avatarUrl;

    return Column(
      children: [
        GestureDetector(
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
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
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
        const SizedBox(height: 12),
        Text(
          displayLabel,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          profile?.email ?? '',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _loading ? null : _openEditProfile,
          icon: const Icon(Icons.edit_rounded, size: 18),
          label: const Text('Edit profile'),
          style: TextButton.styleFrom(
            foregroundColor: _accent,
          ),
        ),
      ],
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
        SnackBar(
          content: Text('Couldn\'t update photo. Try again.'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openEditProfile() async {
    final profile = _profile;
    if (profile == null) return;
    final displayNameController = TextEditingController(text: profile.displayName ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text('Edit profile', style: TextStyle(color: Colors.white.withValues(alpha: 0.95))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: displayNameController,
              decoration: InputDecoration(
                labelText: 'Display name',
                labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3))),
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
      await _profileService.updateProfile(
        displayName: displayNameController.text.trim().isEmpty ? null : displayNameController.text.trim(),
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couldn\'t save. Try again.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildTodaySummary() {
    final t = _today ?? TodayMetrics.zero;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              _SummaryItem(label: 'Steps', value: _formatInt(t.steps)),
              _SummaryItem(label: 'Miles', value: t.distanceMiles.toStringAsFixed(1)),
              _SummaryItem(label: 'Active Cal', value: _formatInt(t.activeEnergyCalories.round())),
              _SummaryItem(label: 'Exercise min', value: _formatInt(t.exerciseMinutes.round())),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyPlaceholder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'This Week',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart_rounded, size: 24, color: Colors.white.withValues(alpha: 0.3)),
              const SizedBox(width: 10),
              Text(
                'Weekly summary coming soon',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalStatsPlaceholder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Personal stats',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _PlaceholderRow(label: 'Average steps', value: '—'),
              const SizedBox(height: 12),
              _PlaceholderRow(label: 'Best day', value: '—'),
              const SizedBox(height: 12),
              _PlaceholderRow(label: 'Streak', value: '—'),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatInt(int n) {
    if (n < 1000) return '$n';
    final s = n.toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    final firstLen = s.length % 3;
    if (firstLen > 0) {
      buf.write(s.substring(0, firstLen));
      if (firstLen < s.length) buf.write(',');
    }
    for (var i = firstLen; i < s.length; i += 3) {
      buf.write(s.substring(i, i + 3));
      if (i + 3 < s.length) buf.write(',');
    }
    return buf.toString();
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.label, required this.value});

  final String label;
  final String value;

  static const Color _accent = Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _accent,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderRow extends StatelessWidget {
  const _PlaceholderRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}
