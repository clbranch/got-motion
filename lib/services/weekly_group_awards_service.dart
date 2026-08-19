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

  static String weekKey([DateTime? now]) {
    final monday = startOfWeek(now);
    return '${monday.year}-${monday.month}-${monday.day}';
  }

  static String weekLabel([DateTime? now]) {
    final local = now ?? DateTime.now();
    final monday = startOfWeek(local);
    final sunday = monday.add(const Duration(days: 6));
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
    final start = '${months[monday.month - 1]} ${monday.day}';
    final end = '${months[sunday.month - 1]} ${sunday.day}';
    return '$start – $end';
  }

  Future<WeeklyGroupAwards?> loadForGroup(String groupId) async {
    final rows = await _leaderboard.fetchGroupLeaderboard(
      groupId,
      range: 'This Week',
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
      weekKey: weekKey(),
      weekLabel: weekLabel(),
      winners: winners,
    );
  }
}

final weeklyGroupAwardsService = WeeklyGroupAwardsService.instance;
