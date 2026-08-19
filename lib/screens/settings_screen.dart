import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../widgets/settings_ui.dart';
import 'settings_account_screen.dart';
import 'settings_connected_devices_screen.dart';
import 'settings_health_permissions_screen.dart';
import 'settings_notifications_screen.dart';
import 'settings_privacy_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ProfileData? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await ProfileService().getCurrentProfile();
    if (mounted) setState(() => _profile = profile);
  }

  Future<void> _openAccount() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsAccountScreen()));
    await _loadProfile();
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: settingsSurface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sign out of Got Motion?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your activity and group history will stay with your account.',
                style: TextStyle(
                  color: settingsMuted,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB4232B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign out'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true) await AuthService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final name = _profile?.displayLabel ?? 'Your account';
    final email = _profile?.email ?? user?.email ?? '';
    final avatarUrl = _profile?.avatarUrl;

    return Scaffold(
      backgroundColor: settingsBackground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: [
            const SettingsPageHeader(
              title: 'Settings',
              subtitle: 'Your account, activity, and privacy controls.',
              showBack: false,
            ),
            const SizedBox(height: 24),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _openAccount,
                borderRadius: BorderRadius.circular(8),
                child: SettingsPanel(
                  accented: true,
                  padding: const EdgeInsets.all(17),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: const Color(0xFF1C3659),
                        foregroundImage:
                            avatarUrl != null && avatarUrl.isNotEmpty
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: Text(
                          name.isEmpty
                              ? '?'
                              : name.characters.first.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF6CB6FF),
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: settingsMuted,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 9),
                            const Text(
                              'Manage profile and sign-in',
                              style: TextStyle(
                                color: Color(0xFF62B2FF),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF62B2FF),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 26),
            const SettingsSectionTitle('Activity & alerts'),
            const SizedBox(height: 10),
            SettingsPanel(
              child: Column(
                children: [
                  SettingsRow(
                    icon: Icons.notifications_active_outlined,
                    iconColor: const Color(0xFFFFB547),
                    title: 'Notifications',
                    subtitle: 'Reminders, rankings, and group activity',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SettingsNotificationsScreen(),
                      ),
                    ),
                  ),
                  const SettingsDivider(),
                  SettingsRow(
                    icon: Icons.favorite_outline_rounded,
                    iconColor: const Color(0xFFFF5A67),
                    title: 'Health permissions',
                    subtitle: 'Steps, CAL, MIN, distance, and stand hours',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SettingsHealthPermissionsScreen(),
                      ),
                    ),
                  ),
                  const SettingsDivider(),
                  SettingsRow(
                    icon: Icons.watch_rounded,
                    iconColor: const Color(0xFF38D6C5),
                    title: 'Connected devices',
                    subtitle: 'Apple Health and future wearables',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SettingsConnectedDevicesScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            const SettingsSectionTitle('Privacy & security'),
            const SizedBox(height: 10),
            SettingsPanel(
              child: SettingsRow(
                icon: Icons.shield_outlined,
                iconColor: const Color(0xFF9B7CFF),
                title: 'Privacy',
                subtitle: 'Visibility, health data, and account controls',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SettingsPrivacyScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 26),
            SettingsPanel(
              child: SettingsRow(
                icon: Icons.logout_rounded,
                iconColor: const Color(0xFFFF575F),
                title: 'Sign out',
                subtitle: 'Sign out of this device',
                destructive: true,
                onTap: _confirmSignOut,
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFFF575F),
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Center(
              child: Text(
                'GOT MOTION',
                style: TextStyle(
                  color: Color(0xFF536071),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
