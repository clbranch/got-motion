import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/motion_stats.dart';
import '../models/today_metrics.dart';
import '../services/daily_steps_service.dart';
import '../services/group_service.dart';
import '../services/leaderboard_service.dart';
import '../services/selected_group_service.dart';
import '../services/health_service.dart';
import '../services/profile_service.dart';
import '../widgets/footsteps_icon.dart';
import '../widgets/group_avatar.dart';
import 'player_detail_screen.dart';

/// Leaderboard screen: group name, leaderboard header row, list of cards.
/// Data is loaded from Supabase via LeaderboardService (group_leaderboard view).
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, this.isActive = false});

  /// True when this tab is visible in the bottom nav.
  final bool isActive;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with WidgetsBindingObserver {
  static const Color _background = Color(0xFF0B0B0F);
  static const Color _accent = Color(0xFF3B82F6);
  static const double _pagePadding = 16.0;

  static const List<String> _rangeOptions = [
    'Today',
    'This Week',
    'This Month',
  ];

  final GroupService _groupService = GroupService();
  final LeaderboardService _leaderboardService = LeaderboardService();
  final DailyStepsService _dailyStepsService = DailyStepsService();

  /// User's groups from Supabase; loaded on screen open.
  List<String> _groups = [];

  /// Selected group for leaderboard; first group when available.
  String? _selectedGroupName;

  List<MotionStats> _leaderboard = [];
  bool _loading = true;
  String? _error;
  String _selectedRange = 'Today';
  String _selectedMetric = 'Steps';

  /// Guards to prevent overlapping requests and recursive reload loops.
  bool _isLoadingLeaderboard = false;
  bool _isSyncingToday = false;
  bool _reloadRequested = false;

  void _onSelectedGroupChanged() {
    if (!mounted || _groups.isEmpty) return;
    final selected = selectedGroupService.selectedGroupName;
    if (selected == _selectedGroupName) return;
    setState(() {
      _selectedGroupName = selected;
      _loading = true;
      _error = null;
    });
    if (_isLoadingLeaderboard) {
      _reloadRequested = true;
    } else {
      _loadFromSupabase();
    }
  }

  /// After loading health, upsert today plus month-to-date so Week/Month can sum.
  void _syncHealthToSupabase(String userId) {
    if (_isSyncingToday) return;
    _isSyncingToday = true;
    if (kDebugMode) {
      // ignore: avoid_print
      print('[DailySteps] Triggering history sync from Leaderboard');
    }
    Future(() async {
      try {
        if (!mounted) return;
        await _dailyStepsService.syncMonthToDate(userId);
        if (mounted) await _loadFromSupabase(skipSyncAfterReload: true);
      } catch (e, stack) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('[DailySteps] Leaderboard sync failed — exception: $e');
          // ignore: avoid_print
          print('[DailySteps] Leaderboard sync failed — stack: $stack');
        }
      } finally {
        _isSyncingToday = false;
      }
    });
  }

  Future<TodayMetrics> _metricsForSelectedRange() {
    final now = DateTime.now();
    switch (_selectedRange) {
      case 'This Week':
      case 'Week':
        return HealthService.getMetricsInRange(
          HealthService.startOfWeek(),
          now,
        );
      case 'This Month':
      case 'Month':
        return HealthService.getMetricsInRange(
          HealthService.startOfMonth(),
          now,
        );
      default:
        return HealthService.getTodayMetrics();
    }
  }

  /// Load user's groups from Supabase, set first as selected, then load leaderboard for that group.
  Future<void> _loadGroupsAndLeaderboard() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _groups = [];
        _selectedGroupName = null;
        _loading = false;
      });
      return;
    }
    try {
      final rows = await _groupService
          .fetchUserGroups(user.id)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('Request timed out'),
          );
      if (!mounted) return;
      final names = rows
          .map(
            (r) => (r['groups'] as Map<String, dynamic>?)?['name']?.toString(),
          )
          .whereType<String>()
          .toList();
      selectedGroupService.setGroupsFromFetchRows(rows);
      setState(() {
        _groups = names;
        _selectedGroupName =
            selectedGroupService.selectedGroupName ??
            (names.isNotEmpty ? names.first : null);
      });
      if (_selectedGroupName != null) {
        _loadFromSupabase();
      } else {
        setState(() {
          _leaderboard = [];
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _groups = [];
        _selectedGroupName = null;
        _error = _friendlyNetworkError(e);
        _loading = false;
      });
    }
  }

  String _friendlyNetworkError(Object e) {
    final s = e.toString();
    if (s.contains('Bad file descriptor') || s.contains('ClientException')) {
      return 'Unable to load. Please pull to try again.';
    }
    if (s.contains('timed out')) return 'Request timed out. Pull to try again.';
    return s.length > 80 ? 'Network error. Pull to try again.' : s;
  }

  /// Load leaderboard from Supabase for [_selectedGroupName]. Maps view: display_name->name, total_steps->steps, total_miles->miles, total_active_calories->activeCalories, total_exercise_minutes->exerciseMinutes.
  /// [skipSyncAfterReload] when true (e.g. called from sync success) skips triggering sync to prevent recursive loop.
  /// [showLoading] when false, keeps existing rows visible while refreshing in the background.
  Future<void> _loadFromSupabase({
    bool skipSyncAfterReload = false,
    bool showLoading = true,
  }) async {
    if (_isLoadingLeaderboard) {
      _reloadRequested = true;
      return;
    }
    final groupId = selectedGroupService.selectedGroupId;
    if (groupId == null || groupId.isEmpty) {
      if (mounted) {
        setState(() {
          _leaderboard = [];
          _loading = false;
          _error = null;
        });
      }
      return;
    }
    _isLoadingLeaderboard = true;
    if (mounted && showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else if (mounted) {
      setState(() => _error = null);
    }
    try {
      if (kDebugMode) {
        // ignore: avoid_print
        print(
          '[Leaderboard] LeaderboardScreen — group_id: $groupId, group_name: $_selectedGroupName, range: $_selectedRange',
        );
      }
      final rows = await _leaderboardService
          .fetchGroupLeaderboard(groupId, range: _selectedRange)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('Request timed out'),
          );
      if (!mounted) return;

      if (kDebugMode) {
        // ignore: avoid_print
        print(
          '[Leaderboard] LeaderboardScreen — rows from Supabase: ${rows.length}',
        );
        for (final r in rows) {
          // ignore: avoid_print
          print(
            '[Leaderboard]   Supabase row: user_id=${r['user_id']}, total_steps=${r['total_steps']}',
          );
        }
      }

      final currentUser = Supabase.instance.client.auth.currentUser;
      final currentUserId = currentUser?.id;
      final currentUserEmail = currentUser?.email?.toLowerCase();

      var list = <MotionStats>[];
      Map<String, dynamic>? myRow;

      final filteredRows = rows.where((row) {
        final isMe = LeaderboardService.isCurrentUserRow(
          row,
          userId: currentUserId,
          email: currentUserEmail,
        );
        if (isMe) {
          myRow = row;
          return false;
        }
        return true;
      }).toList();

      list = filteredRows
          .map(
            (row) => MotionStats(
              name: LeaderboardService.resolveDisplayName(row),
              steps: (row['total_steps'] as num?)?.toInt() ?? 0,
              miles: (row['total_miles'] as num?)?.toDouble() ?? 0.0,
              activeCalories:
                  (row['total_active_calories'] as num?)?.toInt() ?? 0,
              exerciseMinutes:
                  (row['total_exercise_minutes'] as num?)?.toInt() ?? 0,
              avatarUrl: row['avatar_url']?.toString(),
              previousRank: null,
              isCurrentUser: false,
            ),
          )
          .toList();

      if (currentUserId != null) {
        final mine = await _metricsForSelectedRange();

        String myName = 'Unknown';
        String? myAvatarUrl;

        if (myRow != null) {
          myName = LeaderboardService.resolveDisplayName(myRow!);
          myAvatarUrl = myRow!['avatar_url']?.toString();
        } else {
          final profile = await ProfileService().getCurrentProfile();
          myName = profile?.displayLabel ?? currentUserEmail ?? 'Unknown';
          myAvatarUrl = profile?.avatarUrl;
        }

        final me = MotionStats(
          name: myName,
          steps: mine.steps,
          miles: mine.distanceMiles,
          activeCalories: mine.activeEnergyCalories.round(),
          exerciseMinutes: mine.exerciseMinutes.round(),
          avatarUrl: myAvatarUrl,
          previousRank: null,
          isCurrentUser: true,
        );
        if (kDebugMode) {
          // ignore: avoid_print
          print(
            '[Leaderboard] Injecting local Health for $_selectedRange: name=$myName, steps=${mine.steps}',
          );
        }
        list = [me, ...list];
        list.sort((a, b) => b.steps.compareTo(a.steps));

        if (!skipSyncAfterReload) {
          _syncHealthToSupabase(currentUserId);
        }
      }

      if (!mounted) return;
      if (groupId != selectedGroupService.selectedGroupId) {
        _reloadRequested = true;
        return;
      }
      setState(() {
        _leaderboard = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (groupId != selectedGroupService.selectedGroupId) {
        _reloadRequested = true;
        return;
      }
      setState(() {
        _error = _friendlyNetworkError(e);
        _leaderboard = [];
        _loading = false;
      });
    } finally {
      _isLoadingLeaderboard = false;
      if (_reloadRequested && mounted) {
        _reloadRequested = false;
        Future.microtask(_loadFromSupabase);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    selectedGroupService.addListener(_onSelectedGroupChanged);
    _loadGroupsAndLeaderboard();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    selectedGroupService.removeListener(_onSelectedGroupChanged);
    super.dispose();
  }

  void _refreshOnFocus() {
    if (_groups.isEmpty) {
      _loadGroupsAndLeaderboard();
    } else {
      _loadFromSupabase(showLoading: false);
    }
  }

  @override
  void didUpdateWidget(LeaderboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _refreshOnFocus();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.isActive) {
      _refreshOnFocus();
    }
  }

  // Miles is fractional, so metric values are doubles and formatting happens
  // per metric rather than rounding everything to an int.
  double _valueFor(MotionStats stats, String metric) => switch (metric) {
    'Miles' => stats.miles,
    'Calories' => stats.activeCalories.toDouble(),
    'Exercise' => stats.exerciseMinutes.toDouble(),
    _ => stats.steps.toDouble(),
  };

  String _unitFor(String metric) => switch (metric) {
    'Miles' => 'MI',
    'Calories' => 'CAL',
    'Exercise' => 'MIN',
    _ => 'STEPS',
  };

  List<MotionStats> get _ranked {
    final list = [..._leaderboard];
    list.sort(
      (a, b) => _valueFor(
        b,
        _selectedMetric,
      ).compareTo(_valueFor(a, _selectedMetric)),
    );
    return list;
  }

  MotionStats? _leaderFor(String metric) {
    if (_leaderboard.isEmpty) return null;
    final list = [..._leaderboard]
      ..sort((a, b) => _valueFor(b, metric).compareTo(_valueFor(a, metric)));
    return list.first;
  }

  void _openPlayer(MotionStats stats, int rank) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerDetailScreen(
          stats: stats,
          rank: rank,
          selectedRange: _selectedRange,
        ),
      ),
    );
  }

  Future<void> _showAllStandings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D1117),
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .82,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Full Standings',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${_ranked.length} members',
                      style: const TextStyle(
                        color: Color(0xFF8490A3),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$_selectedMetric · $_selectedRange',
                  style: const TextStyle(
                    color: Color(0xFF45A4FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: SingleChildScrollView(
                    child: _StandingsCard(
                      entries: _ranked,
                      metric: _selectedMetric,
                      valueFor: _valueFor,
                      unit: _unitFor(_selectedMetric),
                      onTap: (stats, rank) {
                        Navigator.of(sheetContext).pop();
                        _openPlayer(stats, rank);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadGroupsAndLeaderboard,
          color: _accent,
          backgroundColor: const Color(0xFF141820),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              _pagePadding,
              12,
              _pagePadding,
              88,
            ),
            children: [
              _LeaderboardHeader(
                groups: _groups,
                selectedGroup: _selectedGroupName,
                onGroupSelected: (name) {
                  setState(() => _selectedGroupName = name);
                  selectedGroupService.setSelectedGroup(name);
                  _loadFromSupabase();
                },
              ),
              const SizedBox(height: 22),
              _RangeSelector(
                options: _rangeOptions,
                selected: _selectedRange,
                onSelected: (value) {
                  setState(() => _selectedRange = value);
                  _loadFromSupabase();
                },
              ),
              const SizedBox(height: 20),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(
                    '$_selectedRange-$_loading-$_error-${_leaderboard.length}',
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 420,
                          child: Center(
                            child: CircularProgressIndicator(color: _accent),
                          ),
                        )
                      : _error != null
                      ? _MessageCard(message: _error!)
                      : _groups.isEmpty
                      ? const _MessageCard(
                          message: 'Create or join a group to start competing.',
                        )
                      : _leaderboard.isEmpty
                      ? const _MessageCard(
                          message:
                              'No activity has been shared for this period yet.',
                        )
                      : _LeaderboardResults(
                          ranked: _ranked,
                          selectedMetric: _selectedMetric,
                          valueFor: _valueFor,
                          unitFor: _unitFor,
                          leaderFor: _leaderFor,
                          onOpenPlayer: _openPlayer,
                          onShowAll: _showAllStandings,
                          onMetricSelected: (metric) =>
                              setState(() => _selectedMetric = metric),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaderboardResults extends StatelessWidget {
  const _LeaderboardResults({
    required this.ranked,
    required this.selectedMetric,
    required this.valueFor,
    required this.unitFor,
    required this.leaderFor,
    required this.onOpenPlayer,
    required this.onShowAll,
    required this.onMetricSelected,
  });

  final List<MotionStats> ranked;
  final String selectedMetric;
  final double Function(MotionStats stats, String metric) valueFor;
  final String Function(String metric) unitFor;
  final MotionStats? Function(String metric) leaderFor;
  final void Function(MotionStats stats, int rank) onOpenPlayer;
  final VoidCallback onShowAll;
  final ValueChanged<String> onMetricSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChampionCard(
          leader: ranked.first,
          metric: selectedMetric,
          value: valueFor(ranked.first, selectedMetric),
          unit: unitFor(selectedMetric),
          onTap: () => onOpenPlayer(ranked.first, 1),
        ),
        const SizedBox(height: 20),
        const _SectionTitle('Category Leaders'),
        const SizedBox(height: 10),
        for (final (index, pair) in const [
          ['Steps', 'Miles'],
          ['Calories', 'Exercise'],
        ].indexed) ...[
          if (index > 0) const SizedBox(height: 8),
          Row(
            children: [
              for (final metric in pair) ...[
                Expanded(
                  child: _CategoryLeaderCard(
                    metric: metric,
                    leader: leaderFor(metric)!,
                    value: valueFor(leaderFor(metric)!, metric),
                    unit: unitFor(metric),
                    selected: selectedMetric == metric,
                    onTap: () => onMetricSelected(metric),
                  ),
                ),
                if (metric != pair.last) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
        const SizedBox(height: 22),
        Row(
          children: [
            const _SectionTitle('Standings'),
            const Spacer(),
            if (ranked.length > 3)
              FilledButton.icon(
                onPressed: onShowAll,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF163E69),
                  foregroundColor: const Color(0xFF72B9FF),
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                    side: const BorderSide(color: Color(0xFF2869AD)),
                  ),
                ),
                icon: const Icon(Icons.format_list_numbered_rounded, size: 16),
                label: Text(
                  'View all ${ranked.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            else
              Text(
                '${ranked.length} ${ranked.length == 1 ? 'member' : 'members'}',
                style: const TextStyle(color: Color(0xFF7F899A), fontSize: 12),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (ranked.length > 3) ...[
          _MoreStandingsHint(
            previewCount: ranked.length > 5 ? 5 : ranked.length,
          ),
          const SizedBox(height: 8),
        ],
        _StandingsCard(
          entries: ranked.take(5).toList(),
          metric: selectedMetric,
          valueFor: valueFor,
          unit: unitFor(selectedMetric),
          onTap: onOpenPlayer,
        ),
      ],
    );
  }
}

class _LeaderboardHeader extends StatelessWidget {
  const _LeaderboardHeader({
    required this.groups,
    required this.selectedGroup,
    required this.onGroupSelected,
  });

  final List<String> groups;
  final String? selectedGroup;
  final ValueChanged<String> onGroupSelected;

  Future<void> _showGroupPicker(BuildContext context) async {
    if (groups.isEmpty) return;
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
                'Switch the competition shown on this leaderboard.',
                style: TextStyle(color: Color(0xFF8590A2), fontSize: 13),
              ),
              const SizedBox(height: 18),
              ...groups.map((group) {
                final active = group == selectedGroup;
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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Leaderboard',
        style: TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 12),
      InkWell(
        onTap: groups.isEmpty ? null : () => _showGroupPicker(context),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF11151B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF202631)),
          ),
          child: Row(
            children: [
              GroupAvatar(name: selectedGroup, size: 42),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            selectedGroup ?? 'No group selected',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      'Compete across every move',
                      style: TextStyle(color: Color(0xFF8590A2), fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (groups.isNotEmpty)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF182231),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(
                    Icons.unfold_more_rounded,
                    color: Color(0xFF5BA9FF),
                    size: 19,
                  ),
                ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({
    required this.options,
    required this.selected,
    required this.onSelected,
  });
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = options
        .indexOf(selected)
        .clamp(0, options.length - 1);
    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF11151B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF202631)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / options.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                left: segmentWidth * selectedIndex,
                top: 0,
                bottom: 0,
                width: segmentWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF176DCA),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final option in options)
                    Expanded(
                      child: InkWell(
                        onTap: () => onSelected(option),
                        borderRadius: BorderRadius.circular(6),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              color: option == selected
                                  ? Colors.white
                                  : const Color(0xFF8D97A8),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                            child: Text(
                              option == 'This Week'
                                  ? 'Week'
                                  : option == 'This Month'
                                  ? 'Month'
                                  : 'Today',
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ChampionCard extends StatelessWidget {
  const _ChampionCard({
    required this.leader,
    required this.metric,
    required this.value,
    required this.unit,
    required this.onTap,
  });
  final MotionStats leader;
  final String metric;
  final double value;
  final String unit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF315E91)),
        gradient: const LinearGradient(
          colors: [Color(0xFF102A4B), Color(0xFF091522)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26168BFF),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _Avatar(stats: leader, radius: 36),
              Positioned(
                right: -4,
                bottom: -3,
                child: Container(
                  width: 27,
                  height: 27,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFFFE37A), Color(0xFFD99500)],
                    ),
                  ),
                  child: const Text(
                    '1',
                    style: TextStyle(
                      color: Color(0xFF17130A),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$metric leader',
                  style: const TextStyle(
                    color: Color(0xFF72B9FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  leader.isCurrentUser ? '${leader.name} · You' : leader.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '${_formatMetric(value, metric)} $unit',
                  style: const TextStyle(
                    color: Color(0xFF3FA5FF),
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  leader.isCurrentUser
                      ? 'Tap to view your full stat line'
                      : 'Tap to view ${leader.name}\'s full stat line',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF7F93AA),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF6E7B8F)),
        ],
      ),
    ),
  );
}

class _CategoryLeaderCard extends StatelessWidget {
  const _CategoryLeaderCard({
    required this.metric,
    required this.leader,
    required this.value,
    required this.unit,
    required this.selected,
    required this.onTap,
  });
  final String metric;
  final MotionStats leader;
  final double value;
  final String unit;
  final bool selected;
  final VoidCallback onTap;

  static const _surface = Color(0xFF11161E);
  static const _border = Color(0xFF1C2430);

  String get _label => switch (metric) {
    'Calories' => 'Active calories',
    'Exercise' => 'Exercise',
    'Miles' => 'Miles',
    _ => 'Steps',
  };

  IconData get _icon => switch (metric) {
    'Miles' => Icons.location_on_rounded,
    'Calories' => Icons.local_fire_department_rounded,
    'Exercise' => Icons.timer_outlined,
    _ => Icons.directions_walk_rounded,
  };

  Color get _accent => switch (metric) {
    'Miles' => const Color(0xFF16D6A1),
    'Calories' => const Color(0xFFFF8A1E),
    'Exercise' => const Color(0xFF9A6CFF),
    _ => const Color(0xFF238BFF),
  };

  @override
  Widget build(BuildContext context) {
    final name = leader.isCurrentUser ? 'You' : leader.name;
    final accent = _accent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 104,
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          color: selected
              ? Color.alphaBlend(accent.withValues(alpha: 0.10), _surface)
              : _surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? accent : _border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(7),
              ),
              child: metric == 'Steps'
                  ? FootstepsIcon(size: 15, color: accent)
                  : Icon(_icon, color: accent, size: 15),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          _label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF8D98AA),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 92),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            _formatMetric(value, metric),
                            maxLines: 1,
                            style: TextStyle(
                              color: accent,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          unit.toUpperCase(),
                          style: TextStyle(
                            color: accent.withValues(alpha: 0.82),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StandingsCard extends StatelessWidget {
  const _StandingsCard({
    required this.entries,
    required this.metric,
    required this.valueFor,
    required this.unit,
    required this.onTap,
  });
  final List<MotionStats> entries;
  final String metric;
  final double Function(MotionStats, String) valueFor;
  final String unit;
  final void Function(MotionStats, int) onTap;

  @override
  Widget build(BuildContext context) {
    final compact = entries.length >= 3;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF11151B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF202631)),
      ),
      child: Column(
        children: entries.asMap().entries.map((row) {
          final rank = row.key + 1;
          final stats = row.value;
          return Column(
            children: [
              if (rank > 1)
                const Divider(height: 1, indent: 62, color: Color(0xFF222833)),
              InkWell(
                onTap: () => onTap(stats, rank),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: compact ? 3 : 9,
                  ),
                  color: stats.isCurrentUser
                      ? const Color(0x66112F52)
                      : Colors.transparent,
                  child: Row(
                    children: [
                      _Medal(rank: rank, compact: compact),
                      const SizedBox(width: 10),
                      _Avatar(stats: stats, radius: compact ? 16 : 18),
                      SizedBox(width: compact ? 10 : 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stats.isCurrentUser
                                  ? '${stats.name} · You'
                                  : stats.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: stats.isCurrentUser
                                    ? const Color(0xFF58ACFF)
                                    : Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${_format(stats.activeCalories)} CAL  ·  ${stats.exerciseMinutes} MIN',
                              style: const TextStyle(
                                color: Color(0xFF788395),
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${_formatMetric(valueFor(stats, metric), metric)}\n$unit',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: stats.isCurrentUser
                              ? const Color(0xFF45A4FF)
                              : Colors.white,
                          fontSize: 13,
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF536073),
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.stats, required this.radius});
  final MotionStats stats;
  final double radius;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: const Color(0xFF23324A),
    backgroundImage: stats.avatarUrl?.isNotEmpty == true
        ? NetworkImage(stats.avatarUrl!)
        : null,
    child: stats.avatarUrl?.isNotEmpty == true
        ? null
        : Text(
            stats.name.isEmpty
                ? '?'
                : stats.name.characters.first.toUpperCase(),
            style: TextStyle(
              color: Colors.white,
              fontSize: radius * .7,
              fontWeight: FontWeight.w800,
            ),
          ),
  );
}

class _Medal extends StatelessWidget {
  const _Medal({required this.rank, required this.compact});
  final int rank;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = rank == 1
        ? const Color(0xFFFFC22E)
        : rank == 2
        ? const Color(0xFFBBC6D6)
        : rank == 3
        ? const Color(0xFFC98246)
        : const Color(0xFF536073);
    return Container(
      width: compact ? 26 : 28,
      height: compact ? 26 : 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [color, color.withValues(alpha: .45)]),
        border: Border.all(color: color.withValues(alpha: .8)),
      ),
      child: Text(
        '$rank',
        style: TextStyle(
          color: rank <= 3 ? const Color(0xFF121418) : Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.w800,
    ),
  );
}

class _MoreStandingsHint extends StatelessWidget {
  const _MoreStandingsHint({required this.previewCount});

  final int previewCount;

  @override
  Widget build(BuildContext context) => Container(
    height: 30,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: const Color(0xFF10233C),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFF225A94)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.keyboard_double_arrow_down_rounded,
          color: Color(0xFF45A4FF),
          size: 17,
        ),
        const SizedBox(width: 7),
        Text(
          'Scroll through the top $previewCount',
          style: const TextStyle(
            color: Color(0xFF72B9FF),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 7),
        const Icon(
          Icons.keyboard_double_arrow_down_rounded,
          color: Color(0xFF45A4FF),
          size: 17,
        ),
      ],
    ),
  );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 54),
    decoration: BoxDecoration(
      color: const Color(0xFF11151B),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFF202631)),
    ),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Color(0xFF8F99AA), fontSize: 14),
    ),
  );
}

String _format(num value) => value.round().toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => ',',
);

/// Miles keeps a decimal — rounding would flatten a day's walk to 0 or 1.
/// Matches the one-decimal display used on the home screen.
String _formatMetric(double value, String metric) =>
    metric == 'Miles' ? value.toStringAsFixed(1) : _format(value);
