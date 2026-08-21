import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

/// Activity choices users can start from Got Motion.
enum WorkoutActivityKind {
  cycling,
  running,
  walking,
  strength,
  hiit,
  other,
}

extension WorkoutActivityKindX on WorkoutActivityKind {
  String get storageKey => name;

  String get label {
    switch (this) {
      case WorkoutActivityKind.cycling:
        return 'Cycling';
      case WorkoutActivityKind.running:
        return 'Running';
      case WorkoutActivityKind.walking:
        return 'Walking';
      case WorkoutActivityKind.strength:
        return 'Strength';
      case WorkoutActivityKind.hiit:
        return 'HIIT';
      case WorkoutActivityKind.other:
        return 'Other';
    }
  }

  String get subtitle {
    switch (this) {
      case WorkoutActivityKind.cycling:
        return 'Bike, spin, outdoor ride';
      case WorkoutActivityKind.running:
        return 'Run or jog';
      case WorkoutActivityKind.walking:
        return 'Brisk walk';
      case WorkoutActivityKind.strength:
        return 'Weights, bodyweight, gym';
      case WorkoutActivityKind.hiit:
        return 'Intervals, circuits';
      case WorkoutActivityKind.other:
        return 'Anything else';
    }
  }

  /// HealthKit / Health Connect activity type (platform-safe).
  HealthWorkoutActivityType get healthType {
    final android = defaultTargetPlatform == TargetPlatform.android;
    switch (this) {
      case WorkoutActivityKind.cycling:
        return HealthWorkoutActivityType.BIKING;
      case WorkoutActivityKind.running:
        return HealthWorkoutActivityType.RUNNING;
      case WorkoutActivityKind.walking:
        return HealthWorkoutActivityType.WALKING;
      case WorkoutActivityKind.strength:
        return android
            ? HealthWorkoutActivityType.STRENGTH_TRAINING
            : HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING;
      case WorkoutActivityKind.hiit:
        return HealthWorkoutActivityType.HIGH_INTENSITY_INTERVAL_TRAINING;
      case WorkoutActivityKind.other:
        return HealthWorkoutActivityType.OTHER;
    }
  }

  static WorkoutActivityKind fromStorage(String? raw) {
    return WorkoutActivityKind.values.firstWhere(
      (k) => k.name == raw,
      orElse: () => WorkoutActivityKind.other,
    );
  }
}

class LoggedWorkout {
  const LoggedWorkout({
    required this.id,
    required this.userId,
    this.groupId,
    required this.activityType,
    required this.title,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    this.proofImageUrl,
    this.proofVideoUrl,
    required this.healthWritten,
    this.displayName,
  });

  final String id;
  final String userId;
  final String? groupId;
  final String activityType;
  final String title;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSeconds;
  final String? proofImageUrl;
  final String? proofVideoUrl;
  final bool healthWritten;
  final String? displayName;

  int get durationMinutes => (durationSeconds / 60).round();

  bool get hasProof =>
      (proofImageUrl != null && proofImageUrl!.isNotEmpty) ||
      (proofVideoUrl != null && proofVideoUrl!.isNotEmpty);

  static LoggedWorkout fromMap(Map<String, dynamic> row) {
    return LoggedWorkout(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      groupId: row['group_id'] as String?,
      activityType: row['activity_type'] as String? ?? 'other',
      title: row['title'] as String? ?? 'Workout',
      startedAt: DateTime.parse(row['started_at'].toString()),
      endedAt: DateTime.parse(row['ended_at'].toString()),
      durationSeconds: (row['duration_seconds'] as num).round(),
      proofImageUrl: row['proof_image_url'] as String?,
      proofVideoUrl: row['proof_video_url'] as String?,
      healthWritten: row['health_written'] as bool? ?? false,
      displayName: row['display_name'] as String? ??
          row['profiles']?['display_name'] as String? ??
          row['profiles']?['full_name'] as String?,
    );
  }
}
