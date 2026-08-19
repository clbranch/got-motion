import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/group_invite_service.dart';
import '../services/group_service.dart';
import '../services/selected_group_service.dart';
import '../services/weekly_group_awards_service.dart';
import '../models/weekly_group_award.dart';
import '../widgets/group_avatar.dart';
import '../widgets/weekly_award_celebration.dart';
import '../widgets/weekly_group_awards_card.dart';

/// Group screen: selected group, create/join actions, member list. Uses SelectedGroupService for app-wide selected group.
class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  static const Color _background = Color(0xFF07090D);
  static const Color _cardBg = Color(0xFF11151B);
  static const Color _accent = Color(0xFF168BFF);
  static const Color _pillBorder = Color(0xFF242B36);
  static const double _pagePadding = 20.0;

  final GroupService _groupService = GroupService();
  final GroupInviteService _inviteService = GroupInviteService();
  List<Map<String, dynamic>> _members = [];
  bool _membersLoading = false;
  String? _membersError;

  /// Invite code for the currently selected group; loaded when group changes.
  String? _displayedInviteCode;
  List<GroupInviteRecord> _pendingInvites = [];
  bool _changingPhoto = false;
  WeeklyGroupAwards? _weeklyAwards;
  bool _weeklyAwardsLoading = false;

  @override
  void initState() {
    super.initState();
    selectedGroupService.addListener(_onSelectedGroupChanged);
    _loadGroupsAndMembers();
    _loadPendingInvites();
    _loadWeeklyAwards();
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
      _loadWeeklyAwards();
    }
  }

  Future<void> _loadWeeklyAwards() async {
    final groupId = selectedGroupService.selectedGroupId;
    if (groupId == null) {
      if (mounted) setState(() => _weeklyAwards = null);
      return;
    }
    if (mounted) setState(() => _weeklyAwardsLoading = true);
    try {
      final awards = await weeklyGroupAwardsService.loadForGroup(groupId);
      if (!mounted) return;
      setState(() {
        _weeklyAwards = awards;
        _weeklyAwardsLoading = false;
      });
      _maybeCelebrateWeeklyAwards(groupId, awards);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _weeklyAwards = null;
        _weeklyAwardsLoading = false;
      });
    }
  }

  void _maybeCelebrateWeeklyAwards(String groupId, WeeklyGroupAwards? awards) {
    if (awards == null || awards.winners.isEmpty) return;
    if (!WeeklyGroupAwardsService.shouldShowWeeklyAwards()) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final groupName = selectedGroupService.selectedGroupName;
    if (userId == null || groupName == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      weeklyAwardCelebrationService.maybeCelebrate(
        context: context,
        userId: userId,
        groupId: groupId,
        groupName: groupName,
        awards: awards,
      );
    });
  }

  Future<void> _changeGroupPhoto() async {
    final groupId = selectedGroupService.selectedGroupId;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isAdmin =
        currentUserId != null &&
        currentUserId == selectedGroupService.selectedGroupCreatedBy;
    if (groupId == null || !isAdmin || _changingPhoto) return;

    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (image == null || !mounted) return;
    setState(() => _changingPhoto = true);
    try {
      final url = await _groupService.uploadGroupImage(
        groupId: groupId,
        file: File(image.path),
      );
      selectedGroupService.updateGroupImage(groupId, url);
      if (mounted) _showSnackBar('Group photo updated.');
    } catch (e, st) {
      // ignore: avoid_print
      print('[GroupScreen] changeGroupPhoto error: $e');
      // ignore: avoid_print
      print('[GroupScreen] changeGroupPhoto stackTrace: $st');
      if (mounted) {
        _showSnackBar(_photoErrorMessage(e), isError: true);
      }
    } finally {
      if (mounted) setState(() => _changingPhoto = false);
    }
  }

  String _photoErrorMessage(Object error) {
    final text = error.toString();
    if (text.contains('row-level security') || text.contains('Unauthorized')) {
      return 'Only the group admin can change this photo.';
    }
    if (text.contains('Bucket not found')) {
      return 'Group photo storage is not set up yet.';
    }
    if (text.contains('exceeded') ||
        text.contains('too large') ||
        text.contains('Broken pipe')) {
      return 'That image is too large. Pick a smaller one.';
    }
    if (text.contains('mime') || text.contains('content type')) {
      return 'That image format is not supported.';
    }
    if (text.contains('SocketException') || text.contains('ClientException')) {
      return 'Upload failed. Check your connection and try again.';
    }
    return 'Couldn’t update the group photo: $text';
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
    print(
      '[GroupScreen] _loadGroupsAndMembers: auth user id=${user?.id ?? "null"}',
    );
    if (user == null) {
      if (mounted) setState(() {});
      return;
    }
    try {
      final rows = await _groupService.fetchUserGroups(user.id);
      if (!mounted) return;
      selectedGroupService.setGroupsFromFetchRows(rows);
      setState(
        () =>
            _displayedInviteCode = selectedGroupService.selectedGroupInviteCode,
      );
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
    print(
      '[GroupScreen] createGroup: current auth user id=${user?.id ?? "null"}',
    );
    if (user == null) {
      if (mounted) {
        _showErrorSnackbar('You must be signed in to create a group.');
      }
      return;
    }
    final name = await _showCreateGroupDialog();
    if (name == null || name.isEmpty) return;
    try {
      final result = await _groupService.createGroup(user.id, name);
      if (!mounted) return;
      selectedGroupService.addGroupAndSelect(
        result.id,
        result.name,
        result.inviteCode,
      );
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
    print(
      '[GroupScreen] joinGroup: current auth user id=${user?.id ?? "null"}',
    );
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
    if (s.contains('unique') ||
        s.contains('duplicate') ||
        s.contains('already')) {
      return "You're already in this group.";
    }
    if (s.contains('invite') || s.contains('code')) {
      return 'Invalid invite code. Try again.';
    }
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
        duration: isDebugDetail
            ? const Duration(seconds: 8)
            : const Duration(seconds: 4),
      ),
    );
  }

  Future<String?> _showCreateGroupDialog() async {
    return _showGroupInputSheet(
      icon: Icons.group_add_rounded,
      title: 'Create a group',
      subtitle: 'Start a new crew and invite friends to compete.',
      label: 'Group name',
      hint: 'e.g. Morning Movers',
      actionLabel: 'Create group',
    );
  }

  Future<void> _showInviteCodeDialog(String code, String groupName) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text(
          'Group created',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.95)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Share this code so others can join "$groupName":',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
              ),
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
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.5),
              ),
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
    return _showGroupInputSheet(
      icon: Icons.login_rounded,
      title: 'Join a group',
      subtitle: 'Enter the six-character code shared by a group member.',
      label: 'Invite code',
      hint: 'ABC123',
      actionLabel: 'Join group',
      textCapitalization: TextCapitalization.characters,
      letterSpacing: 3,
    );
  }

  Future<String?> _showGroupInputSheet({
    required IconData icon,
    required String title,
    required String subtitle,
    required String label,
    required String hint,
    required String actionLabel,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    double letterSpacing = 0,
  }) async {
    final controller = TextEditingController();
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardBg,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF142D4D),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: const Color(0xFF5BA9FF)),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF8D96A8),
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: keyboardType,
                  textCapitalization: textCapitalization,
                  autocorrect: false,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    letterSpacing: letterSpacing,
                  ),
                  decoration: InputDecoration(
                    labelText: label,
                    hintText: hint,
                    filled: true,
                    fillColor: const Color(0xFF0D1117),
                    labelStyle: const TextStyle(color: Color(0xFF8D96A8)),
                    hintStyle: const TextStyle(color: Color(0xFF596170)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF2A3340)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _accent, width: 1.5),
                    ),
                  ),
                  onSubmitted: (_) =>
                      Navigator.of(sheetContext).pop(controller.text.trim()),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFA7AFBD),
                          side: const BorderSide(color: Color(0xFF2A3340)),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: () => Navigator.of(
                          sheetContext,
                        ).pop(controller.text.trim()),
                        style: FilledButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(actionLabel),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final groups = selectedGroupService.groupNames;
    final selectedName = selectedGroupService.selectedGroupName;

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            _pagePadding,
            16,
            _pagePadding,
            24,
          ),
          children: [
            _buildHeader(),
            const SizedBox(height: 18),
            _buildGroupControlRow(groups, selectedName),
            if (_pendingInvites.isNotEmpty) ...[
              const SizedBox(height: 18),
              _buildPendingInvitesSection(),
            ],
            const SizedBox(height: 18),
            _buildCurrentGroupCard(selectedName),
            const SizedBox(height: 14),
            _buildQuickActions(),
            const SizedBox(height: 24),
            _buildWeeklyAwardsSection(),
            const SizedBox(height: 24),
            _buildMembersSection(),
            const SizedBox(height: 20),
            _buildInviteCodeSection(),
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
    final isCreator = user != null && createdBy == user.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'Group actions',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: const Color(0xFFEF4444).withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 10),
        if (!isCreator)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _confirmLeaveGroup(groupId, false),
              icon: const Icon(Icons.exit_to_app_rounded, size: 20),
              label: const Text('Leave group'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                side: BorderSide(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        if (isCreator) ...[
          if (_members.length > 1) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showTransferAdminSheet(groupId),
                icon: const Icon(Icons.manage_accounts_rounded, size: 20),
                label: const Text('Transfer admin & leave'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF5BA9FF),
                  side: const BorderSide(color: Color(0xFF275E96)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _confirmDeleteGroup(groupId),
              icon: const Icon(Icons.delete_forever_rounded, size: 20),
              label: const Text('Delete group'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(
                  0xFFEF4444,
                ).withValues(alpha: 0.15),
                foregroundColor: const Color(0xFFEF4444),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _showTransferAdminSheet(String groupId) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;
    final candidates = _members
        .where((member) => member['user_id'] != currentUser.id)
        .toList();
    if (candidates.isEmpty) {
      _showSnackBar(
        'Add another member before transferring admin.',
        isError: true,
      );
      return;
    }

    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: _cardBg,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF102A45),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.manage_accounts_rounded,
                  color: Color(0xFF5BA9FF),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Choose the next admin',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'They will manage members and the group after you leave.',
                style: TextStyle(
                  color: Color(0xFF8D96A8),
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: Color(0xFF242B36)),
                  itemBuilder: (context, index) {
                    final member = candidates[index];
                    final name = _memberDisplayName(member);
                    final avatarUrl = member['avatar_url'] as String?;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 6,
                      ),
                      leading: CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFF22314A),
                        backgroundImage:
                            avatarUrl != null && avatarUrl.isNotEmpty
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl == null || avatarUrl.isEmpty
                            ? Text(
                                name.isEmpty ? '?' : name[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : null,
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: const Text(
                        'Make admin and leave group',
                        style: TextStyle(color: Color(0xFF8D96A8)),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF5BA9FF),
                      ),
                      onTap: () => Navigator.of(sheetContext).pop(member),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;

    final newOwnerId = selected['user_id'] as String?;
    if (newOwnerId == null) return;
    final name = _memberDisplayName(selected);
    try {
      await _groupService.transferOwnershipAndLeave(
        groupId: groupId,
        newOwnerId: newOwnerId,
      );
      if (!mounted) return;
      selectedGroupService.removeGroup(groupId);
      await _loadGroupsAndMembers();
      if (mounted) _showSnackBar('$name is now the group admin.');
    } catch (_) {
      if (mounted) {
        _showSnackBar('Couldn\'t transfer admin. Try again.', isError: true);
      }
    }
  }

  Future<void> _confirmLeaveGroup(String groupId, bool isCreator) async {
    if (isCreator && _members.length > 1) {
      _showSnackBar(
        'The group creator must delete the group or transfer ownership before leaving.',
        isError: true,
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text(
          'Leave group?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.95)),
        ),
        content: Text(
          'Are you sure you want to leave this group? You will no longer participate in its leaderboards.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
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
      if (mounted) {
        _showSnackBar('Failed to leave group. Try again.', isError: true);
      }
    }
  }

  Future<void> _confirmDeleteGroup(String groupId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text(
          'Delete group?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.95)),
        ),
        content: Text(
          'This permanently deletes the group and removes all ${_members.length} members. This action cannot be undone.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
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
      if (mounted) {
        _showSnackBar('Failed to delete group. Try again.', isError: true);
      }
    }
  }

  Future<void> _confirmRemoveMember({
    required String groupId,
    required String userId,
    required String name,
  }) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: _cardBg,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF3A171C),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.person_remove_rounded,
                  color: Color(0xFFFF5A63),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Remove member?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$name will be removed from this group and its leaderboard.',
                style: const TextStyle(
                  color: Color(0xFF8D96A8),
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFA7AFBD),
                        side: const BorderSide(color: Color(0xFF2A3340)),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Remove'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) return;

    try {
      await _groupService.removeMember(userId, groupId);
      await _loadMembers();
      if (mounted) _showSnackBar('$name was removed from the group.');
    } catch (_) {
      if (mounted) {
        _showSnackBar(
          'Couldn\'t remove this member. Try again.',
          isError: true,
        );
      }
    }
  }

  Widget _buildHeader() {
    return const Text(
      'Group',
      style: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
    );
  }

  Widget _buildQuickActions() {
    final hasGroup = selectedGroupService.selectedGroupId != null;
    return Row(
      children: [
        Expanded(
          child: _GroupAction(
            icon: Icons.ios_share_rounded,
            label: 'Share',
            onTap: hasGroup ? _shareInvite : null,
            isPrimary: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _GroupAction(
            icon: Icons.alternate_email_rounded,
            label: 'Email',
            onTap: hasGroup ? _showInviteByEmailDialog : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _GroupAction(
            icon: Icons.login_rounded,
            label: 'Join',
            onTap: _joinGroup,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _GroupAction(
            icon: Icons.add_rounded,
            label: 'Create',
            onTap: _createGroup,
          ),
        ),
      ],
    );
  }

  Widget _buildGroupControlRow(List<String> groups, String? selectedName) {
    final hasGroup = selectedName?.isNotEmpty == true;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isAdmin =
        hasGroup &&
        currentUserId != null &&
        currentUserId == selectedGroupService.selectedGroupCreatedBy;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _pillBorder),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: hasGroup && isAdmin
                ? _changeGroupPhoto
                : () => _showGroupPicker(groups, selectedName),
            child: GroupAvatar(
              name: selectedName,
              size: 48,
              showEditBadge: isAdmin,
              loading: _changingPhoto,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: InkWell(
              onTap: () => _showGroupPicker(groups, selectedName),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasGroup ? selectedName! : 'Choose a group',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasGroup
                              ? '${_members.length} ${_members.length == 1 ? 'member' : 'members'}'
                              : 'Create or join to get started',
                          style: const TextStyle(
                            color: Color(0xFF8D96A8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF14233B),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.unfold_more_rounded,
                      color: Color(0xFF5BA9FF),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showGroupPicker(
    List<String> groups,
    String? selectedName,
  ) async {
    if (groups.isEmpty) {
      await _createGroup();
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _cardBg,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose a group',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Switch the group shown across Got Motion.',
                style: TextStyle(color: Color(0xFF8590A2), fontSize: 13),
              ),
              const SizedBox(height: 18),
              ...groups.map((group) {
                final active = group == selectedName;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      if (!active) selectedGroupService.setSelectedGroup(group);
                    },
                    tileColor: active
                        ? const Color(0xFF102A4B)
                        : const Color(0xFF151A22),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: active
                            ? const Color(0xFF276EBA)
                            : const Color(0xFF242B36),
                      ),
                    ),
                    leading: GroupAvatar(name: group, size: 42),
                    title: Text(
                      group,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    trailing: active
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF45A4FF),
                          )
                        : null,
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentGroupCard(String? selectedName) {
    final memberCount = _members.length;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isAdmin =
        currentUserId != null &&
        currentUserId == selectedGroupService.selectedGroupCreatedBy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your crew',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF102A4B), Color(0xFF0B1C32)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF276EBA)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: isAdmin ? _changeGroupPhoto : null,
                    child: GroupAvatar(
                      name: selectedName,
                      size: 44,
                      showEditBadge: isAdmin,
                      loading: _changingPhoto,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                selectedName ?? 'No group selected',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.95),
                                ),
                              ),
                            ),
                            if (isAdmin) ...[
                              const SizedBox(width: 8),
                              const _AdminBadge(),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          memberCount == 1
                              ? '1 member'
                              : '$memberCount members',
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
                selectedName == null
                    ? 'Create a group or join one with an invite code.'
                    : 'Invite friends, manage your crew, and keep the competition moving.',
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

  Widget _buildWeeklyAwardsSection() {
    if (selectedGroupService.selectedGroupId == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_weeklyAwardsLoading)
          Container(
            height: 160,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _pillBorder),
            ),
            child: const CircularProgressIndicator(color: _accent),
          )
        else if (_weeklyAwards != null)
          WeeklyGroupAwardsCard(
            awards: _weeklyAwards!,
            currentUserId: Supabase.instance.client.auth.currentUser?.id,
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
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _pillBorder),
          ),
          child: _buildMembersChild(),
        ),
      ],
    );
  }

  /// Display name for a member: display_name ?? email ?? 'Member'.
  static String _memberDisplayName(
    Map<String, dynamic> member, {
    String? currentUserEmail,
    String? currentUserId,
  }) {
    final displayName = (member['display_name'] as String?)?.trim();
    final email = (member['email'] as String?)?.trim();

    if (kDebugMode) {
      print(
        '[GroupScreen] _memberDisplayName resolving for user_id=${member['user_id']} -> displayName:$displayName, email:$email',
      );
    }

    if (displayName != null && displayName.isNotEmpty) return displayName;
    if (email != null && email.isNotEmpty) return email;

    if (currentUserId != null &&
        member['user_id'] == currentUserId &&
        currentUserEmail != null &&
        currentUserEmail.isNotEmpty) {
      if (kDebugMode) {
        print(
          '[GroupScreen] _memberDisplayName using currentUserEmail fallback: $currentUserEmail',
        );
      }
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
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.5),
            ),
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
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }
    final currentUser = Supabase.instance.client.auth.currentUser;
    final currentUserId = currentUser?.id;
    final currentUserEmail = currentUser?.email;
    final groupId = selectedGroupService.selectedGroupId;
    final createdBy = selectedGroupService.selectedGroupCreatedBy;
    final canManageMembers =
        currentUserId != null && currentUserId == createdBy;
    return Column(
      children: [
        for (var i = 0; i < _members.length; i++) ...[
          _MemberRow(
            name: _memberDisplayName(
              _members[i],
              currentUserId: currentUserId,
              currentUserEmail: currentUserEmail,
            ),
            avatarUrl: _members[i]['avatar_url'] as String?,
            rank: i + 1,
            isYou: _members[i]['user_id'] == currentUserId,
            isAdmin: _members[i]['user_id'] == createdBy,
            onRemove:
                canManageMembers &&
                    groupId != null &&
                    _members[i]['user_id'] != currentUserId
                ? () => _confirmRemoveMember(
                    groupId: groupId,
                    userId: _members[i]['user_id'] as String,
                    name: _memberDisplayName(
                      _members[i],
                      currentUserId: currentUserId,
                      currentUserEmail: currentUserEmail,
                    ),
                  )
                : null,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
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
                  Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showInviteByEmailDialog() async {
    final email = await _showEmailInputDialog();
    if (email == null || email.isEmpty) return;
    await _inviteByEmail(email);
  }

  Future<String?> _showEmailInputDialog() async {
    return _showGroupInputSheet(
      icon: Icons.alternate_email_rounded,
      title: 'Invite by email',
      subtitle: 'We’ll send an invitation to join your selected group.',
      label: 'Email address',
      hint: 'friend@example.com',
      actionLabel: 'Send invite',
      keyboardType: TextInputType.emailAddress,
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
      print(
        '[GroupInvite] invite by email: user=${user.id}, groupId=$groupId, invitedEmail=$trimmed',
      );
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
      if (mounted) {
        _showSnackBar(
          'An invite was already sent to this email.',
          isError: true,
        );
      }
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
        print(
          '[GroupInvite] acceptInvite success: groupId=${result.groupId}, groupName=${result.groupName}',
        );
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
        msg.contains('already')
            ? "You're already in this group."
            : 'Couldn\'t accept invite. Try again.',
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
      if (mounted) {
        _showSnackBar('Couldn\'t decline. Try again.', isError: true);
      }
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
    final code =
        _displayedInviteCode ?? selectedGroupService.selectedGroupInviteCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Invite code',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _pillBorder),
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
    final text =
        "Join my Got Motion group '$name' 💪\n\n"
        "Use invite code: $code\n\n"
        "Open this invite:\n$inviteLink";
    final subject = 'Join $name on Got Motion';

    if (kDebugMode) {
      // ignore: avoid_print
      print('[GroupInvite] generated invite link: $inviteLink');
    }

    try {
      final shareOrigin = _nativeShareOrigin();
      await Share.share(
        text,
        subject: subject,
        sharePositionOrigin: shareOrigin,
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

  Rect _nativeShareOrigin() {
    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      final center = renderObject.localToGlobal(
        renderObject.size.center(Offset.zero),
      );
      return Rect.fromCenter(center: center, width: 1, height: 1);
    }
    return const Rect.fromLTWH(1, 1, 1, 1);
  }
}

class _GroupAction extends StatelessWidget {
  const _GroupAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final foreground = enabled
        ? (isPrimary ? Colors.white : const Color(0xFF5BA9FF))
        : const Color(0xFF596170);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 74,
        decoration: BoxDecoration(
          color: isPrimary ? const Color(0xFF1676D2) : const Color(0xFF11151B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isPrimary
                ? const Color(0xFF2B94F3)
                : const Color(0xFF242B36),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: foreground, size: 22),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.name,
    required this.rank,
    this.avatarUrl,
    this.isYou = false,
    this.isAdmin = false,
    this.onRemove,
  });

  final String name;
  final String? avatarUrl;
  final int rank;
  final bool isYou;
  final bool isAdmin;
  final VoidCallback? onRemove;

  static const Color _accent = Color(0xFF168BFF);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
            radius: 20,
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
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isYou ? FontWeight.w700 : FontWeight.w600,
                      color: isYou
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.86),
                    ),
                  ),
                ),
                if (isYou) ...[
                  const SizedBox(width: 8),
                  const Text(
                    'YOU',
                    style: TextStyle(
                      color: _accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
                if (isAdmin) ...[const SizedBox(width: 8), const _AdminBadge()],
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              tooltip: 'Remove member',
              icon: const Icon(Icons.person_remove_outlined, size: 20),
              color: const Color(0xFFFF5A63),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF2A151A),
                minimumSize: const Size(38, 38),
              ),
            ),
        ],
      ),
    );
  }
}

class _AdminBadge extends StatelessWidget {
  const _AdminBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF243A17),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF5B8E2F)),
      ),
      child: const Text(
        'ADMIN',
        style: TextStyle(
          color: Color(0xFF9AD65E),
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
