import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/today_metrics.dart';
import 'health_service.dart';

class DailyStepsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// How far back we pull from HealthKit into Supabase (daily rows kept forever).
  static const historyLookbackDays = 730;

  /// Re-sync recent days — HealthKit totals can shift slightly after workouts sync.
  static const historyResyncDays = 7;

  /// Max days pulled from HealthKit per sync call so UI stays responsive.
  static const maxDaysPerSync = 21;

  /// First-time backfill window (older history fills in over later app opens).
  static const initialBackfillDays = 60;

  static String _syncedThroughKey(String userId) =>
      'daily_steps_synced_through_$userId';

  static String _oldestSyncedKey(String userId) =>
      'daily_steps_oldest_synced_$userId';

  /// Set from main.dart after Supabase.initialize so debug logs can show which project is used.
  static String? debugSupabaseUrl;

  /// Upserts today's health metrics for the given user. Used so group leaderboards
  /// show shared data from Supabase. Call after loading health data (Home, Leaderboard, Profile).
  Future<void> upsertDailySteps({
    required String userId,
    required DateTime date,
    required int steps,
    required double miles,
    required int activeCalories,
    required int exerciseMinutes,
  }) async {
    final dateOnly = DateTime(
      date.year,
      date.month,
      date.day,
    ).toIso8601String().split('T').first;

    final payload = {
      'user_id': userId,
      'date': dateOnly,
      'steps': steps,
      'miles': miles,
      'active_calories': activeCalories,
      'exercise_minutes': exerciseMinutes,
    };

    if (kDebugMode) {
      // Explicit debug logs: confirm code path runs and which project is used.
      // ignore: avoid_print
      print(
        '[DailySteps] BEFORE upsert — Supabase URL: ${DailyStepsService.debugSupabaseUrl ?? "(set DailyStepsService.debugSupabaseUrl in main.dart)"}',
      );
      // ignore: avoid_print
      print(
        '[DailySteps] BEFORE upsert — user_id: $userId, date: $dateOnly, steps: $steps, miles: $miles, active_calories: $activeCalories, exercise_minutes: $exerciseMinutes',
      );
    }

    try {
      await _supabase
          .from('daily_steps')
          .upsert(payload, onConflict: 'user_id,date');
      if (kDebugMode) {
        // ignore: avoid_print
        print('[DailySteps] AFTER upsert — success');
      }
    } catch (e, stack) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[DailySteps] AFTER upsert — FAILED. Exception: $e');
        // ignore: avoid_print
        print('[DailySteps] Stack trace: $stack');
      }
      rethrow;
    }
  }

  /// Writes one row per day so Week and Month leaderboards can sum real history.
  Future<void> upsertDays({
    required String userId,
    required List<({DateTime date, TodayMetrics metrics})> days,
  }) async {
    if (days.isEmpty) return;
    final payloads = days
        .map(
          (day) => {
            'user_id': userId,
            'date': DateTime(
              day.date.year,
              day.date.month,
              day.date.day,
            ).toIso8601String().split('T').first,
            'steps': day.metrics.steps,
            'miles': day.metrics.distanceMiles,
            'active_calories': day.metrics.activeEnergyCalories.round(),
            'exercise_minutes': day.metrics.exerciseMinutes.round(),
          },
        )
        .toList();
    await _supabase
        .from('daily_steps')
        .upsert(payloads, onConflict: 'user_id,date');
    if (kDebugMode) {
      // ignore: avoid_print
      print('[DailySteps] upsertDays — ${payloads.length} days for $userId');
    }
  }

  static bool _historySyncing = false;

  /// Backfills daily_steps from HealthKit so Week/Month views can sum real data.
  /// Syncs in small chunks so HealthKit work never blocks the UI for minutes.
  Future<void> syncHistoryToDate(String userId) async {
    if (_historySyncing) return;
    _historySyncing = true;
    try {
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final earliest = todayDate.subtract(
        const Duration(days: historyLookbackDays),
      );

      final prefs = await SharedPreferences.getInstance();
      final oldestSyncedRaw = prefs.getString(_oldestSyncedKey(userId));
      final oldestSynced = oldestSyncedRaw == null
          ? null
          : DateTime.tryParse(oldestSyncedRaw);

      // 1) Always refresh recent days (leaderboard week/month accuracy).
      final recentStart = todayDate.subtract(
        const Duration(days: historyResyncDays - 1),
      );
      final recentDays = await HealthService.getDailyMetrics(recentStart, today);
      await upsertDays(userId: userId, days: recentDays);

      // 2) Extend history backwards in bounded chunks when needed.
      final bool needsOlderBackfill =
          oldestSynced == null || oldestSynced.isAfter(earliest);
      if (needsOlderBackfill) {
        final chunkEnd = oldestSynced == null
            ? todayDate
            : oldestSynced.subtract(const Duration(days: 1));
        var chunkStart = oldestSynced == null
            ? todayDate.subtract(
                const Duration(days: initialBackfillDays - 1),
              )
            : chunkEnd.subtract(const Duration(days: maxDaysPerSync - 1));
        if (chunkStart.isBefore(earliest)) chunkStart = earliest;

        if (!chunkEnd.isBefore(chunkStart)) {
          final olderDays = await HealthService.getDailyMetrics(
            chunkStart,
            chunkEnd,
          );
          await upsertDays(userId: userId, days: olderDays);
          await prefs.setString(
            _oldestSyncedKey(userId),
            chunkStart.toIso8601String().split('T').first,
          );
          if (kDebugMode) {
            // ignore: avoid_print
            print(
              '[DailySteps] syncHistory — backfill chunk '
              '${chunkStart.toIso8601String().split('T').first} → '
              '${chunkEnd.toIso8601String().split('T').first}',
            );
          }
        }
      }

      await prefs.setString(
        _syncedThroughKey(userId),
        todayDate.toIso8601String().split('T').first,
      );
    } finally {
      _historySyncing = false;
    }
  }

}
