import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/motion_stats.dart';
import '../widgets/footsteps_icon.dart';

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
  static const _background = Color(0xFF07090D);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                color: Colors.white,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF11151B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Color(0xFF202631)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  stats.isCurrentUser
                      ? 'Your Performance'
                      : 'Player Performance',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _PlayerHero(stats: stats, rank: rank, range: selectedRange),
          const SizedBox(height: 22),
          const _SectionTitle('Stat Line'),
          const SizedBox(height: 10),
          _StatGrid(stats: stats),
          const SizedBox(height: 22),
          const _SectionTitle('Activity Breakdown'),
          const SizedBox(height: 10),
          _BreakdownCard(stats: stats),
        ],
      ),
    ),
  );
}

class _PlayerHero extends StatelessWidget {
  const _PlayerHero({
    required this.stats,
    required this.rank,
    required this.range,
  });
  final MotionStats stats;
  final int rank;
  final String range;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFF315E91)),
      gradient: const LinearGradient(
        colors: [Color(0xFF102A4B), Color(0xFF091522)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x26168BFF),
          blurRadius: 24,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      children: [
        Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: const Color(0xFF23324A),
                  backgroundImage: stats.avatarUrl?.isNotEmpty == true
                      ? NetworkImage(stats.avatarUrl!)
                      : null,
                  child: stats.avatarUrl?.isNotEmpty == true
                      ? null
                      : Text(
                          stats.name.isEmpty
                              ? '?'
                              : stats.name.characters.first.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
                Positioned(
                  right: -3,
                  bottom: -3,
                  child: _RankBadge(rank: rank),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stats.isCurrentUser ? '${stats.name} · You' : stats.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '#$rank · $range',
                    style: const TextStyle(
                      color: Color(0xFF87A9CF),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Container(height: 1, color: const Color(0xFF264565)),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FootstepsIcon(size: 28, color: Color(0xFF3FA5FF)),
            const SizedBox(width: 12),
            Text(
              _format(stats.steps),
              style: const TextStyle(
                color: Color(0xFF3FA5FF),
                fontSize: 40,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const Text(
          'STEPS',
          style: TextStyle(
            color: Color(0xFF89A0BA),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats});
  final MotionStats stats;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _StatTile(
          icon: Icons.route_rounded,
          color: const Color(0xFF16D69A),
          label: 'Miles',
          value: stats.miles.toStringAsFixed(1),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _StatTile(
          icon: Icons.local_fire_department_rounded,
          color: const Color(0xFFFF8A1E),
          label: 'Calories',
          value: '${_format(stats.activeCalories)} CAL',
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _StatTile(
          icon: Icons.timer_outlined,
          color: const Color(0xFF9A73FF),
          label: 'Exercise',
          value: '${stats.exerciseMinutes} MIN',
        ),
      ),
    ],
  );
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    height: 108,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF11151B),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFF202631)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const Spacer(),
        Text(
          value,
          maxLines: 1,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF808B9C), fontSize: 10),
        ),
      ],
    ),
  );
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.stats});
  final MotionStats stats;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF11151B),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFF202631)),
    ),
    child: Column(
      children: [
        _ProgressRow(
          label: 'Steps',
          value: stats.steps,
          reference: 10000,
          color: const Color(0xFF218FFF),
        ),
        const SizedBox(height: 18),
        _ProgressRow(
          label: 'Active calories',
          value: stats.activeCalories,
          reference: 500,
          color: const Color(0xFFFF8A1E),
        ),
        const SizedBox(height: 18),
        _ProgressRow(
          label: 'Exercise minutes',
          value: stats.exerciseMinutes,
          reference: 30,
          color: const Color(0xFF9A73FF),
        ),
      ],
    ),
  );
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.value,
    required this.reference,
    required this.color,
  });
  final String label;
  final int value;
  final int reference;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress = math.min(1.0, value / reference);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Color(0xFF98A3B4), fontSize: 13),
              ),
            ),
            Text(
              _format(value),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: color.withValues(alpha: .14),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});
  final int rank;

  @override
  Widget build(BuildContext context) {
    final color = rank == 1
        ? const Color(0xFFFFC22E)
        : rank == 2
        ? const Color(0xFFBBC6D6)
        : rank == 3
        ? const Color(0xFFC98246)
        : const Color(0xFF536073);
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [color, color.withValues(alpha: .55)]),
        border: Border.all(color: color),
      ),
      child: Text(
        '$rank',
        style: const TextStyle(
          color: Color(0xFF121418),
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.w800,
    ),
  );
}

String _format(num value) => value.round().toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => ',',
);
