import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_service.dart';

/// Syncs auth provider profile data (Google) into app profile/storage.
class AuthProfileSyncService {
  AuthProfileSyncService() : _supabase = Supabase.instance.client;

  final SupabaseClient _supabase;
  final ProfileService _profileService = ProfileService();

  Future<void> syncCurrentUserFromAuth() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final googlePhotoUrl = _extractGooglePhotoUrl(user);
    final googleDisplayName = _extractGoogleDisplayName(user);

    final profile = await _profileService.getCurrentProfile();
    if (profile == null) return;

    final updates = <String, dynamic>{};
    final isDisplayNameMissing = (profile.displayName ?? '').trim().isEmpty;
    if (isDisplayNameMissing && googleDisplayName != null && googleDisplayName.isNotEmpty) {
      updates['display_name'] = googleDisplayName;
    }

    if (googlePhotoUrl != null && googlePhotoUrl.isNotEmpty) {
      updates['google_avatar_url'] = googlePhotoUrl;
    }

    if (googlePhotoUrl == null || googlePhotoUrl.isEmpty) {
      if (updates.isEmpty) return;
      updates['updated_at'] = DateTime.now().toUtc().toIso8601String();
      await _supabase.from('profiles').update(updates).eq('id', user.id);
      return;
    }

    // If user has chosen a custom avatar in-app, never overwrite it from Google.
    if (profile.avatarSource == 'custom') {
      if (updates.isEmpty) return;
      updates['updated_at'] = DateTime.now().toUtc().toIso8601String();
      await _supabase.from('profiles').update(updates).eq('id', user.id);
      return;
    }

    final photoBytes = await _downloadPhoto(googlePhotoUrl);
    if (photoBytes == null || photoBytes.isEmpty) {
      if (updates.isEmpty) return;
      updates['updated_at'] = DateTime.now().toUtc().toIso8601String();
      await _supabase.from('profiles').update(updates).eq('id', user.id);
      return;
    }

    final storagePath = '${user.id}/avatar_google.jpg';
    await _supabase.storage.from('avatars').uploadBinary(
          storagePath,
          photoBytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );
    final storedUrl = _supabase.storage.from('avatars').getPublicUrl(storagePath);

    updates['avatar_url'] = storedUrl;
    updates['avatar_source'] = 'google';
    updates['google_avatar_last_synced_at'] = DateTime.now().toUtc().toIso8601String();
    updates['updated_at'] = DateTime.now().toUtc().toIso8601String();

    await _supabase.from('profiles').update(updates).eq('id', user.id);
  }

  String? _extractGooglePhotoUrl(User user) {
    final userMeta = user.userMetadata ?? const {};
    final identities = user.identities ?? const <UserIdentity>[];

    String? fromMap(Map<String, dynamic> data) {
      final keys = ['avatar_url', 'picture', 'photoURL'];
      for (final key in keys) {
        final value = data[key]?.toString();
        if (value != null && value.isNotEmpty) return value;
      }
      return null;
    }

    final direct = fromMap(userMeta);
    if (direct != null && _looksLikeGooglePhotoUrl(direct)) {
      return direct;
    }

    for (final identity in identities) {
      if (identity.provider != 'google') continue;
      final identityData = identity.identityData;
      if (identityData == null) continue;
      final v = fromMap(identityData);
      if (v != null && v.isNotEmpty) return v;
    }

    return direct;
  }

  bool _looksLikeGooglePhotoUrl(String url) {
    return url.contains('googleusercontent.com') || url.contains('google.com');
  }

  String? _extractGoogleDisplayName(User user) {
    final userMeta = user.userMetadata ?? const {};
    final identities = user.identities ?? const <UserIdentity>[];

    String? fromMap(Map<String, dynamic> data) {
      final keys = ['display_name', 'full_name', 'name', 'given_name'];
      for (final key in keys) {
        final value = data[key]?.toString().trim();
        if (value != null && value.isNotEmpty) return value;
      }
      return null;
    }

    final direct = fromMap(userMeta);
    if (direct != null) return direct;

    for (final identity in identities) {
      if (identity.provider != 'google') continue;
      final identityData = identity.identityData;
      if (identityData == null) continue;
      final v = fromMap(identityData);
      if (v != null && v.isNotEmpty) return v;
    }

    return null;
  }

  Future<Uint8List?> _downloadPhoto(String url) async {
    try {
      final client = HttpClient();
      final uri = Uri.parse(url);
      final req = await client.getUrl(uri);
      final res = await req.close();
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final bytes = await consolidateHttpClientResponseBytes(res);
      client.close();
      return bytes;
    } catch (_) {
      return null;
    }
  }
}
