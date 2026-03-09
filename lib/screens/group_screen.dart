import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/group_invite_service.dart';
import '../services/group_service.dart';
import '../services/selected_group_service.dart';

/// Group screen: selected group, create/join actions, member list. Uses SelectedGroupService for app-wide selected group.
class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  static const Color _background = Color(0xFF0B0B0F);
  static const Color _cardBg = Color(0xFF14141A);
  static const Color _accent = Color(0xFF3B82F6);
  static const Color _pillBg = Color(0xFF1A1A24);
  static const Color _pillBorder = Color(0xFF2A2A36);
  static const double _pagePadding = 16.0;

  final GroupService _groupService = GroupService();
  final GroupInviteService _inviteService = GroupInviteService();
  List<Map<String, dynamic>> _members = [];
  bool _membersLoading = false;
  String? _membersError;
  /// Invite code for the currently selected group; loaded when group changes.
  String? _displayedInviteCode;
  List<GroupInviteRecord> _pendingInvites = [];

  @override
  void initState() {
    super.initState();
    selectedGroupService.addListener(_onSelectedGroupChanged);
    _loadGroupsAndMembers();
    _loadPendingInvites();
  }

  @override
  void dispose() {
    selectedGroupService.removeListener(_onSelectedGroupChanged);
    super.dispose();
  }

  void _onSelectedGroupChanged() {
    if (mounted) {
      setState(() => _displayedInviteCode = null);
      _loadMembers();
      _loadInviteCodeForSelectedGroup();
    }
  }

  Future<void> _loadPendingInvites() async {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email;
    if (email == null || email.isEmpty) {
      setState(() => _pendingInvites = []);
      return;
    }
    try {
      final list = await _inviteService.fetchPendingInvitesForEmail(email);
      if (!mounted) return;
      setState(() => _pendingInvites = list);
    } catch (_) {
      if (mounted) setState(() => _pendingInvites = []);
    }
  }

  Future<void> _loadInviteCodeForSelectedGroup() async {
    final groupId = selectedGroupService.selectedGroupId;
    if (groupId == null) return;
    final code = selectedGroupService.selectedGroupInviteCode;
    if (code != null && code.isNotEmpty) {
      if (mounted) setState(() => _displayedInviteCode = code);
      return;
    }
    final fetched = await _groupService.getGroupInviteCode(groupId);
    if (!mounted) return;
    setState(() => _displayedInviteCode = fetched);
  }

  Future<void> _loadGroupsAndMembers() async {
    final user = Supabase.instance.client.auth.currentUser;
    // ignore: avoid_print
    print('[GroupScreen] _loadGroupsAndMembers: auth user id=${user?.id ?? "null"}');
    if (user == null) {
      if (mounted) setState(() {});
      return;
    }
    try {
      final rows = await _groupService.fetchUserGroups(user.id);
      if (!mounted) return;
      selectedGroupService.setGroupsFromFetchRows(rows);
      setState(() => _displayedInviteCode = selectedGroupService.selectedGroupInviteCode);
      _loadMembers();
      _loadInviteCodeForSelectedGroup();
    } catch (e, st) {
      // ignore: avoid_print
      print('[GroupScreen] _loadGroupsAndMembers error: $e');
      // ignore: avoid_print
      print('[GroupScreen] _loadGroupsAndMembers stackTrace: $st');
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadMembers() async {
    final groupId = selectedGroupService.selectedGroupId;
    if (groupId == null) {
      setState(() {
        _members = [];
        _membersLoading = false;
        _membersError = null;
      });
      return;
    }
    setState(() {
      _membersLoading = true;
      _membersError = null;
    });
    try {
      final list = await _groupService.fetchGroupMembers(groupId);
      if (!mounted) return;
      setState(() {
        _members = list;
        _membersLoading = false;
        _membersError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _members = [];
        _membersLoading = false;
        _membersError = e.toString().replaceAll(RegExp(r'^Exception:\s*'), '');
      });
    }
  }

  Future<void> _createGroup() async {
    final user = Supabase.instance.client.auth.currentUser;
    // ignore: avoid_print
    print('[GroupScreen] createGroup: current auth user id=${user?.id ?? "null"}');
    if (user == null) {
      if (mounted) _showErrorSnackbar('You must be signed in to create a group.');
      return;
    }
    final name = await _showCreateGroupDialog();
    if (name == null || name.isEmpty) return;
    try {
      final result = await _groupService.createGroup(user.id, name);
      if (!mounted) return;
      selectedGroupService.addGroupAndSelect(result.id, result.name, result.inviteCode);
      await _loadGroupsAndMembers();
      if (!mounted) return;
      await _showInviteCodeDialog(result.inviteCode, result.name);
    } catch (e, st) {
      // ignore: avoid_print
      print('[GroupScreen] createGroup exact error: $e');
      // ignore: avoid_print
      print('[GroupScreen] createGroup stackTrace: $st');
      if (!mounted) return;
      final friendly = _friendlyCreateError(e);
      final detail = kDebugMode ? _shortError(e) : null;
      _showErrorSnackbar(
        detail != null ? '$friendly\n$detail' : friendly,
        isDebugDetail: detail != null,
      );
    }
  }

  /// One-line summary of exception for debug snackbar.
  static String? _shortError(dynamic e) {
    final s = e.toString();
    if (s.length > 80) return '${s.substring(0, 77)}...';
    return s;
  }

  Future<void> _joinGroup() async {
    final user = Supabase.instance.client.auth.currentUser;
    // ignore: avoid_print
    print('[GroupScreen] joinGroup: current auth user id=${user?.id ?? "null"}');
    if (user == null) {
      if (mounted) _showErrorSnackbar('You must be signed in to join a group.');
      return;
    }
    final code = await _showJoinGroupDialog();
    if (code == null || code.isEmpty) return;
    try {
      final result = await _groupService.joinByInviteCode(user.id, code);
      if (!mounted) return;
      selectedGroupService.addGroupAndSelect(result.groupId, result.groupName);
      await _loadGroupsAndMembers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Joined "${result.groupName}"'),
          backgroundColor: _accent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on GroupNotFound catch (e) {
      // ignore: avoid_print
      print('[GroupScreen] joinGroup GroupNotFound: $e');
      if (!mounted) return;
      _showErrorSnackbar(e.toString());
    } on AlreadyInGroup catch (e) {
      // ignore: avoid_print
      print('[GroupScreen] joinGroup AlreadyInGroup: $e');
      if (!mounted) return;
      _showErrorSnackbar(e.toString());
    } catch (e, st) {
      // ignore: avoid_print
      print('[GroupScreen] joinGroup exact error: $e');
      // ignore: avoid_print
      print('[GroupScreen] joinGroup stackTrace: $st');
      if (!mounted) return;
      _showErrorSnackbar(_friendlyError(e));
    }
  }

  /// For join flow: avoid showing raw Supabase errors; map to user-friendly join messages.
  String _friendlyError(dynamic e) {
    final s = e.toString();
    if (s.contains('unique') || s.contains('duplicate') || s.contains('already')) {
      return "You're already in this group.";
    }
    if (s.contains('invite') || s.contains('code')) return 'Invalid invite code. Try again.';
    return 'Something went wrong. Try again.';
  }

  /// For create flow: never show "Invalid invite code" (that's for join). Create failures often mention "invite_code" in DB errors.
  String _friendlyCreateError(dynamic e) {
    final s = e.toString();
    if (s.contains('unique') || s.contains('duplicate')) {
      return 'Couldn\'t create group (name or code conflict). Try again.';
    }
    return 'Couldn\'t create group. Try again.';
  }

  void _showErrorSnackbar(String message, {bool isDebugDetail = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        duration: isDebugDetail ? const Duration(seconds: 8) : const Duration(seconds: 4),
      ),
    );
  }

  Future<String?> _showCreateGroupDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text('Create group', style: TextStyle(color: Colors.white.withValues(alpha: 0.95))),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Group name',
            labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
            ),
          ),
          style: const TextStyle(color: Colors.white),
          onSubmitted: (_) => Navigator.of(context).pop(controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: _accent),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _showInviteCodeDialog(String code, String groupName) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text('Group created', style: TextStyle(color: Colors.white.withValues(alpha: 0.95))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Share this code so others can join "$groupName":',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
            ),
            const SizedBox(height: 12),
            SelectableText(
              code,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3B82F6),
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the code to copy',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Invite code copied'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: _accent),
            child: const Text('Copy code'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(backgroundColor: _accent),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showJoinGroupDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text('Join group', style: TextStyle(color: Colors.white.withValues(alpha: 0.95))),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: 'Invite code',
            hintText: 'e.g. ABC123',
            labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
            ),
          ),
          style: const TextStyle(color: Colors.white, letterSpacing: 2),
          onSubmitted: (_) => Navigator.of(context).pop(controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: _accent),
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = selectedGroupService.groupNames;
    final selectedName = selectedGroupService.selectedGroupName;

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(_pagePadding, 16, _pagePadding, 24),
          children: [
            _buildHeader(),
            const SizedBox(height: 14),
            _buildGroupControlRow(groups, selectedName),
            if (_pendingInvites.isNotEmpty) ...[
              const SizedBox(height: 14),
              _buildPendingInvitesSection(),
            ],
            const SizedBox(height: 18),
            _buildCurrentGroupCard(selectedName),
            const SizedBox(height: 20),
            _buildMembersSection(),
            const SizedBox(height: 14),
            _buildInviteCodeSection(),
            const SizedBox(height: 14),
            _buildShareInviteButton(),
            const SizedBox(height: 10),
            _buildJoinWithCodeButton(),
            const SizedBox(height: 10),
            _buildInviteByEmailButton(),
            const SizedBox(height: 20),
            _buildGroupStatsPlaceholder(),
            _buildDangerZone(),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerZone() {
    final groupId = selectedGroupService.selectedGroupId;
    if (groupId == null) return const SizedBox.shrink();

    final user = Supabase.instance.client.auth.currentUser;
    final createdBy = selectedGroupService.selectedGroupCreatedBy;
    // We treat the user as creator if created_by matches, or if it's somehow null we don't grant creator powers.
    // The rules state only creator can delete, and creator can leave if last member.
    final isCreator = user != null && createdBy == user.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'Group Actions',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFEF4444).withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _confirmLeaveGroup(groupId, isCreator),
            icon: const Icon(Icons.exit_to_app_rounded, size: 20),
            label: const Text('Leave Group'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
              side: BorderSide(color: const Color(0xFFEF4444).withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        if (isCreator) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _confirmDeleteGroup(groupId),
              icon: const Icon(Icons.delete_forever_rounded, size: 20),
              label: const Text('Delete Group'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.15),
                foregroundColor: const Color(0xFFEF4444),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmLeaveGroup(String groupId, bool isCreator) async {
    if (isCreator && _members.length > 1) {
      _showSnackBar('The group creator must delete the group or transfer ownership before leaving.', isError: true);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text('Leave group?', style: TextStyle(color: Colors.white.withValues(alpha: 0.95))),
        content: Text(
          'Are you sure you want to leave this group? You will no longer participate in its leaderboards.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await _groupService.leaveGroup(user.id, groupId);
      if (!mounted) return;
      selectedGroupService.removeGroup(groupId);
      await _loadGroupsAndMembers();
      if (mounted) _showSnackBar('You left the group.');
    } catch (e) {
      if (mounted) _showSnackBar('Failed to leave group. Try again.', isError: true);
    }
  }

  Future<void> _confirmDeleteGroup(String groupId) async {
    if (_members.length > 1) {
      _showSnackBar('You can only delete this group after all other members leave.', isError: true);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text('Delete group?', style: TextStyle(color: Colors.white.withValues(alpha: 0.95))),
        content: Text(
          'Are you sure you want to permanently delete this group? This action cannot be undone.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _groupService.deleteGroup(groupId);
      if (!mounted) return;
      selectedGroupService.removeGroup(groupId);
      await _loadGroupsAndMembers();
      if (mounted) _showSnackBar('Group deleted.');
    } catch (e) {
      if (mounted) _showSnackBar('Failed to delete group. Try again.', isError: true);
    }
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        'Group',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: 0.95),
        ),
      ),
    );
  }

  Widget _buildGroupControlRow(List<String> groups, String? selectedName) {
    final groupId = selectedGroupService.selectedGroupId;
    final user = Supabase.instance.client.auth.currentUser;
    final createdBy = selectedGroupService.selectedGroupCreatedBy;
    final isCreator = user != null && createdBy == user.id;

    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: Colors.transparent,
              child: groups.isEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: _pillBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: _pillBorder, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.groups_rounded, size: 20, color: Colors.white.withValues(alpha: 0.5)),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'No group',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.5)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    )
                  : PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      offset: const Offset(0, 48),
                      color: _background,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      onSelected: (String g) => selectedGroupService.setSelectedGroup(g),
                      itemBuilder: (context) => groups
                          .map((g) => PopupMenuItem<String>(
                                value: g,
                                child: Text(
                                  g,
                                  style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.9)),
                                ),
                              ))
                          .toList(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: _pillBg,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: _pillBorder, width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.groups_rounded, size: 20, color: Colors.white.withValues(alpha: 0.7)),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                selectedName ?? 'No group',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: Colors.white.withValues(alpha: 0.9)),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: _createGroup,
          icon: Icon(Icons.add_rounded, size: 20, color: _accent),
          label: const Text(
            'New Group',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF3B82F6)),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        if (groupId != null) ...[
          Theme(
            data: Theme.of(context).copyWith(
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: PopupMenuButton<String>(
              color: _cardBg,
              icon: Icon(Icons.more_vert_rounded, color: Colors.white.withValues(alpha: 0.7)),
              offset: const Offset(0, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              onSelected: (value) {
                if (value == 'leave') {
                  _confirmLeaveGroup(groupId, isCreator);
                } else if (value == 'delete') {
                  _confirmDeleteGroup(groupId);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'leave',
                  child: Text('Leave Group', style: TextStyle(color: Colors.white.withValues(alpha: 0.9))),
                ),
                if (isCreator)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete Group', style: TextStyle(color: Color(0xFFEF4444))),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCurrentGroupCard(String? selectedName) {
    final memberCount = _members.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Current group',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.groups_rounded, color: _accent, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedName ?? 'No group selected',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          memberCount == 1 ? '1 member' : '$memberCount members',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Connect with your crew and compete on daily steps. Create a group or join one with an invite code.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMembersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Members',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: _buildMembersChild(),
        ),
      ],
    );
  }

  /// Display name for a member: display_name ?? email ?? 'Member'.
  static String _memberDisplayName(Map<String, dynamic> member, {String? currentUserEmail, String? currentUserId}) {
    final displayName = (member['display_name'] as String?)?.trim();
    final email = (member['email'] as String?)?.trim();
    
    if (kDebugMode) {
      print('[GroupScreen] _memberDisplayName resolving for user_id=${member['user_id']} -> displayName:$displayName, email:$email');
    }

    if (displayName != null && displayName.isNotEmpty) return displayName;
    if (email != null && email.isNotEmpty) return email;
    
    if (currentUserId != null && member['user_id'] == currentUserId && currentUserEmail != null && currentUserEmail.isNotEmpty) {
      if (kDebugMode) print('[GroupScreen] _memberDisplayName using currentUserEmail fallback: $currentUserEmail');
      return currentUserEmail;
    }
    
    return 'Member';
  }

  Widget _buildMembersChild() {
    if (selectedGroupService.selectedGroupId == null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            'Select or create a group to see members.',
            style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.5)),
          ),
        ),
      );
    }
    if (_membersLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(color: _accent)),
      );
    }
    if (_membersError != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          _membersError!,
          style: const TextStyle(fontSize: 14, color: Color(0xFFEF4444)),
        ),
      );
    }
    if (_members.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            'No members yet.',
            style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.5)),
          ),
        ),
      );
    }
    final currentUser = Supabase.instance.client.auth.currentUser;
    final currentUserId = currentUser?.id;
    final currentUserEmail = currentUser?.email;
    return Column(
      children: [
        for (var i = 0; i < _members.length; i++) ...[
          _MemberRow(
            name: _memberDisplayName(_members[i], currentUserId: currentUserId, currentUserEmail: currentUserEmail),
            avatarUrl: _members[i]['avatar_url'] as String?,
            rank: i + 1,
            isYou: _members[i]['user_id'] == currentUserId,
          ),
          if (i < _members.length - 1)
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
        ],
      ],
    );
  }

  Widget _buildPendingInvitesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pending invites',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (final invite in _pendingInvites) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          invite.groupName != null
                              ? 'You were invited to join ${invite.groupName!}'
                              : 'You were invited to join a group',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _declineInvite(invite.id),
                        child: Text(
                          'Decline',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      FilledButton(
                        onPressed: () => _acceptInvite(invite.id),
                        style: FilledButton.styleFrom(
                          backgroundColor: _accent,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: const Text('Accept'),
                      ),
                    ],
                  ),
                ),
                if (invite != _pendingInvites.last)
                  Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInviteByEmailButton() {
    final hasGroup = selectedGroupService.selectedGroupId != null;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: hasGroup ? _showInviteByEmailDialog : null,
        icon: const Icon(Icons.email_outlined, size: 20),
        label: const Text('Invite by email'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _accent,
          side: BorderSide(color: _accent.withValues(alpha: 0.6)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Future<void> _showInviteByEmailDialog() async {
    final email = await _showEmailInputDialog();
    if (email == null || email.isEmpty) return;
    await _inviteByEmail(email);
  }

  Future<String?> _showEmailInputDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text(
          'Invite by email',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.95)),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: 'Email address',
            labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
            ),
          ),
          style: const TextStyle(color: Colors.white),
          onSubmitted: (_) => Navigator.of(context).pop(controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: _accent),
            child: const Text('Send invite'),
          ),
        ],
      ),
    );
  }

  Future<void> _inviteByEmail(String email) async {
    final user = Supabase.instance.client.auth.currentUser;
    final groupId = selectedGroupService.selectedGroupId;
    if (user == null || groupId == null) return;
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      _showSnackBar('Please enter an email address.', isError: true);
      return;
    }
    if (!trimmed.contains('@')) {
      _showSnackBar('Please enter a valid email address.', isError: true);
      return;
    }
    if (kDebugMode) {
      // ignore: avoid_print
      print('[GroupInvite] invite by email: user=${user.id}, groupId=$groupId, invitedEmail=$trimmed');
    }
    try {
      final record = await _inviteService.createInvite(
        groupId: groupId,
        invitedEmail: trimmed,
        invitedBy: user.id,
      );
      if (kDebugMode) {
        // ignore: avoid_print
        print('[GroupInvite] invite DB row created: id=${record.id}');
      }
      final emailSent = await _inviteService.sendInviteEmail(record.id);
      if (kDebugMode) {
        // ignore: avoid_print
        print('[GroupInvite] email send attempted: success=$emailSent');
      }
      if (!mounted) return;
      if (emailSent) {
        _showSnackBar('Invite sent to ${record.invitedEmail}.');
      } else {
        _showSnackBar(
          'Invite saved, but we couldn\'t send the email. They can still join using the group invite code.',
          isError: false,
        );
      }
    } on InviteAlreadyExists {
      if (mounted) _showSnackBar('An invite was already sent to this email.', isError: true);
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[GroupInvite] invite by email error: $e');
      }
      if (mounted) {
        _showSnackBar('Couldn\'t send invite. Try again.', isError: true);
      }
    }
  }

  Future<void> _acceptInvite(String inviteId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    if (kDebugMode) {
      // ignore: avoid_print
      print('[GroupInvite] acceptInvite: user=${user.id}, inviteId=$inviteId');
    }
    try {
      final result = await _inviteService.acceptInvite(inviteId, user.id);
      if (kDebugMode) {
        // ignore: avoid_print
        print('[GroupInvite] acceptInvite success: groupId=${result.groupId}, groupName=${result.groupName}');
      }
      if (!mounted) return;
      selectedGroupService.addGroupAndSelect(result.groupId, result.groupName);
      await _loadGroupsAndMembers();
      await _loadPendingInvites();
      if (!mounted) return;
      _showSnackBar('Joined ${result.groupName}!');
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[GroupInvite] acceptInvite error: $e');
      }
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      _showSnackBar(
        msg.contains('already') ? "You're already in this group." : 'Couldn\'t accept invite. Try again.',
        isError: true,
      );
    }
  }

  Future<void> _declineInvite(String inviteId) async {
    try {
      await _inviteService.declineInvite(inviteId);
      if (!mounted) return;
      await _loadPendingInvites();
      if (mounted) _showSnackBar('Invite declined.');
    } catch (_) {
      if (mounted) _showSnackBar('Couldn\'t decline. Try again.', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFEF4444) : _accent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildInviteCodeSection() {
    final code = _displayedInviteCode ?? selectedGroupService.selectedGroupInviteCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Invite Code',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      (code != null && code.isNotEmpty) ? code : '—',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: (code != null && code.isNotEmpty)
                            ? Colors.white.withValues(alpha: 0.95)
                            : Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Share this code or link with friends to join the group.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              if (code != null && code.isNotEmpty)
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invite code copied'),
                        backgroundColor: _accent,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  color: _accent,
                  style: IconButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.all(8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _shareInvite() async {
    final groupId = selectedGroupService.selectedGroupId;
    final name = selectedGroupService.selectedGroupName;
    if (groupId == null || name == null || name.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Select a group first.'),
            backgroundColor: Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    String? code = selectedGroupService.selectedGroupInviteCode;
    if (code == null || code.isEmpty) {
      code = await _groupService.getGroupInviteCode(groupId);
      if (code == null || code.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This group has no invite code. Try again later.'),
              backgroundColor: Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }
    
    final inviteLink = 'gotmotion://join/$code';
    final text = "Join my Got Motion group '$name' 💪\n\n"
        "Use invite code: $code\n\n"
        "Open this invite:\n$inviteLink";
    final subject = 'Join $name on Got Motion';
    
    if (kDebugMode) {
      // ignore: avoid_print
      print('[GroupInvite] generated invite link: $inviteLink');
    }

    try {
      await Share.share(
        text,
        subject: subject,
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invite link copied to clipboard.'),
            backgroundColor: _accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildShareInviteButton() {
    final hasGroup = selectedGroupService.selectedGroupId != null;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: hasGroup ? _shareInvite : null,
        icon: const Icon(Icons.share_rounded, size: 20),
        label: const Text('Share Invite Link'),
        style: FilledButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildJoinWithCodeButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _joinGroup,
        icon: const Icon(Icons.person_add_rounded, size: 20),
        label: const Text('Join with invite code'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _accent,
          side: BorderSide(color: _accent.withValues(alpha: 0.6)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildGroupStatsPlaceholder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Group stats / Challenge',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emoji_events_rounded, size: 24, color: Colors.white.withValues(alpha: 0.3)),
              const SizedBox(width: 10),
              Text(
                'Challenges and group stats coming soon',
                style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.4)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.name,
    required this.rank,
    this.avatarUrl,
    this.isYou = false,
  });

  final String name;
  final String? avatarUrl;
  final int rank;
  final bool isYou;

  static const Color _accent = Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isYou ? _accent : Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
                ? NetworkImage(avatarUrl!)
                : null,
            child: (avatarUrl == null || avatarUrl!.isEmpty)
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isYou ? FontWeight.w600 : FontWeight.w500,
                color: isYou ? Colors.white : Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
