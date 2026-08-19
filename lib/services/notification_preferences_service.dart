import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notification_preferences.dart';

class NotificationPreferencesService {
  NotificationPreferencesService._();
  static final NotificationPreferencesService instance =
      NotificationPreferencesService._();

  final _supabase = Supabase.instance.client;

  Future<NotificationPreferences> load() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('Not signed in');
    }

    try {
      final row = await _supabase
          .from('notification_preferences')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      if (row != null) {
        final prefs = NotificationPreferences.fromMap(
          Map<String, dynamic>.from(row),
        );
        await _cacheLocal(prefs);
        return prefs;
      }
      final defaults = NotificationPreferences.defaults(user.id);
      await save(defaults);
      return defaults;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationPrefs] remote load failed: $e');
      }
      return _loadLocal(user.id);
    }
  }

  Future<NotificationPreferences> save(NotificationPreferences prefs) async {
    try {
      await _supabase
          .from('notification_preferences')
          .upsert(prefs.toUpsertMap(), onConflict: 'user_id');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationPrefs] remote save failed: $e');
      }
    }
    await _cacheLocal(prefs);
    return prefs;
  }

  Future<void> _cacheLocal(NotificationPreferences prefs) async {
    final store = await SharedPreferences.getInstance();
    await store.setBool('np_push_${prefs.userId}', prefs.pushEnabled);
    await store.setBool('np_rank_${prefs.userId}', prefs.rankChanges);
    await store.setBool('np_catch_${prefs.userId}', prefs.catchUpReminders);
    await store.setBool('np_group_${prefs.userId}', prefs.groupActivity);
    await store.setBool('np_weekly_${prefs.userId}', prefs.weeklyRecap);
  }

  Future<NotificationPreferences> _loadLocal(String userId) async {
    final store = await SharedPreferences.getInstance();
    return NotificationPreferences(
      userId: userId,
      pushEnabled: store.getBool('np_push_$userId') ?? false,
      rankChanges: store.getBool('np_rank_$userId') ?? true,
      catchUpReminders: store.getBool('np_catch_$userId') ?? true,
      groupActivity: store.getBool('np_group_$userId') ?? true,
      weeklyRecap: store.getBool('np_weekly_$userId') ?? true,
    );
  }
}

final notificationPreferencesService = NotificationPreferencesService.instance;
