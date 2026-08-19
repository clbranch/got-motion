import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/auth_service.dart';
import '../services/data_export_service.dart';
import '../widgets/settings_ui.dart';
import 'settings_privacy_policy_screen.dart';

class SettingsPrivacyScreen extends StatefulWidget {
  const SettingsPrivacyScreen({super.key});

  @override
  State<SettingsPrivacyScreen> createState() => _SettingsPrivacyScreenState();
}

class _SettingsPrivacyScreenState extends State<SettingsPrivacyScreen> {
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: settingsBackground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: [
            const SettingsPageHeader(
              title: 'Privacy',
              subtitle:
                  'Understand what your crew can see and how your data is used.',
            ),
            const SizedBox(height: 24),
            SettingsPanel(
              accented: true,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF9B7CFF,
                          ).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.shield_rounded,
                          color: Color(0xFF9B7CFF),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Your health activity stays focused on your progress and competitions.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            const SettingsSectionTitle('What your group sees'),
            const SizedBox(height: 10),
            const SettingsPanel(
              child: Column(
                children: [
                  SettingsRow(
                    icon: Icons.badge_outlined,
                    iconColor: settingsAccent,
                    title: 'Profile identity',
                    subtitle: 'Your display name and profile photo',
                    trailing: Icon(
                      Icons.visibility_outlined,
                      color: settingsMuted,
                    ),
                  ),
                  SettingsDivider(),
                  SettingsRow(
                    icon: Icons.bar_chart_rounded,
                    iconColor: Color(0xFF38D6C5),
                    title: 'Competition stats',
                    subtitle: 'Steps, CAL, MIN, distance, and rank',
                    trailing: Icon(
                      Icons.visibility_outlined,
                      color: settingsMuted,
                    ),
                  ),
                  SettingsDivider(),
                  SettingsRow(
                    icon: Icons.email_outlined,
                    iconColor: Color(0xFFFFB547),
                    title: 'Email address',
                    subtitle: 'Never shown to other group members',
                    trailing: Icon(
                      Icons.visibility_off_outlined,
                      color: settingsMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            const SettingsSectionTitle('Data controls'),
            const SizedBox(height: 10),
            SettingsPanel(
              child: Column(
                children: [
                  SettingsRow(
                    icon: Icons.article_outlined,
                    iconColor: const Color(0xFF62B2FF),
                    title: 'Privacy policy',
                    subtitle: 'How Got Motion uses your data',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SettingsPrivacyPolicyScreen(),
                      ),
                    ),
                  ),
                  const SettingsDivider(),
                  SettingsRow(
                    icon: Icons.download_outlined,
                    iconColor: const Color(0xFF38D6C5),
                    title: 'Download my data',
                    subtitle: _exporting
                        ? 'Preparing your export...'
                        : 'Save a copy of your Got Motion data',
                    onTap: _exporting ? null : _confirmAndExport,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            SettingsPanel(
              child: SettingsRow(
                icon: Icons.delete_forever_rounded,
                iconColor: const Color(0xFFFF575F),
                title: 'Delete account',
                subtitle: 'Permanently remove your Got Motion account',
                destructive: true,
                onTap: _showDeleteAccountDialog,
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFFF575F),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndExport() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: settingsSurface,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Download my data',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'This export contains private account, group, goal, and activity data stored by Got Motion for your signed-in account. It does not include other members’ profiles or activity.',
                style: TextStyle(
                  color: settingsMuted,
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Anyone you share the file with will be able to read it. Only create an export if you want a copy.',
                style: TextStyle(
                  color: settingsMuted,
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: settingsAccent,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Create export'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true) await _runExport();
  }

  Future<void> _runExport() async {
    setState(() => _exporting = true);
    var dialogOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const Center(
        child: Card(
          color: settingsSurface,
          child: Padding(
            padding: EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: settingsAccent),
                SizedBox(height: 14),
                Text(
                  'Preparing your export...',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    void closeProgress() {
      if (!dialogOpen || !mounted) return;
      dialogOpen = false;
      Navigator.of(context, rootNavigator: true).pop();
    }

    try {
      final file = await DataExportService().createCurrentUserExportFile();
      closeProgress();
      if (!mounted) return;
      await Share.shareXFiles([
        XFile(file.path, mimeType: 'application/json'),
      ], subject: 'Got Motion data export');
    } on DataExportException catch (e) {
      closeProgress();
      if (mounted) _showExportError(e.message);
    } catch (_) {
      closeProgress();
      if (mounted) {
        _showExportError('Could not create your export. Try again.');
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _showExportError(String message) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: settingsSurface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Export failed',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(
                  color: settingsMuted,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: settingsAccent,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: settingsSurface,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Delete account',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This permanently deletes your Got Motion account, profile, group memberships, synced activity, and notification data. This cannot be undone.',
                style: TextStyle(
                  color: settingsMuted,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    final error = await AuthService.deleteAccount();
                    if (!mounted) return;
                    if (error != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(error),
                          backgroundColor: const Color(0xFFEF4444),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF575F),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Delete my account'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: settingsMuted),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
