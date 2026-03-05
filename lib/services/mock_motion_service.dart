///
/// Mock leaderboard data for development and UI testing.
///
/// This file provides fake leaderboard users (Alex Chen, Jordan Lee, etc.) with
/// hardcoded steps, miles, calories, and minutes. The real step count for the
/// current device user is supplied by [HealthService] via Apple Health (HealthKit)
/// and is merged into the leaderboard in the UI layer.
///
/// The mock users here will later be replaced with real users synced from a
/// backend service (e.g. Firebase or Supabase).
///
import '../models/motion_stats.dart';

/// Provides fake motion/leaderboard data for development.
class MockMotionService {
  MockMotionService._();

  static const List<MotionStats> _todayData = [
    
    MotionStats(name: 'Alex Chen', steps: 12450, miles: 5.2, activeCalories: 312, exerciseMinutes: 48, previousRank: 2),
    MotionStats(name: 'Jordan Lee', steps: 11200, miles: 4.7, activeCalories: 285, exerciseMinutes: 42, previousRank: 3),
    MotionStats(name: 'Sam Rivera', steps: 9870, miles: 4.1, activeCalories: 248, exerciseMinutes: 35, previousRank: 4),
    MotionStats(name: 'Taylor Kim', steps: 8450, miles: 3.5, activeCalories: 210, exerciseMinutes: 28, previousRank: 5),
  ];

  /// This Week: order Jordan(1), Sam(2), Alex(3), Morgan(4), Taylor(5). previousRank = last week's rank.
  static const List<MotionStats> _weekData = [
    
    MotionStats(name: 'Alex Chen', steps: 52100, miles: 21.8, activeCalories: 1280, exerciseMinutes: 195, previousRank: 2),
    MotionStats(name: 'Jordan Lee', steps: 58900, miles: 24.6, activeCalories: 1420, exerciseMinutes: 218, previousRank: 3),
    MotionStats(name: 'Sam Rivera', steps: 55400, miles: 23.2, activeCalories: 1350, exerciseMinutes: 202, previousRank: 4),
    MotionStats(name: 'Taylor Kim', steps: 41200, miles: 17.2, activeCalories: 998, exerciseMinutes: 152, previousRank: 5),
  ];

  /// This Month: order Sam(1), Alex(2), Taylor(3), Jordan(4), Morgan(5). previousRank = last month's rank.
  static const List<MotionStats> _monthData = [
    
    MotionStats(name: 'Alex Chen', steps: 198200, miles: 82.9, activeCalories: 4820, exerciseMinutes: 738, previousRank: 3),
    MotionStats(name: 'Jordan Lee', steps: 156400, miles: 65.4, activeCalories: 3780, exerciseMinutes: 582, previousRank: 4),
    MotionStats(name: 'Sam Rivera', steps: 221500, miles: 92.6, activeCalories: 5420, exerciseMinutes: 828, previousRank: 1),
    MotionStats(name: 'Taylor Kim', steps: 178900, miles: 74.8, activeCalories: 4320, exerciseMinutes: 662, previousRank: 5),
  ];

  /// Returns leaderboard entries for the given range. Caller should sort by steps descending.
  static List<MotionStats> getLeaderboardForRange(String range) {
    switch (range) {
      case 'This Week':
        return List<MotionStats>.from(_weekData);
      case 'This Month':
        return List<MotionStats>.from(_monthData);
      case 'Today':
      default:
        return List<MotionStats>.from(_todayData);
    }
  }
}