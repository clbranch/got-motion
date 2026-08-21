import 'package:flutter/material.dart';

import '../models/logged_workout.dart';
import '../screens/active_workout_screen.dart';
import '../screens/workout_detail_screen.dart';

/// Entry point for phone-only / no-Watch workout logging — not a Home primary CTA.
class WorkoutLogEntryCard extends StatelessWidget {
  const WorkoutLogEntryCard({
    super.key,
    required this.active,
    required this.onTap,
  });

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF14101F),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF9A73FF).withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF9A73FF).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  active ? Icons.timer_rounded : Icons.fitness_center_rounded,
                  color: const Color(0xFF9A73FF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      active ? 'Workout in progress' : 'Log a workout',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      active
                          ? 'Tap to return to your timer'
                          : 'Optional — for iPhone without an Apple Watch. Watch users don’t need this.',
                      style: const TextStyle(
                        color: Color(0xFF9BA5B7),
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF9A73FF),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thin home banner only while a session is already running.
class ActiveWorkoutHomeBanner extends StatelessWidget {
  const ActiveWorkoutHomeBanner({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A1528),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              const Icon(
                Icons.timer_rounded,
                color: Color(0xFF9A73FF),
                size: 20,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Workout in progress — tap to return',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF9A73FF),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RecentGroupWorkoutsStrip extends StatelessWidget {
  const RecentGroupWorkoutsStrip({super.key, required this.workouts});

  final List<LoggedWorkout> workouts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Group workouts',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: workouts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final w = workouts[index];
              return InkWell(
                onTap: () => openWorkoutDetail(context, workout: w),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 148,
                  decoration: BoxDecoration(
                    color: const Color(0xFF11151B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF242A35)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (w.proofImageUrl != null)
                              Image.network(
                                w.proofImageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const ColoredBox(
                                  color: Color(0xFF1A222D),
                                  child: Icon(
                                    Icons.fitness_center_rounded,
                                    color: Color(0xFF9A73FF),
                                  ),
                                ),
                              )
                            else
                              const ColoredBox(
                                color: Color(0xFF1A222D),
                                child: Icon(
                                  Icons.fitness_center_rounded,
                                  color: Color(0xFF9A73FF),
                                ),
                              ),
                            if (w.proofVideoUrl != null)
                              const Align(
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.play_circle_fill_rounded,
                                  color: Colors.white,
                                  size: 36,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              w.displayName ?? 'Member',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${w.title} · ${w.durationMinutes} min',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF9BA5B7),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

Future<void> openWorkoutLogFlow(BuildContext context) async {
  await showStartWorkoutSheet(context);
}
