import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'settings_account_screen.dart';
import 'settings_notifications_screen.dart';
import 'settings_health_permissions_screen.dart';
import 'settings_connected_devices_screen.dart';
import 'settings_privacy_screen.dart';

/// V1 Settings shell: header and list of placeholder sections.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const Color _background = Color(0xFF0B0B0F);
  static const Color _cardBg = Color(0xFF14141A);
  static const double _pagePadding = 16.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(_pagePadding, 16, _pagePadding, 24),
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildSettingsList(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        'Settings',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: 0.95),
        ),
      ),
    );
  }

  Widget _buildSettingsList(BuildContext context) {
    final items = [
      _SettingsItem(
        icon: Icons.person_outline_rounded,
        label: 'Account',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsAccountScreen()),
          );
        },
      ),
      _SettingsItem(
        icon: Icons.notifications_outlined,
        label: 'Notifications',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsNotificationsScreen()),
          );
        },
      ),
      _SettingsItem(
        icon: Icons.favorite_border_rounded,
        label: 'Health Permissions',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsHealthPermissionsScreen()),
          );
        },
      ),
      _SettingsItem(
        icon: Icons.watch_rounded,
        label: 'Connected Devices',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsConnectedDevicesScreen()),
          );
        },
      ),
      _SettingsItem(
        icon: Icons.lock_outline_rounded,
        label: 'Privacy',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsPrivacyScreen()),
          );
        },
      ),
      _SettingsItem(
        icon: Icons.logout_rounded,
        label: 'Sign Out',
        onTap: () {
          AuthService.signOut();
          // AuthGate listens to auth state and will show AuthScreen
        },
        isDestructive: true,
      ),
    ];
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
            items[i],
          ],
        ],
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  const _SettingsItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? const Color(0xFFEF4444) : Colors.white.withValues(alpha: 0.85);
    final iconColor = isDestructive ? const Color(0xFFEF4444) : Colors.white.withValues(alpha: 0.5);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
