import 'package:flutter/material.dart';
import '../models/motion_stats.dart';
import '../models/today_metrics.dart';
import '../services/health_service.dart';
import '../services/mock_motion_service.dart';
import '../widgets/leaderboard_card.dart';
import 'leaderboard_screen.dart';
import 'player_detail_screen.dart';

/// Dashboard: Today cards (Steps, Miles, Active Cals, Exercise Mins), This Week steps, mini leaderboard.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color _background = Color(0xFF0B0B0F);
  static const Color _accent = Color(0xFF3B82F6);
  static const double _pagePadding = 16.0;

  TodayMetrics _today = TodayMetrics.zero;
  int _weekStepsTotal = 0;
  List<MotionStats> _miniLeaderboard = [];
  bool _loading = true;

  Future<void> _loadData() async {
    final today = await HealthService.getTodayMetrics();
    final weekSteps = await HealthService.getWeekStepsTotal();
    var list = MockMotionService.getLeaderboardForRange('Today');
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
    final top = list.take(5).toList();
    if (!mounted) return;
    setState(() {
      _today = today;
      _weekStepsTotal = weekSteps;
      _miniLeaderboard = top;
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Got Motion',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            color: Colors.white70,
            onPressed: () => _loadData(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: _accent,
              child: ListView(
                padding: const EdgeInsets.all(_pagePadding),
                children: [
                  const Text(
                    'Today',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _TodayCards(metrics: _today),
                  const SizedBox(height: 24),
                  const Text(
                    'This Week',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _WeekStepsWidget(totalSteps: _weekStepsTotal),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Leaderboard',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const LeaderboardScreen(),
                          ),
                        ),
                        child: const Text('See all', style: TextStyle(color: _accent)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _MiniLeaderboard(list: _miniLeaderboard),
                ],
              ),
            ),
    );
  }
}

class _TodayCards extends StatelessWidget {
  const _TodayCards({required this.metrics});

  final TodayMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _MetricCard(label: 'Steps', value: _formatInt(metrics.steps))),
        const SizedBox(width: 10),
        Expanded(child: _MetricCard(label: 'Miles', value: metrics.distanceMiles.toStringAsFixed(1))),
        const SizedBox(width: 10),
        Expanded(child: _MetricCard(label: 'Active Cal', value: _formatInt(metrics.activeEnergyCalories.round()))),
        const SizedBox(width: 10),
        Expanded(child: _MetricCard(label: 'Exercise min', value: _formatInt(metrics.exerciseMinutes.round()))),
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  static const Color _cardBg = Color(0xFF14141A);
  static const Color _accent = Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _accent,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekStepsWidget extends StatelessWidget {
  const _WeekStepsWidget({required this.totalSteps});

  final int totalSteps;

  static const Color _cardBg = Color(0xFF14141A);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total steps',
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          Text(
            _formatSteps(totalSteps),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF3B82F6),
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

class _MiniLeaderboard extends StatelessWidget {
  const _MiniLeaderboard({required this.list});

  final List<MotionStats> list;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < list.length; i++) ...[
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PlayerDetailScreen(
                    stats: list[i],
                    rank: i + 1,
                    selectedRange: 'Today',
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: LeaderboardCard(rank: i + 1, stats: list[i]),
          ),
          if (i < list.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}
