import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/today_metrics.dart';
import '../services/goal_celebration_copy.dart';
import '../services/goal_service.dart';

/// Full-screen confetti + champagne moment once per user per calendar day.
class GoalCelebrationService {
  GoalCelebrationService._();
  static final GoalCelebrationService instance = GoalCelebrationService._();

  static String _key(String userId) => 'goal_celebration_$userId';

  Future<void> maybeCelebrate(
    BuildContext context, {
    required String userId,
    VoidCallback? onKeepMoving,
  }) async {
    final today = _todayKey();
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_key(userId)) == today) return;
    if (!context.mounted) return;

    await prefs.setString(_key(userId), today);
    if (!context.mounted) return;
    await show(context, onKeepMoving: onKeepMoving);
  }

  Future<void> show(
    BuildContext context, {
    VoidCallback? onKeepMoving,
  }) async {
    await HapticFeedback.heavyImpact();
    if (!context.mounted) return;

    final copy = GoalCelebrationCopy.forToday();

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss celebration',
      barrierColor: Colors.black.withValues(alpha: 0.62),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _GoalCompleteCelebration(
          headline: copy.headline,
          body: copy.body,
          onKeepMoving: onKeepMoving,
        );
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

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  static bool allGoalsComplete(TodayMetrics today, UserGoals goals) {
    return today.steps >= goals.steps &&
        today.activeEnergyCalories.round() >= goals.activeCalories &&
        today.exerciseMinutes.round() >= goals.exerciseMinutes &&
        today.distanceMiles >= goals.miles;
  }
}

final goalCelebrationService = GoalCelebrationService.instance;

class _GoalCompleteCelebration extends StatefulWidget {
  const _GoalCompleteCelebration({
    required this.headline,
    required this.body,
    this.onKeepMoving,
  });

  final String headline;
  final String body;
  final VoidCallback? onKeepMoving;

  @override
  State<_GoalCompleteCelebration> createState() =>
      _GoalCompleteCelebrationState();
}

class _GoalCompleteCelebrationState extends State<_GoalCompleteCelebration>
    with TickerProviderStateMixin {
  late final AnimationController _confetti;
  late final AnimationController _pop;
  late final AnimationController _sparkle;

  @override
  void initState() {
    super.initState();
    _confetti = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..forward();
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _sparkle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    Future<void>.delayed(const Duration(milliseconds: 420), () {
      if (mounted) HapticFeedback.mediumImpact();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    _pop.dispose();
    _sparkle.dispose();
    super.dispose();
  }

  void _onKeepMoving() {
    Navigator.of(context).pop();
    widget.onKeepMoving?.call();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Material(
      color: Colors.transparent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _confetti,
            builder: (context, _) => CustomPaint(
              painter: _ConfettiPainter(
                progress: _confetti.value,
                burstCenter: Offset(size.width / 2, size.height * 0.42),
              ),
              size: size,
            ),
          ),
          ScaleTransition(
            scale: CurvedAnimation(parent: _pop, curve: Curves.elasticOut),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
              decoration: BoxDecoration(
                color: const Color(0xFF11151B),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF315E91)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF218FFF).withValues(alpha: 0.28),
                    blurRadius: 36 + _sparkle.value * 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _sparkle,
                    builder: (context, child) => Transform.rotate(
                      angle: _sparkle.value * 0.08 - 0.04,
                      child: child,
                    ),
                    child: const Text('🍾', style: TextStyle(fontSize: 64)),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.headline,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.body,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF8F99AA),
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _onKeepMoving,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF168BFF),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Keep it moving',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress, required this.burstCenter});

  final double progress;
  final Offset burstCenter;

  static const _colors = [
    Color(0xFF218FFF),
    Color(0xFFFF8A1E),
    Color(0xFF9A73FF),
    Color(0xFF16D6A0),
    Color(0xFFFFD54F),
    Color(0xFFFF5C8A),
    Color(0xFFFFFFFF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    _paintBurst(canvas, size, seed: 11, count: 70, speed: 1.0);
    _paintRain(canvas, size, seed: 29, count: 55, speed: 0.85);
  }

  void _paintBurst(
    Canvas canvas,
    Size size, {
    required int seed,
    required int count,
    required double speed,
  }) {
    final random = math.Random(seed);
    for (var i = 0; i < count; i++) {
      final angle = random.nextDouble() * math.pi * 2;
      final distance = progress * speed * (80 + random.nextDouble() * 220);
      final x = burstCenter.dx + math.cos(angle) * distance;
      final y = burstCenter.dy + math.sin(angle) * distance - progress * 40;
      if (progress < 0.05) continue;

      final paint = Paint()..color = _colors[i % _colors.length];
      final w = 5.0 + (i % 4);
      final h = 9.0 + (i % 5);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * math.pi * 4 + i * 0.4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w, height: h),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  void _paintRain(
    Canvas canvas,
    Size size, {
    required int seed,
    required int count,
    required double speed,
  }) {
    final random = math.Random(seed);
    for (var i = 0; i < count; i++) {
      final originX = random.nextDouble() * size.width;
      final delay = random.nextDouble() * 0.3;
      final local = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;

      final y = -30 + local * speed * (size.height * 0.95);
      final x = originX + math.sin(local * math.pi * 5 + i) * 36;
      final paint = Paint()
        ..color = _colors[(i + 2) % _colors.length].withValues(alpha: 0.85);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(local * math.pi * 3 + i);
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
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
