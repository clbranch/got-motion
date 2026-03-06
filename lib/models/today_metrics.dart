/// Today's health metrics from HealthKit (startOfDay → now), aligned with Apple Health "All Health Data" tiles.
/// Display rounding: miles 1 decimal, calories whole, minutes whole.
class TodayMetrics {
  const TodayMetrics({
    required this.steps,
    required this.distanceMiles,
    required this.activeEnergyCalories,
    required this.exerciseMinutes,
  });

  final int steps;
  final double distanceMiles;
  final double activeEnergyCalories;
  final double exerciseMinutes;

  static const TodayMetrics zero = TodayMetrics(
    steps: 0,
    distanceMiles: 0,
    activeEnergyCalories: 0,
    exerciseMinutes: 0,
  );
}
