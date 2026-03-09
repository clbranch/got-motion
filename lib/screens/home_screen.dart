import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/motion_stats.dart';
import '../models/today_metrics.dart';
import '../services/daily_steps_service.dart';
import '../services/health_service.dart';
import '../services/leaderboard_service.dart';
import '../services/selected_group_service.dart';
import 'leaderboard_screen.dart';
import 'player_detail_screen.dart';

/// Competitive motion dashboard: hero card, today grid, weekly trend, mini leaderboard, activity.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.onSeeAllLeaderboard,
    this.onOpenGroupTab,
  });

  final VoidCallback? onSeeAllLeaderboard;
  final VoidCallback? onOpenGroupTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color _background = Color(0xFF0B0B0F);
  static const Color _accent = Color(0xFF3B82F6);
  static const double _pagePadding = 16.0;

  TodayMetrics _today = TodayMetrics.zero;
  int _weekStepsTotal = 0;
  List<int> _weekStepsByDay = List.filled(7, 0);
  List<MotionStats> _miniLeaderboard = [];
  int? _myCurrentRank;
  int? _myPreviousRank;
  double? _standHours;
  bool _loading = true;

  final DailyStepsService _dailyStepsService = DailyStepsService();
  final LeaderboardService _leaderboardService = LeaderboardService();

  /// After health data loads, upsert today's stats to Supabase for the current user (background, no UI change).
  Future<void> _syncTodayToSupabase(TodayMetrics today) async {
    final user = Supabase.instance.client.auth.currentUser;
    // ignore: avoid_print
    if (user == null) {
      print('[DailySteps] current user id: none (not signed in), skip upsert');
      return;
    }
    // ignore: avoid_print
    print('[DailySteps] current user id: ${user.id}');
    final steps = today.steps;
    final miles = today.distanceMiles;
    final activeCalories = today.activeEnergyCalories.round();
    final exerciseMinutes = today.exerciseMinutes.round();
    // ignore: avoid_print
    print('[DailySteps] values being written: steps=$steps, miles=$miles, activeCalories=$activeCalories, exerciseMinutes=$exerciseMinutes');
    try {
      await _dailyStepsService.upsertDailySteps(
        userId: user.id,
        date: DateTime.now(),
        steps: steps,
        miles: miles,
        activeCalories: activeCalories,
        exerciseMinutes: exerciseMinutes,
      );
      // ignore: avoid_print
      print('[DailySteps] upsert success');
    } catch (e) {
      // ignore: avoid_print
      print('[DailySteps] upsert failure: $e');
    }
  }

  Future<void> _loadData() async {
    final today = await HealthService.getTodayMetrics();
    final weekSteps = await HealthService.getWeekStepsTotal();
    final weekByDay = await HealthService.getWeekStepsByDay();
    final standHours = await HealthService.getTodayStandHours();

    final selectedGroupId = selectedGroupService.selectedGroupId;
    List<MotionStats> top = [];
    int newRank = 0;
    if (selectedGroupId != null && selectedGroupId.isNotEmpty) {
      try {
        final currentUser = Supabase.instance.client.auth.currentUser;
        final currentUserId = currentUser?.id;
        final currentUserEmail = currentUser?.email?.toLowerCase();
        final rows = await _leaderboardService.fetchGroupLeaderboard(selectedGroupId);
        final filteredRows = rows.where((row) {
          final rowUserId = row['user_id']?.toString();
          final rowEmail = row['email']?.toString().toLowerCase();
          final rowDisplayName = row['display_name']?.toString().toLowerCase();
          if (currentUserId != null && rowUserId == currentUserId) return false;
          if (currentUserEmail != null && rowEmail == currentUserEmail) return false;
          // Some sources put email in display_name; avoid duplicate "You" row.
          if (currentUserEmail != null && rowDisplayName == currentUserEmail) return false;
          return true;
        }).toList();
        var list = filteredRows
            .map((row) => MotionStats(
                  name: LeaderboardService.resolveDisplayName(row),
                  steps: (row['total_steps'] as num?)?.toInt() ?? 0,
                  miles: (row['total_miles'] as num?)?.toDouble() ?? 0.0,
                  activeCalories: (row['total_active_calories'] as num?)?.toInt() ?? 0,
                  exerciseMinutes: (row['total_exercise_minutes'] as num?)?.toInt() ?? 0,
                  previousRank: null,
                ))
            .toList();
        final me = MotionStats(
          name: 'You',
          steps: today.steps,
          miles: today.distanceMiles,
          activeCalories: today.activeEnergyCalories.round(),
          exerciseMinutes: today.exerciseMinutes.round(),
          previousRank: null,
        );
        list = [me, ...list];
        list.sort((a, b) => b.steps.compareTo(a.steps));
        top = list.take(5).toList();
        newRank = list.indexWhere((e) => e.name == 'You') + 1;
      } catch (_) {
        top = [];
      }
    }

    if (!mounted) return;
    setState(() {
      _today = today;
      _weekStepsTotal = weekSteps;
      _weekStepsByDay = weekByDay;
      _miniLeaderboard = top;
      _myPreviousRank = _myCurrentRank;
      _myCurrentRank = newRank;
      _standHours = standHours;
      _loading = false;
    });
    // Background: upsert today's health metrics to Supabase daily_steps (current user only).
    _syncTodayToSupabase(today);
  }

  @override
  void initState() {
    super.initState();
    selectedGroupService.addListener(_onSelectedGroupChanged);
    _loadData();
  }

  @override
  void dispose() {
    selectedGroupService.removeListener(_onSelectedGroupChanged);
    super.dispose();
  }

  void _onSelectedGroupChanged() {
    if (mounted) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        top: true,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _accent))
            : RefreshIndicator(
                onRefresh: _loadData,
                color: _accent,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(_pagePadding, 16, _pagePadding, 24),
                  children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _HeroCard(
                    steps: _today.steps,
                    rank: _myCurrentRank,
                    previousRank: _myPreviousRank,
                  ),
                  const SizedBox(height: 20),
                  _TodayGrid(metrics: _today),
                  const SizedBox(height: 18),
                  _WeeklyTrendCard(
                    totalSteps: _weekStepsTotal,
                    dailySteps: _weekStepsByDay,
                  ),
                  const SizedBox(height: 18),
                  _MiniLeaderboardSection(
                    list: _miniLeaderboard,
                    onSeeAll: widget.onSeeAllLeaderboard,
                  ),
                  const SizedBox(height: 16),
                  _ActivitySection(
                    moveCal: _today.activeEnergyCalories,
                    exerciseMin: _today.exerciseMinutes,
                    standHours: _standHours,
                  ),
                ],
              ),
            ),
      ),
    );
  }

  static const Color _headerPillBg = Color(0xFF1A1A24);
  static const Color _headerPillBorder = Color(0xFF2A2A36);

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onOpenGroupTab,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _headerPillBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _headerPillBorder, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.groups_rounded,
                      size: 20,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      selectedGroupService.selectedGroupName ?? 'No group',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: (selectedGroupService.selectedGroupName ?? '').isEmpty
                            ? Colors.white.withValues(alpha: 0.5)
                            : Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 22,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            color: Colors.white70,
            onPressed: () => _loadData(),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.steps,
    required this.rank,
    required this.previousRank,
  });

  final int steps;
  final int? rank;
  final int? previousRank;

  static const Color _cardBg = Color(0xFF14141A);
  static const Color _accent = Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context) {
    final delta = (rank != null && previousRank != null) ? previousRank! - rank! : 0;
    final movedUp = delta > 0;
    final movedDown = delta < 0;
    String motionLine2;
    String motionArrow;
    if (movedUp) {
      motionLine2 = 'Up $delta today';
      motionArrow = '▲';
    } else if (movedDown) {
      motionLine2 = 'Down ${-delta} today';
      motionArrow = '▼';
    } else {
      motionLine2 = 'No change today';
      motionArrow = '↔';
    }
    final motionColor = movedUp
        ? const Color(0xFF22C55E)
        : (movedDown ? const Color(0xFFEF4444) : Colors.white38);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatSteps(steps),
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: _accent,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Steps today',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (rank != null)
                Text(
                  '#$rank in group',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              if (rank != null) const SizedBox(height: 6),
              Text(
                '$motionArrow $motionLine2',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: motionColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatSteps(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    final firstLen = s.length % 3;
    if (firstLen > 0) {
      buf.write(s.substring(0, firstLen));
      if (firstLen < s.length) buf.write(',');
    }
    for (var i = firstLen; i < s.length; i += 3) {
      buf.write(s.substring(i, i + 3));
      if (i + 3 < s.length) buf.write(',');
    }
    return buf.toString();
  }
}

class _TodayGrid extends StatelessWidget {
  const _TodayGrid({required this.metrics});

  final TodayMetrics metrics;

  static const double _cardHeight = 72;
  static const double _gapH = 8;
  static const double _gapV = 6;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  SizedBox(
                    height: _cardHeight,
                    child: _GridMetricCard(label: 'Steps', value: _formatInt(metrics.steps)),
                  ),
                  const SizedBox(height: _gapV),
                  SizedBox(
                    height: _cardHeight,
                    child: _GridMetricCard(label: 'Miles', value: metrics.distanceMiles.toStringAsFixed(1)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: _gapH),
            Expanded(
              child: Column(
                children: [
                  SizedBox(
                    height: _cardHeight,
                    child: _GridMetricCard(label: 'Active Cal', value: _formatInt(metrics.activeEnergyCalories.round())),
                  ),
                  const SizedBox(height: _gapV),
                  SizedBox(
                    height: _cardHeight,
                    child: _GridMetricCard(label: 'Exercise min', value: _formatInt(metrics.exerciseMinutes.round())),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _formatInt(int n) {
    if (n < 1000) return '$n';
    final s = n.toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    final firstLen = s.length % 3;
    if (firstLen > 0) {
      buf.write(s.substring(0, firstLen));
      if (firstLen < s.length) buf.write(',');
    }
    for (var i = firstLen; i < s.length; i += 3) {
      buf.write(s.substring(i, i + 3));
      if (i + 3 < s.length) buf.write(',');
    }
    return buf.toString();
  }
}

class _GridMetricCard extends StatelessWidget {
  const _GridMetricCard({required this.label, required this.value});

  final String label;
  final String value;

  static const Color _cardBg = Color(0xFF14141A);
  static const Color _accent = Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _accent,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyTrendCard extends StatelessWidget {
  const _WeeklyTrendCard({
    required this.totalSteps,
    required this.dailySteps,
  });

  final int totalSteps;
  final List<int> dailySteps;

  static const Color _cardBg = Color(0xFF14141A);
  static const Color _accent = Color(0xFF3B82F6);
  static const double _chartHeight = 56;

  @override
  Widget build(BuildContext context) {
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final steps = dailySteps.length >= 7 ? dailySteps : List<int>.filled(7, 0);
    final maxSteps = steps.isEmpty ? 1 : steps.reduce((a, b) => a > b ? a : b);
    final maxH = maxSteps > 0 ? maxSteps.toDouble() : 1.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'This Week',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              Text(
                _formatSteps(totalSteps),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: _chartHeight + 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final daySteps = steps[i];
                final h = maxH > 0
                    ? (daySteps / maxH * _chartHeight).clamp(4.0, _chartHeight)
                    : 4.0;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 20,
                      height: h,
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dayLabels[i],
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatSteps(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    final firstLen = s.length % 3;
    if (firstLen > 0) {
      buf.write(s.substring(0, firstLen));
      if (firstLen < s.length) buf.write(',');
    }
    for (var i = firstLen; i < s.length; i += 3) {
      buf.write(s.substring(i, i + 3));
      if (i + 3 < s.length) buf.write(',');
    }
    return buf.toString();
  }
}

class _MiniLeaderboardSection extends StatelessWidget {
  const _MiniLeaderboardSection({
    required this.list,
    this.onSeeAll,
  });

  final List<MotionStats> list;
  final VoidCallback? onSeeAll;

  static const Color _accent = Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Leaderboard',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            TextButton(
              onPressed: onSeeAll ?? () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const LeaderboardScreen()),
                  ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('See all', style: TextStyle(color: _accent, fontSize: 14)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF14141A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: list.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'Create or join a group to see the leaderboard.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < list.length; i++) ...[
                      _MiniLeaderboardRow(
                        rank: i + 1,
                        stats: list[i],
                        isYou: list[i].name == 'You',
                      ),
                      if (i < list.length - 1)
                        Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _MiniLeaderboardRow extends StatelessWidget {
  const _MiniLeaderboardRow({
    required this.rank,
    required this.stats,
    required this.isYou,
  });

  final int rank;
  final MotionStats stats;
  final bool isYou;

  static const _medals = ['🥇', '🥈', '🥉'];

  @override
  Widget build(BuildContext context) {
    final rankLabel = rank >= 1 && rank <= 3 ? _medals[rank - 1] : '$rank';
    return Material(
      color: isYou ? const Color(0xFF3B82F6).withValues(alpha: 0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PlayerDetailScreen(
                stats: stats,
                rank: rank,
                selectedRange: 'Today',
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  rankLabel,
                  style: TextStyle(
                    fontSize: rank <= 3 ? 16 : 13,
                    fontWeight: FontWeight.w600,
                    color: isYou ? const Color(0xFF3B82F6) : Colors.white70,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  stats.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isYou ? FontWeight.w600 : FontWeight.w500,
                    color: isYou ? Colors.white : Colors.white70,
                  ),
                ),
              ),
              Text(
                _formatSteps(stats.steps),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isYou ? const Color(0xFF3B82F6) : Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatSteps(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    final firstLen = s.length % 3;
    if (firstLen > 0) {
      buf.write(s.substring(0, firstLen));
      if (firstLen < s.length) buf.write(',');
    }
    for (var i = firstLen; i < s.length; i += 3) {
      buf.write(s.substring(i, i + 3));
      if (i + 3 < s.length) buf.write(',');
    }
    return buf.toString();
  }
}

class _ActivitySection extends StatelessWidget {
  const _ActivitySection({
    required this.moveCal,
    required this.exerciseMin,
    this.standHours,
  });

  final double moveCal;
  final double exerciseMin;
  final double? standHours;

  @override
  Widget build(BuildContext context) {
    final standValue = standHours != null
        ? '${standHours!.round()} hr'
        : '—';
    final standLabel = standHours != null ? 'Stand' : 'Stand (hr)';
    final standSubtitle = standHours == null ? 'Unavailable' : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Activity',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF14141A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: _ActivityChip(
                  label: 'Move',
                  value: '${moveCal.round()} cal',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActivityChip(
                  label: 'Exercise',
                  value: '${exerciseMin.round()} min',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActivityChip(
                  label: standLabel,
                  value: standValue,
                  subtitle: standSubtitle,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActivityChip extends StatelessWidget {
  const _ActivityChip({
    required this.label,
    required this.value,
    this.subtitle,
  });

  final String label;
  final String value;
  final String? subtitle;

  static const Color _cardBg = Color(0xFF14141A);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
