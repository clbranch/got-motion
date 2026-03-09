import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Profile row for display and edit.
class ProfileData {
  const ProfileData({
    required this.id,
    this.email,
    this.fullName,
    this.displayName,
    this.avatarUrl,
    this.googleAvatarUrl,
    this.avatarSource,
    this.googleAvatarLastSyncedAt,
    this.updatedAt,
  });

  final String id;
  final String? email;
  final String? fullName;
  final String? displayName;
  final String? avatarUrl;
  final String? googleAvatarUrl;
  final String? avatarSource;
  final DateTime? googleAvatarLastSyncedAt;
  final DateTime? updatedAt;

  static ProfileData fromMap(Map<String, dynamic> r) {
    return ProfileData(
      id: r['id'] as String,
      email: r['email']?.toString(),
      fullName: r['full_name']?.toString(),
      displayName: r['display_name']?.toString(),
      avatarUrl: r['avatar_url']?.toString(),
      googleAvatarUrl: r['google_avatar_url']?.toString(),
      avatarSource: r['avatar_source']?.toString(),
      googleAvatarLastSyncedAt: r['google_avatar_last_synced_at'] != null
          ? DateTime.tryParse(r['google_avatar_last_synced_at'].toString())
          : null,
      updatedAt: r['updated_at'] != null
          ? DateTime.tryParse(r['updated_at'].toString())
          : null,
    );
  }

  /// Display name for UI: display_name ?? full_name ?? email ?? 'User'
  String get displayLabel {
    final d = (displayName ?? '').trim();
    final f = (fullName ?? '').trim();
    final e = (email ?? '').trim();
    if (d.isNotEmpty) return d;
    if (f.isNotEmpty) return f;
    if (e.isNotEmpty) return e;
    return 'User';
  }
}

class ProfileService {
  ProfileService() : _supabase = Supabase.instance.client;

  final SupabaseClient _supabase;

  /// Fetches the current user's profile. Returns null if not found.
  Future<ProfileData?> getCurrentProfile() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final res = await _supabase
          .from('profiles')
          .select(
            'id, email, full_name, display_name, avatar_url, google_avatar_url, avatar_source, google_avatar_last_synced_at, updated_at',
          )
          .eq('id', userId)
          .maybeSingle();
      if (res == null) return null;
      return ProfileData.fromMap(Map<String, dynamic>.from(res));
    } catch (_) {
      return null;
    }
  }

  /// Updates profile fields. Only provided non-null fields are updated.
  Future<void> updateProfile({
    String? displayName,
    String? avatarUrl,
    String? avatarSource,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('Not signed in');
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (displayName != null) updates['display_name'] = displayName.trim().isEmpty ? null : displayName.trim();
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (avatarSource != null && avatarSource.trim().isNotEmpty) {
      updates['avatar_source'] = avatarSource.trim();
    }
    await _supabase.from('profiles').update(updates).eq('id', userId);
  }

  /// Uploads a file as the user's avatar. Returns the public URL to store in profile.
  /// Path: {user_id}/avatar.{ext}
  Future<String> uploadAvatar(File file) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('Not signed in');
    final ext = _extensionFor(file.path);
    final path = '$userId/avatar$ext';
    await _supabase.storage.from('avatars').upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: true),
        );
    final url = _supabase.storage.from('avatars').getPublicUrl(path);
    return url;
  }

  static String _extensionFor(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return '.png';
    if (lower.endsWith('.webp')) return '.webp';
    if (lower.endsWith('.gif')) return '.gif';
    return '.jpg';
  }
}
