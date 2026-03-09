import 'dart:convert';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Single row from group_invites for display (e.g. pending invites).
class GroupInviteRecord {
  const GroupInviteRecord({
    required this.id,
    required this.groupId,
    required this.invitedEmail,
    required this.invitedBy,
    required this.inviteToken,
    required this.status,
    required this.createdAt,
    this.acceptedAt,
    this.groupName,
  });
  final String id;
  final String groupId;
  final String invitedEmail;
  final String invitedBy;
  final String inviteToken;
  final String status;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final String? groupName;

  static GroupInviteRecord fromMap(Map<String, dynamic> r) {
    return GroupInviteRecord(
      id: r['id'] as String,
      groupId: r['group_id'] as String,
      invitedEmail: r['invited_email'] as String? ?? '',
      invitedBy: r['invited_by'] as String,
      inviteToken: r['invite_token'] as String? ?? '',
      status: r['status'] as String? ?? 'pending',
      createdAt: r['created_at'] != null
          ? DateTime.parse(r['created_at'].toString())
          : DateTime.now(),
      acceptedAt: r['accepted_at'] != null
          ? DateTime.tryParse(r['accepted_at'].toString())
          : null,
      groupName: r['group_name']?.toString(),
    );
  }
}

/// Thrown when a pending invite already exists for this group + email.
class InviteAlreadyExists implements Exception {
  InviteAlreadyExists([this.message]);
  final String? message;
  @override
  String toString() => message ?? 'An invite was already sent to this email.';
}

class GroupInviteService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static final Random _random = Random();

  static String _generateInviteToken() {
    final bytes = List<int>.generate(24, (_) => _random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  /// Creates a pending invite. invited_by should be auth.uid().
  /// Throws [InviteAlreadyExists] if a pending invite for this group+email already exists.
  /// invite_token is stored for future deep-link / non-user signup flow.
  Future<GroupInviteRecord> createInvite({
    required String groupId,
    required String invitedEmail,
    required String invitedBy,
  }) async {
    final email = invitedEmail.trim().toLowerCase();
    if (email.isEmpty) throw ArgumentError('Email is required');
    final token = _generateInviteToken();
    // ignore: avoid_print
    print('[GroupInviteService] createInvite: invitedBy=$invitedBy, groupId=$groupId, invitedEmail=$email, invite_token=${token.substring(0, 8)}...');
    try {
      final response = await _supabase
          .from('group_invites')
          .insert({
            'group_id': groupId,
            'invited_email': email,
            'invited_by': invitedBy,
            'invite_token': token,
            'status': 'pending',
          })
          .select()
          .single();
      final record = GroupInviteRecord.fromMap(Map<String, dynamic>.from(response as Map));
      // ignore: avoid_print
      print('[GroupInviteService] createInvite success: id=${record.id} (invite DB row created)');
      return record;
    } on PostgrestException catch (e) {
      // ignore: avoid_print
      print('[GroupInviteService] createInvite PostgrestException: ${e.message}');
      if (e.code == '23505' ||
          e.message.contains('unique') ||
          e.message.contains('duplicate')) {
        throw InviteAlreadyExists('An invite was already sent to this email.');
      }
      rethrow;
    }
  }

  /// Sends the invite email via Edge Function (Resend). Call after [createInvite] for full flow.
  /// Returns true if email was sent, false if send failed (invite row still exists).
  Future<bool> sendInviteEmail(String inviteId) async {
    // ignore: avoid_print
    print('[GroupInviteService] sendInviteEmail: attempting outbound email for invite_id=$inviteId');
    try {
      final res = await _supabase.functions.invoke(
        'send-invite-email',
        body: {'invite_id': inviteId},
      );
      if (res.status >= 200 && res.status < 300) {
        // ignore: avoid_print
        print('[GroupInviteService] sendInviteEmail: email send success');
        return true;
      }
      // ignore: avoid_print
      print('[GroupInviteService] sendInviteEmail: email send failed status=${res.status} body=${res.data}');
      return false;
    } catch (e) {
      // ignore: avoid_print
      print('[GroupInviteService] sendInviteEmail: exception (email send failed) $e');
      return false;
    }
  }

  /// Fetches pending invites for the given email (e.g. current user's auth email).
  /// group_name may be null if RLS blocks reading the group before the user joins.
  Future<List<GroupInviteRecord>> fetchPendingInvitesForEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return [];
    try {
      final response = await _supabase
          .from('group_invites')
          .select('id, group_id, invited_email, invited_by, invite_token, status, created_at, accepted_at, groups(name)')
          .eq('invited_email', normalized)
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      final list = List<Map<String, dynamic>>.from(response);
      return list.map((r) {
        final g = r['groups'] as Map<String, dynamic>?;
        return GroupInviteRecord.fromMap({
          ...r,
          'group_name': g?['name']?.toString(),
        });
      }).toList();
    } catch (_) {
      try {
        final response = await _supabase
            .from('group_invites')
            .select('id, group_id, invited_email, invited_by, invite_token, status, created_at, accepted_at')
            .eq('invited_email', normalized)
            .eq('status', 'pending')
            .order('created_at', ascending: false);
        final list = List<Map<String, dynamic>>.from(response);
        return list.map((r) => GroupInviteRecord.fromMap(r)).toList();
      } catch (_) {
        return [];
      }
    }
  }

  /// Accepts an invite: adds user to group_members if not already, marks invite accepted.
  /// Returns the group id and name. Throws if already a member (friendly message).
  Future<({String groupId, String groupName})> acceptInvite(
    String inviteId,
    String userId,
  ) async {
    final inviteRows = await _supabase
        .from('group_invites')
        .select('id, group_id, status')
        .eq('id', inviteId)
        .eq('status', 'pending')
        .limit(1);
    final list = List<Map<String, dynamic>>.from(inviteRows);
    if (list.isEmpty) {
      throw Exception('Invite not found or already used.');
    }
    final row = list.single;
    final groupId = row['group_id'] as String;

    final existing = await _supabase
        .from('group_members')
        .select('user_id')
        .eq('user_id', userId)
        .eq('group_id', groupId)
        .maybeSingle();

    if (existing != null) {
      await _supabase
          .from('group_invites')
          .update({
            'status': 'accepted',
            'accepted_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', inviteId);
      throw Exception("You're already in this group.");
    }

    await _supabase.from('group_members').insert({
      'user_id': userId,
      'group_id': groupId,
    });
    await _supabase
        .from('group_invites')
        .update({
          'status': 'accepted',
          'accepted_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', inviteId);

    // ignore: avoid_print
    print('[GroupInviteService] acceptInvite success: userId=$userId, groupId=$groupId');

    String groupName = 'Group';
    try {
      final groupRows = await _supabase
          .from('groups')
          .select('name')
          .eq('id', groupId)
          .limit(1);
      final gList = List<Map<String, dynamic>>.from(groupRows);
      if (gList.isNotEmpty) groupName = gList.single['name']?.toString() ?? groupName;
    } catch (_) {}

    return (groupId: groupId, groupName: groupName);
  }

  /// Marks an invite as declined.
  Future<void> declineInvite(String inviteId) async {
    await _supabase
        .from('group_invites')
        .update({'status': 'declined'})
        .eq('id', inviteId)
        .eq('status', 'pending');
  }
}
