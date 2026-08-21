import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_notification.dart';
import '../services/notification_service.dart';
import '../services/main_nav_service.dart';
import '../screens/workout_detail_screen.dart';
import '../widgets/settings_ui.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  @override
  void initState() {
    super.initState();
    notificationService.addListener(_onChange);
    unawaited(notificationService.refresh());
  }

  @override
  void dispose() {
    notificationService.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final items = notificationService.items;
    final unread = notificationService.unreadCount;

    return Scaffold(
      backgroundColor: settingsBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Back',
                    style: IconButton.styleFrom(foregroundColor: Colors.white),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (unread > 0)
                    TextButton(
                      onPressed: () => notificationService.markAllRead(),
                      child: const Text(
                        'Mark all read',
                        style: TextStyle(
                          color: settingsAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (notificationService.usingLocalOnly)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  'Sample notifications until live events are connected.',
                  style: TextStyle(color: settingsMuted, fontSize: 13),
                ),
              ),
            Expanded(
              child: notificationService.loading && items.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(color: settingsAccent),
                    )
                  : items.isEmpty
                  ? const _EmptyState()
                  : RefreshIndicator(
                      color: settingsAccent,
                      backgroundColor: settingsSurface,
                      onRefresh: notificationService.refresh,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _NotificationRow(
                            notification: item,
                            onTap: () {
                              notificationService.markRead(item.id);
                              if (item.type == AppNotificationType.weeklyAward) {
                                Navigator.of(context).pop();
                                mainNavService.goToGroup();
                                return;
                              }
                              if (item.type ==
                                  AppNotificationType.workoutLogged) {
                                final workoutId =
                                    item.data['workout_id']?.toString();
                                Navigator.of(context).pop();
                                if (workoutId != null && workoutId.isNotEmpty) {
                                  openWorkoutDetail(
                                    context,
                                    workoutId: workoutId,
                                  );
                                } else {
                                  mainNavService.goToTab(0);
                                }
                              }
                            },
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFF45A4FF),
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              'You are all caught up',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Rank moves, catch-up nudges, and group leaders will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: settingsMuted, fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = notification.isUnread;
    final meta = _metaFor(notification.type);

    return Material(
      color: unread ? const Color(0xFF121A26) : settingsSurface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: unread
                  ? settingsAccent.withValues(alpha: 0.35)
                  : settingsBorder,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: meta.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(meta.icon, color: meta.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: unread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (unread)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 8, top: 4),
                            decoration: const BoxDecoration(
                              color: settingsAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: const TextStyle(
                        color: Color(0xFFA4ADBB),
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _relativeTime(notification.createdAt),
                      style: const TextStyle(
                        color: Color(0xFF6F7A8C),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ({IconData icon, Color color}) _metaFor(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.rankMovement:
        return (
          icon: Icons.emoji_events_rounded,
          color: const Color(0xFFFFB547),
        );
      case AppNotificationType.catchUp:
        return (icon: Icons.directions_walk_rounded, color: settingsAccent);
      case AppNotificationType.leaderUpdate:
        return (
          icon: Icons.local_fire_department_rounded,
          color: const Color(0xFFFF8A1E),
        );
      case AppNotificationType.dailyReturn:
        return (icon: Icons.alarm_rounded, color: const Color(0xFF9B7CFF));
      case AppNotificationType.weeklyAward:
        return (
          icon: Icons.workspace_premium_rounded,
          color: const Color(0xFF16D6A1),
        );
      case AppNotificationType.groupActivity:
        return (icon: Icons.groups_rounded, color: const Color(0xFF38D6C5));
      case AppNotificationType.workoutLogged:
        return (
          icon: Icons.fitness_center_rounded,
          color: const Color(0xFF9A73FF),
        );
      case AppNotificationType.unknown:
        return (icon: Icons.notifications_rounded, color: settingsAccent);
    }
  }

  String _relativeTime(DateTime when) {
    final now = DateTime.now();
    final diff = now.difference(when);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat.MMMd().format(when);
  }
}
