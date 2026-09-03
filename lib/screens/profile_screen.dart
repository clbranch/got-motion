import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/logged_workout.dart';
import '../models/today_metrics.dart';
import '../services/daily_steps_service.dart';
import '../services/goal_service.dart';
import '../services/health_service.dart';
import '../services/main_nav_service.dart';
import '../services/profile_service.dart';
import '../services/workout_log_service.dart';
import '../widgets/daily_activity_rings.dart';
import '../widgets/footsteps_icon.dart';
import '../widgets/goal_complete_celebration.dart';
import '../widgets/workout_log_entry.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.isActive = false, this.scrollController});

  final bool isActive;
  final ScrollController? scrollController;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _background = Color(0xFF07090D);
  static const _accent = Color(0xFF168BFF);
  static const _card = Color(0xFF11151B);

  final _profileService = ProfileService();
  final _dailyStepsService = DailyStepsService();
  TodayMetrics _today = TodayMetrics.zero;
  ProfileData? _profile;
  List<LoggedWorkout> _recentWorkouts = const [];
  ActiveWorkoutSession? _activeWorkout;
  bool _loading = true;
  bool _savingAvatar = false;

  /// Personal history range on Profile (not the group leaderboard).
  String _historyRange = 'This Week'; // This Week | This Month | past YYYY-MM
  List<({DateTime date, int steps})> _historyDays = const [];
  bool _historyLoading = false;

  @override
  void initState() {
    super.initState();
    goalService.addListener(_goalsChanged);
    goalService.reloadFromCurrentUser();
    if (widget.isActive) _load();
  }

  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _load();
    }
  }

  @override
  void dispose() {
    goalService.removeListener(_goalsChanged);
    super.dispose();
  }

  void _goalsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final results = await Future.wait<dynamic>([
        HealthService.getTodayMetrics().timeout(
          const Duration(seconds: 8),
          onTimeout: () => TodayMetrics.zero,
        ),
        _profileService.getCurrentProfile().timeout(
          const Duration(seconds: 8),
          onTimeout: () => null,
        ),
      ]);
      if (!mounted) return;
      final today = results[0] as TodayMetrics;
      final recent = await workoutLogService.recentForSelectedGroup().timeout(
        const Duration(seconds: 5),
        onTimeout: () => const <LoggedWorkout>[],
      );
      final active = await workoutLogService.getActiveSession().timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );
      if (!mounted) return;
      setState(() {
        _today = today;
        _profile = results[1] as ProfileData?;
        _recentWorkouts = recent;
        _activeWorkout = active;
        _loading = false;
      });
      _syncToday(user.id, today);
      _maybeCelebrateGoals(user.id, goalService.goals, today);
      unawaited(_loadHistory(user.id));
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadHistory(String userId) async {
    if (_historyLoading) return;
    setState(() => _historyLoading = true);
    try {
      final now = DateTime.now();
      late DateTime start;
      late DateTime end;
      if (_historyRange == 'This Week') {
        start = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
        end = DateTime(now.year, now.month, now.day);
      } else if (_historyRange == 'This Month') {
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month, now.day);
      } else {
        // past YYYY-MM
        final parts = _historyRange.split('-');
        final year = int.tryParse(parts[0]) ?? now.year;
        final month = int.tryParse(parts[1]) ?? now.month;
        start = DateTime(year, month, 1);
        end = DateTime(year, month + 1, 0);
      }

      final startStr = start.toIso8601String().split('T').first;
      final endStr = end.toIso8601String().split('T').first;
      final rows = await Supabase.instance.client
          .from('daily_steps')
          .select('date, steps')
          .eq('user_id', userId)
          .gte('date', startStr)
          .lte('date', endStr)
          .order('date')
          .timeout(const Duration(seconds: 8));

      final byDate = <String, int>{};
      for (final row in List<Map<String, dynamic>>.from(rows as List)) {
        final d = row['date']?.toString() ?? '';
        byDate[d] = (row['steps'] as num?)?.toInt() ?? 0;
      }

      final days = <({DateTime date, int steps})>[];
      var cursor = start;
      while (!cursor.isAfter(end)) {
        final key = cursor.toIso8601String().split('T').first;
        days.add((date: cursor, steps: byDate[key] ?? 0));
        cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
      }

      if (!mounted) return;
      setState(() {
        _historyDays = days;
        _historyLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  List<String> get _historyOptions {
    final now = DateTime.now();
    final options = <String>['This Week', 'This Month'];
    // Offer the prior 5 calendar months (enough once history exists).
    for (var i = 1; i <= 5; i++) {
      final m = DateTime(now.year, now.month - i, 1);
      options.add(
        '${m.year}-${m.month.toString().padLeft(2, '0')}',
      );
    }
    return options;
  }

  String _historyLabel(String key) {
    if (key == 'This Week' || key == 'This Month') return key;
    final parts = key.split('-');
    if (parts.length != 2) return key;
    final year = int.tryParse(parts[0]) ?? 0;
    final month = int.tryParse(parts[1]) ?? 1;
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${names[month - 1]} $year';
  }

  Future<void> _openWorkoutLog() async {
    await openWorkoutLogFlow(context);
    if (mounted) _load();
  }

  void _maybeCelebrateGoals(
    String userId,
    UserGoals goals,
    TodayMetrics today,
  ) {
    if (!GoalCelebrationService.allGoalsComplete(today, goals)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      goalCelebrationService.maybeCelebrate(
        context,
        userId: userId,
        onKeepMoving: mainNavService.goToProfile,
      );
    });
  }

  void _syncToday(String userId, TodayMetrics today) {
    Future(() async {
      try {
        await _dailyStepsService.upsertDailySteps(
          userId: userId,
          date: DateTime.now(),
          steps: today.steps,
          miles: today.distanceMiles,
          activeCalories: today.activeEnergyCalories.round(),
          exerciseMinutes: today.exerciseMinutes.round(),
        );
        await _dailyStepsService.syncHistoryToDate(userId);
      } catch (error) {
        if (kDebugMode) debugPrint('[Profile] Daily sync failed: $error');
      }
    });
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
                onRefresh: _load,
                color: _accent,
                backgroundColor: _card,
                child: ListView(
                  controller: widget.scrollController,
                  primary: false,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 92),
                  children: [
                    const Text(
                      'Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _identityCard(),
                    const SizedBox(height: 16),
                    WorkoutLogEntryCard(
                      active: _activeWorkout != null,
                      onTap: _openWorkoutLog,
                    ),
                    if (_recentWorkouts.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      RecentGroupWorkoutsStrip(workouts: _recentWorkouts),
                    ],
                    const SizedBox(height: 22),
                    _sectionHeader(
                      'Daily Goals',
                      action: TextButton.icon(
                        onPressed: _editGoals,
                        icon: const Icon(Icons.tune_rounded, size: 17),
                        label: const Text('Adjust'),
                        style: TextButton.styleFrom(foregroundColor: _accent),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _goalsGrid(goals),
                    const SizedBox(height: 22),
                    _sectionHeader('Today’s Progress'),
                    const SizedBox(height: 8),
                    _todayCard(goals),
                    const SizedBox(height: 22),
                    _sectionHeader('Your history'),
                    const SizedBox(height: 10),
                    _historyRangeChips(),
                    const SizedBox(height: 10),
                    _historyCard(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _historyRangeChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final option in _historyOptions) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(_historyLabel(option)),
                selected: _historyRange == option,
                onSelected: (_) {
                  final userId =
                      Supabase.instance.client.auth.currentUser?.id;
                  setState(() => _historyRange = option);
                  if (userId != null) unawaited(_loadHistory(userId));
                },
                selectedColor: _accent.withValues(alpha: 0.25),
                labelStyle: TextStyle(
                  color: _historyRange == option
                      ? const Color(0xFF9FD0FF)
                      : const Color(0xFF9BA5B7),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                backgroundColor: const Color(0xFF151A22),
                side: BorderSide(
                  color: _historyRange == option
                      ? _accent.withValues(alpha: 0.5)
                      : const Color(0xFF2A3340),
                ),
                showCheckmark: false,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _historyCard() {
    if (_historyLoading && _historyDays.isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: _decoration(),
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
        ),
      );
    }

    final total = _historyDays.fold<int>(0, (sum, d) => sum + d.steps);
    final activeDays = _historyDays.where((d) => d.steps > 0).length;
    final average = activeDays == 0 ? 0 : total ~/ activeDays;
    ({DateTime date, int steps})? best;
    for (final day in _historyDays) {
      if (best == null || day.steps > best.steps) best = day;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _decoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _historyLabel(_historyRange),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${_number(total)} steps',
                style: const TextStyle(
                  color: Color(0xFF45A4FF),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_historyDays.isEmpty)
            const Text(
              'No synced days in this range yet. Open Got Motion after you move so Health can sync.',
              style: TextStyle(color: Color(0xFF9BA5B7), fontSize: 13),
            )
          else ...[
            SizedBox(
              height: 72,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final day in _historyDays)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: Container(
                          height: () {
                            final maxSteps = best?.steps ?? 0;
                            if (maxSteps <= 0) return 4.0;
                            return 8.0 + (day.steps / maxSteps) * 56.0;
                          }(),
                          decoration: BoxDecoration(
                            color: day.steps > 0
                                ? _accent.withValues(alpha: 0.85)
                                : const Color(0xFF1B2737),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _Insight(label: 'Daily average', value: _number(average)),
                _Insight(
                  label: 'Best day',
                  value: best == null || best.steps == 0
                      ? '--'
                      : '${best.date.month}/${best.date.day}',
                ),
                _Insight(label: 'Active days', value: '$activeDays'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _identityCard() {
    final profile = _profile;
    final label = profile?.displayLabel ?? 'User';
    final avatarUrl = profile?.avatarUrl;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _decoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF102A4B), Color(0xFF0B1421)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: const Color(0xFF315E91),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _savingAvatar ? null : _pickAndUploadAvatar,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: const Color(0xFF23324A),
                  backgroundImage: avatarUrl?.isNotEmpty == true
                      ? NetworkImage(avatarUrl!)
                      : null,
                  child: avatarUrl?.isNotEmpty == true
                      ? null
                      : Text(
                          label.characters.first.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 27,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 27,
                    height: 27,
                    decoration: const BoxDecoration(
                      color: _accent,
                      shape: BoxShape.circle,
                    ),
                    child: _savingAvatar
                        ? const Padding(
                            padding: EdgeInsets.all(6),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt_rounded,
                            size: 15,
                            color: Colors.white,
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  profile?.email ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8C9AAF),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _openEditProfile,
                  icon: const Icon(Icons.edit_rounded, size: 15),
                  label: const Text('Manage profile'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF72B9FF),
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    side: const BorderSide(color: Color(0xFF2869AD)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _goalsGrid(UserGoals goals) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisSpacing: 10,
    mainAxisSpacing: 10,
    childAspectRatio: 1.75,
    children: [
      _GoalTile(
        label: 'Steps',
        value: _number(goals.steps),
        unit: 'DAILY',
        color: const Color(0xFF218FFF),
        icon: const FootstepsIcon(size: 19, color: Color(0xFF218FFF)),
      ),
      _GoalTile(
        label: 'Active calories',
        value: _number(goals.activeCalories),
        unit: 'CAL',
        color: const Color(0xFFFF8A1E),
        icon: const Icon(
          Icons.local_fire_department_rounded,
          size: 21,
          color: Color(0xFFFF8A1E),
        ),
      ),
      _GoalTile(
        label: 'Exercise',
        value: '${goals.exerciseMinutes}',
        unit: 'MIN',
        color: const Color(0xFF9A73FF),
        icon: const Icon(
          Icons.timer_outlined,
          size: 21,
          color: Color(0xFF9A73FF),
        ),
      ),
      _GoalTile(
        label: 'Distance',
        value: _decimal(goals.miles),
        unit: 'MI',
        color: const Color(0xFF16D6A0),
        icon: const Icon(
          Icons.location_on_rounded,
          size: 21,
          color: Color(0xFF16D6A0),
        ),
      ),
    ],
  );

  Widget _todayCard(UserGoals goals) {
    final rings = DailyActivityRings(
      steps: _today.steps,
      stepsGoal: goals.steps,
      calories: _today.activeEnergyCalories.round(),
      caloriesGoal: goals.activeCalories,
      exerciseMinutes: _today.exerciseMinutes.round(),
      exerciseGoal: goals.exerciseMinutes,
      miles: _today.distanceMiles,
      milesGoal: goals.miles,
    );
    final summary = rings.allComplete
        ? 'Perfect day — every ring closed.'
        : rings.completedCount == 0
        ? 'Close all four rings today.'
        : '${rings.completedCount} of 4 complete — keep going.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _decoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              rings,
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  summary,
                  style: TextStyle(
                    color: rings.allComplete
                        ? const Color(0xFF16D6A0)
                        : Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: Color(0xFF252B35)),
          const SizedBox(height: 14),
          DailyRingLegend(
            steps: _today.steps,
            stepsGoal: goals.steps,
            calories: _today.activeEnergyCalories.round(),
            caloriesGoal: goals.activeCalories,
            exerciseMinutes: _today.exerciseMinutes.round(),
            exerciseGoal: goals.exerciseMinutes,
            miles: _today.distanceMiles,
            milesGoal: goals.miles,
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, {Widget? action}) => Row(
    children: [
      Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      const Spacer(),
      ?action,
    ],
  );

  Future<void> _editGoals() async {
    var steps = goalService.goals.steps.toDouble();
    var calories = goalService.goals.activeCalories.toDouble();
    var exercise = goalService.goals.exerciseMinutes.toDouble();
    var miles = goalService.goals.miles;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Set your daily goals',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'These targets power your Home and Profile progress.',
                  style: TextStyle(color: Color(0xFF8590A2), fontSize: 13),
                ),
                const SizedBox(height: 16),
                _GoalSlider(
                  label: 'Steps',
                  valueLabel: _number(steps.round()),
                  value: steps,
                  min: 2000,
                  max: 30000,
                  divisions: 56,
                  color: const Color(0xFF218FFF),
                  onChanged: (value) => setSheetState(() => steps = value),
                ),
                _GoalSlider(
                  label: 'Active calories',
                  valueLabel: '${calories.round()} CAL',
                  value: calories,
                  min: 100,
                  max: 1500,
                  divisions: 28,
                  color: const Color(0xFFFF8A1E),
                  onChanged: (value) => setSheetState(() => calories = value),
                ),
                _GoalSlider(
                  label: 'Exercise',
                  valueLabel: '${exercise.round()} MIN',
                  value: exercise,
                  min: 10,
                  max: 180,
                  divisions: 17,
                  color: const Color(0xFF9A73FF),
                  onChanged: (value) => setSheetState(() => exercise = value),
                ),
                _GoalSlider(
                  label: 'Distance',
                  valueLabel: '${_decimal(miles)} MI',
                  value: miles,
                  min: 1,
                  max: 20,
                  divisions: 38,
                  color: const Color(0xFF16D6A0),
                  onChanged: (value) => setSheetState(() => miles = value),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Save goals',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved != true) return;
    try {
      await goalService.save(
        UserGoals(
          steps: steps.round(),
          activeCalories: calories.round(),
          exerciseMinutes: exercise.round(),
          miles: miles,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your goals are updated.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couldn’t save goals. Try again.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (image == null || !mounted) return;
    setState(() => _savingAvatar = true);
    try {
      final url = await _profileService.uploadAvatar(File(image.path));
      await _profileService.updateProfile(
        avatarUrl: url,
        avatarSource: 'custom',
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couldn’t update photo. Try again.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _savingAvatar = false);
    }
  }

  Future<void> _openEditProfile() async {
    final profile = _profile;
    if (profile == null) return;
    final controller = TextEditingController(text: profile.displayName ?? '');
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Manage profile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Update how you appear to your groups.',
                style: TextStyle(color: Color(0xFF8590A2), fontSize: 13),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: const Color(0xFF23324A),
                    backgroundImage: profile.avatarUrl?.isNotEmpty == true
                        ? NetworkImage(profile.avatarUrl!)
                        : null,
                    child: profile.avatarUrl?.isNotEmpty == true
                        ? null
                        : Text(
                            profile.displayLabel.characters.first.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Profile photo',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        OutlinedButton.icon(
                          onPressed: () =>
                              Navigator.of(sheetContext).pop('photo'),
                          icon: const Icon(
                            Icons.photo_library_rounded,
                            size: 16,
                          ),
                          label: const Text('Change photo'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF72B9FF),
                            side: const BorderSide(color: Color(0xFF2869AD)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: _profileInputDecoration(
                  label: 'Display name',
                  icon: Icons.badge_outlined,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                initialValue: profile.email ?? '',
                readOnly: true,
                style: const TextStyle(color: Color(0xFF8F99AA)),
                decoration: _profileInputDecoration(
                  label: 'Account email',
                  icon: Icons.lock_outline_rounded,
                  helper: 'Managed through your sign-in account',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(sheetContext).pop('save'),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Save changes'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == 'photo') {
      await _pickAndUploadAvatar();
      return;
    }
    if (result != 'save') return;
    try {
      await _profileService.updateProfile(displayName: controller.text.trim());
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couldn’t save profile. Try again.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  InputDecoration _profileInputDecoration({
    required String label,
    required IconData icon,
    String? helper,
  }) => InputDecoration(
    labelText: label,
    helperText: helper,
    prefixIcon: Icon(icon),
    labelStyle: const TextStyle(color: Color(0xFF8F99AA)),
    helperStyle: const TextStyle(color: Color(0xFF667184), fontSize: 10),
    prefixIconColor: const Color(0xFF667184),
    enabledBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: Color(0xFF303846)),
    ),
    focusedBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: _accent),
    ),
    border: const OutlineInputBorder(),
  );

  static BoxDecoration _decoration({
    Gradient? gradient,
    Color border = const Color(0xFF202631),
  }) => BoxDecoration(
    color: gradient == null ? _card : null,
    gradient: gradient,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: border),
  );
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.icon,
  });
  final String label;
  final String value;
  final String unit;
  final Color color;
  final Widget icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: _ProfileScreenState._decoration(),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: icon,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF8F99AA), fontSize: 10),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(unit, style: TextStyle(color: color, fontSize: 9)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Insight extends StatelessWidget {
  const _Insight({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          maxLines: 1,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF7F899A), fontSize: 9),
        ),
      ],
    ),
  );
}

class _GoalSlider extends StatelessWidget {
  const _GoalSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.color,
    required this.onChanged,
  });
  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final Color color;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            valueLabel,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          activeTrackColor: color,
          thumbColor: color,
          inactiveTrackColor: color.withValues(alpha: .18),
          overlayColor: color.withValues(alpha: .12),
        ),
        child: Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ),
    ],
  );
}

String _number(num value) => value.round().toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => ',',
);

String _decimal(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toStringAsFixed(1);
