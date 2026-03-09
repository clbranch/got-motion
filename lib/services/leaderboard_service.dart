import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LeaderboardService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Resolves the best display name for leaderboard rows.
  /// Order: display_name -> email -> Unknown
  static String resolveDisplayName(Map<String, dynamic> row) {
    final displayName = row['display_name']?.toString().trim();
    final email = row['email']?.toString().trim();

    if (displayName != null && displayName.isNotEmpty) return displayName;
    if (email != null && email.isNotEmpty) return email;
    return 'Unknown';
  }

  /// Fetches leaderboard rows for a given group ID and time range.
  /// Returns a list of maps with: user_id, display_name, email, avatar_url, total_steps, total_miles, etc.
  Future<List<Map<String, dynamic>>> fetchGroupLeaderboard(String groupId, {String range = 'Today'}) async {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[Leaderboard] READ — group_id: $groupId, range: $range');
    }

    // 1. Fetch all members of the group
    final memberRows = await _supabase
        .from('group_members')
        .select('user_id')
        .eq('group_id', groupId);

    final List<String> userIds = List<Map<String, dynamic>>.from(memberRows)
        .map((r) => r['user_id']?.toString())
        .whereType<String>()
        .toList();

    if (kDebugMode) {
      // ignore: avoid_print
      print('[Leaderboard] READ — group_members user_ids: $userIds');
    }

    if (userIds.isEmpty) return [];

    // 2. Fetch profiles for these members
    final profilesResponse = await _supabase
        .from('profiles')
        .select('id, email, display_name, avatar_url')
        .inFilter('id', userIds);

    final profiles = <String, Map<String, dynamic>>{};
    for (final p in List<Map<String, dynamic>>.from(profilesResponse)) {
      final id = p['id']?.toString();
      if (id != null) profiles[id] = p;
    }

    // 3. Determine date filter
    DateTime now = DateTime.now();
    DateTime startDate;
    if (range == 'Today') {
      startDate = DateTime(now.year, now.month, now.day);
    } else if (range == 'This Week') {
      // Week starts on Monday
      startDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    } else if (range == 'This Month') {
      startDate = DateTime(now.year, now.month, 1);
    } else {
      startDate = DateTime(2000); // Fallback to all time
    }
    final startDateStr = startDate.toIso8601String().split('T').first;

    // 4. Fetch daily_steps for these users within the date range
    final stepsResponse = await _supabase
        .from('daily_steps')
        .select()
        .inFilter('user_id', userIds)
        .gte('date', startDateStr);

    final stepsData = List<Map<String, dynamic>>.from(stepsResponse);

    if (kDebugMode) {
      // ignore: avoid_print
      print('[Leaderboard] READ — daily_steps rows returned: ${stepsData.length}');
      for (final row in stepsData) {
        // ignore: avoid_print
        print('[Leaderboard]   daily_steps row: user_id=${row['user_id']}, date=${row['date']}, steps=${row['steps']}, miles=${row['miles']}, active_calories=${row['active_calories']}, exercise_minutes=${row['exercise_minutes']}');
      }
    }

    // 5. Aggregate stats per user
    final aggregatedStats = <String, Map<String, dynamic>>{};
    for (final uid in userIds) {
      aggregatedStats[uid] = {
        'total_steps': 0,
        'total_miles': 0.0,
        'total_active_calories': 0,
        'total_exercise_minutes': 0,
      };
    }

    for (final row in stepsData) {
      final uid = row['user_id']?.toString();
      if (uid != null && aggregatedStats.containsKey(uid)) {
        aggregatedStats[uid]!['total_steps'] += (row['steps'] as num?)?.toInt() ?? 0;
        aggregatedStats[uid]!['total_miles'] += (row['miles'] as num?)?.toDouble() ?? 0.0;
        aggregatedStats[uid]!['total_active_calories'] += (row['active_calories'] as num?)?.toInt() ?? 0;
        aggregatedStats[uid]!['total_exercise_minutes'] += (row['exercise_minutes'] as num?)?.toInt() ?? 0;
      }
    }

    // 6. Build the final list
    final List<Map<String, dynamic>> results = [];
    for (final uid in userIds) {
      final profile = profiles[uid];
      final stats = aggregatedStats[uid]!;
      
      results.add({
        'user_id': uid,
        'email': profile?['email'],
        'display_name': profile?['display_name'],
        'avatar_url': profile?['avatar_url'],
        'total_steps': stats['total_steps'],
        'total_miles': stats['total_miles'],
        'total_active_calories': stats['total_active_calories'],
        'total_exercise_minutes': stats['total_exercise_minutes'],
      });
    }

    // 7. Sort by steps descending
    results.sort((a, b) => (b['total_steps'] as int).compareTo(a['total_steps'] as int));

    if (kDebugMode) {
      // ignore: avoid_print
      print('[Leaderboard] READ — final mapped leaderboard rows: ${results.length}');
      for (final row in results) {
        // ignore: avoid_print
        print('[Leaderboard]   row: user_id=${row['user_id']}, display_name=${row['display_name']}, total_steps=${row['total_steps']}, total_miles=${row['total_miles']}, total_active_calories=${row['total_active_calories']}, total_exercise_minutes=${row['total_exercise_minutes']}');
      }
    }

    return results;
  }
}
