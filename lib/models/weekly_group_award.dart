/// Weekly group award categories (Mon–Sun, live leaders).
enum WeeklyAwardCategory {
  steps,
  calories,
  exercise,
  miles,
}

extension WeeklyAwardCategoryX on WeeklyAwardCategory {
  String get title => switch (this) {
    WeeklyAwardCategory.steps => 'Step Leader',
    WeeklyAwardCategory.calories => 'Calorie King',
    WeeklyAwardCategory.exercise => 'Exercise Pro',
    WeeklyAwardCategory.miles => 'Distance Leader',
  };

  String get emoji => switch (this) {
    WeeklyAwardCategory.steps => '👟',
    WeeklyAwardCategory.calories => '🔥',
    WeeklyAwardCategory.exercise => '⏱️',
    WeeklyAwardCategory.miles => '📍',
  };

  String formatValue(num value) => switch (this) {
    WeeklyAwardCategory.steps => _formatInt(value.round()),
    WeeklyAwardCategory.calories => '${value.round()} cal',
    WeeklyAwardCategory.exercise => '${value.round()} min',
    WeeklyAwardCategory.miles => value is double && value != value.roundToDouble()
        ? '${value.toStringAsFixed(1)} mi'
        : '${value.round()} mi',
  };
}

String _formatInt(int value) =>
    value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );

class WeeklyAwardWinner {
  const WeeklyAwardWinner({
    required this.category,
    required this.userId,
    required this.displayName,
    required this.value,
    this.avatarUrl,
  });

  final WeeklyAwardCategory category;
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final num value;
}

class WeeklyGroupAwards {
  const WeeklyGroupAwards({
    required this.weekKey,
    required this.weekLabel,
    required this.winners,
  });

  final String weekKey;
  final String weekLabel;
  final List<WeeklyAwardWinner> winners;

  WeeklyAwardWinner? winnerFor(WeeklyAwardCategory category) {
    for (final w in winners) {
      if (w.category == category) return w;
    }
    return null;
  }

  List<WeeklyAwardWinner> winsForUser(String userId) =>
      winners.where((w) => w.userId == userId).toList(growable: false);

  bool userLeadsAny(String userId) => winsForUser(userId).isNotEmpty;
}
