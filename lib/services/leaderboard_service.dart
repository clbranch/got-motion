import 'package:supabase_flutter/supabase_flutter.dart';

class LeaderboardService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchGroupLeaderboard(String groupName) async {
    final response = await _supabase
        .from('group_leaderboard')
        .select()
        .eq('group_name', groupName)
        .order('total_steps', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }
}