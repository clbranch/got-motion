import '../models/weekly_group_award.dart';
import 'leaderboard_service.dart';

class WeeklyGroupAwardsService {
  WeeklyGroupAwardsService._();
  static final WeeklyGroupAwardsService instance = WeeklyGroupAwardsService._();

  final _leaderboard = LeaderboardService();

  /// Monday of the current calendar week (local time).
  static DateTime startOfWeek([DateTime? now]) {
    final local = now ?? DateTime.now();
    final today = DateTime(local.year, local.month, local.day);
    return today.subtract(Duration(days: local.weekday - 1));
  }

  /// Weekly awards only drop on Monday for the Mon–Sun block that just ended.
  static bool shouldShowWeeklyAwards([DateTime? now]) =>
      displayWeekMonday(now) != null;

  /// Monday of the completed week to display, or null while a week is in progress.
  static DateTime? displayWeekMonday([DateTime? now]) {
    final local = now ?? DateTime.now();
    if (local.weekday != DateTime.monday) return null;
    return startOfWeek(local).subtract(const Duration(days: 7));
  }

  static String weekKeyFor(DateTime weekMonday) =>
      '${weekMonday.year}-${weekMonday.month}-${weekMonday.day}';

  static String weekKey([DateTime? now]) {
    final monday = displayWeekMonday(now);
    if (monday == null) return weekKeyFor(startOfWeek(now));
    return weekKeyFor(monday);
  }

  static String weekLabelFor(DateTime weekMonday) {
    final sunday = weekMonday.add(const Duration(days: 6));
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final start = '${months[weekMonday.month - 1]} ${weekMonday.day}';
    final end = '${months[sunday.month - 1]} ${sunday.day}';
    return '$start – $end';
  }

  static String weekLabel([DateTime? now]) {
    final monday = displayWeekMonday(now);
    if (monday == null) return '';
    return weekLabelFor(monday);
  }

  Future<WeeklyGroupAwards?> loadForGroup(String groupId, [DateTime? now]) async {
    final displayMonday = displayWeekMonday(now);
    if (displayMonday == null) return null;

    final weekEnd = displayMonday.add(const Duration(days: 6));
    final rows = await _leaderboard.fetchGroupLeaderboard(
      groupId,
      rangeStart: displayMonday,
      rangeEnd: weekEnd,
    );
    if (rows.isEmpty) return null;

    final winners = <WeeklyAwardWinner>[];

    void pickWinner({
      required WeeklyAwardCategory category,
      required num? Function(Map<String, dynamic> row) readValue,
    }) {
      Map<String, dynamic>? bestRow;
      num bestValue = -1;
      for (final row in rows) {
        final value = readValue(row) ?? 0;
        if (value <= 0) continue;
        if (value > bestValue) {
          bestValue = value;
          bestRow = row;
        } else if (value == bestValue && bestRow != null) {
          final a = row['user_id']?.toString() ?? '';
          final b = bestRow['user_id']?.toString() ?? '';
          if (a.compareTo(b) < 0) bestRow = row;
        }
      }
      if (bestRow == null || bestValue <= 0) return;
      final winnerRow = bestRow;
      winners.add(
        WeeklyAwardWinner(
          category: category,
          userId: winnerRow['user_id']?.toString() ?? '',
          displayName: LeaderboardService.resolveDisplayName(winnerRow),
          avatarUrl: winnerRow['avatar_url']?.toString(),
          value: bestValue,
        ),
      );
    }

    pickWinner(
      category: WeeklyAwardCategory.steps,
      readValue: (row) => (row['total_steps'] as num?) ?? 0,
    );
    pickWinner(
      category: WeeklyAwardCategory.calories,
      readValue: (row) => (row['total_active_calories'] as num?) ?? 0,
    );
    pickWinner(
      category: WeeklyAwardCategory.exercise,
      readValue: (row) => (row['total_exercise_minutes'] as num?) ?? 0,
    );
    pickWinner(
      category: WeeklyAwardCategory.miles,
      readValue: (row) => (row['total_miles'] as num?) ?? 0,
    );

    return WeeklyGroupAwards(
      weekKey: weekKeyFor(displayMonday),
      weekLabel: weekLabelFor(displayMonday),
      winners: winners,
    );
  }
}

final weeklyGroupAwardsService = WeeklyGroupAwardsService.instance;
