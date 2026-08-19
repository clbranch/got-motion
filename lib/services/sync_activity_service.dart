import 'package:shared_preferences/shared_preferences.dart';

/// Tracks the last successful app / Health sync so inactivity reminders
/// never fire merely because Health values are still zero.
class SyncActivityService {
  SyncActivityService._();
  static final SyncActivityService instance = SyncActivityService._();

  static const _key = 'last_successful_health_sync_at';

  DateTime? _cached;

  DateTime? get lastSuccessfulHealthSyncAt => _cached;

  Future<void> hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    _cached = raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> markHealthSynced([DateTime? at]) async {
    final stamp = (at ?? DateTime.now()).toUtc();
    _cached = stamp.toLocal();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, stamp.toIso8601String());
  }

  /// Product rule helper: only consider a daily-return nudge after a quiet
  /// stretch and once local time is late afternoon or later.
  bool shouldConsiderInactivityReminder({
    DateTime? now,
    Duration quietFor = const Duration(hours: 6),
    int lateAfternoonHour = 16,
  }) {
    final localNow = now ?? DateTime.now();
    if (localNow.hour < lateAfternoonHour) return false;
    final last = _cached;
    if (last == null) {
      // Never synced successfully — do not nag about "zero" motion.
      return false;
    }
    return localNow.difference(last) >= quietFor;
  }
}

final syncActivityService = SyncActivityService.instance;
