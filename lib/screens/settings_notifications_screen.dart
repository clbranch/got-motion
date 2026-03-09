import 'package:flutter/material.dart';

class SettingsNotificationsScreen extends StatefulWidget {
  const SettingsNotificationsScreen({super.key});

  @override
  State<SettingsNotificationsScreen> createState() => _SettingsNotificationsScreenState();
}

class _SettingsNotificationsScreenState extends State<SettingsNotificationsScreen> {
  static const Color _background = Color(0xFF0B0B0F);
  static const Color _cardBg = Color(0xFF14141A);
  static const Color _accent = Color(0xFF3B82F6);

  bool _leaderboardUpdates = true;
  bool _groupInvites = true;
  bool _dailyReminders = false;
  bool _friendActivity = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        title: const Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildToggleItem('Leaderboard updates', _leaderboardUpdates, (v) => setState(() => _leaderboardUpdates = v)),
            const SizedBox(height: 12),
            _buildToggleItem('Group invites', _groupInvites, (v) => setState(() => _groupInvites = v)),
            const SizedBox(height: 12),
            _buildToggleItem('Daily reminders', _dailyReminders, (v) => setState(() => _dailyReminders = v)),
            const SizedBox(height: 12),
            _buildToggleItem('Friend activity', _friendActivity, (v) => setState(() => _friendActivity = v)),
            const SizedBox(height: 24),
            Text(
              'Notification settings are currently stored locally. Push notifications coming soon.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleItem(String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: _accent,
          ),
        ],
      ),
    );
  }
}
