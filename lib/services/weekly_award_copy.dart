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
      'This week in $groupName';

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
      return 'The LeBron of Motion this week';
    }
    if (wins.length == 1) {
      return wins.first.category.shortBadgeYou;
    }
    return '${wins.length} weekly awards — keep pushing';
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
          'You led $groupName in steps — ${formatValue(value)}. '
          'Nobody else came close.',
        WeeklyAwardCategory.calories =>
          'Most active calories in $groupName — ${formatValue(value)}. '
          'You burned it up.',
        WeeklyAwardCategory.exercise =>
          'Most exercise minutes in $groupName — ${formatValue(value)}. '
          'You really moved that weight.',
        WeeklyAwardCategory.miles =>
          'Most miles in $groupName — ${formatValue(value)}. '
          'You ran circles around everyone.',
      };

  String get shortBadgeYou => switch (this) {
    WeeklyAwardCategory.steps => 'You\'re the big stepper this week',
    WeeklyAwardCategory.calories => 'You\'re burning it off faster than anyone',
    WeeklyAwardCategory.exercise => 'You\'re really moving that weight',
    WeeklyAwardCategory.miles => 'You\'re running circles around the group',
  };

  String highlightYou(num value) => switch (this) {
    WeeklyAwardCategory.steps =>
      'Hey — you were the big stepper this week with ${formatValue(value)}. Keep it up.',
    WeeklyAwardCategory.calories =>
      'Man, you\'re burning it all there — ${formatValue(value)} and nobody\'s close.',
    WeeklyAwardCategory.exercise =>
      'Hey, you really moving that weight — ${formatValue(value)} of work this week.',
    WeeklyAwardCategory.miles =>
      'You ran miles around these folks — ${formatValue(value)} this week. Great job.',
  };

  String highlightThem(String name, num value) => switch (this) {
    WeeklyAwardCategory.steps =>
      '$name was the big stepper this week — ${formatValue(value)}.',
    WeeklyAwardCategory.calories =>
      '$name is burning it off faster than anyone — ${formatValue(value)}.',
    WeeklyAwardCategory.exercise =>
      '$name is really moving that weight — ${formatValue(value)}.',
    WeeklyAwardCategory.miles =>
      '$name ran miles around the group — ${formatValue(value)}.',
  };
}
