import 'package:flutter/material.dart';

import '../models/notification_preferences.dart';
import '../services/notification_preferences_service.dart';
import '../services/push_notification_service.dart';
import '../widgets/settings_ui.dart';

class SettingsNotificationsScreen extends StatefulWidget {
  const SettingsNotificationsScreen({super.key});

  @override
  State<SettingsNotificationsScreen> createState() =>
      _SettingsNotificationsScreenState();
}

class _SettingsNotificationsScreenState
    extends State<SettingsNotificationsScreen> {
  NotificationPreferences? _prefs;
  PushPermissionState _permission = PushPermissionState.notDetermined;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await pushNotificationService.ensureHandlers();
      final results = await Future.wait([
        notificationPreferencesService.load(),
        pushNotificationService.currentPermission(),
      ]);
      if (!mounted) return;
      setState(() {
        _prefs = results[0] as NotificationPreferences;
        _permission = results[1] as PushPermissionState;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _save(NotificationPreferences next) async {
    setState(() {
      _prefs = next;
      _busy = true;
    });
    await notificationPreferencesService.save(next);
    if (!mounted) return;
    setState(() => _busy = false);
  }

  Future<void> _onMasterPushChanged(bool enabled) async {
    final current = _prefs;
    if (current == null || _busy) return;

    if (!enabled) {
      await pushNotificationService.disablePushOnDevice();
      await _save(current.copyWith(pushEnabled: false));
      return;
    }

    setState(() => _busy = true);
    final result = await pushNotificationService.enablePush();
    if (!mounted) return;

    if (result == PushPermissionState.granted ||
        result == PushPermissionState.provisional) {
      await _save(current.copyWith(pushEnabled: true));
      setState(() {
        _permission = result;
        _busy = false;
      });
      return;
    }

    setState(() {
      _permission = PushPermissionState.denied;
      _busy = false;
    });
    await _save(current.copyWith(pushEnabled: false));
    if (!mounted) return;
    _showDeniedSheet();
  }

  void _showDeniedSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF11151B),
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Notifications are off in iPhone Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Got Motion can’t send alerts until you allow Notifications for this app.',
                style: TextStyle(
                  color: settingsMuted,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await pushNotificationService.openSystemSettings();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: settingsAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Open iPhone Settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = _prefs;

    return Scaffold(
      backgroundColor: settingsBackground,
      body: SafeArea(
        child: _loading || prefs == null
            ? const Center(
                child: CircularProgressIndicator(color: settingsAccent),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                children: [
                  const SettingsPageHeader(
                    title: 'Notifications',
                    subtitle:
                        'Leaderboard standings for your groups — not generic get-moving spam.',
                  ),
                  const SizedBox(height: 24),
                  SettingsPanel(
                    accented: true,
                    padding: const EdgeInsets.all(18),
                    child: const Row(
                      children: [
                        _NotificationHeroIcon(),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Know where you stand',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                'Digests when you’re top 3 in a group, with how far you are from 1st.',
                                style: TextStyle(
                                  color: settingsMuted,
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  const SettingsSectionTitle('Push notifications'),
                  const SizedBox(height: 10),
                  SettingsPanel(
                    child: Column(
                      children: [
                        _toggleRow(
                          icon: Icons.notifications_active_rounded,
                          color: const Color(0xFFFFB547),
                          title: 'Enable push notifications',
                          subtitle: _permission == PushPermissionState.denied
                              ? 'Permission denied — open iPhone Settings'
                              : 'Ask iPhone for permission when you turn this on',
                          value: prefs.pushEnabled,
                          onChanged: _onMasterPushChanged,
                        ),
                        if (_permission == PushPermissionState.denied) ...[
                          const SettingsDivider(),
                          SettingsRow(
                            icon: Icons.settings_rounded,
                            iconColor: settingsAccent,
                            title: 'Open iPhone Settings',
                            subtitle: 'Allow Notifications for Got Motion',
                            onTap: () =>
                                pushNotificationService.openSystemSettings(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  const SettingsSectionTitle('Alert types'),
                  const SizedBox(height: 10),
                  SettingsPanel(
                    child: Column(
                      children: [
                        _toggleRow(
                          icon: Icons.emoji_events_outlined,
                          color: const Color(0xFFFFB547),
                          title: 'Leaderboard digests',
                          subtitle:
                              'Top 3 in your groups + gap to 1st (one digest)',
                          value: prefs.rankChanges || prefs.groupActivity,
                          enabled: prefs.pushEnabled,
                          onChanged: (v) => _save(
                            prefs.copyWith(
                              rankChanges: v,
                              groupActivity: v,
                              catchUpReminders: false,
                            ),
                          ),
                        ),
                        const SettingsDivider(),
                        _toggleRow(
                          icon: Icons.workspace_premium_rounded,
                          color: const Color(0xFF16D6A1),
                          title: 'Weekly recap / awards',
                          subtitle:
                              'Monday recap of last week\'s category leaders',
                          value: prefs.weeklyRecap,
                          enabled: prefs.pushEnabled,
                          onChanged: (v) =>
                              _save(prefs.copyWith(weeklyRecap: v)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const SettingsPanel(
                    padding: EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: settingsMuted,
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'We don’t send “get moving” morning/evening spam. Digests only fire when you’re top 3 in a group.',
                            style: TextStyle(
                              color: settingsMuted,
                              fontSize: 13,
                              height: 1.4,
                            ),
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

  Widget _toggleRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: SettingsRow(
        icon: icon,
        iconColor: color,
        title: title,
        subtitle: subtitle,
        onTap: enabled && !_busy ? () => onChanged(!value) : null,
        trailing: Switch.adaptive(
          value: value,
          onChanged: enabled && !_busy ? onChanged : null,
          activeTrackColor: settingsAccent,
        ),
      ),
    );
  }
}

class _NotificationHeroIcon extends StatelessWidget {
  const _NotificationHeroIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: const Color(0xFFFFB547).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.notifications_active_rounded,
        color: Color(0xFFFFB547),
        size: 28,
      ),
    );
  }
}
