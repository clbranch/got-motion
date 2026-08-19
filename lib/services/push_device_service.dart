import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushDeviceService {
  PushDeviceService._();
  static final PushDeviceService instance = PushDeviceService._();

  final _supabase = Supabase.instance.client;

  Future<void> upsertToken({
    required String token,
    required String platform,
    bool enabled = true,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null || token.isEmpty) return;

    try {
      await _supabase.from('push_devices').upsert({
        'user_id': user.id,
        'platform': platform,
        'token': token,
        'enabled': enabled,
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,platform,token');
    } catch (e) {
      if (kDebugMode) debugPrint('[PushDevice] upsert failed: $e');
    }
  }

  Future<void> setEnabledForToken({
    required String token,
    required String platform,
    required bool enabled,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null || token.isEmpty) return;
    try {
      await _supabase
          .from('push_devices')
          .update({
            'enabled': enabled,
            'last_seen_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('user_id', user.id)
          .eq('platform', platform)
          .eq('token', token);
    } catch (e) {
      if (kDebugMode) debugPrint('[PushDevice] setEnabled failed: $e');
    }
  }
}

final pushDeviceService = PushDeviceService.instance;
