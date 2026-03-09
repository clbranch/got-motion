import 'package:flutter/foundation.dart';

/// App-wide selected group state. Used by Home, Leaderboard, and Group screens.
/// Groups list: [{ 'id': uuid, 'name': string }]. Selected group name drives leaderboard and home.
class SelectedGroupService extends ChangeNotifier {
  List<Map<String, dynamic>> _groups = [];
  String? _selectedGroupName;

  List<Map<String, dynamic>> get groups => List.unmodifiable(_groups);

  /// Group names only, for dropdowns.
  List<String> get groupNames => _groups.map((g) => g['name'] as String? ?? '').where((s) => s.isNotEmpty).toList();

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
          return <String, dynamic>{
            'id': id,
            'name': name,
            if (inviteCode != null && inviteCode.isNotEmpty) 'invite_code': inviteCode,
            if (g['created_by'] != null) 'created_by': g['created_by']?.toString(),
          };
        })
        .whereType<Map<String, dynamic>>()
        .toList();
    if (_groups.isNotEmpty && (_selectedGroupName == null || !groupNames.contains(_selectedGroupName))) {
      _selectedGroupName = _groups.first['name'] as String?;
    } else if (_groups.isEmpty) {
      _selectedGroupName = null;
    }
    notifyListeners();
  }

  void setSelectedGroup(String? name) {
    if (_selectedGroupName == name) return;
    _selectedGroupName = name;
    notifyListeners();
  }

  /// After create or join, add a group and optionally set it as selected. Optional [inviteCode] for new groups.
  void addGroupAndSelect(String id, String name, [String? inviteCode]) {
    final existing = _groups.where((g) => g['id'] == id || g['name'] == name).toList();
    if (existing.isEmpty) {
      _groups = [
        ..._groups,
        {'id': id, 'name': name, if (inviteCode != null) 'invite_code': inviteCode},
      ];
    }
    _selectedGroupName = name;
    notifyListeners();
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
  }

  void clear() {
    _groups = [];
    _selectedGroupName = null;
    notifyListeners();
  }
}

/// App-wide singleton. Clear on logout.
SelectedGroupService get selectedGroupService => _selectedGroupService;
final SelectedGroupService _selectedGroupService = SelectedGroupService();
