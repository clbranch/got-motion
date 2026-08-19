class NotificationPreferences {
  const NotificationPreferences({
    required this.userId,
    this.pushEnabled = false,
    this.rankChanges = true,
    this.catchUpReminders = true,
    this.groupActivity = true,
    this.weeklyRecap = true,
  });

  final String userId;
  final bool pushEnabled;
  final bool rankChanges;
  final bool catchUpReminders;
  final bool groupActivity;
  final bool weeklyRecap;

  NotificationPreferences copyWith({
    bool? pushEnabled,
    bool? rankChanges,
    bool? catchUpReminders,
    bool? groupActivity,
    bool? weeklyRecap,
  }) {
    return NotificationPreferences(
      userId: userId,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      rankChanges: rankChanges ?? this.rankChanges,
      catchUpReminders: catchUpReminders ?? this.catchUpReminders,
      groupActivity: groupActivity ?? this.groupActivity,
      weeklyRecap: weeklyRecap ?? this.weeklyRecap,
    );
  }

  factory NotificationPreferences.defaults(String userId) {
    return NotificationPreferences(userId: userId);
  }

  factory NotificationPreferences.fromMap(Map<String, dynamic> map) {
    return NotificationPreferences(
      userId: map['user_id'].toString(),
      pushEnabled: map['push_enabled'] == true,
      rankChanges: map['rank_changes'] != false,
      catchUpReminders: map['catch_up_reminders'] != false,
      groupActivity: map['group_activity'] != false,
      weeklyRecap: map['weekly_recap'] != false,
    );
  }

  Map<String, dynamic> toUpsertMap() {
    return {
      'user_id': userId,
      'push_enabled': pushEnabled,
      'rank_changes': rankChanges,
      'catch_up_reminders': catchUpReminders,
      'group_activity': groupActivity,
      'weekly_recap': weeklyRecap,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}
