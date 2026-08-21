import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/logged_workout.dart';
import 'avatar_image.dart';
import 'health_service.dart';
import 'selected_group_service.dart';

/// In-app Start / Finish workouts + optional proof photo/video.
class WorkoutLogService {
  WorkoutLogService._();
  static final WorkoutLogService instance = WorkoutLogService._();

  static const _activeKey = 'active_workout_session_v1';
  final _uuid = const Uuid();

  SupabaseClient get _db => Supabase.instance.client;

  Future<ActiveWorkoutSession?> getActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_activeKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return ActiveWorkoutSession.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      await prefs.remove(_activeKey);
      return null;
    }
  }

  Future<void> startSession(WorkoutActivityKind kind) async {
    final now = DateTime.now();
    final session = ActiveWorkoutSession(
      activityType: kind.storageKey,
      title: kind.label,
      startedAt: now,
      segmentStartedAt: now,
      accumulatedSeconds: 0,
      isPaused: false,
    );
    await _persistSession(session);
  }

  Future<void> clearActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeKey);
  }

  Future<void> _persistSession(ActiveWorkoutSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeKey, jsonEncode(session.toJson()));
  }

  Future<ActiveWorkoutSession?> pauseSession() async {
    final session = await getActiveSession();
    if (session == null || session.isPaused) return session;
    final now = DateTime.now();
    final updated = session.copyWith(
      accumulatedSeconds: session.elapsedSecondsAt(now),
      isPaused: true,
      clearSegmentStartedAt: true,
    );
    await _persistSession(updated);
    return updated;
  }

  Future<ActiveWorkoutSession?> resumeSession() async {
    final session = await getActiveSession();
    if (session == null || !session.isPaused) return session;
    final updated = session.copyWith(
      segmentStartedAt: DateTime.now(),
      isPaused: false,
    );
    await _persistSession(updated);
    return updated;
  }

  /// Finish timer → write Health → save row (+ optional proof) → notify group.
  Future<LoggedWorkout> finishSession({
    required ActiveWorkoutSession session,
    File? proofImage,
    File? proofVideo,
  }) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) throw StateError('Not signed in');

    final endedAt = DateTime.now();
    final durationSeconds = session.elapsedSecondsAt(endedAt);
    if (durationSeconds < 30) {
      throw StateError('Work out at least 30 seconds before finishing.');
    }

    final kind = WorkoutActivityKindX.fromStorage(session.activityType);
    final healthStart = endedAt.subtract(Duration(seconds: durationSeconds));
    final healthWritten = await HealthService.writeWorkout(
      activityType: kind.healthType,
      start: healthStart,
      end: endedAt,
      title: 'Got Motion · ${session.title}',
    );

    String? proofImageUrl;
    String? proofVideoUrl;
    if (proofVideo != null) {
      proofVideoUrl = await _uploadVideo(userId: userId, file: proofVideo);
    } else if (proofImage != null) {
      proofImageUrl = await _uploadImage(userId: userId, file: proofImage);
    }

    final groupId = selectedGroupService.selectedGroupId;
    final row = await _db
        .from('logged_workouts')
        .insert({
          'user_id': userId,
          'group_id': groupId,
          'activity_type': session.activityType,
          'title': session.title,
          'started_at': healthStart.toUtc().toIso8601String(),
          'ended_at': endedAt.toUtc().toIso8601String(),
          'duration_seconds': durationSeconds,
          'proof_image_url': proofImageUrl,
          'proof_video_url': proofVideoUrl,
          'health_written': healthWritten,
        })
        .select()
        .single();

    await clearActiveSession();
    final logged = LoggedWorkout.fromMap(row);
    // Fire-and-forget group notify (inbox + push).
    // ignore: unawaited_futures
    notifyGroupOfWorkout(logged.id);
    return logged;
  }

  Future<void> notifyGroupOfWorkout(String workoutId) async {
    try {
      await _db.functions.invoke(
        'notify-workout-logged',
        body: {'workout_id': workoutId},
      );
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[WorkoutLog] notify failed: $e');
      }
    }
  }

  Future<LoggedWorkout?> fetchById(String workoutId) async {
    try {
      final row = await _db
          .from('logged_workouts')
          .select(
            'id, user_id, group_id, activity_type, title, started_at, ended_at, '
            'duration_seconds, proof_image_url, proof_video_url, health_written',
          )
          .eq('id', workoutId)
          .maybeSingle();
      if (row == null) return null;
      final workout = LoggedWorkout.fromMap(Map<String, dynamic>.from(row));
      final profile = await _db
          .from('profiles')
          .select('display_name, full_name')
          .eq('id', workout.userId)
          .maybeSingle();
      if (profile == null) return workout;
      final d = (profile['display_name'] as String?)?.trim() ?? '';
      final f = (profile['full_name'] as String?)?.trim() ?? '';
      return LoggedWorkout(
        id: workout.id,
        userId: workout.userId,
        groupId: workout.groupId,
        activityType: workout.activityType,
        title: workout.title,
        startedAt: workout.startedAt,
        endedAt: workout.endedAt,
        durationSeconds: workout.durationSeconds,
        proofImageUrl: workout.proofImageUrl,
        proofVideoUrl: workout.proofVideoUrl,
        healthWritten: workout.healthWritten,
        displayName: d.isNotEmpty ? d : (f.isNotEmpty ? f : 'Member'),
      );
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[WorkoutLog] fetchById failed: $e');
      }
      return null;
    }
  }

  Future<String> _uploadImage({
    required String userId,
    required File file,
  }) async {
    final bytes = await AvatarImage.prepareProof(file);
    final path = '$userId/${_uuid.v4}${AvatarImage.extension}';
    await _db.storage.from('workout-proofs').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            upsert: false,
            contentType: AvatarImage.contentType,
          ),
        );
    final base = _db.storage.from('workout-proofs').getPublicUrl(path);
    return '$base?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<String> _uploadVideo({
    required String userId,
    required File file,
  }) async {
    final bytes = await file.readAsBytes();
    final lower = file.path.toLowerCase();
    final ext = lower.endsWith('.mov') ? '.mov' : '.mp4';
    final contentType =
        ext == '.mov' ? 'video/quicktime' : 'video/mp4';
    final path = '$userId/${_uuid.v4}$ext';
    await _db.storage.from('workout-proofs').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: false,
            contentType: contentType,
          ),
        );
    final base = _db.storage.from('workout-proofs').getPublicUrl(path);
    return '$base?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<List<LoggedWorkout>> recentForSelectedGroup({int limit = 12}) async {
    final groupId = selectedGroupService.selectedGroupId;
    if (groupId == null) return const [];
    try {
      final rows = await _db
          .from('logged_workouts')
          .select(
            'id, user_id, group_id, activity_type, title, started_at, ended_at, '
            'duration_seconds, proof_image_url, proof_video_url, health_written',
          )
          .eq('group_id', groupId)
          .order('started_at', ascending: false)
          .limit(limit);
      final list = (rows as List)
          .map((r) => LoggedWorkout.fromMap(Map<String, dynamic>.from(r as Map)))
          .toList();
      if (list.isEmpty) return list;

      final ids = list.map((w) => w.userId).toSet().toList();
      final profiles = await _db
          .from('profiles')
          .select('id, display_name, full_name')
          .inFilter('id', ids);
      final names = <String, String>{};
      for (final p in profiles as List) {
        final map = Map<String, dynamic>.from(p as Map);
        final id = map['id'] as String?;
        if (id == null) continue;
        final d = (map['display_name'] as String?)?.trim() ?? '';
        final f = (map['full_name'] as String?)?.trim() ?? '';
        names[id] = d.isNotEmpty ? d : (f.isNotEmpty ? f : 'Member');
      }
      return list
          .map(
            (w) => LoggedWorkout(
              id: w.id,
              userId: w.userId,
              groupId: w.groupId,
              activityType: w.activityType,
              title: w.title,
              startedAt: w.startedAt,
              endedAt: w.endedAt,
              durationSeconds: w.durationSeconds,
              proofImageUrl: w.proofImageUrl,
              proofVideoUrl: w.proofVideoUrl,
              healthWritten: w.healthWritten,
              displayName: names[w.userId],
            ),
          )
          .toList();
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[WorkoutLog] recentForSelectedGroup failed: $e');
      }
      return const [];
    }
  }
}

class ActiveWorkoutSession {
  const ActiveWorkoutSession({
    required this.activityType,
    required this.title,
    required this.startedAt,
    required this.accumulatedSeconds,
    required this.isPaused,
    this.segmentStartedAt,
  });

  final String activityType;
  final String title;
  final DateTime startedAt;
  /// Seconds completed before the current running segment.
  final int accumulatedSeconds;
  final bool isPaused;
  /// When the current run segment began; null while paused.
  final DateTime? segmentStartedAt;

  int elapsedSecondsAt(DateTime now) {
    var total = accumulatedSeconds;
    final segmentStart = segmentStartedAt;
    if (!isPaused && segmentStart != null) {
      total += now.difference(segmentStart).inSeconds;
    }
    return total < 0 ? 0 : total;
  }

  ActiveWorkoutSession copyWith({
    String? activityType,
    String? title,
    DateTime? startedAt,
    int? accumulatedSeconds,
    bool? isPaused,
    DateTime? segmentStartedAt,
    bool clearSegmentStartedAt = false,
  }) {
    return ActiveWorkoutSession(
      activityType: activityType ?? this.activityType,
      title: title ?? this.title,
      startedAt: startedAt ?? this.startedAt,
      accumulatedSeconds: accumulatedSeconds ?? this.accumulatedSeconds,
      isPaused: isPaused ?? this.isPaused,
      segmentStartedAt: clearSegmentStartedAt
          ? null
          : (segmentStartedAt ?? this.segmentStartedAt),
    );
  }

  Map<String, dynamic> toJson() => {
        'activityType': activityType,
        'title': title,
        'startedAt': startedAt.toIso8601String(),
        'accumulatedSeconds': accumulatedSeconds,
        'isPaused': isPaused,
        'segmentStartedAt': segmentStartedAt?.toIso8601String(),
      };

  static ActiveWorkoutSession fromJson(Map<String, dynamic> json) {
    final startedAt = DateTime.parse(json['startedAt'] as String);
    final segmentRaw = json['segmentStartedAt'] as String?;
    final hasPauseFields = json.containsKey('accumulatedSeconds');
    if (!hasPauseFields) {
      // Legacy sessions: treat as running since startedAt.
      return ActiveWorkoutSession(
        activityType: json['activityType'] as String? ?? 'other',
        title: json['title'] as String? ?? 'Workout',
        startedAt: startedAt,
        accumulatedSeconds: 0,
        isPaused: false,
        segmentStartedAt: startedAt,
      );
    }
    return ActiveWorkoutSession(
      activityType: json['activityType'] as String? ?? 'other',
      title: json['title'] as String? ?? 'Workout',
      startedAt: startedAt,
      accumulatedSeconds: (json['accumulatedSeconds'] as num?)?.toInt() ?? 0,
      isPaused: json['isPaused'] as bool? ?? false,
      segmentStartedAt:
          segmentRaw == null ? null : DateTime.tryParse(segmentRaw),
    );
  }
}

final workoutLogService = WorkoutLogService.instance;
