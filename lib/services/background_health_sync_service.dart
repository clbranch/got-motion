import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'daily_steps_service.dart';
import 'health_service.dart';
import 'sync_activity_service.dart';

/// Listens for native HealthKit background updates and upserts today's
/// totals to Supabase so leaderboards stay fresh while the app is idle.
class BackgroundHealthSyncService {
  BackgroundHealthSyncService._();
  static final BackgroundHealthSyncService instance =
      BackgroundHealthSyncService._();

  static const _channel = MethodChannel(
    'com.brogrammers.gotmotionapp/system',
  );

  bool _listening = false;
  bool _syncing = false;
  DateTime? _lastAttemptAt;

  Future<void> start() async {
    if (_listening) return;
    _listening = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onHealthDataChanged') {
        unawaited(syncToday(reason: 'background'));
      }
    });

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await _channel.invokeMethod<void>('startHealthBackgroundDelivery');
      } catch (e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('[BackgroundHealth] start failed: $e');
        }
      }
    }

    // Catch updates that arrived before Flutter was ready.
    unawaited(syncToday(reason: 'startup'));
  }

  Future<void> syncToday({String reason = 'manual'}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    if (_syncing) return;
    if (_lastAttemptAt != null &&
        now.difference(_lastAttemptAt!) < const Duration(seconds: 45)) {
      return;
    }
    _syncing = true;
    _lastAttemptAt = now;

    try {
      final today = await HealthService.getTodayMetrics().timeout(
        const Duration(seconds: 12),
        onTimeout: () => throw TimeoutException('Health read'),
      );
      await DailyStepsService().upsertDailySteps(
        userId: user.id,
        date: DateTime.now(),
        steps: today.steps,
        miles: today.distanceMiles,
        activeCalories: today.activeEnergyCalories.round(),
        exerciseMinutes: today.exerciseMinutes.round(),
      );
      await syncActivityService.markHealthSynced();
      if (kDebugMode) {
        // ignore: avoid_print
        print(
          '[BackgroundHealth] synced ($reason) steps=${today.steps}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[BackgroundHealth] sync failed ($reason): $e');
      }
    } finally {
      _syncing = false;
    }
  }
}

final backgroundHealthSyncService = BackgroundHealthSyncService.instance;
