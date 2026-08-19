/// Daily all-rings-closed champagne copy — one variant per calendar day.
class GoalCelebrationCopy {
  GoalCelebrationCopy._();

  static const _variants = [
    (headline: 'All gas. Full motion.', body: 'Every daily goal is complete.'),
    (
      headline: 'Motion all day.',
      body: 'You closed every goal. Keep it rolling.',
    ),
    (headline: 'Motion stamped.', body: 'You handled every goal today.'),
    (
      headline: 'You put in work today.',
      body: 'That\'s how you close out a day.',
    ),
  ];

  static ({String headline, String body}) forToday([DateTime? now]) {
    final local = now ?? DateTime.now();
    final index = local.day % _variants.length;
    return _variants[index];
  }
}
