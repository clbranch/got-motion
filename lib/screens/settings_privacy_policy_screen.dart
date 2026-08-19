import 'package:flutter/material.dart';

import '../widgets/settings_ui.dart';

class SettingsPrivacyPolicyScreen extends StatelessWidget {
  const SettingsPrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: settingsBackground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
          children: const [
            SettingsPageHeader(
              title: 'Privacy Policy',
              subtitle: 'Effective August 18, 2026',
            ),
            SizedBox(height: 24),
            _PolicySection(
              title: 'What Got Motion collects',
              body:
                  'Got Motion stores your account identifier, email address, display name, profile photo, daily goals, group memberships, invite and administrator information, notification preferences, device push tokens you enable, and activity you choose to sync. Supported Apple Health types are steps, walking and running distance, active energy (calories), exercise minutes, and stand hours.',
            ),
            _PolicySection(
              title: 'Apple Health',
              body:
                  'Health activity is read only after you grant access. You can change or revoke access in Apple Health at any time. Apple does not tell Got Motion whether a read type was denied; denied data simply appears unavailable. Got Motion does not use Health data for advertising and does not sell Health data. Activity that has already synced may remain in Got Motion until your account is deleted.',
            ),
            _PolicySection(
              title: 'How data is used',
              body:
                  'We use your data to display your progress, calculate group leaderboards and rankings, operate groups and invitations, remember goals and preferences, send the push notifications you opt into, and maintain the service.',
            ),
            _PolicySection(
              title: 'What your group sees',
              body:
                  'People in a shared group can see your display name, profile photo, rank, and the activity statistics used in that competition (steps, calories, exercise minutes, and distance). Your email address is not shown to group members.',
            ),
            _PolicySection(
              title: 'Service providers',
              body:
                  'Got Motion uses Supabase to provide authentication, database, file storage, and optional push delivery infrastructure. These providers process information only to operate the app. Got Motion does not sell personal information or Health data.',
            ),
            _PolicySection(
              title: 'Your choices',
              body:
                  'You can change Health permissions in Apple Health. From Privacy, you can download a copy of data stored by Got Motion for your signed-in account. You can permanently delete your account from Privacy or Account settings; related app data is removed with your account.',
            ),
            _PolicySection(
              title: 'Retention and security',
              body:
                  'Data is retained while your account is active or as needed to operate and protect the service. We use access controls and encrypted network connections, but no system can guarantee absolute security.',
            ),
            _PolicySection(
              title: 'Children and changes',
              body:
                  'Got Motion is not intended for children under 13. We may update this policy; the effective date above will change when we do.',
            ),
            _PolicySection(
              title: 'Contact',
              body:
                  'Questions about privacy: contact Brogrammers Agency, Inc. through the support channel listed on the App Store listing for Got Motion.',
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              color: settingsMuted,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
