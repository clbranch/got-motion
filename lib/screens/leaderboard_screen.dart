import 'package:flutter/material.dart';
import '../models/motion_stats.dart';
import '../services/leaderboard_service.dart';
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

  /// Current group name; default for v1. Later can be loaded from Supabase when user selects/joins a group.
  String currentGroupName = 'Rich-Men';

  final LeaderboardService _leaderboardService = LeaderboardService();

  List<MotionStats> _leaderboard = [];
  bool _loading = true;
  String? _error;
  String _selectedRange = 'Today';

  /// Load leaderboard from Supabase. Maps view: display_name->name, total_steps->steps, total_miles->miles, total_active_calories->activeCalories, total_exercise_minutes->exerciseMinutes.
  Future<void> _loadFromSupabase() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _leaderboardService.fetchGroupLeaderboard(currentGroupName);
      if (!mounted) return;
      final list = rows
          .map((row) => MotionStats(
                name: row['display_name'] as String? ?? 'Unknown',
                steps: (row['total_steps'] as num?)?.toInt() ?? 0,
                miles: (row['total_miles'] as num?)?.toDouble() ?? 0.0,
                activeCalories: (row['total_active_calories'] as num?)?.toInt() ?? 0,
                exerciseMinutes: (row['total_exercise_minutes'] as num?)?.toInt() ?? 0,
                previousRank: null,
              ))
          .toList();
      setState(() {
        _leaderboard = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _leaderboard = [];
        _loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadFromSupabase();
  }

  Widget _buildListContent() {
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
            child: Text(
              '$currentGroupName ▾',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: _accent,
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
              onRefresh: _loadFromSupabase,
              color: _accent,
              child: _buildListContent(),
            ),
          ),
        ],
      ),
    );
  }
}
