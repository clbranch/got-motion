import '../models/weekly_group_award.dart';

/// Call-of-Duty-style weekly highlight copy — personal for celebrations,
/// flexible for group leader cards.
class WeeklyAwardCopy {
  WeeklyAwardCopy._();

  static bool sweptAllCategories(List<WeeklyAwardWinner> wins) {
    if (wins.length < WeeklyAwardCategory.values.length) return false;
    final categories = wins.map((w) => w.category).toSet();
    return categories.length == WeeklyAwardCategory.values.length;
  }

  static String celebrationHeadline(List<WeeklyAwardWinner> wins) {
    if (sweptAllCategories(wins)) {
      return 'The LeBron of Motion!';
    }
    if (wins.length == 1) {
      return wins.first.category.headlineYou;
    }
    return 'You\'re stacking awards';
  }

  static String celebrationSubhead(String groupName) =>
      'Last week in $groupName';

  static String celebrationBody({
    required List<WeeklyAwardWinner> wins,
    required String groupName,
  }) {
    if (sweptAllCategories(wins)) {
      return 'You swept every category — steps, calories, exercise, '
          'and miles. The LeBron of Motion in $groupName.';
    }
    return wins.map((w) => w.category.highlightYou(w.value)).join('\n\n');
  }

  static String cardBannerForUser(List<WeeklyAwardWinner> wins) {
    if (sweptAllCategories(wins)) {
      return 'The LeBron of Motion last week';
    }
    if (wins.length == 1) {
      return wins.first.category.shortBadgeYou;
    }
    return '${wins.length} weekly awards last week';
  }

  static String tileLine({
    required WeeklyAwardCategory category,
    required String? winnerName,
    required bool isYou,
    required num value,
  }) {
    if (winnerName == null || winnerName.isEmpty) {
      return 'No leader yet';
    }
    if (isYou) return category.highlightYou(value);
    return category.highlightThem(winnerName, value);
  }

  /// Lock-screen title for end-of-week push / in-app notification.
  static String pushTitle(List<WeeklyAwardWinner> wins) {
    if (sweptAllCategories(wins)) {
      return 'The LeBron of Motion!';
    }
    if (wins.length == 1) {
      return wins.first.category.pushTitleYou;
    }
    return 'You\'re stacking awards';
  }

  /// Lock-screen body for end-of-week push / in-app notification.
  static String pushBody({
    required List<WeeklyAwardWinner> wins,
    required String groupName,
  }) {
    if (sweptAllCategories(wins)) {
      return 'You swept steps, calories, exercise, and miles in '
          '$groupName. The LeBron of Motion.';
    }
    if (wins.length == 1) {
      final w = wins.first;
      return w.category.pushBodyYou(groupName: groupName, value: w.value);
    }
    final lines = wins
        .map((w) => '${w.category.cardTitle} (${w.category.formatValue(w.value)})')
        .join(', ');
    return 'You led $groupName in $lines. Keep that motion going.';
  }

  static String groupRecapTitle(String groupName) =>
      'Last week in $groupName';

  static String groupRecapBody({
    required String groupName,
    required List<WeeklyAwardWinner> winners,
  }) {
    if (winners.isEmpty) {
      return 'Last week\'s board is up in $groupName. Open Group and get after this week.';
    }
    final byUser = <String, List<WeeklyAwardWinner>>{};
    for (final w in winners) {
      byUser.putIfAbsent(w.userId, () => []).add(w);
    }
    if (byUser.length == 1) {
      final only = winners.first;
      if (sweptAllCategories(winners)) {
        return '${only.displayName} swept last week in $groupName. '
            'Open Group — new week starts now.';
      }
      final cats = winners.map((w) => w.category.cardTitle.toLowerCase()).join(' and ');
      return '${only.displayName} took $cats in $groupName last week. '
          'Open Group to see the board.';
    }
    return 'Last week\'s leaders are up in $groupName. '
        'Open Group to see who took it — then get after this week.';
  }
}

extension WeeklyAwardCopyCategory on WeeklyAwardCategory {
  /// Card / leaderboard label (e.g. "Step Leader").
  String get cardTitle => title;

  String get headlineYou => switch (this) {
    WeeklyAwardCategory.steps => 'Big Stepper',
    WeeklyAwardCategory.calories => 'Calorie King',
    WeeklyAwardCategory.exercise => 'Exercise Pro',
    WeeklyAwardCategory.miles => 'Distance Leader',
  };

  String get pushTitleYou => headlineYou;

  String pushBodyYou({required String groupName, required num value}) =>
      switch (this) {
        WeeklyAwardCategory.steps =>
          'You led $groupName in steps last week — ${formatValue(value)}. '
          'Nobody else came close.',
        WeeklyAwardCategory.calories =>
          'Most active calories in $groupName last week — ${formatValue(value)}. '
          'You burned it up.',
        WeeklyAwardCategory.exercise =>
          'Most exercise minutes in $groupName last week — ${formatValue(value)}. '
          'You really moved that weight.',
        WeeklyAwardCategory.miles =>
          'Most miles in $groupName last week — ${formatValue(value)}. '
          'You ran circles around everyone.',
      };

  String get shortBadgeYou => switch (this) {
    WeeklyAwardCategory.steps => 'You were the big stepper last week',
    WeeklyAwardCategory.calories =>
      'You burned it off faster than anyone last week',
    WeeklyAwardCategory.exercise => 'You really moved that weight last week',
    WeeklyAwardCategory.miles => 'You ran circles around the group last week',
  };

  String highlightYou(num value) => switch (this) {
    WeeklyAwardCategory.steps =>
      'Hey — you were the big stepper last week with ${formatValue(value)}.',
    WeeklyAwardCategory.calories =>
      'You burned it all last week — ${formatValue(value)} and nobody was close.',
    WeeklyAwardCategory.exercise =>
      'You really moved that weight last week — ${formatValue(value)} of work.',
    WeeklyAwardCategory.miles =>
      'You ran miles around the group last week — ${formatValue(value)}.',
  };

  String highlightThem(String name, num value) => switch (this) {
    WeeklyAwardCategory.steps =>
      '$name was the big stepper last week — ${formatValue(value)}.',
    WeeklyAwardCategory.calories =>
      '$name burned it off faster than anyone last week — ${formatValue(value)}.',
    WeeklyAwardCategory.exercise =>
      '$name really moved that weight last week — ${formatValue(value)}.',
    WeeklyAwardCategory.miles =>
      '$name ran miles around the group last week — ${formatValue(value)}.',
  };
}
