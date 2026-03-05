import 'package:health/health.dart';

import '../models/user_step_data.dart';

/// Fetches step count from Apple HealthKit (iOS). Handles permission denial gracefully.
/// On iOS: enable the HealthKit capability in Xcode (Runner target → Signing & Capabilities) for step data to be read.
class HealthService {
  HealthService._();

  static final Health _health = Health();

  static const List<HealthDataType> _stepTypes = [HealthDataType.STEPS];

  /// Request read permission for steps and fetch today, this week, and this month.
  /// Returns [UserStepData.zero] when permission is denied or an error occurs.
  static Future<UserStepData> requestAndFetchSteps() async {
    try {
      await _health.configure();
      final granted = await _health.requestAuthorization(_stepTypes);
      if (!granted) return UserStepData.zero;

      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final startOfWeek = midnight.subtract(Duration(days: now.weekday - 1));
      final startOfMonth = DateTime(now.year, now.month, 1);

      final todaySteps = await _health.getTotalStepsInInterval(midnight, now) ?? 0;
      final weekSteps = await _health.getTotalStepsInInterval(startOfWeek, now) ?? 0;
      final monthSteps = await _health.getTotalStepsInInterval(startOfMonth, now) ?? 0;

      return UserStepData(
        todaySteps: todaySteps,
        weekSteps: weekSteps,
        monthSteps: monthSteps,
      );
    } catch (_) {
      return UserStepData.zero;
    }
  }
}
