import 'package:health/health.dart';

import '../models/today_metrics.dart';
import '../models/user_step_data.dart';

class HealthService {
  HealthService._();

  static final Health _health = Health();

  static const List<HealthDataType> _dashboardTypes = [
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.EXERCISE_TIME,
  ];

  static bool _configured = false;

  static DateTime _startOfLocalDay() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
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

  static Future<UserStepData> requestAndFetchSteps() async {
    try {
      final granted = await _ensureConfiguredAndAuthorized();
      if (!granted) return UserStepData.zero;

      final now = DateTime.now();
      final startOfDay = _startOfLocalDay();
      final startOfWeek = startOfDay.subtract(Duration(days: now.weekday - 1));
      final startOfMonth = DateTime(now.year, now.month, 1);

      final todaySteps = await _health.getTotalStepsInInterval(startOfDay, now) ?? 0;
      final weekSteps = await _health.getTotalStepsInInterval(startOfWeek, now) ?? 0;
      final monthSteps = await _health.getTotalStepsInInterval(startOfMonth, now) ?? 0;

      return UserStepData(
        todaySteps: todaySteps,
        weekSteps: weekSteps,
        monthSteps: monthSteps,
      );
    } catch (_) {
      return UserStepData.zero;
    }
  }

  static Future<int> getTodaySteps() async {
    try {
      if (!await _ensureConfiguredAndAuthorized()) return 0;
      final now = DateTime.now();
      final startOfDay = _startOfLocalDay();
      return await _health.getTotalStepsInInterval(startOfDay, now) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<double> getTodayDistanceMiles() async {
    try {
      if (!await _ensureConfiguredAndAuthorized()) return 0;

      final now = DateTime.now();
      final startOfDay = _startOfLocalDay();

      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.DISTANCE_WALKING_RUNNING],
        startTime: startOfDay,
        endTime: now,
      );

      final cleaned = _health.removeDuplicates(data);

      // Group by sourceName and sum meters per source (avoid double-counting Watch + iPhone).
      final metersPerSource = <String, double>{};
      for (final p in cleaned) {
        final value = p.value is NumericHealthValue
            ? (p.value as NumericHealthValue).numericValue.toDouble()
            : double.tryParse(p.value.toString()) ?? 0.0;

        final unit = p.unit;
        double sampleMeters;
        if (unit == HealthDataUnit.METER) {
          sampleMeters = value;
        } else if (unit == HealthDataUnit.MILE) {
          sampleMeters = value * 1609.344;
        } else {
          final unitStr = unit.toString().toLowerCase();
          if (unitStr.contains('meter') || unitStr == 'm') {
            sampleMeters = value;
          } else if (unitStr.contains('kilometer') || unitStr == 'km') {
            sampleMeters = value * 1000;
          } else if (unitStr.contains('mile') || unitStr == 'mi') {
            sampleMeters = value * 1609.344;
          } else {
            sampleMeters = value;
          }
        }

        final source = p.sourceName;
        metersPerSource[source] = (metersPerSource[source] ?? 0) + sampleMeters;
      }

      // Pick the single source with the highest total meters (matches Health merged/preferred).
      String? chosenSource;
      double chosenMeters = 0;
      for (final e in metersPerSource.entries) {
        if (e.value > chosenMeters) {
          chosenMeters = e.value;
          chosenSource = e.key;
        }
      }

      // Debug: meters per source
      // ignore: avoid_print
      for (final e in metersPerSource.entries) {
        print('[getTodayDistanceMiles] meters per source: ${e.key}: ${e.value} m');
      }
      // Debug: chosen source and miles
      // ignore: avoid_print
      print('[getTodayDistanceMiles] chosen source: $chosenSource');
      // ignore: avoid_print
      final chosenMiles = chosenMeters / 1609.344;
      print('[getTodayDistanceMiles] chosen source miles: $chosenMiles');

      return chosenMiles;
    } catch (_) {
      return 0;
    }
  }

  static Future<double> getTodayActiveEnergyCalories() async {
    try {
      if (!await _ensureConfiguredAndAuthorized()) return 0;

      final now = DateTime.now();
      final startOfDay = _startOfLocalDay();

      final points = await _health.getHealthDataFromTypes(
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
        startTime: startOfDay,
        endTime: now,
      );

      double cal = 0;
      for (final p in points) {
        final raw = p.value;
        if (raw is NumericHealthValue) {
          cal += raw.numericValue.toDouble();
        } else {
          final parsed = double.tryParse(raw.toString());
          if (parsed != null) cal += parsed;
        }
      }
      return cal;
    } catch (_) {
      return 0;
    }
  }

  static Future<double> getTodayExerciseMinutes() async {
    try {
      if (!await _ensureConfiguredAndAuthorized()) return 0;

      final now = DateTime.now();
      final startOfDay = _startOfLocalDay();

      final points = await _health.getHealthDataFromTypes(
        types: [HealthDataType.EXERCISE_TIME],
        startTime: startOfDay,
        endTime: now,
      );

      double min = 0;
      for (final p in points) {
        final raw = p.value;
        if (raw is NumericHealthValue) {
          min += raw.numericValue.toDouble();
        } else {
          final parsed = double.tryParse(raw.toString());
          if (parsed != null) min += parsed;
        }
      }
      return min;
    } catch (_) {
      return 0;
    }
  }

  static Future<TodayMetrics> getTodayMetrics() async {
    try {
      if (!await _ensureConfiguredAndAuthorized()) return TodayMetrics.zero;

      final now = DateTime.now();
      final startOfDay = _startOfLocalDay();

      final steps = await _health.getTotalStepsInInterval(startOfDay, now) ?? 0;
      final miles = await getTodayDistanceMiles();
      final cal = await getTodayActiveEnergyCalories();
      final min = await getTodayExerciseMinutes();

      return TodayMetrics(
        steps: steps,
        distanceMiles: miles,
        activeEnergyCalories: cal,
        exerciseMinutes: min,
      );
    } catch (_) {
      return TodayMetrics.zero;
    }
  }

  static Future<int> getWeekStepsTotal() async {
    try {
      if (!await _ensureConfiguredAndAuthorized()) return 0;
      final now = DateTime.now();
      final startOfDay = _startOfLocalDay();
      final startOfWeek = startOfDay.subtract(Duration(days: now.weekday - 1));
      return await _health.getTotalStepsInInterval(startOfWeek, now) ?? 0;
    } catch (_) {
      return 0;
    }
  }
}