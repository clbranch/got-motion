import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/logged_workout.dart';
import '../services/daily_steps_service.dart';
import '../services/health_service.dart';
import '../services/workout_log_service.dart';
import '../widgets/settings_ui.dart';

const _bg = Color(0xFF07090D);
const _card = Color(0xFF12161E);
const _accent = Color(0xFF2997FF);
const _purple = Color(0xFF9A73FF);
const _timerYellow = Color(0xFFFFCC33);
const _endRed = Color(0xFFFF453A);
const _muted = Color(0xFF8D98AA);

/// Opens Fitness-style workout picker → countdown → live session.
/// Keeps entry off Home (Profile / Health only).
Future<void> showStartWorkoutSheet(BuildContext context) async {
  final active = await workoutLogService.getActiveSession();
  if (!context.mounted) return;
  if (active != null) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ActiveWorkoutScreen(session: active),
      ),
    );
    return;
  }

  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => const WorkoutPickerScreen(),
    ),
  );
}

IconData iconForWorkout(WorkoutActivityKind kind) {
  switch (kind) {
    case WorkoutActivityKind.cycling:
      return Icons.directions_bike_rounded;
    case WorkoutActivityKind.running:
      return Icons.directions_run_rounded;
    case WorkoutActivityKind.walking:
      return Icons.directions_walk_rounded;
    case WorkoutActivityKind.strength:
      return Icons.fitness_center_rounded;
    case WorkoutActivityKind.hiit:
      return Icons.bolt_rounded;
    case WorkoutActivityKind.other:
      return Icons.sports_rounded;
  }
}

Color accentForWorkout(WorkoutActivityKind kind) {
  switch (kind) {
    case WorkoutActivityKind.cycling:
      return const Color(0xFF38D6C5);
    case WorkoutActivityKind.running:
      return const Color(0xFFFF8A1E);
    case WorkoutActivityKind.walking:
      return _accent;
    case WorkoutActivityKind.strength:
      return _purple;
    case WorkoutActivityKind.hiit:
      return const Color(0xFFFF5A67);
    case WorkoutActivityKind.other:
      return const Color(0xFF9BA5B7);
  }
}

// ---------------------------------------------------------------------------
// Picker (Fitness-style cards)
// ---------------------------------------------------------------------------

class WorkoutPickerScreen extends StatelessWidget {
  const WorkoutPickerScreen({super.key});

  Future<void> _start(BuildContext context, WorkoutActivityKind kind) async {
    final started = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => WorkoutCountdownScreen(kind: kind),
      ),
    );
    if (started != true || !context.mounted) return;
    await workoutLogService.startSession(kind);
    final session = await workoutLogService.getActiveSession();
    if (session == null || !context.mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ActiveWorkoutScreen(session: session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Workout',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const Text(
            'Optional for iPhone without a Watch — Watch users can skip this; Health already tracks you.',
            style: TextStyle(color: _muted, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 16),
          for (final kind in WorkoutActivityKind.values) ...[
            _WorkoutTypeCard(
              kind: kind,
              onStart: () => _start(context, kind),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _WorkoutTypeCard extends StatelessWidget {
  const _WorkoutTypeCard({required this.kind, required this.onStart});

  final WorkoutActivityKind kind;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final color = accentForWorkout(kind);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(iconForWorkout(kind), color: color, size: 22),
                ),
                const SizedBox(height: 12),
                Text(
                  kind.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  kind.subtitle,
                  style: const TextStyle(color: _muted, fontSize: 13),
                ),
              ],
            ),
          ),
          Material(
            color: color,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onStart,
              child: const SizedBox(
                width: 56,
                height: 56,
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Countdown 3 → 2 → 1 → Go
// ---------------------------------------------------------------------------

class WorkoutCountdownScreen extends StatefulWidget {
  const WorkoutCountdownScreen({super.key, required this.kind});

  final WorkoutActivityKind kind;

  @override
  State<WorkoutCountdownScreen> createState() => _WorkoutCountdownScreenState();
}

class _WorkoutCountdownScreenState extends State<WorkoutCountdownScreen>
    with SingleTickerProviderStateMixin {
  int _count = 3;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
    _runCountdown();
  }

  Future<void> _runCountdown() async {
    for (var n = 3; n >= 1; n--) {
      if (!mounted) return;
      setState(() => _count = n);
      _pulse
        ..value = 0
        ..forward();
      await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 900));
    }
    if (!mounted) return;
    await SystemSound.play(SystemSoundType.click);
    await HapticFeedback.mediumImpact();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = accentForWorkout(widget.kind);
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(iconForWorkout(widget.kind), color: color, size: 28),
              ),
              const SizedBox(height: 28),
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) {
                  final t = Curves.easeOut.transform(_pulse.value);
                  return SizedBox(
                    width: 180,
                    height: 180,
                    child: CustomPaint(
                      painter: _CountdownRingPainter(
                        progress: t,
                        color: color,
                      ),
                      child: Center(
                        child: Text(
                          '$_count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 84,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                widget.kind.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountdownRingPainter extends CustomPainter {
  _CountdownRingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    final track = Paint()
      ..color = color.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _CountdownRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

// ---------------------------------------------------------------------------
// Active workout (Fitness-inspired)
// ---------------------------------------------------------------------------

class ActiveWorkoutScreen extends StatefulWidget {
  const ActiveWorkoutScreen({super.key, required this.session});

  final ActiveWorkoutSession session;

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  Timer? _tick;
  late ActiveWorkoutSession _session;
  Duration _elapsed = Duration.zero;
  bool _finishing = false;
  bool _pauseOpen = false;

  WorkoutActivityKind get _kind =>
      WorkoutActivityKindX.fromStorage(_session.activityType);

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _elapsed = Duration(seconds: _session.elapsedSecondsAt(DateTime.now()));
    _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted || _session.isPaused) return;
      setState(() {
        _elapsed = Duration(seconds: _session.elapsedSecondsAt(DateTime.now()));
      });
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String get _clock {
    final total = _elapsed.inSeconds;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  Future<void> _openPauseSheet() async {
    if (_pauseOpen || _finishing) return;
    final updated = await workoutLogService.pauseSession();
    if (updated != null) _session = updated;
    setState(() {
      _pauseOpen = true;
      _elapsed = Duration(seconds: _session.elapsedSecondsAt(DateTime.now()));
    });
    await HapticFeedback.mediumImpact();

    if (!mounted) return;
    final action = await showModalBottomSheet<_PauseAction>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (sheetContext) => _PauseSheet(
        title: _session.title,
        kind: _kind,
        clock: _clock,
      ),
    );

    if (!mounted) return;
    setState(() => _pauseOpen = false);

    if (action == _PauseAction.end) {
      await _finish();
      return;
    }

    // Resume (default)
    final resumed = await workoutLogService.resumeSession();
    if (resumed != null) _session = resumed;
    setState(() {
      _elapsed = Duration(seconds: _session.elapsedSecondsAt(DateTime.now()));
    });
  }

  Future<void> _finish() async {
    if (_finishing) return;
    final proof = await showModalBottomSheet<_FinishChoice>(
      context: context,
      backgroundColor: settingsSurface,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _FinishWorkoutSheet(),
    );
    if (proof == null || !mounted) {
      // User dismissed — keep paused session so they can resume.
      final resumed = await workoutLogService.resumeSession();
      if (resumed != null && mounted) {
        setState(() {
          _session = resumed;
          _elapsed =
              Duration(seconds: _session.elapsedSecondsAt(DateTime.now()));
        });
      }
      return;
    }
    if (proof.discarded) {
      await workoutLogService.clearActiveSession();
      if (mounted) Navigator.of(context).pop();
      return;
    }

    setState(() => _finishing = true);
    try {
      final logged = await workoutLogService.finishSession(
        session: _session,
        proofImage: proof.image,
        proofVideo: proof.video,
      );
      try {
        final metrics = await HealthService.getTodayMetrics();
        await DailyStepsService().upsertDailySteps(
          userId: logged.userId,
          date: DateTime.now(),
          steps: metrics.steps,
          miles: metrics.distanceMiles,
          activeCalories: metrics.activeEnergyCalories.round(),
          exerciseMinutes: metrics.exerciseMinutes.round(),
        );
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            logged.healthWritten
                ? 'Workout saved to Health · ${logged.durationMinutes} min'
                : 'Workout saved · ${logged.durationMinutes} min '
                    '(Health write may need permission)',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(logged);
    } catch (e) {
      if (!mounted) return;
      setState(() => _finishing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Bad state: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      final resumed = await workoutLogService.resumeSession();
      if (resumed != null && mounted) {
        setState(() {
          _session = resumed;
          _elapsed =
              Duration(seconds: _session.elapsedSecondsAt(DateTime.now()));
        });
      }
    }
  }

  Future<void> _endWorkoutDirect() async {
    if (_finishing || _pauseOpen) return;
    await HapticFeedback.mediumImpact();
    final updated = await workoutLogService.pauseSession();
    if (updated != null) _session = updated;
    setState(() {
      _elapsed = Duration(seconds: _session.elapsedSecondsAt(DateTime.now()));
    });
    await _finish();
  }

  @override
  Widget build(BuildContext context) {
    final color = accentForWorkout(_kind);
    final statusLabel = _session.isPaused ? 'Paused' : 'Workout in progress';
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  ),
                  const Spacer(),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      color: _session.isPaused ? _timerYellow : color,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        iconForWorkout(_kind),
                        color: color,
                        size: 56,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _session.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      statusLabel,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      _clock,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 56,
                        fontWeight: FontWeight.w300,
                        height: 1,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'ELAPSED',
                      style: TextStyle(
                        color: Color(0xFFAEAEB2),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          iconForWorkout(_kind),
                          color: color,
                          size: 20,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _clock,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _timerYellow,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      const SizedBox(width: 36),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _DrawerCircleButton(
                        icon: Icons.pause_rounded,
                        color: _timerYellow,
                        background: _timerYellow.withValues(alpha: 0.18),
                        size: 72,
                        iconSize: 36,
                        onTap: _finishing ? () {} : _openPauseSheet,
                      ),
                      const SizedBox(width: 28),
                      _DrawerCircleButton(
                        icon: Icons.stop_rounded,
                        color: _endRed,
                        background: _endRed.withValues(alpha: 0.16),
                        size: 72,
                        iconSize: 36,
                        onTap: _finishing ? () {} : _endWorkoutDirect,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 72,
                        child: Text(
                          'Pause',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(width: 28),
                      SizedBox(
                        width: 72,
                        child: Text(
                          'End',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerCircleButton extends StatelessWidget {
  const _DrawerCircleButton({
    required this.icon,
    required this.onTap,
    this.color = Colors.white70,
    this.background = const Color(0xFF2C2C2E),
    this.size = 52,
    this.iconSize = 22,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final Color background;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: color, size: iconSize),
        ),
      ),
    );
  }
}

enum _PauseAction { resume, end }

class _PauseSheet extends StatelessWidget {
  const _PauseSheet({
    required this.title,
    required this.kind,
    required this.clock,
  });

  final String title;
  final WorkoutActivityKind kind;
  final String clock;

  @override
  Widget build(BuildContext context) {
    final color = accentForWorkout(kind);
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(iconForWorkout(kind), color: color, size: 20),
                  ),
                  Expanded(
                    child: Text(
                      clock,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _timerYellow,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(width: 36),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(color: _muted, fontSize: 14),
              ),
              const SizedBox(height: 22),
              Material(
                color: _timerYellow.withValues(alpha: 0.2),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(context).pop(_PauseAction.resume),
                  child: const SizedBox(
                    width: 78,
                    height: 78,
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: _timerYellow,
                      size: 42,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Resume',
                style: TextStyle(
                  color: _timerYellow,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 28),
              _PauseActionButton(
                label: 'End Workout',
                icon: Icons.close_rounded,
                background: const Color(0xFF3A1214),
                foreground: _endRed,
                onTap: () => Navigator.of(context).pop(_PauseAction.end),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _PauseActionButton extends StatelessWidget {
  const _PauseActionButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: foreground, size: 22),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Proof sheet (unchanged behavior)
// ---------------------------------------------------------------------------

class _FinishChoice {
  const _FinishChoice({this.image, this.video, this.discarded = false});
  final File? image;
  final File? video;
  final bool discarded;
}

class _FinishWorkoutSheet extends StatefulWidget {
  const _FinishWorkoutSheet();

  @override
  State<_FinishWorkoutSheet> createState() => _FinishWorkoutSheetState();
}

class _FinishWorkoutSheetState extends State<_FinishWorkoutSheet> {
  File? _image;
  File? _video;
  final _picker = ImagePicker();

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 2000,
      imageQuality: 90,
    );
    if (picked == null) return;
    setState(() {
      _image = File(picked.path);
      _video = null;
    });
  }

  Future<void> _pickVideo(ImageSource source) async {
    final picked = await _picker.pickVideo(
      source: source,
      maxDuration: const Duration(seconds: 5),
    );
    if (picked == null) return;
    setState(() {
      _video = File(picked.path);
      _image = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasProof = _image != null || _video != null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Add proof',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Snap a 5-second video or photo so your group can see you put in the work. Finish time comes from the Got Motion timer.',
              style: TextStyle(color: settingsMuted, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 16),
            if (_image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _image!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            else if (_video != null)
              Container(
                height: 120,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A222D),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2A3544)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.videocam_rounded, color: _purple),
                    SizedBox(width: 8),
                    Text(
                      '5-second video ready',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              )
            else
              Container(
                height: 120,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A222D),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2A3544)),
                ),
                child: const Text(
                  'No proof yet',
                  style: TextStyle(color: settingsMuted),
                ),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickVideo(ImageSource.camera),
                    icon: const Icon(Icons.videocam_rounded),
                    label: const Text('Video'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF3A4B61)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickPhoto(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_rounded),
                    label: const Text('Photo'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF3A4B61)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _pickPhoto(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_rounded),
              label: const Text('Choose from library'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFF3A4B61)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                _FinishChoice(image: _image, video: _video),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                hasProof ? 'Save workout with proof' : 'Save without proof',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(
                const _FinishChoice(discarded: true),
              ),
              child: const Text(
                'Discard workout',
                style: TextStyle(color: Color(0xFFFF5A67)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
