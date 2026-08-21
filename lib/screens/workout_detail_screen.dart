import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../models/logged_workout.dart';
import '../services/workout_log_service.dart';
import '../widgets/settings_ui.dart';

Future<void> openWorkoutDetail(
  BuildContext context, {
  String? workoutId,
  LoggedWorkout? workout,
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => WorkoutDetailScreen(
        workoutId: workoutId,
        initial: workout,
      ),
    ),
  );
}

class WorkoutDetailScreen extends StatefulWidget {
  const WorkoutDetailScreen({
    super.key,
    this.workoutId,
    this.initial,
  });

  final String? workoutId;
  final LoggedWorkout? initial;

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  LoggedWorkout? _workout;
  bool _loading = true;
  VideoPlayerController? _video;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final initial = widget.initial;
    if (initial != null) {
      setState(() {
        _workout = initial;
        _loading = false;
      });
      await _setupVideo(initial);
      return;
    }
    final id = widget.workoutId;
    if (id == null) {
      setState(() {
        _loading = false;
        _error = 'Workout not found';
      });
      return;
    }
    final loaded = await workoutLogService.fetchById(id);
    if (!mounted) return;
    if (loaded == null) {
      setState(() {
        _loading = false;
        _error = 'Workout not found';
      });
      return;
    }
    setState(() {
      _workout = loaded;
      _loading = false;
    });
    await _setupVideo(loaded);
  }

  Future<void> _setupVideo(LoggedWorkout workout) async {
    final url = workout.proofVideoUrl;
    if (url == null || url.isEmpty) return;
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await controller.initialize();
      await controller.setLooping(true);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _video = controller);
      await controller.play();
    } catch (_) {
      await controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final workout = _workout;
    return Scaffold(
      backgroundColor: settingsBackground,
      appBar: AppBar(
        backgroundColor: settingsBackground,
        foregroundColor: Colors.white,
        title: const Text('Workout'),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: settingsAccent))
          : _error != null
          ? Center(
              child: Text(_error!, style: const TextStyle(color: settingsMuted)),
            )
          : workout == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Text(
                  workout.displayName ?? 'Member',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${workout.title} · ${workout.durationMinutes} min',
                  style: const TextStyle(
                    color: Color(0xFF9A73FF),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Finished ${DateFormat.jm().format(workout.endedAt.toLocal())}'
                  ' · ${DateFormat.MMMd().format(workout.endedAt.toLocal())}',
                  style: const TextStyle(color: settingsMuted, fontSize: 14),
                ),
                const SizedBox(height: 18),
                if (workout.proofVideoUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AspectRatio(
                      aspectRatio: _video?.value.aspectRatio ?? 9 / 16,
                      child: _video == null
                          ? const ColoredBox(
                              color: Color(0xFF1A222D),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF9A73FF),
                                ),
                              ),
                            )
                          : Stack(
                              alignment: Alignment.center,
                              children: [
                                VideoPlayer(_video!),
                                Positioned(
                                  bottom: 12,
                                  right: 12,
                                  child: IconButton.filled(
                                    onPressed: () {
                                      setState(() {
                                        if (_video!.value.isPlaying) {
                                          _video!.pause();
                                        } else {
                                          _video!.play();
                                        }
                                      });
                                    },
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.black54,
                                    ),
                                    icon: Icon(
                                      _video!.value.isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ] else if (workout.proofImageUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      workout.proofImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox(
                        height: 220,
                        child: ColoredBox(
                          color: Color(0xFF1A222D),
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: settingsMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    height: 160,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A222D),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'No proof media attached',
                      style: TextStyle(color: settingsMuted),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  workout.healthWritten
                      ? 'Saved to Apple Health / Health Connect so exercise minutes count.'
                      : 'Saved in Got Motion. Health write may need permission on next workout.',
                  style: const TextStyle(
                    color: settingsMuted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
    );
  }
}
