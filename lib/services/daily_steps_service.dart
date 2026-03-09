import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DailyStepsService {
  final SupabaseClient _supabase = Supabase.instance.client;

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
    final dateOnly =
        DateTime(date.year, date.month, date.day).toIso8601String().split('T').first;

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
      print('[DailySteps] BEFORE upsert — Supabase URL: ${DailyStepsService.debugSupabaseUrl ?? "(set DailyStepsService.debugSupabaseUrl in main.dart)"}');
      // ignore: avoid_print
      print('[DailySteps] BEFORE upsert — user_id: $userId, date: $dateOnly, steps: $steps, miles: $miles, active_calories: $activeCalories, exercise_minutes: $exerciseMinutes');
    }

    try {
      await _supabase.from('daily_steps').upsert(payload, onConflict: 'user_id,date');
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
}