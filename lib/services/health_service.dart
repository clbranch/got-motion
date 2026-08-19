import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';

import '../models/today_metrics.dart';
import '../models/user_step_data.dart';

class HealthService {
  HealthService._();

  static final Health _health = Health();
  static const _systemChannel = MethodChannel(
    'com.brogrammers.gotmotionapp/system',
  );

  static const List<HealthDataType> _dashboardTypes = [
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.EXERCISE_TIME,
    HealthDataType.WORKOUT,
    HealthDataType.APPLE_STAND_HOUR,
  ];

  static bool _configured = false;

  static DateTime _startOfLocalDay() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime _startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime _endOfDay(DateTime date) {
    final start = _startOfDay(date);
    final tomorrow = start.add(const Duration(days: 1));
    final now = DateTime.now();
    return tomorrow.isAfter(now) ? now : tomorrow;
  }

  static Future<bool> _ensureConfiguredAndAuthorized() async {
    try {
      if (!_configured) {
        await _health.configure();
        _configured = true;
      }
      return await _health.requestAuthorization(_dashboardTypes);
    } catch (_) {
      return false;
    }
  }

  static final Map<String, ({Map<String, dynamic> data, DateTime at})>
  _nativeCache = {};

  static Future<Map<String, dynamic>?> _nativeMetrics(
    DateTime start,
    DateTime end,
  ) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return null;
    if (!end.isAfter(start)) return null;
    final key = '${start.millisecondsSinceEpoch}-${end.millisecondsSinceEpoch}';
    final cached = _nativeCache[key];
    if (cached != null && DateTime.now().difference(cached.at).inSeconds < 20) {
      return cached.data;
    }
    try {
      final raw = await _systemChannel
          .invokeMethod<dynamic>('getHealthMetrics', {
            'startMs': start.millisecondsSinceEpoch,
            'endMs': end.millisecondsSinceEpoch,
          });
      if (raw is Map) {
        final data = Map<String, dynamic>.from(raw);
        _nativeCache[key] = (data: data, at: DateTime.now());
        return data;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static TodayMetrics _metricsFromNative(Map<String, dynamic> raw) {
    return TodayMetrics(
      steps: (raw['steps'] as num?)?.round() ?? 0,
      distanceMiles: (raw['miles'] as num?)?.toDouble() ?? 0,
      activeEnergyCalories: (raw['calories'] as num?)?.toDouble() ?? 0,
      exerciseMinutes: (raw['exerciseMinutes'] as num?)?.toDouble() ?? 0,
    );
  }

  static double? _standFromNative(Map<String, dynamic> raw) {
    final value = raw['standHours'];
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static Future<List<HealthDataPoint>> _read(
    List<HealthDataType> types,
    DateTime start,
    DateTime end,
  ) async {
    if (!end.isAfter(start)) return const [];
    final points = await _health.getHealthDataFromTypes(
      types: types,
      startTime: start,
      endTime: end,
    );
    return _health.removeDuplicates(points);
  }

  static double _numericValue(HealthDataPoint point) {
    final raw = point.value;
    if (raw is NumericHealthValue) return raw.numericValue.toDouble();
    return double.tryParse(raw.toString()) ?? 0;
  }

  static double _toMeters(HealthDataPoint point) {
    final value = _numericValue(point);
    final unit = point.unit;
    if (unit == HealthDataUnit.MILE) return value * 1609.344;
    final unitStr = unit.toString().toLowerCase();
    if (unitStr.contains('mile')) return value * 1609.344;
    if (unitStr.contains('kilometer')) return value * 1000;
    return value;
  }

  static String _sourceBucket(HealthDataPoint point) {
    final blob =
        '${point.sourceName} ${point.sourceId} ${point.deviceModel ?? ''}'
            .toLowerCase();
    if (blob.contains('watch')) return 'watch';
    if (blob.contains('iphone') || blob.contains('phone')) return 'phone';
    return 'other';
  }

  /// Watch-only when Watch recorded today; otherwise iPhone. Never add both.
  static List<HealthDataPoint> _activeSourcePoints(
    List<HealthDataPoint> points,
  ) {
    final watch = points.where((p) => _sourceBucket(p) == 'watch').toList();
    if (watch.isNotEmpty) return watch;
    final phone = points.where((p) => _sourceBucket(p) == 'phone').toList();
    if (phone.isNotEmpty) return phone;
    return points;
  }

  static List<HealthDataPoint> _otherSourcePoints(
    List<HealthDataPoint> points,
  ) {
    return points.where((p) => _sourceBucket(p) == 'other').toList();
  }

  static double _workoutMinutes(HealthDataPoint point) {
    final seconds = point.dateTo.difference(point.dateFrom).inSeconds;
    return seconds > 0 ? seconds / 60.0 : 0;
  }

  static double _workoutKilocalories(HealthDataPoint point) {
    final raw = point.value;
    if (raw is WorkoutHealthValue) {
      return (raw.totalEnergyBurned ?? 0).toDouble();
    }
    return 0;
  }

  static double _sumBestNamedSource(
    List<HealthDataPoint> points,
    double Function(HealthDataPoint) valueOf,
  ) {
    final totals = <String, double>{};
    for (final point in points) {
      totals[point.sourceName] =
          (totals[point.sourceName] ?? 0) + valueOf(point);
    }
    var best = 0.0;
    for (final value in totals.values) {
      if (value > best) best = value;
    }
    return best;
  }

  /// Apple Stand Hour is a category: 0 = stood, 1 = idle. Count unique local hours stood.
  static double _uniqueStoodHours(
    List<HealthDataPoint> points,
    DateTime start,
    DateTime end,
  ) {
    final hours = <int>{};
    for (final point in points) {
      if (_numericValue(point) != 0) continue;
      var from = point.dateFrom;
      if (from.isBefore(start)) from = start;
      if (!from.isBefore(end)) continue;
      hours.add(
        from.year * 1000000 + from.month * 10000 + from.day * 100 + from.hour,
      );
    }
    return hours.length.toDouble();
  }

  static Future<TodayMetrics> _fallbackMetrics(
    DateTime startOfDay,
    DateTime endOfDay,
  ) async {
    final points = await _read(
      const [
        HealthDataType.STEPS,
        HealthDataType.DISTANCE_WALKING_RUNNING,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.EXERCISE_TIME,
        HealthDataType.WORKOUT,
      ],
      startOfDay,
      endOfDay,
    );
    final active = _activeSourcePoints(points);
    final other = _otherSourcePoints(points);
    final steps = _sumBestNamedSource(
      active.where((p) => p.type == HealthDataType.STEPS).toList(),
      _numericValue,
    );
    final meters = _sumBestNamedSource(
      active
          .where((p) => p.type == HealthDataType.DISTANCE_WALKING_RUNNING)
          .toList(),
      _toMeters,
    );
    final appleCalories = _sumBestNamedSource(
      active
          .where((p) => p.type == HealthDataType.ACTIVE_ENERGY_BURNED)
          .toList(),
      _numericValue,
    );
    final otherCalories = other
        .where((p) => p.type == HealthDataType.ACTIVE_ENERGY_BURNED)
        .fold<double>(0, (sum, point) => sum + _numericValue(point));
    final workoutCalories = other
        .where((p) => p.type == HealthDataType.WORKOUT)
        .fold<double>(0, (sum, point) => sum + _workoutKilocalories(point));
    final appleMinutes = _sumBestNamedSource(
      active.where((p) => p.type == HealthDataType.EXERCISE_TIME).toList(),
      _numericValue,
    );
    final workoutMinutes = other
        .where((p) => p.type == HealthDataType.WORKOUT)
        .fold<double>(0, (sum, point) => sum + _workoutMinutes(point));
    return TodayMetrics(
      steps: steps.round(),
      distanceMiles: meters / 1609.344,
      activeEnergyCalories:
          appleCalories + (otherCalories > workoutCalories ? otherCalories : workoutCalories),
      exerciseMinutes: appleMinutes + workoutMinutes,
    );
  }

  static Future<UserStepData> requestAndFetchSteps() async {
    try {
      final granted = await _ensureConfiguredAndAuthorized();
      if (!granted) return UserStepData.zero;

      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final byDay = await getWeekStepsByDay();
      final todayIndex = now.weekday - 1;
      final nativeMonth = await _nativeMetrics(startOfMonth, now);
      final monthSteps = nativeMonth != null
          ? (nativeMonth['steps'] as num?)?.round() ?? 0
          : (await _fallbackMetrics(startOfMonth, now)).steps;

      return UserStepData(
        todaySteps: todayIndex >= 0 && todayIndex < byDay.length
            ? byDay[todayIndex]
            : (await getMetricsForDay(now)).steps,
        weekSteps: byDay.fold<int>(0, (sum, value) => sum + value),
        monthSteps: monthSteps,
      );
    } catch (_) {
      return UserStepData.zero;
    }
  }

  static Future<int> getTodaySteps() async {
    final metrics = await getTodayMetrics();
    return metrics.steps;
  }

  static Future<double> getTodayDistanceMiles() async {
    final metrics = await getTodayMetrics();
    return metrics.distanceMiles;
  }

  static Future<double> getTodayActiveEnergyCalories() async {
    final metrics = await getTodayMetrics();
    return metrics.activeEnergyCalories;
  }

  static Future<double> getTodayExerciseMinutes() async {
    final metrics = await getTodayMetrics();
    return metrics.exerciseMinutes;
  }

  static Future<TodayMetrics> getTodayMetrics() async {
    return getMetricsForDay(DateTime.now());
  }

  static Future<TodayMetrics> getMetricsForDay(DateTime date) async {
    try {
      if (!await _ensureConfiguredAndAuthorized()) return TodayMetrics.zero;

      final startOfDay = _startOfDay(date);
      final endOfDay = _endOfDay(date);
      if (!endOfDay.isAfter(startOfDay)) return TodayMetrics.zero;

      final native = await _nativeMetrics(startOfDay, endOfDay);
      final metrics = native != null
          ? _metricsFromNative(native)
          : await _fallbackMetrics(startOfDay, endOfDay);

      if (kDebugMode) {
        debugPrint(
          '[Health] ${startOfDay.toIso8601String().split('T').first} '
          'source=${native?['source'] ?? 'fallback'} '
          'steps=${metrics.steps} miles=${metrics.distanceMiles.toStringAsFixed(2)} '
          'cal=${metrics.activeEnergyCalories.round()} '
          'min=${metrics.exerciseMinutes.round()}',
        );
      }
      return metrics;
    } catch (_) {
      return TodayMetrics.zero;
    }
  }

  static DateTime startOfWeek([DateTime? date]) {
    final start = _startOfDay(date ?? DateTime.now());
    return start.subtract(Duration(days: start.weekday - 1));
  }

  static DateTime startOfMonth([DateTime? date]) {
    final value = date ?? DateTime.now();
    return DateTime(value.year, value.month, 1);
  }

  static Future<TodayMetrics> getMetricsInRange(
    DateTime start,
    DateTime end,
  ) async {
    final days = await getDailyMetrics(start, end);
    return days.fold<TodayMetrics>(
      TodayMetrics.zero,
      (sum, day) => sum + day.metrics,
    );
  }

  static Future<List<({DateTime date, TodayMetrics metrics})>> getDailyMetrics(
    DateTime start,
    DateTime end,
  ) async {
    final days = <DateTime>[];
    var cursor = _startOfDay(start);
    final last = _startOfDay(end);
    final today = _startOfLocalDay();
    while (!cursor.isAfter(last) && !cursor.isAfter(today)) {
      days.add(cursor);
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }
    if (days.isEmpty) return const [];

    final out = <({DateTime date, TodayMetrics metrics})>[];
    const batchSize = 4;
    for (var i = 0; i < days.length; i += batchSize) {
      final chunk = days.sublist(
        i,
        i + batchSize > days.length ? days.length : i + batchSize,
      );
      final metrics = await Future.wait(chunk.map(getMetricsForDay));
      for (var n = 0; n < chunk.length; n++) {
        out.add((date: chunk[n], metrics: metrics[n]));
      }
    }
    return out;
  }

  static Future<int> getWeekStepsTotal() async {
    final days = await getWeekStepsByDay();
    return days.fold<int>(0, (sum, value) => sum + value);
  }

  /// Returns step counts for the current week, one per day [Mon..Sun]. Today may be partial.
  static Future<List<int>> getWeekStepsByDay() async {
    try {
      if (!await _ensureConfiguredAndAuthorized()) {
        return List.filled(7, 0);
      }
      final now = DateTime.now();
      final startOfDay = _startOfLocalDay();
      final startOfWeek = startOfDay.subtract(Duration(days: now.weekday - 1));
      final out = <int>[];
      for (var d = 0; d < 7; d++) {
        final dayStart = startOfWeek.add(Duration(days: d));
        final dayEnd = d == now.weekday - 1
            ? now
            : dayStart.add(const Duration(days: 1));
        if (!dayEnd.isAfter(dayStart)) {
          out.add(0);
          continue;
        }
        final native = await _nativeMetrics(dayStart, dayEnd);
        if (native != null) {
          out.add((native['steps'] as num?)?.round() ?? 0);
        } else {
          final points = await _read(
            const [HealthDataType.STEPS],
            dayStart,
            dayEnd,
          );
          out.add(
            _sumBestNamedSource(
              _activeSourcePoints(points),
              _numericValue,
            ).round(),
          );
        }
      }
      return out;
    } catch (_) {
      return List.filled(7, 0);
    }
  }

  static Future<double?> getTodayStandHours() async {
    return getStandHoursForDay(DateTime.now());
  }

  static Future<double?> getStandHoursForDay(DateTime date) async {
    try {
      if (!await _ensureConfiguredAndAuthorized()) return null;
      final startOfDay = _startOfDay(date);
      final endOfDay = _endOfDay(date);
      if (!endOfDay.isAfter(startOfDay)) return null;
      final native = await _nativeMetrics(startOfDay, endOfDay);
      if (native != null) return _standFromNative(native);

      final points = await _read(
        const [HealthDataType.APPLE_STAND_HOUR],
        startOfDay,
        endOfDay,
      );
      if (points.isEmpty) return null;
      return _uniqueStoodHours(points, startOfDay, endOfDay);
    } catch (_) {
      return null;
    }
  }
}
