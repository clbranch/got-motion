enum AppNotificationType {
  rankMovement,
  catchUp,
  leaderUpdate,
  dailyReturn,
  weeklyAward,
  groupActivity,
  workoutLogged,
  unknown;

  static AppNotificationType fromWire(String? value) {
    switch (value) {
      case 'rank_movement':
        return AppNotificationType.rankMovement;
      case 'catch_up':
        return AppNotificationType.catchUp;
      case 'leader_update':
        return AppNotificationType.leaderUpdate;
      case 'daily_return':
        return AppNotificationType.dailyReturn;
      case 'weekly_award':
        return AppNotificationType.weeklyAward;
      case 'group_activity':
        return AppNotificationType.groupActivity;
      case 'workout_logged':
        return AppNotificationType.workoutLogged;
      default:
        return AppNotificationType.unknown;
    }
  }

  String get wire {
    switch (this) {
      case AppNotificationType.rankMovement:
        return 'rank_movement';
      case AppNotificationType.catchUp:
        return 'catch_up';
      case AppNotificationType.leaderUpdate:
        return 'leader_update';
      case AppNotificationType.dailyReturn:
        return 'daily_return';
      case AppNotificationType.weeklyAward:
        return 'weekly_award';
      case AppNotificationType.groupActivity:
        return 'group_activity';
      case AppNotificationType.workoutLogged:
        return 'workout_logged';
      case AppNotificationType.unknown:
        return 'unknown';
    }
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.groupId,
    this.data = const {},
    this.readAt,
    this.isLocalSample = false,
  });

  final String id;
  final String userId;
  final String? groupId;
  final AppNotificationType type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final DateTime? readAt;
  final bool isLocalSample;

  bool get isUnread => readAt == null;

  AppNotification copyWith({DateTime? readAt, bool clearReadAt = false}) {
    return AppNotification(
      id: id,
      userId: userId,
      groupId: groupId,
      type: type,
      title: title,
      body: body,
      data: data,
      createdAt: createdAt,
      readAt: clearReadAt ? null : (readAt ?? this.readAt),
      isLocalSample: isLocalSample,
    );
  }

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    final rawData = map['data'];
    return AppNotification(
      id: map['id'].toString(),
      userId: map['user_id'].toString(),
      groupId: map['group_id']?.toString(),
      type: AppNotificationType.fromWire(map['type']?.toString()),
      title: (map['title'] ?? '').toString(),
      body: (map['body'] ?? '').toString(),
      data: rawData is Map<String, dynamic>
          ? Map<String, dynamic>.from(rawData)
          : const {},
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      readAt: map['read_at'] == null
          ? null
          : DateTime.tryParse(map['read_at'].toString())?.toLocal(),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'id': id,
      'user_id': userId,
      'group_id': groupId,
      'type': type.wire,
      'title': title,
      'body': body,
      'data': data,
      'created_at': createdAt.toUtc().toIso8601String(),
      if (readAt != null) 'read_at': readAt!.toUtc().toIso8601String(),
    };
  }
}
