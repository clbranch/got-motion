import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/app_notification.dart';
import 'motion_push_copy.dart';
import 'selected_group_service.dart';

/// In-app Notification Center data + unread badge.
///
/// Fetches from Supabase when available. Until server-triggered rows exist,
/// seeds realistic local sample notifications once per user (or keeps them
/// local if the migration has not been applied yet).
class NotificationService extends ChangeNotifier {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  List<AppNotification> _items = [];
  bool _loading = false;
  bool _usingLocalOnly = false;
  String? _error;

  List<AppNotification> get items => List.unmodifiable(_items);
  bool get loading => _loading;
  bool get usingLocalOnly => _usingLocalOnly;
  String? get error => _error;

  int get unreadCount => _items.where((n) => n.isUnread).length;

  Future<void> refresh() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _items = [];
      _usingLocalOnly = false;
      notifyListeners();
      return;
    }

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final rows = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(50);

      var list = (rows as List<dynamic>)
          .map(
            (row) =>
                AppNotification.fromMap(Map<String, dynamic>.from(row as Map)),
          )
          .toList();

      if (list.isEmpty) {
        final seeded = await _wasSeeded(user.id);
        if (!seeded) {
          list = await _ensureSamples(user.id);
          await _markSeeded(user.id);
        }
      }

      _items = list;
      _usingLocalOnly = list.isNotEmpty && list.every((n) => n.isLocalSample);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Notifications] fetch failed, using local samples: $e');
      }
      _error = e.toString();
      _items = await _loadOrCreateLocalSamples(user.id);
      _usingLocalOnly = true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> markRead(String id) async {
    final index = _items.indexWhere((n) => n.id == id);
    if (index < 0 || !_items[index].isUnread) return;

    final now = DateTime.now();
    _items = [
      for (var i = 0; i < _items.length; i++)
        if (i == index) _items[i].copyWith(readAt: now) else _items[i],
    ];
    notifyListeners();
    await _persistRead(id, now);
  }

  Future<void> markAllRead() async {
    final now = DateTime.now();
    final unreadIds = _items.where((n) => n.isUnread).map((n) => n.id).toList();
    if (unreadIds.isEmpty) return;

    _items = [for (final n in _items) n.isUnread ? n.copyWith(readAt: now) : n];
    notifyListeners();

    for (final id in unreadIds) {
      await _persistRead(id, now);
    }
  }

  Future<void> _persistRead(String id, DateTime readAt) async {
    AppNotification? item;
    for (final n in _items) {
      if (n.id == id) {
        item = n;
        break;
      }
    }
    if (item == null) return;

    if (item.isLocalSample || _usingLocalOnly) {
      await _saveLocalSamples(_items);
      return;
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      await _supabase
          .from('notifications')
          .update({'read_at': readAt.toUtc().toIso8601String()})
          .eq('id', id)
          .eq('user_id', user.id);
    } catch (e) {
      if (kDebugMode) debugPrint('[Notifications] markRead failed: $e');
      await _saveLocalSamples(_items);
    }
  }

  Future<List<AppNotification>> _ensureSamples(String userId) async {
    final samples = _buildSampleNotifications(userId);
    try {
      await _supabase
          .from('notifications')
          .insert(samples.map((s) => s.toInsertMap()..remove('id')).toList());
      final rows = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return (rows as List<dynamic>)
          .map(
            (row) =>
                AppNotification.fromMap(Map<String, dynamic>.from(row as Map)),
          )
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Notifications] sample insert failed: $e');
      }
      return _loadOrCreateLocalSamples(userId);
    }
  }

  Future<bool> _wasSeeded(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_seeded_v2_$userId') ?? false;
  }

  Future<void> _markSeeded(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_seeded_v2_$userId', true);
  }

  Future<List<AppNotification>> _loadOrCreateLocalSamples(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'local_notifications_v2_$userId';
    final raw = prefs.getStringList(key);
    if (raw != null && raw.isNotEmpty) {
      return raw.map(_decodeLocal).whereType<AppNotification>().toList();
    }
    // Already seeded (and cleared): stay empty. New installs / v2 upgrade: seed.
    if (await _wasSeeded(userId)) return [];
    final samples = _buildSampleNotifications(userId, local: true);
    await _saveLocalSamples(samples);
    await _markSeeded(userId);
    return samples;
  }

  Future<void> _saveLocalSamples(List<AppNotification> items) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'local_notifications_v2_${user.id}',
      items.map(_encodeLocal).toList(),
    );
  }

  List<AppNotification> _buildSampleNotifications(
    String userId, {
    bool local = false,
  }) {
    final groupId = selectedGroupService.selectedGroupId;
    final groupName = selectedGroupService.selectedGroupName ?? 'Mighty Ducks';
    final now = DateTime.now();
    final daySeed = now.year * 1000 + now.month * 50 + now.day;

    return [
      AppNotification(
        id: _uuid.v4(),
        userId: userId,
        groupId: groupId,
        type: AppNotificationType.catchUp,
        title: 'Catch up',
        body: MotionPushCopy.catchUp(seed: daySeed),
        data: {'kind': 'catch_up', 'group_name': groupName},
        createdAt: now.subtract(const Duration(minutes: 18)),
        isLocalSample: local,
      ),
      AppNotification(
        id: _uuid.v4(),
        userId: userId,
        groupId: groupId,
        type: AppNotificationType.leaderUpdate,
        title: 'Group motion',
        body: MotionPushCopy.someoneMoving(
          name: 'Q',
          steps: 500,
          groupName: groupName,
          seed: daySeed + 1,
        ),
        data: {
          'metric': 'steps',
          'leader_name': 'Q',
          'steps': 500,
          'group_name': groupName,
        },
        createdAt: now.subtract(const Duration(hours: 2)),
        isLocalSample: local,
      ),
      AppNotification(
        id: _uuid.v4(),
        userId: userId,
        groupId: groupId,
        type: AppNotificationType.groupActivity,
        title: 'Crew in motion',
        body: MotionPushCopy.memberInMotionYourTurn('Adrian'),
        data: {'leader_name': 'Adrian', 'group_name': groupName},
        createdAt: now.subtract(const Duration(hours: 5)),
        isLocalSample: local,
      ),
      AppNotification(
        id: _uuid.v4(),
        userId: userId,
        groupId: groupId,
        type: AppNotificationType.dailyReturn,
        title: 'Morning motion',
        body: MotionPushCopy.morning(seed: daySeed + 2),
        data: const {'kind': 'morning'},
        createdAt: now.subtract(const Duration(days: 1, hours: 3)),
        readAt: now.subtract(const Duration(days: 1, hours: 2)),
        isLocalSample: local,
      ),
      AppNotification(
        id: _uuid.v4(),
        userId: userId,
        groupId: groupId,
        type: AppNotificationType.leaderUpdate,
        title: 'On the board',
        body: MotionPushCopy.memberPutMotionOnBoard(name: 'Jay', steps: 1200),
        data: {
          'metric': 'steps',
          'leader_name': 'Jay',
          'steps': 1200,
          'group_name': groupName,
        },
        createdAt: now.subtract(const Duration(days: 2)),
        readAt: now.subtract(const Duration(days: 2)),
        isLocalSample: local,
      ),
    ];
  }

  String _encodeLocal(AppNotification n) {
    return [
      n.id,
      n.userId,
      n.groupId ?? '',
      n.type.wire,
      n.title.replaceAll('|', '/'),
      n.body.replaceAll('|', '/'),
      n.createdAt.toUtc().toIso8601String(),
      n.readAt?.toUtc().toIso8601String() ?? '',
    ].join('|');
  }

  AppNotification? _decodeLocal(String raw) {
    final parts = raw.split('|');
    if (parts.length < 8) return null;
    return AppNotification(
      id: parts[0],
      userId: parts[1],
      groupId: parts[2].isEmpty ? null : parts[2],
      type: AppNotificationType.fromWire(parts[3]),
      title: parts[4],
      body: parts[5],
      createdAt: DateTime.tryParse(parts[6])?.toLocal() ?? DateTime.now(),
      readAt: parts[7].isEmpty ? null : DateTime.tryParse(parts[7])?.toLocal(),
      isLocalSample: true,
    );
  }
}

final notificationService = NotificationService.instance;
