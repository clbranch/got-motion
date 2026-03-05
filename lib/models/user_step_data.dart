/// Current user's step counts from HealthKit for today, this week, and this month.
class UserStepData {
  const UserStepData({
    required this.todaySteps,
    required this.weekSteps,
    required this.monthSteps,
  });

  final int todaySteps;
  final int weekSteps;
  final int monthSteps;

  /// Zero steps when Health is unavailable or permission denied.
  static const UserStepData zero = UserStepData(
    todaySteps: 0,
    weekSteps: 0,
    monthSteps: 0,
  );
}
