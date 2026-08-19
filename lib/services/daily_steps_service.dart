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

  static String _syncedThroughKey(String userId) =>
      'daily_steps_synced_through_$userId';

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

  /// Backfills daily_steps from HealthKit so Week/Month views and future history
  /// screens can sum real data. First run pulls up to [historyLookbackDays];
  /// later runs refresh the last week and fill any new days.
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
      final syncedThroughRaw = prefs.getString(_syncedThroughKey(userId));
      final syncedThrough = syncedThroughRaw == null
          ? null
          : DateTime.tryParse(syncedThroughRaw);

      final DateTime start;
      if (syncedThrough == null) {
        start = earliest;
        if (kDebugMode) {
          // ignore: avoid_print
          print(
            '[DailySteps] syncHistory — initial backfill from '
            '${start.toIso8601String().split('T').first}',
          );
        }
      } else {
        final rewind = syncedThrough.subtract(
          const Duration(days: historyResyncDays),
        );
        start = rewind.isBefore(earliest) ? earliest : rewind;
      }

      final days = await HealthService.getDailyMetrics(start, today);
      await upsertDays(userId: userId, days: days);
      await prefs.setString(
        _syncedThroughKey(userId),
        todayDate.toIso8601String().split('T').first,
      );
    } finally {
      _historySyncing = false;
    }
  }

}
