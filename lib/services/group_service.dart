import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of creating a group: id, name, invite_code.
class CreateGroupResult {
  const CreateGroupResult({
    required this.id,
    required this.name,
    required this.inviteCode,
  });
  final String id;
  final String name;
  final String inviteCode;
}

/// Result of joining a group: group id and name.
class JoinGroupResult {
  const JoinGroupResult({required this.groupId, required this.groupName});
  final String groupId;
  final String groupName;
}

/// Thrown when invite code does not match any group.
class GroupNotFound implements Exception {
  GroupNotFound([this.message]);
  final String? message;
  @override
  String toString() => message ?? 'Invalid invite code.';
}

/// Thrown when user is already a member of the group.
class AlreadyInGroup implements Exception {
  AlreadyInGroup([this.message]);
  final String? message;
  @override
  String toString() => message ?? "You're already in this group.";
}

class GroupService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static final Random _random = Random();
  static const String _inviteCodeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const int _inviteCodeLength = 6;

  static String _generateInviteCode() {
    return List.generate(_inviteCodeLength, (_) => _inviteCodeChars[_random.nextInt(_inviteCodeChars.length)]).join();
  }

  /// Fetches the invite code for a group the user is in. Returns null if not found or RLS denies.
  Future<String?> getGroupInviteCode(String groupId) async {
    try {
      final rows = await _supabase
          .from('groups')
          .select('invite_code')
          .eq('id', groupId)
          .limit(1);
      final list = List<Map<String, dynamic>>.from(rows);
      if (list.isEmpty) return null;
      return list.first['invite_code']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchUserGroups(String userId) async {
    // ignore: avoid_print
    print('[GroupService] fetchUserGroups: user id=$userId');
    try {
      final response = await _supabase
          .from('group_members')
          .select('group_id, groups(id, name, invite_code, created_by)')
          .eq('user_id', userId);
      final list = List<Map<String, dynamic>>.from(response);
      // ignore: avoid_print
      print('[GroupService] fetchUserGroups: returned ${list.length} row(s)');
      return list;
    } catch (e, st) {
      // ignore: avoid_print
      print('[GroupService] fetchUserGroups error: $e');
      // ignore: avoid_print
      print('[GroupService] fetchUserGroups stackTrace: $st');
      rethrow;
    }
  }

  /// Creates a group and adds the creator as a member. Returns the created group with invite code.
  /// Requires groups table with: id, name, invite_code (unique).
  /// Requires group_members table with: user_id, group_id.
  Future<CreateGroupResult> createGroup(String userId, String name) async {
    // ignore: avoid_print
    print('[GroupService] createGroup: current auth user id=$userId');
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Group name cannot be empty');
    }
    String? inviteCode;
    Map<String, dynamic>? inserted;
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = _generateInviteCode();
      // ignore: avoid_print
      print('[GroupService] createGroup payload: name="$trimmedName", invite_code=$code (attempt ${attempt + 1})');
      try {
        final response = await _supabase
            .from('groups')
            .insert({
              'name': trimmedName,
              'invite_code': code,
              'created_by': userId,
            })
            .select()
            .single();
        inserted = Map<String, dynamic>.from(response as Map);
        inviteCode = code;
        break;
      } catch (e, st) {
        // ignore: avoid_print
        print('[GroupService] createGroup Supabase/database error: $e');
        // ignore: avoid_print
        print('[GroupService] createGroup stackTrace: $st');
        if (e.toString().contains('unique') || e.toString().contains('duplicate')) {
          continue;
        }
        rethrow;
      }
    }
    if (inserted == null || inviteCode == null) {
      throw Exception('Could not create group; please try again.');
    }
    final groupId = inserted['id'] as String;
    try {
      await _supabase.from('group_members').insert({
        'user_id': userId,
        'group_id': groupId,
      });
    } catch (e, st) {
      // ignore: avoid_print
      print('[GroupService] createGroup group_members insert error: $e');
      // ignore: avoid_print
      print('[GroupService] createGroup group_members stackTrace: $st');
      rethrow;
    }
    return CreateGroupResult(
      id: groupId,
      name: inserted['name'] as String,
      inviteCode: inserted['invite_code'] as String? ?? inviteCode,
    );
  }

  /// Joins a group by invite code. Throws [GroupNotFound] or [AlreadyInGroup] with friendly messages.
  Future<JoinGroupResult> joinByInviteCode(String userId, String code) async {
    // ignore: avoid_print
    print('[GroupService] joinByInviteCode: current auth user id=$userId, code="$code"');
    final normalizedCode = code.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
      throw GroupNotFound('Please enter an invite code.');
    }
    // ignore: avoid_print
    print('[GroupService] joinByInviteCode: looking up group with invite_code=$normalizedCode');
    List<Map<String, dynamic>> groups;
    try {
      final groupRows = await _supabase
          .from('groups')
          .select('id, name')
          .eq('invite_code', normalizedCode)
          .limit(1);
      groups = List<Map<String, dynamic>>.from(groupRows);
    } catch (e, st) {
      // ignore: avoid_print
      print('[GroupService] joinByInviteCode groups lookup error: $e');
      // ignore: avoid_print
      print('[GroupService] joinByInviteCode stackTrace: $st');
      rethrow;
    }
    if (groups.isEmpty) {
      // ignore: avoid_print
      print('[GroupService] joinByInviteCode: no group found for code');
      throw GroupNotFound('Invalid invite code. Check the code and try again.');
    }
    final group = groups.single;
    final groupId = group['id'] as String;
    final groupName = group['name'] as String? ?? '';

    final existing = await _supabase
        .from('group_members')
        .select('user_id')
        .eq('user_id', userId)
        .eq('group_id', groupId)
        .maybeSingle();

    if (existing != null) {
      // ignore: avoid_print
      print('[GroupService] joinByInviteCode: user already in group');
      throw AlreadyInGroup("You're already in this group.");
    }

    try {
      await _supabase.from('group_members').insert({
        'user_id': userId,
        'group_id': groupId,
      });
    } catch (e, st) {
      // ignore: avoid_print
      print('[GroupService] joinByInviteCode group_members insert error: $e');
      // ignore: avoid_print
      print('[GroupService] joinByInviteCode group_members stackTrace: $st');
      rethrow;
    }

    return JoinGroupResult(groupId: groupId, groupName: groupName);
  }

  /// Fetches members of a group for display. Returns list of { user_id, email?, display_name?, avatar_url? }.
  /// Display name in UI: display_name ?? email ?? 'Member'. Avatar: avatar_url or first letter.
  Future<List<Map<String, dynamic>>> fetchGroupMembers(String groupId) async {
    try {
      final response = await _supabase
          .from('group_members')
          .select('user_id')
          .eq('group_id', groupId);
      
      final list = List<Map<String, dynamic>>.from(response);
      final userIds = list.map((r) => r['user_id'] as String).toList();

      if (userIds.isEmpty) return [];

      final profilesResponse = await _supabase
          .from('profiles')
          .select('id, email, display_name, avatar_url')
          .inFilter('id', userIds);
          
      final profiles = List<Map<String, dynamic>>.from(profilesResponse);
      
      final profileMap = {
        for (final p in profiles) p['id'] as String: p
      };

      return list.map((r) {
        final userId = r['user_id'] as String;
        final profile = profileMap[userId];
        
        return {
          'user_id': userId,
          'email': profile?['email']?.toString(),
          'display_name': profile?['display_name']?.toString(),
          'avatar_url': profile?['avatar_url']?.toString(),
        };
      }).toList();
    } catch (_) {
      // Fallback
      try {
        final fallback = await _supabase
            .from('group_members')
            .select('user_id')
            .eq('group_id', groupId);
        return (List<Map<String, dynamic>>.from(fallback))
            .map((r) => {
                  'user_id': r['user_id'],
                  'email': null,
                  'display_name': null,
                  'avatar_url': null,
                })
            .toList();
      } catch (fallbackErr) {
        return [];
      }
    }
  }

  Future<void> leaveGroup(String userId, String groupId) async {
    try {
      await _supabase
          .from('group_members')
          .delete()
          .eq('user_id', userId)
          .eq('group_id', groupId);
    } catch (e, st) {
      // ignore: avoid_print
      print('[GroupService] leaveGroup error: $e');
      // ignore: avoid_print
      print('[GroupService] leaveGroup stackTrace: $st');
      rethrow;
    }
  }

  Future<void> deleteGroup(String groupId) async {
    try {
      // Because group_members and group_invites have ON DELETE CASCADE (or should be managed),
      // we just delete the group. The RLS will block it if not the creator.
      await _supabase
          .from('groups')
          .delete()
          .eq('id', groupId);
    } catch (e, st) {
      // ignore: avoid_print
      print('[GroupService] deleteGroup error: $e');
      // ignore: avoid_print
      print('[GroupService] deleteGroup stackTrace: $st');
      rethrow;
    }
  }
}