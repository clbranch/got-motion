import 'package:flutter/material.dart';

import '../widgets/settings_ui.dart';

class SettingsConnectedDevicesScreen extends StatelessWidget {
  const SettingsConnectedDevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: settingsBackground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: [
            const SettingsPageHeader(
              title: 'Devices',
              subtitle: 'See where your activity enters Got Motion.',
            ),
            const SizedBox(height: 24),
            SettingsPanel(
              accented: true,
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: const Color(0xFF38D6C5).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.watch_rounded,
                      color: Color(0xFF38D6C5),
                      size: 31,
                    ),
                  ),
                  const SizedBox(width: 15),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Apple Health',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Primary activity source',
                          style: TextStyle(
                            color: Color(0xFF62B2FF),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'iPhone, Apple Watch, and apps that sync to Health (MyZone, gym wearables, and similar).',
                          style: TextStyle(
                            color: settingsMuted,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            const SettingsSectionTitle('More integrations'),
            const SizedBox(height: 10),
            SettingsPanel(
              child: Column(
                children: const [
                  SettingsRow(
                    icon: Icons.watch_outlined,
                    iconColor: Color(0xFF62B2FF),
                    title: 'Garmin',
                    subtitle: 'Direct connection planned',
                    trailing: _ComingSoonBadge(),
                  ),
                  SettingsDivider(),
                  SettingsRow(
                    icon: Icons.circle_outlined,
                    iconColor: Color(0xFF9B7CFF),
                    title: 'Oura',
                    subtitle: 'Recovery and activity integration planned',
                    trailing: _ComingSoonBadge(),
                  ),
                  SettingsDivider(),
                  SettingsRow(
                    icon: Icons.monitor_heart_outlined,
                    iconColor: Color(0xFFFF5A67),
                    title: 'WHOOP',
                    subtitle: 'Strain and workout integration planned',
                    trailing: _ComingSoonBadge(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const SettingsPanel(
              padding: EdgeInsets.all(15),
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
                      'If a wearable writes workouts or calories to Apple Health, Got Motion includes that activity in today\'s totals and the leaderboard. Turn on Workouts and Active Energy for Got Motion in Apple Health.',
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
}

class _ComingSoonBadge extends StatelessWidget {
  const _ComingSoonBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: settingsBorder),
      ),
      child: const Text(
        'SOON',
        style: TextStyle(
          color: settingsMuted,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
