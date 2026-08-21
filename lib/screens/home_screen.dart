import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/motion_stats.dart';
import '../models/today_metrics.dart';
import '../services/daily_steps_service.dart';
import '../services/goal_service.dart';
import '../services/main_nav_service.dart';
import '../services/group_invite_service.dart';
import '../services/group_service.dart';
import '../services/health_service.dart';
import '../services/leaderboard_service.dart';
import '../services/profile_service.dart';
import '../services/notification_service.dart';
import '../services/selected_group_service.dart';
import '../services/sync_activity_service.dart';
import '../services/workout_log_service.dart';
import '../screens/notification_center_screen.dart';
import '../widgets/footsteps_icon.dart';
import '../widgets/goal_complete_celebration.dart';
import '../widgets/group_avatar.dart';
import '../widgets/workout_log_entry.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.isActive = true,
    this.onSeeAllLeaderboard,
    this.onOpenGroupTab,
  });

  /// True when this tab is visible in the bottom nav.
  final bool isActive;
  final VoidCallback? onSeeAllLeaderboard;
  final VoidCallback? onOpenGroupTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const _background = Color(0xFF07090D);
  static const _accent = Color(0xFF168BFF);

  TodayMetrics _today = TodayMetrics.zero;
  int _weekTotal = 0;
  List<int> _week = List.filled(7, 0);
  List<MotionStats> _leaders = [];
  int? _rank;
  double? _standHours;
  int _selectedDay = DateTime.now().weekday - 1;
  String _leaderboardMetric = 'Steps';
  bool _loading = true;
  ActiveWorkoutSession? _activeWorkout;

  final _dailySteps = DailyStepsService();
  final _leaderboard = LeaderboardService();
  final _groupService = GroupService();
  final _inviteService = GroupInviteService();

  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    selectedGroupService.addListener(_groupChanged);
    goalService.addListener(_goalsChanged);
    notificationService.addListener(_notificationsChanged);
    goalService.reloadFromCurrentUser();
    syncActivityService.hydrate();
    notificationService.refresh();
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    selectedGroupService.removeListener(_groupChanged);
    goalService.removeListener(_goalsChanged);
    notificationService.removeListener(_notificationsChanged);
    super.dispose();
  }

  void _groupChanged() {
    if (mounted) _load();
  }

  void _goalsChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _notificationsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.isActive) {
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    await selectedGroupService.hydrate();
    if (!mounted || generation != _loadGeneration) return;

    final values = await Future.wait<dynamic>([
      HealthService.getTodayMetrics(),
      HealthService.getWeekStepsTotal(),
      HealthService.getWeekStepsByDay(),
      HealthService.getTodayStandHours(),
    ]);
    if (!mounted || generation != _loadGeneration) return;

    final today = values[0] as TodayMetrics;
    final leaders = await _fetchLeaders(today);
    if (!mounted || generation != _loadGeneration) return;
    final active = await workoutLogService.getActiveSession();
    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      _today = today;
      _weekTotal = values[1] as int;
      _week = values[2] as List<int>;
      _standHours = values[3] as double?;
      _leaders = leaders;
      _rank = _findRank(leaders);
      _activeWorkout = active;
      _loading = false;
    });
    _sync(today);
    _maybeCelebrateGoals(today);
  }

  Future<void> _resumeActiveWorkout() async {
    await openWorkoutLogFlow(context);
    if (mounted) _load();
  }

  void _maybeCelebrateGoals(TodayMetrics today) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    if (!GoalCelebrationService.allGoalsComplete(today, goalService.goals)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      goalCelebrationService.maybeCelebrate(
        context,
        userId: userId,
        onKeepMoving: mainNavService.goToProfile,
      );
    });
  }

  int? _findRank(List<MotionStats> leaders) {
    final index = leaders.indexWhere((entry) => entry.name == 'You');
    return index < 0 ? null : index + 1;
  }

  DateTime get _selectedDate {
    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    return monday.add(Duration(days: _selectedDay));
  }

  bool get _isToday => _selectedDay == DateTime.now().weekday - 1;

  Future<List<MotionStats>> _fetchLeaders(
    TodayMetrics today, {
    DateTime? date,
  }) async {
    final groupId = selectedGroupService.selectedGroupId;
    if (groupId == null) return [];
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final rows = await _leaderboard.fetchGroupLeaderboard(
        groupId,
        date: date,
      );
      String? myAvatar;
      final others = <MotionStats>[];
      for (final row in rows) {
        final isMe = LeaderboardService.isCurrentUserRow(
          row,
          userId: user?.id,
          email: user?.email?.toLowerCase(),
        );
        if (isMe) {
          final url = row['avatar_url']?.toString();
          if (url != null && url.isNotEmpty) myAvatar = url;
          continue;
        }
        others.add(
          MotionStats(
            name: LeaderboardService.resolveDisplayName(row),
            steps: (row['total_steps'] as num?)?.toInt() ?? 0,
            miles: (row['total_miles'] as num?)?.toDouble() ?? 0,
            activeCalories:
                (row['total_active_calories'] as num?)?.toInt() ?? 0,
            exerciseMinutes:
                (row['total_exercise_minutes'] as num?)?.toInt() ?? 0,
            avatarUrl: row['avatar_url']?.toString(),
            previousRank: null,
          ),
        );
      }
      if (myAvatar == null || myAvatar.isEmpty) {
        final profile = await ProfileService().getCurrentProfile();
        myAvatar = profile?.avatarUrl ?? profile?.googleAvatarUrl;
      }
      final me = MotionStats(
        name: 'You',
        steps: today.steps,
        miles: today.distanceMiles,
        activeCalories: today.activeEnergyCalories.round(),
        exerciseMinutes: today.exerciseMinutes.round(),
        avatarUrl: myAvatar,
        previousRank: null,
        isCurrentUser: true,
      );
      return [me, ...others]..sort((a, b) => b.steps.compareTo(a.steps));
    } catch (_) {
      return [];
    }
  }

  Future<void> _selectDay(int index) async {
    final todayIndex = DateTime.now().weekday - 1;
    if (index > todayIndex || index == _selectedDay) return;
    setState(() {
      _selectedDay = index;
      _loading = true;
    });
    final date = _selectedDate;
    final values = await Future.wait<dynamic>([
      HealthService.getMetricsForDay(date),
      HealthService.getStandHoursForDay(date),
    ]);
    final metrics = values[0] as TodayMetrics;
    final leaders = await _fetchLeaders(metrics, date: date);
    if (!mounted) return;
    setState(() {
      _today = metrics;
      _standHours = values[1] as double?;
      _leaders = leaders;
      _rank = _findRank(leaders);
      _loading = false;
    });
  }

  Future<void> _sync(TodayMetrics today) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      await _dailySteps.upsertDailySteps(
        userId: user.id,
        date: DateTime.now(),
        steps: today.steps,
        miles: today.distanceMiles,
        activeCalories: today.activeEnergyCalories.round(),
        exerciseMinutes: today.exerciseMinutes.round(),
      );
      await syncActivityService.markHealthSynced();
      Future(() => _dailySteps.syncHistoryToDate(user.id));
      final leaders = await _fetchLeaders(today);
      if (mounted) {
        setState(() {
          _leaders = leaders;
          _rank = _findRank(leaders);
        });
      }
    } catch (error) {
      if (kDebugMode) debugPrint('[Home] Daily sync failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final goals = goalService.goals;
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _accent))
            : RefreshIndicator(
                color: _accent,
                backgroundColor: const Color(0xFF141820),
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  children: [
                    _Header(
                      groups: selectedGroupService.groupNames,
                      groupName: selectedGroupService.selectedGroupName,
                      onGroupSelected: selectedGroupService.setSelectedGroup,
                      onManageGroup: widget.onOpenGroupTab,
                      onNotifications: _showNotifications,
                      unreadNotifications: notificationService.unreadCount,
                      onInvitePeople: _showInviteMembers,
                    ),
                    const SizedBox(height: 18),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.03, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: Column(
                        key: ValueKey(_selectedDay),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _GoalHero(
                            steps: _today.steps,
                            goal: goals.steps,
                            rank: _rank,
                            leaderSteps: _leaders.isEmpty
                                ? null
                                : _leaders.first.steps,
                            hasGroup:
                                selectedGroupService.selectedGroupId != null,
                            onGroupTap: widget.onOpenGroupTab,
                            dayLabel: _isToday
                                ? "Today's"
                                : "${_weekday(_selectedDay)}'s",
                          ),
                          if (_activeWorkout != null) ...[
                            const SizedBox(height: 12),
                            ActiveWorkoutHomeBanner(onTap: _resumeActiveWorkout),
                          ],
                          const SizedBox(height: 24),
                          _Title(_isToday ? 'Today' : _weekday(_selectedDay)),
                          const SizedBox(height: 12),
                          _MetricGrid(metrics: _today, goals: goals),
                          const SizedBox(height: 12),
                          _ActivityStrip(
                            calories: _today.activeEnergyCalories,
                            exercise: _today.exerciseMinutes,
                            stand: _standHours,
                            calorieGoal: goals.activeCalories.toDouble(),
                            exerciseGoal: goals.exerciseMinutes.toDouble(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _WeeklyCard(
                      total: _weekTotal,
                      values: _week,
                      selected: _selectedDay,
                      onSelect: _selectDay,
                    ),
                    const SizedBox(height: 16),
                    _LeaderboardCard(
                      entries: _leaders,
                      metric: _leaderboardMetric,
                      hasGroup: selectedGroupService.selectedGroupId != null,
                      onSeeAll: widget.onSeeAllLeaderboard,
                      onGroupTap: widget.onOpenGroupTab,
                      onMetricSelected: (metric) {
                        setState(() => _leaderboardMetric = metric);
                      },
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  void _showNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NotificationCenterScreen()),
    );
  }

  Future<void> _showInviteMembers() async {
    final groupId = selectedGroupService.selectedGroupId;
    final groupName = selectedGroupService.selectedGroupName;
    if (groupId == null || groupName == null || groupName.isEmpty) {
      widget.onOpenGroupTab?.call();
      return;
    }

    var code = selectedGroupService.selectedGroupInviteCode;
    code ??= await _groupService.getGroupInviteCode(groupId);
    if (!mounted) return;
    if (code == null || code.isEmpty) {
      _showInviteMessage(
        'This group does not have an invite code yet.',
        isError: true,
      );
      return;
    }

    final inviteCode = code;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF11151B),
      showDragHandle: true,
      isScrollControlled: true,
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
              const Row(
                children: [
                  Icon(
                    Icons.person_add_alt_1_rounded,
                    color: Color(0xFF45A4FF),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Invite members',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Bring someone into $groupName.',
                style: const TextStyle(color: Color(0xFF8590A2), fontSize: 13),
              ),
              const SizedBox(height: 18),
              _InviteAction(
                icon: Icons.ios_share_rounded,
                title: 'Share invite link',
                subtitle: 'Send through Messages, Mail, or another app',
                isPrimary: true,
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await Future<void>.delayed(const Duration(milliseconds: 400));
                  if (mounted) {
                    await _shareInvite(
                      groupName,
                      inviteCode,
                      _nativeShareOrigin(),
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
              _InviteAction(
                icon: Icons.alternate_email_rounded,
                title: 'Invite by email',
                subtitle: 'Send an invitation directly',
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await Future<void>.delayed(const Duration(milliseconds: 400));
                  if (mounted) await _showInviteByEmailDialog();
                },
              ),
              const SizedBox(height: 8),
              _InviteAction(
                icon: Icons.copy_rounded,
                title: 'Copy invite code',
                subtitle: inviteCode,
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: inviteCode));
                  if (!sheetContext.mounted) return;
                  Navigator.of(sheetContext).pop();
                  _showInviteMessage('Invite code copied.');
                },
              ),
              const SizedBox(height: 8),
              _InviteAction(
                icon: Icons.groups_2_outlined,
                title: 'Manage group',
                subtitle: 'View members and group settings',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  widget.onOpenGroupTab?.call();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Rect _nativeShareOrigin() {
    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      final center = renderObject.localToGlobal(
        renderObject.size.center(Offset.zero),
      );
      return Rect.fromCenter(center: center, width: 1, height: 1);
    }
    final size = MediaQuery.sizeOf(context);
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: 1,
      height: 1,
    );
  }

  Future<void> _shareInvite(
    String groupName,
    String code,
    Rect shareOrigin,
  ) async {
    final inviteLink = 'gotmotion://join/$code';
    final text =
        "Join my Got Motion group '$groupName'.\n\n"
        'Use invite code: $code\n\n'
        'Open this invite:\n$inviteLink';
    try {
      await Share.share(
        text,
        subject: 'Join $groupName on Got Motion',
        sharePositionOrigin: shareOrigin,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[HomeInvite] Native share sheet failed: $error');
      }
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) _showInviteMessage('Invite link copied.');
    }
  }

  Future<void> _showInviteByEmailDialog() async {
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF141820),
        title: const Text(
          'Invite by email',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Email address',
            labelStyle: TextStyle(color: Color(0xFF8D96A8)),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF343C49)),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: _accent),
            ),
          ),
          onSubmitted: (_) =>
              Navigator.of(dialogContext).pop(controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Send invite'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (email == null || email.isEmpty) return;
    await _inviteByEmail(email);
  }

  Future<void> _inviteByEmail(String email) async {
    final user = Supabase.instance.client.auth.currentUser;
    final groupId = selectedGroupService.selectedGroupId;
    final trimmed = email.trim().toLowerCase();
    if (user == null || groupId == null) return;
    if (!trimmed.contains('@')) {
      _showInviteMessage('Enter a valid email address.', isError: true);
      return;
    }
    try {
      final record = await _inviteService.createInvite(
        groupId: groupId,
        invitedEmail: trimmed,
        invitedBy: user.id,
      );
      final sent = await _inviteService.sendInviteEmail(record.id);
      if (!mounted) return;
      _showInviteMessage(
        sent
            ? 'Invite sent to ${record.invitedEmail}.'
            : 'Invite saved. Share the group code if the email does not arrive.',
      );
    } on InviteAlreadyExists {
      if (mounted) {
        _showInviteMessage(
          'An invite was already sent to this email.',
          isError: true,
        );
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[HomeInvite] Email invite failed: $error');
      }
      if (mounted) {
        _showInviteMessage(
          'Could not send the invite. Try again.',
          isError: true,
        );
      }
    }
  }

  void _showInviteMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFEF4444) : _accent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _InviteAction extends StatelessWidget {
  const _InviteAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isPrimary = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isPrimary ? const Color(0xFF102A4B) : const Color(0xFF151A22),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isPrimary
                ? const Color(0xFF276EBA)
                : const Color(0xFF242B36),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isPrimary
                  ? const Color(0xFF45A4FF)
                  : const Color(0xFF9BA5B7),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF8590A2),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF667184)),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.groups,
    required this.groupName,
    required this.onGroupSelected,
    required this.onManageGroup,
    required this.onNotifications,
    this.unreadNotifications = 0,
    required this.onInvitePeople,
  });
  final List<String> groups;
  final String? groupName;
  final ValueChanged<String> onGroupSelected;
  final VoidCallback? onManageGroup;
  final VoidCallback onNotifications;
  final int unreadNotifications;
  final VoidCallback onInvitePeople;

  Future<void> _showGroupPicker(BuildContext context) async {
    if (groups.isEmpty) {
      onManageGroup?.call();
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF11151B),
      showDragHandle: true,
      isScrollControlled: true,
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
                'Switch the competition shown on your dashboard.',
                style: TextStyle(color: Color(0xFF8590A2), fontSize: 13),
              ),
              const SizedBox(height: 18),
              ...groups.map((group) {
                final active = group == groupName;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      if (!active) onGroupSelected(group);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xFF102A4B)
                            : const Color(0xFF151A22),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: active
                              ? const Color(0xFF276EBA)
                              : const Color(0xFF242B36),
                        ),
                      ),
                      child: Row(
                        children: [
                          GroupAvatar(name: group, size: 42),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              group,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (active)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF45A4FF),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasGroup = groupName?.isNotEmpty == true;
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _showGroupPicker(context),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  GroupAvatar(name: groupName, size: 46),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                hasGroup ? groupName! : 'Choose a group',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Color(0xFF5BA9FF),
                            ),
                          ],
                        ),
                        Text(
                          hasGroup
                              ? 'Your active competition'
                              : 'Create or join to compete',
                          style: const TextStyle(
                            color: Color(0xFF8D96A8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton.filled(
              onPressed: onNotifications,
              tooltip: 'Notifications',
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF11151D),
                foregroundColor: unreadNotifications > 0
                    ? const Color(0xFF45A4FF)
                    : const Color(0xFF9BA5B7),
                fixedSize: const Size(44, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFF242A35)),
                ),
              ),
              icon: Icon(
                unreadNotifications > 0
                    ? Icons.notifications_rounded
                    : Icons.notifications_none_rounded,
              ),
            ),
            if (unreadNotifications > 0)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF238BFF),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: const Color(0xFF07090D),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    unreadNotifications > 9 ? '9+' : '$unreadNotifications',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: onInvitePeople,
          tooltip: 'Add people',
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF11151D),
            foregroundColor: const Color(0xFF9BA5B7),
            fixedSize: const Size(44, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Color(0xFF242A35)),
            ),
          ),
          icon: const Icon(Icons.person_add_alt_1_rounded),
        ),
      ],
    );
  }
}

class _GoalHero extends StatelessWidget {
  const _GoalHero({
    required this.steps,
    required this.goal,
    required this.rank,
    required this.leaderSteps,
    required this.hasGroup,
    required this.onGroupTap,
    required this.dayLabel,
  });
  final int steps;
  final int goal;
  final int? rank;
  final int? leaderSteps;
  final bool hasGroup;
  final VoidCallback? onGroupTap;
  final String dayLabel;

  @override
  Widget build(BuildContext context) {
    final progress = goal <= 0 ? 0.0 : (steps / goal).clamp(0.0, 1.0);
    final behind = math.max(0, (leaderSteps ?? steps) - steps);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF173A69)),
        gradient: const LinearGradient(
          colors: [Color(0xFF0C1B35), Color(0xFF09111F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26168BFF),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final ringSize = math.min(142.0, constraints.maxWidth * .42);
          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$dayLabel Steps',
                      style: const TextStyle(
                        color: Color(0xFFA6B6D0),
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _number(steps),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      'of ${_number(goal)} steps',
                      style: const TextStyle(
                        color: Color(0xFF45A4FF),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (hasGroup) ...[
                      Text(
                        rank == null ? 'Ranking...' : '#$rank in group',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        behind > 0
                            ? '${_number(behind)} steps to take the lead'
                            : 'You are setting the pace',
                        style: const TextStyle(
                          color: Color(0xFFA6B6D0),
                          fontSize: 13,
                        ),
                      ),
                    ] else
                      TextButton.icon(
                        onPressed: onGroupTap,
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        icon: const Icon(
                          Icons.add_circle_outline_rounded,
                          size: 18,
                        ),
                        label: const Text('Create or join a group'),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: ringSize,
                height: ringSize,
                child: CustomPaint(
                  painter: _RingPainter(progress),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(progress * 100).round()}%',
                          style: const TextStyle(
                            color: Color(0xFF2E9BFF),
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          'Goal',
                          style: TextStyle(
                            color: Color(0xFF8490A3),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Color(0xFF0E5EAD),
                            borderRadius: BorderRadius.all(Radius.circular(7)),
                          ),
                          child: const Center(
                            child: FootstepsIcon(size: 18, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * .085;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final track = Paint()
      ..color = const Color(0xFF17345C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final fill = Paint()
      ..shader = const SweepGradient(
        colors: [Color(0xFF19C2FF), Color(0xFF106DFF), Color(0xFF19C2FF)],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, track);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0, 1),
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics, required this.goals});
  final TodayMetrics metrics;
  final UserGoals goals;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _Metric(
        kind: _MetricKind.steps,
        color: const Color(0xFF218FFF),
        label: 'Steps',
        displayValue: _number(metrics.steps),
        unit: 'of ${_number(goals.steps)}',
        current: metrics.steps.toDouble(),
        goal: goals.steps.toDouble(),
      ),
      _Metric(
        kind: _MetricKind.calories,
        color: const Color(0xFFFF8A1E),
        label: 'Active Calories',
        displayValue: _number(metrics.activeEnergyCalories.round()),
        unit: 'CAL',
        current: metrics.activeEnergyCalories,
        goal: goals.activeCalories.toDouble(),
      ),
      _Metric(
        kind: _MetricKind.miles,
        color: const Color(0xFF16D69A),
        label: 'Miles',
        displayValue: metrics.distanceMiles.toStringAsFixed(1),
        unit: 'MI',
        current: metrics.distanceMiles,
        goal: goals.miles,
      ),
      _Metric(
        kind: _MetricKind.exercise,
        color: const Color(0xFF9A73FF),
        label: 'Exercise Minutes',
        displayValue: _number(metrics.exerciseMinutes.round()),
        unit: 'MIN',
        current: metrics.exerciseMinutes,
        goal: goals.exerciseMinutes.toDouble(),
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.72,
      ),
      itemCount: cards.length,
      itemBuilder: (_, index) => _MetricCard(metric: cards[index]),
    );
  }
}

enum _MetricKind { steps, calories, miles, exercise }

class _Metric {
  const _Metric({
    required this.kind,
    required this.color,
    required this.label,
    required this.displayValue,
    required this.unit,
    required this.current,
    required this.goal,
  });

  final _MetricKind kind;
  final Color color;
  final String label;
  final String displayValue;
  final String unit;
  final double current;
  final double goal;

  double get progress => goal <= 0 ? 0 : (current / goal).clamp(0, 1);

  bool get isComplete => goal > 0 && current >= goal;

  String get remainingLabel {
    if (isComplete) return 'Daily goal closed';
    final left = goal - current;
    return switch (kind) {
      _MetricKind.steps => '${_number(left.round())} steps to go',
      _MetricKind.calories => '${_number(left.round())} cal to go',
      _MetricKind.miles =>
        '${left.toStringAsFixed(left >= 10 ? 0 : 1)} mi to go',
      _MetricKind.exercise => '${_number(left.round())} min to go',
    };
  }

  String get insightLine {
    if (isComplete) {
      return switch (kind) {
        _MetricKind.steps => 'Ring closed. You hit your step goal today.',
        _MetricKind.calories => 'Ring closed. Calorie goal handled.',
        _MetricKind.miles => 'Ring closed. Distance goal handled.',
        _MetricKind.exercise => 'Ring closed. Exercise goal handled.',
      };
    }
    final pct = (progress * 100).round();
    if (pct == 0) {
      return 'Start stacking motion — every bit counts.';
    }
    if (pct >= 75) {
      return 'Almost there. Finish strong and close the ring.';
    }
    if (pct >= 40) {
      return 'You\'re building momentum. Keep it moving.';
    }
    return 'Plenty of day left to close this ring.';
  }

  IconData? get icon => switch (kind) {
    _MetricKind.steps => null,
    _MetricKind.calories => Icons.local_fire_department_rounded,
    _MetricKind.miles => Icons.location_on_rounded,
    _MetricKind.exercise => Icons.timer_outlined,
  };
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});
  final _Metric metric;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF11151B),
      showDragHandle: true,
      builder: (_) => _MetricDetailSheet(metric: metric),
    ),
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.all(13),
      decoration: _cardDecoration,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: metric.color.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: metric.kind == _MetricKind.steps
                ? Center(
                    child: FootstepsIcon(size: 25, color: metric.color),
                  )
                : Icon(metric.icon, color: metric.color, size: 23),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF9AA4B5),
                    fontSize: 11,
                  ),
                ),
                Text(
                  metric.displayValue,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  metric.unit,
                  style: const TextStyle(
                    color: Color(0xFF7F899A),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFF667184),
            size: 20,
          ),
        ],
      ),
    ),
  );
}

class _MetricDetailSheet extends StatelessWidget {
  const _MetricDetailSheet({required this.metric});

  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    final goalLabel = switch (metric.kind) {
      _MetricKind.steps => _number(metric.goal.round()),
      _MetricKind.calories => '${_number(metric.goal.round())} cal',
      _MetricKind.miles =>
        metric.goal == metric.goal.roundToDouble()
            ? '${metric.goal.round()} mi'
            : '${metric.goal.toStringAsFixed(1)} mi',
      _MetricKind.exercise => '${_number(metric.goal.round())} min',
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: metric.color.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: metric.kind == _MetricKind.steps
                      ? Center(
                          child: FootstepsIcon(size: 28, color: metric.color),
                        )
                      : Icon(metric.icon, color: metric.color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        metric.label,
                        style: const TextStyle(
                          color: Color(0xFF9AA4B5),
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        metric.displayValue,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(metric.progress * 100).round()}%',
                  style: TextStyle(
                    color: metric.color,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: metric.progress,
                minHeight: 10,
                backgroundColor: metric.color.withValues(alpha: .18),
                color: metric.color,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  metric.isComplete ? 'Goal complete' : metric.remainingLabel,
                  style: TextStyle(
                    color: metric.isComplete
                        ? const Color(0xFF16D6A0)
                        : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Goal: $goalLabel',
                  style: const TextStyle(
                    color: Color(0xFF8F99AA),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              metric.insightLine,
              style: const TextStyle(
                color: Color(0xFF9AA4B5),
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityStrip extends StatelessWidget {
  const _ActivityStrip({
    required this.calories,
    required this.exercise,
    required this.stand,
    required this.calorieGoal,
    required this.exerciseGoal,
  });
  final double calories;
  final double exercise;
  final double? stand;
  final double calorieGoal;
  final double exerciseGoal;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
    decoration: _cardDecoration,
    child: Row(
      children: [
        Expanded(
          child: _ActivityItem(
            'Move',
            calories,
            calorieGoal,
            'CAL',
            const Color(0xFFFF315F),
          ),
        ),
        const _VerticalDivider(),
        Expanded(
          child: _ActivityItem(
            'Exercise',
            exercise,
            exerciseGoal,
            'MIN',
            const Color(0xFF87E923),
          ),
        ),
        const _VerticalDivider(),
        Expanded(
          child: _ActivityItem(
            'Stand',
            stand,
            12,
            'HRS',
            const Color(0xFF20DAD2),
          ),
        ),
      ],
    ),
  );
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 54, color: const Color(0xFF2A303B));
}

class _ActivityItem extends StatelessWidget {
  const _ActivityItem(this.label, this.value, this.goal, this.unit, this.color);
  final String label;
  final double? value;
  final double goal;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final available = value != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: CircularProgressIndicator(
              value: available ? (value! / goal).clamp(0, 1) : 0,
              strokeWidth: 6,
              backgroundColor: color.withValues(alpha: .16),
              color: color,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFA4ADBB),
                    fontSize: 11,
                  ),
                ),
                Text(
                  available ? '${value!.round()} / ${goal.round()}' : '--',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  available ? unit : 'Unavailable',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF7D8797), fontSize: 9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyCard extends StatelessWidget {
  const _WeeklyCard({
    required this.total,
    required this.values,
    required this.selected,
    required this.onSelect,
  });
  final int total;
  final List<int> values;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final maxValue = math.max(1, values.fold<int>(0, math.max));
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final today = DateTime.now().weekday - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: _cardDecoration,
      child: Column(
        children: [
          Row(
            children: [
              const _Title('This Week'),
              const Spacer(),
              Text(
                '${_number(total)} steps',
                style: const TextStyle(
                  color: Color(0xFF2E9BFF),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final isSelected = index == selected;
                final enabled = index <= today;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: enabled ? () => onSelect(index) : null,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          labels[index],
                          style: TextStyle(
                            color: isSelected
                                ? const Color(0xFF45A4FF)
                                : const Color(0xFF858E9F),
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final factor = math.max(
                                .05,
                                values[index] / maxValue,
                              );
                              return Align(
                                alignment: Alignment.bottomCenter,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 380),
                                  curve: Curves.easeOutCubic,
                                  height: constraints.maxHeight * factor,
                                  width: constraints.maxWidth * .55,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: isSelected
                                          ? const [
                                              Color(0xFF087BFF),
                                              Color(0xFF35B5FF),
                                            ]
                                          : const [
                                              Color(0xFF123766),
                                              Color(0xFF246BC0),
                                            ],
                                    ),
                                    borderRadius: BorderRadius.circular(5),
                                    boxShadow: isSelected
                                        ? const [
                                            BoxShadow(
                                              color: Color(0x55168BFF),
                                              blurRadius: 10,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardCard extends StatelessWidget {
  const _LeaderboardCard({
    required this.entries,
    required this.metric,
    required this.hasGroup,
    required this.onSeeAll,
    required this.onGroupTap,
    required this.onMetricSelected,
  });
  final List<MotionStats> entries;
  final String metric;
  final bool hasGroup;
  final VoidCallback? onSeeAll;
  final VoidCallback? onGroupTap;
  final ValueChanged<String> onMetricSelected;

  static const _metrics = ['Steps', 'Calories', 'Miles', 'Exercise'];

  double _valueFor(MotionStats stats) => switch (metric) {
    'Calories' => stats.activeCalories.toDouble(),
    'Miles' => stats.miles,
    'Exercise' => stats.exerciseMinutes.toDouble(),
    _ => stats.steps.toDouble(),
  };

  String _displayValue(MotionStats stats) {
    final value = _valueFor(stats);
    if (metric == 'Miles') return value.toStringAsFixed(1);
    return _number(value);
  }

  String get _unit => switch (metric) {
    'Calories' => 'cal',
    'Miles' => 'mi',
    'Exercise' => 'min',
    _ => 'steps',
  };

  @override
  Widget build(BuildContext context) {
    final ranked = [...entries]..sort((a, b) => _valueFor(b).compareTo(_valueFor(a)));
    return Container(
    padding: const EdgeInsets.all(16),
    decoration: _cardDecoration,
    child: Column(
      children: [
        Row(
          children: [
            const _Title('Leaderboard'),
            const Spacer(),
            if (hasGroup)
              TextButton(onPressed: onSeeAll, child: const Text('See all')),
          ],
        ),
        Row(
          children: [
            PopupMenuButton<String>(
              onSelected: onMetricSelected,
              color: const Color(0xFF171C24),
              offset: const Offset(0, 36),
              itemBuilder: (context) => [
                for (final option in _metrics)
                  PopupMenuItem(
                    value: option,
                    child: Text(
                      option,
                      style: TextStyle(
                        color: option == metric
                            ? const Color(0xFF45A4FF)
                            : Colors.white,
                        fontWeight: option == metric
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D2340),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF174B82)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      metric,
                      style: const TextStyle(
                        color: Color(0xFF45A4FF),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: Color(0xFF45A4FF),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'today',
              style: TextStyle(color: Color(0xFF8F99AA), fontSize: 13),
            ),
          ],
        ),
        if (ranked.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Column(
              children: [
                Text(
                  hasGroup
                      ? 'No activity has been shared today.'
                      : 'Create or join a group to start competing.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF8F99AA)),
                ),
                if (!hasGroup)
                  TextButton(
                    onPressed: onGroupTap,
                    child: const Text('Open Groups'),
                  ),
              ],
            ),
          )
        else
          ...ranked.take(3).toList().asMap().entries.map((row) {
            final rank = row.key + 1;
            final entry = row.value;
            final isMe = entry.isCurrentUser || entry.name == 'You';
            final rankColor = rank == 1
                ? const Color(0xFFFFC22E)
                : rank == 2
                ? const Color(0xFFBEC7D5)
                : const Color(0xFFC8874D);
            return Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF0D2340) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: isMe
                    ? Border.all(color: const Color(0xFF174B82))
                    : null,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 34,
                    child: Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            rankColor.withValues(alpha: .95),
                            rankColor.withValues(alpha: .45),
                          ],
                        ),
                        border: Border.all(
                          color: rankColor.withValues(alpha: .9),
                        ),
                      ),
                      child: Text(
                        '$rank',
                        style: const TextStyle(
                          color: Color(0xFF101318),
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF23324A),
                    backgroundImage: entry.avatarUrl?.isNotEmpty == true
                        ? NetworkImage(entry.avatarUrl!)
                        : null,
                    child: entry.avatarUrl?.isNotEmpty == true
                        ? null
                        : Text(
                            entry.name.characters.first.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.name,
                      style: TextStyle(
                        color: isMe ? const Color(0xFF45A4FF) : Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Text(
                    '${_displayValue(entry)} $_unit',
                    style: TextStyle(
                      color: isMe ? const Color(0xFF45A4FF) : Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    ),
    );
  }
}

const _cardDecoration = BoxDecoration(
  color: Color(0xFF11151B),
  borderRadius: BorderRadius.all(Radius.circular(8)),
  border: Border.fromBorderSide(BorderSide(color: Color(0xFF202631))),
);

String _number(num value) => value.round().toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => ',',
);

String _weekday(int index) => const [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
][index];
