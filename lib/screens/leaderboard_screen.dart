import 'package:flutter/material.dart';
import '../models/motion_stats.dart';
import '../services/health_service.dart';
import '../services/mock_motion_service.dart';
import '../widgets/leaderboard_card.dart';
import 'player_detail_screen.dart';

/// Leaderboard screen: group name, leaderboard header row, list of cards.
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

  late List<MotionStats> _leaderboard;
  String _selectedRange = 'Today';
  /// Current user steps from HealthKit; null until fetched, zero when permission denied.
  int? _userStepsToday;
  int? _userStepsWeek;
  int? _userStepsMonth;
  /// Full today metrics (miles, cal, min) for "You" row when range is Today.
  double? _userTodayMiles;
  int? _userTodayCalories;
  int? _userTodayExerciseMinutes;

  void _loadLeaderboard() {
    var list = MockMotionService.getLeaderboardForRange(_selectedRange);
    final userSteps = _selectedRange == 'Today'
        ? (_userStepsToday ?? 0)
        : _selectedRange == 'This Week'
            ? (_userStepsWeek ?? 0)
            : (_userStepsMonth ?? 0);
    final me = MotionStats(
      name: 'You',
      steps: userSteps,
      miles: _selectedRange == 'Today' ? (_userTodayMiles ?? 0) : 0,
      activeCalories: _selectedRange == 'Today' ? (_userTodayCalories ?? 0) : 0,
      exerciseMinutes: _selectedRange == 'Today' ? (_userTodayExerciseMinutes ?? 0) : 0,
      previousRank: null,
    );
    list = [me, ...list];
    list.sort((a, b) => b.steps.compareTo(a.steps));
    _leaderboard = list;
  }

  Future<void> _fetchHealthSteps() async {
    final data = await HealthService.requestAndFetchSteps();
    final today = await HealthService.getTodayMetrics();
    if (!mounted) return;
    setState(() {
      _userStepsToday = data.todaySteps;
      _userStepsWeek = data.weekSteps;
      _userStepsMonth = data.monthSteps;
      _userTodayMiles = today.distanceMiles;
      _userTodayCalories = today.activeEnergyCalories.round();
      _userTodayExerciseMinutes = today.exerciseMinutes.round();
      _loadLeaderboard();
    });
  }

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
    _fetchHealthSteps();
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
                      setState(() {
                        _selectedRange = value;
                        _loadLeaderboard();
                      });
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
              onRefresh: _fetchHealthSteps,
              color: _accent,
              child: ListView.separated(
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
            ),
            ),
          ),
        ],
      ),
    );
  }
}
