import 'package:supabase_flutter/supabase_flutter.dart';

class DailyStepsService {
  final SupabaseClient _supabase = Supabase.instance.client;

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

    try {
      await _supabase.from('daily_steps').upsert({
        'user_id': userId,
        'date': dateOnly,
        'steps': steps,
        'miles': miles,
        'active_calories': activeCalories,
        'exercise_minutes': exerciseMinutes,
      }, onConflict: 'user_id,date');

      print('Daily steps upsert success');
    } catch (e) {
      print('Daily steps upsert failed: $e');
    }
  }
}