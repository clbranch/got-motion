import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/motion_stats.dart';
import '../models/today_metrics.dart';
import '../services/daily_steps_service.dart';
import '../services/health_service.dart';
import '../services/leaderboard_service.dart';
import '../services/selected_group_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onSeeAllLeaderboard, this.onOpenGroupTab});

  final VoidCallback? onSeeAllLeaderboard;
  final VoidCallback? onOpenGroupTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _background = Color(0xFF07090D);
  static const _accent = Color(0xFF168BFF);
  static const _stepGoal = 10000;

  TodayMetrics _today = TodayMetrics.zero;
  int _weekTotal = 0;
  List<int> _week = List.filled(7, 0);
  List<MotionStats> _leaders = [];
  int? _rank;
  double? _standHours;
  int _selectedDay = DateTime.now().weekday - 1;
  bool _loading = true;

  final _dailySteps = DailyStepsService();
  final _leaderboard = LeaderboardService();

  @override
  void initState() {
    super.initState();
    selectedGroupService.addListener(_groupChanged);
    _load();
  }

  @override
  void dispose() {
    selectedGroupService.removeListener(_groupChanged);
    super.dispose();
  }

  void _groupChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    final values = await Future.wait<dynamic>([
      HealthService.getTodayMetrics(),
      HealthService.getWeekStepsTotal(),
      HealthService.getWeekStepsByDay(),
      HealthService.getTodayStandHours(),
    ]);
    final today = values[0] as TodayMetrics;
    final leaders = await _fetchLeaders(today);
    if (!mounted) return;
    setState(() {
      _today = today;
      _weekTotal = values[1] as int;
      _week = values[2] as List<int>;
      _standHours = values[3] as double?;
      _leaders = leaders;
      _rank = _findRank(leaders);
      _loading = false;
    });
    _sync(today);
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
      final others = rows
          .where((row) {
            return row['user_id']?.toString() != user?.id &&
                row['email']?.toString().toLowerCase() !=
                    user?.email?.toLowerCase();
          })
          .map(
            (row) => MotionStats(
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
      final me = MotionStats(
        name: 'You',
        steps: today.steps,
        miles: today.distanceMiles,
        activeCalories: today.activeEnergyCalories.round(),
        exerciseMinutes: today.exerciseMinutes.round(),
        previousRank: null,
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
                      groupName: selectedGroupService.selectedGroupName,
                      onGroupTap: widget.onOpenGroupTab,
                      onNotifications: _showNotifications,
                    ),
                    const SizedBox(height: 18),
                    _GoalHero(
                      steps: _today.steps,
                      goal: _stepGoal,
                      rank: _rank,
                      leaderSteps: _leaders.isEmpty
                          ? null
                          : _leaders.first.steps,
                      hasGroup: selectedGroupService.selectedGroupId != null,
                      onGroupTap: widget.onOpenGroupTab,
                      dayLabel: _isToday
                          ? "Today's"
                          : "${_weekday(_selectedDay)}'s",
                    ),
                    const SizedBox(height: 24),
                    _Title(_isToday ? 'Today' : _weekday(_selectedDay)),
                    const SizedBox(height: 12),
                    _MetricGrid(metrics: _today, stepGoal: _stepGoal),
                    const SizedBox(height: 12),
                    _ActivityStrip(
                      calories: _today.activeEnergyCalories,
                      exercise: _today.exerciseMinutes,
                      stand: _standHours,
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
                      hasGroup: selectedGroupService.selectedGroupId != null,
                      onSeeAll: widget.onSeeAllLeaderboard,
                      onGroupTap: widget.onOpenGroupTab,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  void _showNotifications() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF11151B),
      showDragHandle: true,
      builder: (context) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    color: Color(0xFF45A4FF),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Notifications',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 28),
              Text(
                'You are all caught up.',
                style: TextStyle(color: Color(0xFFA4ADBB), fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.groupName,
    required this.onGroupTap,
    required this.onNotifications,
  });
  final String? groupName;
  final VoidCallback? onGroupTap;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final hasGroup = groupName?.isNotEmpty == true;
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onGroupTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFF14233B),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.groups_rounded,
                      color: Color(0xFF5BA9FF),
                    ),
                  ),
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
        IconButton.filled(
          onPressed: onNotifications,
          tooltip: 'Notifications',
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF11151D),
            foregroundColor: const Color(0xFF9BA5B7),
            fixedSize: const Size(44, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Color(0xFF242A35)),
            ),
          ),
          icon: const Icon(Icons.notifications_none_rounded),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: onGroupTap,
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
    final progress = steps / goal;
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
                            child: _FootstepsIcon(
                              size: 18,
                              color: Colors.white,
                            ),
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
  const _MetricGrid({required this.metrics, required this.stepGoal});
  final TodayMetrics metrics;
  final int stepGoal;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _Metric(
        Icons.directions_walk_rounded,
        const Color(0xFF218FFF),
        'Steps',
        _number(metrics.steps),
        'of ${_number(stepGoal)}',
      ),
      _Metric(
        Icons.local_fire_department_rounded,
        const Color(0xFFFF8A1E),
        'Active Calories',
        _number(metrics.activeEnergyCalories.round()),
        'kcal',
      ),
      _Metric(
        Icons.location_on_rounded,
        const Color(0xFF16D69A),
        'Miles',
        metrics.distanceMiles.toStringAsFixed(1),
        'mi',
      ),
      _Metric(
        Icons.timer_outlined,
        const Color(0xFF9A73FF),
        'Exercise Minutes',
        _number(metrics.exerciseMinutes.round()),
        'min',
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
      itemBuilder: (_, index) => _MetricCard(cards[index]),
    );
  }
}

class _Metric {
  const _Metric(this.icon, this.color, this.label, this.value, this.unit);
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String unit;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.data);
  final _Metric data;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF11151B),
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 30),
          child: Row(
            children: [
              Icon(data.icon, color: data.color, size: 30),
              const SizedBox(width: 16),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.label,
                    style: const TextStyle(
                      color: Color(0xFF9AA4B5),
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${data.value} ${data.unit}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
              color: data.color.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: data.label == 'Steps'
                ? Center(child: _FootstepsIcon(size: 25, color: data.color))
                : Icon(data.icon, color: data.color, size: 23),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF9AA4B5),
                    fontSize: 11,
                  ),
                ),
                Text(
                  data.value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  data.unit,
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

class _FootstepsIcon extends StatelessWidget {
  const _FootstepsIcon({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _FootstepsPainter(color)),
  );
}

class _FootstepsPainter extends CustomPainter {
  const _FootstepsPainter(this.color);

  final Color color;

  void _foot(Canvas canvas, Size size, Offset center, double angle) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final paint = Paint()..color = color;
    final scale = size.shortestSide / 24;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, 2 * scale),
        width: 6 * scale,
        height: 10 * scale,
      ),
      paint,
    );
    canvas.drawCircle(Offset(-2.4 * scale, -4.4 * scale), 1.3 * scale, paint);
    canvas.drawCircle(Offset(-.4 * scale, -5.4 * scale), 1.25 * scale, paint);
    canvas.drawCircle(Offset(1.7 * scale, -5.1 * scale), 1.1 * scale, paint);
    canvas.drawCircle(Offset(3.2 * scale, -3.9 * scale), .85 * scale, paint);
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    _foot(canvas, size, Offset(size.width * .34, size.height * .39), -.12);
    _foot(canvas, size, Offset(size.width * .68, size.height * .65), .12);
  }

  @override
  bool shouldRepaint(covariant _FootstepsPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _ActivityStrip extends StatelessWidget {
  const _ActivityStrip({
    required this.calories,
    required this.exercise,
    required this.stand,
  });
  final double calories;
  final double exercise;
  final double? stand;

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
            500,
            'kcal',
            const Color(0xFFFF315F),
          ),
        ),
        const _VerticalDivider(),
        Expanded(
          child: _ActivityItem(
            'Exercise',
            exercise,
            30,
            'min',
            const Color(0xFF87E923),
          ),
        ),
        const _VerticalDivider(),
        Expanded(
          child: _ActivityItem(
            'Stand',
            stand,
            12,
            'hrs',
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
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: math.max(
                                .05,
                                values[index] / maxValue,
                              ),
                              widthFactor: .55,
                              child: Container(
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
                            ),
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
    required this.hasGroup,
    required this.onSeeAll,
    required this.onGroupTap,
  });
  final List<MotionStats> entries;
  final bool hasGroup;
  final VoidCallback? onSeeAll;
  final VoidCallback? onGroupTap;

  @override
  Widget build(BuildContext context) => Container(
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
        if (entries.isEmpty)
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
          ...entries.take(3).toList().asMap().entries.map((row) {
            final rank = row.key + 1;
            final entry = row.value;
            final isMe = entry.name == 'You';
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
                    _number(entry.steps),
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
