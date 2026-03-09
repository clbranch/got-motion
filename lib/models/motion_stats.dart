/// Represents motion/activity stats for a single user on the leaderboard.
class MotionStats {
  const MotionStats({
    required this.name,
    required this.steps,
    required this.miles,
    required this.activeCalories,
    required this.exerciseMinutes,
    this.avatarUrl,
    this.previousRank,
  });

  final String name;
  final int steps;
  final double miles;
  final int activeCalories;
  final int exerciseMinutes;
  /// Profile avatar URL when available (e.g. from group_leaderboard view).
  final String? avatarUrl;
  /// Previous period rank; null treated as same as current rank (delta = 0).
  final int? previousRank;
}
