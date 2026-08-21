import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/logged_workout.dart';
import '../services/daily_steps_service.dart';
import '../services/health_service.dart';
import '../services/workout_log_service.dart';
import '../widgets/settings_ui.dart';

Future<void> showStartWorkoutSheet(BuildContext context) async {
  final active = await workoutLogService.getActiveSession();
  if (!context.mounted) return;
  if (active != null) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ActiveWorkoutScreen(session: active),
      ),
    );
    return;
  }

  final kind = await showModalBottomSheet<WorkoutActivityKind>(
    context: context,
    backgroundColor: settingsSurface,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Start a workout',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Timer runs in Got Motion and saves to Apple Health / Health Connect when you finish. Add a proof photo so your group can see you put in the work.',
              style: TextStyle(color: settingsMuted, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 16),
            for (final kind in WorkoutActivityKind.values) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF9A73FF).withValues(alpha: 0.18),
                  child: Icon(
                    _iconFor(kind),
                    color: const Color(0xFF9A73FF),
                    size: 22,
                  ),
                ),
                title: Text(
                  kind.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  kind.subtitle,
                  style: const TextStyle(color: settingsMuted, fontSize: 13),
                ),
                onTap: () => Navigator.of(sheetContext).pop(kind),
              ),
            ],
          ],
        ),
      ),
    ),
  );
  if (kind == null || !context.mounted) return;
  await workoutLogService.startSession(kind);
  final session = await workoutLogService.getActiveSession();
  if (session == null || !context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ActiveWorkoutScreen(session: session),
    ),
  );
}

IconData _iconFor(WorkoutActivityKind kind) {
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

class ActiveWorkoutScreen extends StatefulWidget {
  const ActiveWorkoutScreen({super.key, required this.session});

  final ActiveWorkoutSession session;

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  static const _bg = Color(0xFF07090D);
  static const _accent = Color(0xFF9A73FF);

  Timer? _tick;
  Duration _elapsed = Duration.zero;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _elapsed = DateTime.now().difference(widget.session.startedAt);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed = DateTime.now().difference(widget.session.startedAt);
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

  Future<void> _finish() async {
    if (_finishing) return;
    final proof = await showModalBottomSheet<_FinishChoice>(
      context: context,
      backgroundColor: settingsSurface,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => const _FinishWorkoutSheet(),
    );
    if (proof == null || !mounted) return;
    if (proof.discarded) {
      await workoutLogService.clearActiveSession();
      if (mounted) Navigator.of(context).pop();
      return;
    }

    setState(() => _finishing = true);
    try {
      final logged = await workoutLogService.finishSession(
        session: widget.session,
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: Colors.white,
        title: Text(widget.session.title),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Workout in progress',
                style: TextStyle(color: settingsMuted, fontSize: 14),
              ),
              const Spacer(),
              Text(
                _clock,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 64,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.session.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _accent,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              const Text(
                'When you’re done, finish and add a short proof video or photo so your group knows it was real.',
                textAlign: TextAlign.center,
                style: TextStyle(color: settingsMuted, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _finishing ? null : _finish,
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _finishing ? 'Saving…' : 'Finish workout',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
              'Like posting in the group chat — snap a 5-second video on the bike or a photo. Your finish time comes from the Got Motion timer, and your group gets notified.',
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
                    Icon(Icons.videocam_rounded, color: Color(0xFF9A73FF)),
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
                backgroundColor: const Color(0xFF9A73FF),
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
