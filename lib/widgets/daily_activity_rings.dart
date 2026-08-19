import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Apple Fitness–style concentric daily goal rings. Center stays open so the
/// rings remain the hero; progress detail lives in the legend below.
class DailyActivityRings extends StatefulWidget {
  const DailyActivityRings({
    super.key,
    required this.steps,
    required this.stepsGoal,
    required this.calories,
    required this.caloriesGoal,
    required this.exerciseMinutes,
    required this.exerciseGoal,
    required this.miles,
    required this.milesGoal,
    this.size = 156,
  });

  final int steps;
  final int stepsGoal;
  final int calories;
  final int caloriesGoal;
  final int exerciseMinutes;
  final int exerciseGoal;
  final double miles;
  final double milesGoal;
  final double size;

  static const stepsColor = Color(0xFF218FFF);
  static const caloriesColor = Color(0xFFFF8A1E);
  static const exerciseColor = Color(0xFF9A73FF);
  static const milesColor = Color(0xFF16D6A0);

  int get completedCount => [
    steps >= stepsGoal,
    calories >= caloriesGoal,
    exerciseMinutes >= exerciseGoal,
    miles >= milesGoal,
  ].where((done) => done).length;

  bool get allComplete => completedCount == 4;

  @override
  State<DailyActivityRings> createState() => _DailyActivityRingsState();
}

class _DailyActivityRingsState extends State<DailyActivityRings>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (widget.allComplete) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(DailyActivityRings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.allComplete && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.allComplete && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  List<_RingData> get _rings => [
    _RingData(
      progress: _progress(widget.steps, widget.stepsGoal),
      color: DailyActivityRings.stepsColor,
      trackColor: const Color(0xFF18365A),
      radius: widget.size * 0.46,
      strokeWidth: widget.size * 0.072,
    ),
    _RingData(
      progress: _progress(widget.calories, widget.caloriesGoal),
      color: DailyActivityRings.caloriesColor,
      trackColor: const Color(0xFF3D2818),
      radius: widget.size * 0.355,
      strokeWidth: widget.size * 0.072,
    ),
    _RingData(
      progress: _progress(widget.exerciseMinutes, widget.exerciseGoal),
      color: DailyActivityRings.exerciseColor,
      trackColor: const Color(0xFF2A2240),
      radius: widget.size * 0.25,
      strokeWidth: widget.size * 0.072,
    ),
    _RingData(
      progress: _progress(widget.miles, widget.milesGoal),
      color: DailyActivityRings.milesColor,
      trackColor: const Color(0xFF123028),
      radius: widget.size * 0.145,
      strokeWidth: widget.size * 0.068,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          return CustomPaint(
            painter: _ActivityRingsPainter(
              rings: _rings,
              glowStrength: widget.allComplete ? 0.35 + _pulse.value * 0.45 : 0,
            ),
          );
        },
      ),
    );
  }

  static double _progress(num value, num goal) {
    if (goal <= 0) return 0;
    return (value / goal).clamp(0.0, 1.0);
  }
}

class _RingData {
  const _RingData({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.radius,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double radius;
  final double strokeWidth;
}

class _ActivityRingsPainter extends CustomPainter {
  const _ActivityRingsPainter({
    required this.rings,
    this.glowStrength = 0,
  });

  final List<_RingData> rings;
  final double glowStrength;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const startAngle = -math.pi / 2;

    if (glowStrength > 0) {
      final glowPaint = Paint()
        ..color = DailyActivityRings.stepsColor.withValues(
          alpha: 0.08 + glowStrength * 0.12,
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      canvas.drawCircle(center, size.width * 0.42, glowPaint);
    }

    for (final ring in rings) {
      final rect = Rect.fromCircle(center: center, radius: ring.radius);
      final trackPaint = Paint()
        ..color = ring.trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = ring.strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, startAngle, math.pi * 2, false, trackPaint);

      if (ring.progress <= 0) continue;

      if (glowStrength > 0 && ring.progress >= 1) {
        final halo = Paint()
          ..color = ring.color.withValues(alpha: 0.25 + glowStrength * 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = ring.strokeWidth + 6
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawArc(rect, startAngle, math.pi * 2, false, halo);
      }

      final progressPaint = Paint()
        ..color = ring.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = ring.strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        rect,
        startAngle,
        math.pi * 2 * ring.progress.clamp(0, 1),
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ActivityRingsPainter oldDelegate) {
    return oldDelegate.rings != rings ||
        oldDelegate.glowStrength != glowStrength;
  }
}

class DailyRingLegend extends StatelessWidget {
  const DailyRingLegend({
    super.key,
    required this.steps,
    required this.stepsGoal,
    required this.calories,
    required this.caloriesGoal,
    required this.exerciseMinutes,
    required this.exerciseGoal,
    required this.miles,
    required this.milesGoal,
  });

  final int steps;
  final int stepsGoal;
  final int calories;
  final int caloriesGoal;
  final int exerciseMinutes;
  final int exerciseGoal;
  final double miles;
  final double milesGoal;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _LegendRow(
          color: DailyActivityRings.stepsColor,
          label: 'Steps',
          value: _formatInt(steps),
          goal: _formatInt(stepsGoal),
          progress: _progress(steps, stepsGoal),
        ),
        const SizedBox(height: 10),
        _LegendRow(
          color: DailyActivityRings.caloriesColor,
          label: 'Calories',
          value: '$calories',
          goal: '$caloriesGoal',
          progress: _progress(calories, caloriesGoal),
        ),
        const SizedBox(height: 10),
        _LegendRow(
          color: DailyActivityRings.exerciseColor,
          label: 'Exercise',
          value: '$exerciseMinutes',
          goal: '$exerciseGoal min',
          progress: _progress(exerciseMinutes, exerciseGoal),
        ),
        const SizedBox(height: 10),
        _LegendRow(
          color: DailyActivityRings.milesColor,
          label: 'Miles',
          value: _formatMiles(miles),
          goal: _formatMiles(milesGoal),
          progress: _progress(miles, milesGoal),
        ),
      ],
    );
  }

  static double _progress(num value, num goal) {
    if (goal <= 0) return 0;
    return (value / goal).clamp(0.0, 1.0);
  }

  static String _formatInt(int value) =>
      value.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => ',',
      );

  static String _formatMiles(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
    required this.goal,
    required this.progress,
  });

  final Color color;
  final String label;
  final String value;
  final String goal;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final done = progress >= 1;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              color: done ? Colors.white : const Color(0xFF8F99AA),
              fontSize: 12,
              fontWeight: done ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.15),
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: Text(
            '$value / $goal',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: done ? color : Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (done) ...[
          const SizedBox(width: 4),
          Icon(Icons.check_circle_rounded, size: 14, color: color),
        ],
      ],
    );
  }
}
