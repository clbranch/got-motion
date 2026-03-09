import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/motion_stats.dart';
import '../models/today_metrics.dart';
import '../services/daily_steps_service.dart';
import '../services/group_service.dart';
import '../services/leaderboard_service.dart';
import '../services/selected_group_service.dart';
import '../services/health_service.dart';
import '../services/profile_service.dart';
import '../widgets/leaderboard_card.dart';
import 'player_detail_screen.dart';

/// Leaderboard screen: group name, leaderboard header row, list of cards.
/// Data is loaded from Supabase via LeaderboardService (group_leaderboard view).
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  static const Color _background = Color(0xFF0B0B0F);
  static const Color _accent = Color(0xFF3B82F6);
  static const double _pagePadding = 16.0;

  static const List<String> _rangeOptions = ['Today', 'This Week', 'This Month'];

  final GroupService _groupService = GroupService();
  final LeaderboardService _leaderboardService = LeaderboardService();
  final DailyStepsService _dailyStepsService = DailyStepsService();

  /// User's groups from Supabase; loaded on screen open.
  List<String> _groups = [];
  /// Selected group for leaderboard; first group when available.
  String? _selectedGroupName;

  List<MotionStats> _leaderboard = [];
  bool _loading = true;
  String? _error;
  String _selectedRange = 'Today';

  /// Guards to prevent overlapping requests and recursive reload loops.
  bool _isLoadingLeaderboard = false;
  bool _isSyncingToday = false;

  /// After loading today's health, upsert to Supabase so group leaderboard has shared data (background).
  /// On success, re-fetches leaderboard once (skipSyncAfterReload=true) so we don't create a reload loop.
  void _syncTodayToSupabase(String userId, TodayMetrics today) {
    if (_isSyncingToday) return;
    _isSyncingToday = true;
    if (kDebugMode) {
      // ignore: avoid_print
      print('[DailySteps] Triggering sync from Leaderboard');
    }
    Future(() async {
      try {
        if (!mounted) return;
        await _dailyStepsService.upsertDailySteps(
          userId: userId,
          date: DateTime.now(),
          steps: today.steps,
          miles: today.distanceMiles,
          activeCalories: today.activeEnergyCalories.round(),
          exerciseMinutes: today.exerciseMinutes.round(),
        );
        // Re-fetch leaderboard once after sync so shared rankings are fresh. Must use skipSync=true to prevent loop.
        if (mounted) await _loadFromSupabase(skipSyncAfterReload: true);
      } catch (e, stack) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('[DailySteps] Leaderboard sync failed — exception: $e');
          // ignore: avoid_print
          print('[DailySteps] Leaderboard sync failed — stack: $stack');
        }
      } finally {
        _isSyncingToday = false;
      }
    });
  }

  /// Load user's groups from Supabase, set first as selected, then load leaderboard for that group.
  Future<void> _loadGroupsAndLeaderboard() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _groups = [];
        _selectedGroupName = null;
        _loading = false;
      });
      return;
    }
    try {
      final rows = await _groupService.fetchUserGroups(user.id).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Request timed out'),
      );
      if (!mounted) return;
      final names = rows
          .map((r) => (r['groups'] as Map<String, dynamic>?)?['name']?.toString())
          .whereType<String>()
          .toList();
      selectedGroupService.setGroupsFromFetchRows(rows);
      setState(() {
        _groups = names;
        _selectedGroupName = selectedGroupService.selectedGroupName ?? (names.isNotEmpty ? names.first : null);
      });
      if (_selectedGroupName != null) {
        _loadFromSupabase();
      } else {
        setState(() {
          _leaderboard = [];
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _groups = [];
        _selectedGroupName = null;
        _error = _friendlyNetworkError(e);
        _loading = false;
      });
    }
  }

  String _friendlyNetworkError(Object e) {
    final s = e.toString();
    if (s.contains('Bad file descriptor') || s.contains('ClientException')) {
      return 'Unable to load. Please pull to try again.';
    }
    if (s.contains('timed out')) return 'Request timed out. Pull to try again.';
    return s.length > 80 ? 'Network error. Pull to try again.' : s;
  }

  /// Load leaderboard from Supabase for [_selectedGroupName]. Maps view: display_name->name, total_steps->steps, total_miles->miles, total_active_calories->activeCalories, total_exercise_minutes->exerciseMinutes.
  /// [skipSyncAfterReload] when true (e.g. called from sync success) skips triggering sync to prevent recursive loop.
  Future<void> _loadFromSupabase({bool skipSyncAfterReload = false}) async {
    if (_isLoadingLeaderboard) return;
    final groupId = selectedGroupService.selectedGroupId;
    if (groupId == null || groupId.isEmpty) {
      if (mounted) {
        setState(() {
          _leaderboard = [];
          _loading = false;
          _error = null;
        });
      }
      return;
    }
    _isLoadingLeaderboard = true;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[Leaderboard] LeaderboardScreen — group_id: $groupId, group_name: $_selectedGroupName, range: $_selectedRange');
      }
      final rows = await _leaderboardService.fetchGroupLeaderboard(
        groupId,
        range: _selectedRange,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Request timed out'),
      );
      if (!mounted) return;

      if (kDebugMode) {
        // ignore: avoid_print
        print('[Leaderboard] LeaderboardScreen — rows from Supabase: ${rows.length}');
        for (final r in rows) {
          // ignore: avoid_print
          print('[Leaderboard]   Supabase row: user_id=${r['user_id']}, total_steps=${r['total_steps']}');
        }
      }

      final currentUser = Supabase.instance.client.auth.currentUser;
      final currentUserId = currentUser?.id;
      final currentUserEmail = currentUser?.email?.toLowerCase();

      var list = <MotionStats>[];
      Map<String, dynamic>? myRow;

      // Filter out the current user's row if viewing 'Today' to inject live data.
      final filteredRows = rows.where((row) {
        if (_selectedRange == 'Today') {
          final rowUserId = row['user_id']?.toString();
          final rowEmail = row['email']?.toString().toLowerCase();
          final rowDisplayName = row['display_name']?.toString().toLowerCase();

          bool isMe = (currentUserId != null && rowUserId == currentUserId) ||
              (currentUserEmail != null && rowEmail == currentUserEmail) ||
              (currentUserEmail != null && rowDisplayName == currentUserEmail);

          if (isMe) {
            myRow = row;
            return false;
          }
        }
        return true;
      }).toList();

      list = filteredRows
          .map((row) => MotionStats(
                name: LeaderboardService.resolveDisplayName(row),
                steps: (row['total_steps'] as num?)?.toInt() ?? 0,
                miles: (row['total_miles'] as num?)?.toDouble() ?? 0.0,
                activeCalories: (row['total_active_calories'] as num?)?.toInt() ?? 0,
                exerciseMinutes: (row['total_exercise_minutes'] as num?)?.toInt() ?? 0,
                avatarUrl: row['avatar_url']?.toString(),
                previousRank: null,
              ))
          .toList();

      // Inject current user's real-time Today stats if range is Today
      if (_selectedRange == 'Today' && currentUserId != null) {
        final today = await HealthService.getTodayMetrics();

        String myName = 'Unknown';
        String? myAvatarUrl;

        if (myRow != null) {
          myName = LeaderboardService.resolveDisplayName(myRow!);
          myAvatarUrl = myRow!['avatar_url']?.toString();
        } else {
          final profile = await ProfileService().getCurrentProfile();
          myName = profile?.displayLabel ?? currentUserEmail ?? 'Unknown';
          myAvatarUrl = profile?.avatarUrl;
        }

        final me = MotionStats(
          name: myName,
          steps: today.steps,
          miles: today.distanceMiles,
          activeCalories: today.activeEnergyCalories.round(),
          exerciseMinutes: today.exerciseMinutes.round(),
          avatarUrl: myAvatarUrl,
          previousRank: null,
        );
        if (kDebugMode) {
          // ignore: avoid_print
          print('[Leaderboard] LeaderboardScreen — INJECTING local Health row for current user: name=$myName, steps=${today.steps}, miles=${today.distanceMiles}. Other users shown from Supabase only.');
        }
        list = [me, ...list];
        list.sort((a, b) => b.steps.compareTo(a.steps));

        // Sync current user's today stats to Supabase so group leaderboard has shared data.
        // Skip if this load was triggered by sync success (prevents recursive loop).
        if (!skipSyncAfterReload) {
          _syncTodayToSupabase(currentUserId, today);
        }
      }

      if (!mounted) return;
      setState(() {
        _leaderboard = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyNetworkError(e);
        _leaderboard = [];
        _loading = false;
      });
    } finally {
      _isLoadingLeaderboard = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadGroupsAndLeaderboard();
  }

  Widget _buildListContent() {
    if (_groups.isEmpty && !_loading) {
      return Center(
        child: Text(
          'No groups yet.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      );
    }
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _accent),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(_pagePadding),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ),
      );
    }
    if (_leaderboard.isEmpty) {
      return Center(
        child: Text(
          'No leaderboard data yet.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(_pagePadding, 0, _pagePadding, _pagePadding),
      itemCount: _leaderboard.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final stats = _leaderboard[index];
        final rank = index + 1;
        return InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => PlayerDetailScreen(
                  stats: stats,
                  rank: rank,
                  selectedRange: _selectedRange,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: LeaderboardCard(rank: rank, stats: stats),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const SizedBox.shrink(),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(_pagePadding, 16, _pagePadding, 0),
            child: _groups.isEmpty
                ? Text(
                    'No groups yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  )
                : PopupMenuButton<String>(
                    initialValue: _selectedGroupName!,
                    offset: const Offset(0, 32),
                    padding: EdgeInsets.zero,
                    color: _background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    onSelected: (String name) {
                      setState(() => _selectedGroupName = name);
                      selectedGroupService.setSelectedGroup(name);
                      _loadFromSupabase();
                    },
                    itemBuilder: (context) => _groups
                        .map((g) => PopupMenuItem<String>(
                              value: g,
                              child: Text(
                                g,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ))
                        .toList(),
                    child: Text(
                      '${_selectedGroupName ?? ''} ▾',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: _accent,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(_pagePadding, 0, _pagePadding, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Leaderboard',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: PopupMenuButton<String>(
                    initialValue: _selectedRange,
                    offset: const Offset(0, 32),
                    padding: EdgeInsets.zero,
                    color: _background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    onSelected: (value) {
                      setState(() => _selectedRange = value);
                      _loadFromSupabase();
                    },
                    itemBuilder: (context) => _rangeOptions
                        .map((option) => PopupMenuItem<String>(
                              value: option,
                              child: Text(
                                option,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ))
                        .toList(),
                    child: Text(
                      '$_selectedRange ▾',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadGroupsAndLeaderboard,
              color: _accent,
              child: _buildListContent(),
            ),
          ),
        ],
      ),
    );
  }
}
