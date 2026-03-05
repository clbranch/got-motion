import 'package:flutter/material.dart';
import '../models/motion_stats.dart';

/// V1 player profile screen: avatar, name, username, hero step count, stats rows.
class PlayerDetailScreen extends StatelessWidget {
  const PlayerDetailScreen({
    super.key,
    required this.stats,
    required this.rank,
    required this.selectedRange,
  });

  final MotionStats stats;
  final int rank;
  final String selectedRange;

  static const Color _background = Color(0xFF0B0B0F);
  static const Color _accent = Color(0xFF3B82F6);
  static const double _pagePadding = 16.0;

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

  static String _usernameFromName(String name) {
    return '@${name.toLowerCase().replaceAll(' ', '')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          stats.name,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        iconTheme: IconThemeData(color: Colors.white.withValues(alpha: 0.9)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: _pagePadding, vertical: 24),
        children: [
          // Profile section
          Center(
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  stats.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  _usernameFromName(stats.name),
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Hero metric
          Center(
            child: Column(
              children: [
                Text(
                  _formatSteps(stats.steps),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: _accent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Steps Today',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Stats section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                _RankRow(
                  rank: rank,
                  previousRank: stats.previousRank,
                  showMovement: selectedRange == 'This Week' || selectedRange == 'This Month',
                ),
                _StatRow(label: 'Miles', value: stats.miles.toStringAsFixed(1)),
                _StatRow(label: 'Calories', value: '${stats.activeCalories}'),
                _StatRow(label: 'Minutes', value: '${stats.exerciseMinutes}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.previousRank,
    required this.showMovement,
  });

  final int rank;
  final int? previousRank;
  final bool showMovement;

  @override
  Widget build(BuildContext context) {
    final effectivePrevious = previousRank ?? rank;
    final delta = effectivePrevious - rank;
    Widget? arrow;
    if (showMovement) {
      if (delta > 0) {
        arrow = Icon(Icons.arrow_upward, size: 20, color: Colors.green.shade400);
      } else if (delta < 0) {
        arrow = Icon(Icons.arrow_downward, size: 20, color: Colors.red.shade400);
      } else {
        arrow = Icon(Icons.remove, size: 20, color: Colors.white.withValues(alpha: 0.45));
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Rank',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (arrow != null) ...[arrow, const SizedBox(width: 6)],
              Text(
                '$rank',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
