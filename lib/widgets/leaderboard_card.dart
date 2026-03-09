import 'package:flutter/material.dart';
import '../models/motion_stats.dart';

/// Single leaderboard row: rank, name, steps (emphasized), miles, calories, minutes.
class LeaderboardCard extends StatelessWidget {
  const LeaderboardCard({
    super.key,
    required this.rank,
    required this.stats,
  });

  static const Color _cardBackground = Color(0xFF14141A);
  static const Color _accent = Color(0xFF3B82F6);
  static const double _radius = 16.0;

  final int rank;
  final MotionStats stats;

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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildRank(),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            backgroundImage: (stats.avatarUrl != null && stats.avatarUrl!.isNotEmpty)
                ? NetworkImage(stats.avatarUrl!)
                : null,
            child: (stats.avatarUrl == null || stats.avatarUrl!.isEmpty)
                ? Text(
                    stats.name.isNotEmpty ? stats.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  stats.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatSteps(stats.steps),
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                    Text(
                      'Steps',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _statChip('${stats.miles.toStringAsFixed(1)} mi'),
                    const SizedBox(width: 8),
                    _statChip('${stats.activeCalories} cal'),
                    const SizedBox(width: 8),
                    _statChip('${stats.exerciseMinutes} min'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRank() {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: rank <= 3 ? _accent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      child: Text(
        '$rank',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: rank <= 3 ? _accent : Colors.white70,
        ),
      ),
    );
  }

  Widget _statChip(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        color: Colors.white.withValues(alpha: 0.65),
      ),
    );
  }
}
