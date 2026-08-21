import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/deep_link_handler.dart';
import '../services/goal_service.dart';
import '../services/group_invite_service.dart';
import '../services/group_service.dart';
import '../services/health_hub_service.dart';
import '../services/health_service.dart';
import '../services/main_nav_service.dart';
import '../services/push_prompt_service.dart';
import '../services/selected_group_service.dart';
import '../widgets/goal_complete_celebration.dart';
import '../widgets/health_connect_install_prompt.dart';
import '../widgets/push_enable_prompt.dart';
import 'group_screen.dart';
import 'home_screen.dart';
import 'leaderboard_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

/// Bottom navigation with 5 tabs: Home, Leaderboard, Profile, Group, Settings.
/// Default tab is Home. Checks for pending group invites on load and shows a modal.
class MainNav extends StatefulWidget {
  const MainNav({super.key});

  @override
  State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> with WidgetsBindingObserver {
  static const Color _background = Color(0xFF0B0B0F);
  static const Color _accent = Color(0xFF3B82F6);
  static const Color _cardBg = Color(0xFF14141A);

  int _currentIndex = 0;
  bool _pendingInvitesChecked = false;
  final GroupInviteService _inviteService = GroupInviteService();
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    mainNavService.bind(_selectTab);
    _pageController = PageController();
    // Belt-and-suspenders: AuthGate hydrates first, but if Home mounts before
    // that finishes, this shared future still fills selectedGroupService.
    unawaited(selectedGroupService.hydrate());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runStartupModals());
    });
    DeepLinkHandler.pendingInviteCode.addListener(_onPendingInviteCodeChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    mainNavService.unbind(_selectTab);
    DeepLinkHandler.pendingInviteCode.removeListener(
      _onPendingInviteCodeChanged,
    );
    _pageController.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPendingInviteCodeChanged() {
    if (DeepLinkHandler.pendingInviteCode.value != null) {
      unawaited(_checkPendingLink());
    }
  }

  /// Invite dialogs first, then Health Connect (Android), push, then goals.
  Future<void> _runStartupModals() async {
    await _checkPendingInvites();
    if (!mounted) return;
    await _checkPendingLink();
    if (!mounted) return;
    await _maybeShowHealthConnectPrompt();
    if (!mounted) return;
    await _maybeShowPushPrompt();
    if (!mounted) return;
    await _checkDailyGoalCelebration();
  }

  Future<void> _maybeShowHealthConnectPrompt() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || !mounted) return;
    if (!await healthHubService.shouldPromptInstall(userId)) return;
    final status = await healthHubService.status();
    if (!mounted) return;
    if (status == HealthHubStatus.ready) return;
    await showHealthConnectInstallPrompt(
      context,
      userId: userId,
      status: status,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkDailyGoalCelebration());
    }
  }

  Future<void> _checkDailyGoalCelebration() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || !mounted) return;
    try {
      goalService.reloadFromCurrentUser();
      final today = await HealthService.getTodayMetrics();
      if (!mounted) return;
      if (!GoalCelebrationService.allGoalsComplete(today, goalService.goals)) {
        return;
      }
      await goalCelebrationService.maybeCelebrate(
        context,
        userId: userId,
        onKeepMoving: mainNavService.goToProfile,
      );
    } catch (_) {}
  }

  Future<void> _maybeShowPushPrompt() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || !mounted) return;
    if (!await pushPromptService.shouldPrompt(userId)) return;
    if (!mounted) return;
    await showPushEnablePrompt(context, userId: userId);
  }

  Future<void> _checkPendingLink() async {
    final code = DeepLinkHandler.pendingInviteCode.value;
    if (code == null || code.isEmpty) return;

    // Clear it so we don't process it again (even if cancelled)
    DeepLinkHandler.pendingInviteCode.value = null;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    if (kDebugMode) {
      print('[MainNav] Resuming pending invite join flow for code: $code');
    }

    if (!mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text(
          'Join Group',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.95)),
        ),
        content: Text(
          'You have an invite link. Do you want to join this group?',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 15,
          ),
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
            style: FilledButton.styleFrom(backgroundColor: _accent),
            child: const Text('Join'),
          ),
        ],
      ),
    );

    if (accepted != true || !mounted) return;

    // Show a loading indicator while joining
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: _accent)),
    );

    try {
      final result = await GroupService().joinByInviteCode(user.id, code);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dismiss loading

      selectedGroupService.addGroupAndSelect(result.groupId, result.groupName);
      _selectTab(3);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Joined ${result.groupName}!'),
          backgroundColor: _accent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dismiss loading

      final msg = e
          .toString()
          .replaceFirst('Exception: ', '')
          .replaceFirst('AlreadyInGroup: ', '')
          .replaceFirst('GroupNotFound: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg.contains('already') ? "You're already in this group." : msg,
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _checkPendingInvites() async {
    if (_pendingInvitesChecked) return;
    final email = Supabase.instance.client.auth.currentUser?.email;
    if (email == null || email.isEmpty) {
      _pendingInvitesChecked = true;
      return;
    }
    _pendingInvitesChecked = true;
    try {
      final list = await _inviteService.fetchPendingInvitesForEmail(email);
      if (!mounted || list.isEmpty) return;
      await _showPendingInviteDialog(list);
    } catch (_) {}
  }

  Future<void> _showPendingInviteDialog(List<GroupInviteRecord> list) async {
    if (!mounted || list.isEmpty) return;
    final invite = list.first;
    final groupName = invite.groupName ?? 'a group';
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text(
          'Group invite',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.95)),
        ),
        content: Text(
          'You were invited to join $groupName.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 15,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Decline',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: _accent),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (accepted == true) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        try {
          final result = await _inviteService.acceptInvite(invite.id, user.id);
          if (!mounted) return;
          selectedGroupService.addGroupAndSelect(
            result.groupId,
            result.groupName,
          );
          _selectTab(3);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Joined ${result.groupName}!'),
              backgroundColor: _accent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e.toString().contains('already')
                    ? "You're already in this group."
                    : 'Couldn\'t accept. Try again.',
              ),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } else {
      try {
        await _inviteService.declineInvite(invite.id);
      } catch (_) {}
    }
    final remaining = list.skip(1).toList();
    if (remaining.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showPendingInviteDialog(remaining),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _KeepAlive(
        child: HomeScreen(
          isActive: _currentIndex == 0,
          onSeeAllLeaderboard: () => _selectTab(1),
          onOpenGroupTab: () => _selectTab(3),
        ),
      ),
      _KeepAlive(child: LeaderboardScreen(isActive: _currentIndex == 1)),
      const _KeepAlive(child: ProfileScreen()),
      const _KeepAlive(child: GroupScreen()),
      const _KeepAlive(child: SettingsScreen()),
    ];
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(color: _background),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  label: 'Home',
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home,
                  selected: _currentIndex == 0,
                  onTap: () => _selectTab(0),
                ),
                _NavItem(
                  label: 'Leaderboard',
                  icon: Icons.leaderboard_outlined,
                  selectedIcon: Icons.leaderboard,
                  selected: _currentIndex == 1,
                  onTap: () => _selectTab(1),
                ),
                _NavItem(
                  label: 'Profile',
                  icon: Icons.person_outline,
                  selectedIcon: Icons.person,
                  selected: _currentIndex == 2,
                  onTap: () => _selectTab(2),
                ),
                _NavItem(
                  label: 'Group',
                  icon: Icons.group_outlined,
                  selectedIcon: Icons.group,
                  selected: _currentIndex == 3,
                  onTap: () => _selectTab(3),
                ),
                _NavItem(
                  label: 'Settings',
                  icon: Icons.settings_outlined,
                  selectedIcon: Icons.settings,
                  selected: _currentIndex == 4,
                  onTap: () => _selectTab(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  static const Color _accent = Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: selected ? 1.12 : 1,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  selected ? selectedIcon : icon,
                  key: ValueKey(selected),
                  size: 24,
                  color: selected ? _accent : Colors.white54,
                ),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? _accent : Colors.white54,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
