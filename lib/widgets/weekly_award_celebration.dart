import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/weekly_group_award.dart';
import '../services/weekly_award_copy.dart';

class WeeklyAwardCelebrationService {
  WeeklyAwardCelebrationService._();
  static final WeeklyAwardCelebrationService instance =
      WeeklyAwardCelebrationService._();

  static String _key(String userId, String groupId, String weekKey) =>
      'weekly_award_celebration_${userId}_${groupId}_$weekKey';

  Future<void> maybeCelebrate({
    required BuildContext context,
    required String userId,
    required String groupId,
    required String groupName,
    required WeeklyGroupAwards awards,
  }) async {
    final mine = awards.winsForUser(userId);
    if (mine.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_key(userId, groupId, awards.weekKey)) == '1') return;
    if (!context.mounted) return;

    await prefs.setString(_key(userId, groupId, awards.weekKey), '1');
    if (!context.mounted) return;

    await show(context, groupName: groupName, wins: mine);
  }

  Future<void> show(
    BuildContext context, {
    required String groupName,
    required List<WeeklyAwardWinner> wins,
  }) async {
    await HapticFeedback.heavyImpact();
    if (!context.mounted) return;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss weekly award',
      barrierColor: Colors.black.withValues(alpha: 0.62),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _WeeklyAwardCelebration(groupName: groupName, wins: wins);
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
    );
  }
}

final weeklyAwardCelebrationService = WeeklyAwardCelebrationService.instance;

class _WeeklyAwardCelebration extends StatefulWidget {
  const _WeeklyAwardCelebration({
    required this.groupName,
    required this.wins,
  });

  final String groupName;
  final List<WeeklyAwardWinner> wins;

  @override
  State<_WeeklyAwardCelebration> createState() =>
      _WeeklyAwardCelebrationState();
}

class _WeeklyAwardCelebrationState extends State<_WeeklyAwardCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confetti;
  bool get _swept => WeeklyAwardCopy.sweptAllCategories(widget.wins);

  @override
  void initState() {
    super.initState();
    _confetti = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..forward();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final headline = WeeklyAwardCopy.celebrationHeadline(widget.wins);
    final body = WeeklyAwardCopy.celebrationBody(
      wins: widget.wins,
      groupName: widget.groupName,
    );

    return Material(
      color: Colors.transparent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _confetti,
            builder: (context, _) => CustomPaint(
              painter: _WeeklyConfettiPainter(
                progress: _confetti.value,
                center: Offset(size.width / 2, size.height * 0.34),
              ),
              size: size,
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 22),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            decoration: BoxDecoration(
              color: const Color(0xFF11151B),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _swept
                    ? const Color(0xFFFFB547)
                    : const Color(0xFF6E5718),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFB547).withValues(
                    alpha: _swept ? 0.32 : 0.18,
                  ),
                  blurRadius: 34,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _swept ? '👑' : '🏆',
                  style: const TextStyle(fontSize: 58),
                ),
                const SizedBox(height: 12),
                Text(
                  headline,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  WeeklyAwardCopy.celebrationSubhead(widget.groupName),
                  style: const TextStyle(
                    color: Color(0xFFFFB547),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                if (_swept)
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFE8EDF5),
                      fontSize: 15,
                      height: 1.45,
                    ),
                  )
                else
                  ...widget.wins.map((win) => _HighlightCard(win: win)),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB547),
                    foregroundColor: const Color(0xFF11151B),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _swept ? 'King\'s work' : 'Keep it up',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({required this.win});

  final WeeklyAwardWinner win;

  @override
  Widget build(BuildContext context) {
    final accent = switch (win.category) {
      WeeklyAwardCategory.steps => const Color(0xFF218FFF),
      WeeklyAwardCategory.calories => const Color(0xFFFF8A1E),
      WeeklyAwardCategory.exercise => const Color(0xFF9A73FF),
      WeeklyAwardCategory.miles => const Color(0xFF16D6A0),
    };

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1016),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(win.category.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                win.category.headlineYou,
                style: TextStyle(
                  color: accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                win.category.formatValue(win.value),
                style: const TextStyle(
                  color: Color(0xFF8F99AA),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            win.category.highlightYou(win.value),
            style: const TextStyle(
              color: Color(0xFFE8EDF5),
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyConfettiPainter extends CustomPainter {
  _WeeklyConfettiPainter({required this.progress, required this.center});

  final double progress;
  final Offset center;

  static const _colors = [
    Color(0xFFFFB547),
    Color(0xFF218FFF),
    Color(0xFFFF8A1E),
    Color(0xFF16D6A0),
    Color(0xFFFFFFFF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(19);
    for (var i = 0; i < 65; i++) {
      final angle = random.nextDouble() * math.pi * 2;
      final distance = progress * (90 + random.nextDouble() * 210);
      final x = center.dx + math.cos(angle) * distance;
      final y = center.dy + math.sin(angle) * distance - progress * 30;
      if (progress < 0.04) continue;
      final paint = Paint()..color = _colors[i % _colors.length];
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * math.pi * 3 + i);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: 5 + (i % 3),
            height: 9 + (i % 4),
          ),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
