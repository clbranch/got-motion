import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'group_service.dart';

/// App-wide selected group state. Used by Home, Leaderboard, and Group screens.
/// Groups list: [{ 'id': uuid, 'name': string }]. Selected group name drives leaderboard and home.
class SelectedGroupService extends ChangeNotifier {
  static const _prefsKey = 'selected_group_id';

  List<Map<String, dynamic>> _groups = [];
  String? _selectedGroupName;
  bool _hydrated = false;
  Future<void>? _hydrateFuture;

  List<Map<String, dynamic>> get groups => List.unmodifiable(_groups);

  /// Group names only, for dropdowns.
  List<String> get groupNames => _groups
      .map((g) => g['name'] as String? ?? '')
      .where((s) => s.isNotEmpty)
      .toList();

  String? get selectedGroupName => _selectedGroupName;

  /// Selected group's id, or null if none selected.
  String? get selectedGroupId {
    if (_selectedGroupName == null) return null;
    for (final g in _groups) {
      if (g['name'] == _selectedGroupName) return g['id'] as String?;
    }
    return null;
  }

  /// Selected group's invite code (for sharing). Null if none selected or code not loaded.
  String? get selectedGroupInviteCode {
    if (_selectedGroupName == null) return null;
    for (final g in _groups) {
      if (g['name'] == _selectedGroupName) return g['invite_code'] as String?;
    }
    return null;
  }

  /// Selected group's created_by user ID. Null if none selected or not loaded.
  String? get selectedGroupCreatedBy {
    if (_selectedGroupName == null) return null;
    for (final g in _groups) {
      if (g['name'] == _selectedGroupName) return g['created_by'] as String?;
    }
    return null;
  }

  /// Loads the signed-in user's groups before Home paints, and restores the
  /// last selected group. Safe to call from multiple screens — in-flight work
  /// is shared, and a completed hydrate is a no-op until [clear] or [force].
  Future<void> hydrate({bool force = false}) {
    if (_hydrateFuture != null) return _hydrateFuture!;
    if (_hydrated && !force) return Future.value();
    _hydrateFuture = _hydrate();
    return _hydrateFuture!;
  }

  Future<void> _hydrate() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        _hydrated = true;
        return;
      }
      final rows = await GroupService().fetchUserGroups(userId);
      final savedId = (await SharedPreferences.getInstance()).getString(
        _prefsKey,
      );
      setGroupsFromFetchRows(rows);
      if (savedId != null) {
        for (final g in _groups) {
          if (g['id'] == savedId) {
            final name = g['name'] as String?;
            if (name != null && name != _selectedGroupName) {
              _selectedGroupName = name;
              notifyListeners();
            }
            break;
          }
        }
      }
      _hydrated = true;
      await _persist();
    } catch (e, st) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[SelectedGroup] hydrate error: $e');
        // ignore: avoid_print
        print('[SelectedGroup] hydrate stackTrace: $st');
      }
      _hydrated = true;
    } finally {
      _hydrateFuture = null;
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final id = selectedGroupId;
    if (id == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, id);
    }
  }

  /// Set groups from GroupService.fetchUserGroups rows. Parses groups(id, name, invite_code).
  void setGroupsFromFetchRows(List<Map<String, dynamic>> rows) {
    _groups = rows
        .map((r) {
          final g = r['groups'] as Map<String, dynamic>?;
          if (g == null) return null;
          final id = g['id']?.toString();
          final name = g['name']?.toString();
          if (id == null || name == null) return null;
          final inviteCode = g['invite_code']?.toString();
          final imageUrl = g['image_url']?.toString();
          return <String, dynamic>{
            'id': id,
            'name': name,
            if (inviteCode != null && inviteCode.isNotEmpty)
              'invite_code': inviteCode,
            if (g['created_by'] != null)
              'created_by': g['created_by']?.toString(),
            if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
          };
        })
        .whereType<Map<String, dynamic>>()
        .toList();
    if (_groups.isNotEmpty &&
        (_selectedGroupName == null ||
            !groupNames.contains(_selectedGroupName))) {
      _selectedGroupName = _groups.first['name'] as String?;
    } else if (_groups.isEmpty) {
      _selectedGroupName = null;
    }
    _hydrated = true;
    notifyListeners();
    unawaited(_persist());
  }

  String? get selectedGroupImageUrl => imageUrlFor(_selectedGroupName);

  String? imageUrlFor(String? name) {
    if (name == null || name.isEmpty) return null;
    for (final g in _groups) {
      if (g['name'] == name) {
        final url = g['image_url']?.toString();
        if (url != null && url.isNotEmpty) return url;
      }
    }
    return null;
  }

  void updateGroupImage(String groupId, String imageUrl) {
    _groups = [
      for (final g in _groups)
        if (g['id'] == groupId) {...g, 'image_url': imageUrl} else g,
    ];
    notifyListeners();
  }

  void setSelectedGroup(String? name) {
    if (_selectedGroupName == name) return;
    _selectedGroupName = name;
    notifyListeners();
    unawaited(_persist());
  }

  /// After create or join, add a group and optionally set it as selected. Optional [inviteCode] for new groups.
  void addGroupAndSelect(String id, String name, [String? inviteCode]) {
    final existing = _groups
        .where((g) => g['id'] == id || g['name'] == name)
        .toList();
    if (existing.isEmpty) {
      _groups = [
        ..._groups,
        {'id': id, 'name': name, ?inviteCode: 'invite_code'},
      ];
    }
    _selectedGroupName = name;
    _hydrated = true;
    notifyListeners();
    unawaited(_persist());
  }

  /// Removes a group locally (e.g., after leaving/deleting) and selects another if available.
  void removeGroup(String groupId) {
    _groups = _groups.where((g) => g['id'] != groupId).toList();
    if (_groups.isNotEmpty) {
      _selectedGroupName = _groups.first['name'] as String?;
    } else {
      _selectedGroupName = null;
    }
    notifyListeners();
    unawaited(_persist());
  }

  void clear() {
    _groups = [];
    _selectedGroupName = null;
    _hydrated = false;
    _hydrateFuture = null;
    notifyListeners();
    unawaited(_persist());
  }
}

/// App-wide singleton. Clear on logout.
SelectedGroupService get selectedGroupService => _selectedGroupService;
final SelectedGroupService _selectedGroupService = SelectedGroupService();
