import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/health_hub_service.dart';
import '../services/health_service.dart';
import '../widgets/settings_ui.dart';
import '../widgets/workout_log_entry.dart';

class SettingsHealthPermissionsScreen extends StatefulWidget {
  const SettingsHealthPermissionsScreen({super.key});

  @override
  State<SettingsHealthPermissionsScreen> createState() =>
      _SettingsHealthPermissionsScreenState();
}

class _SettingsHealthPermissionsScreenState
    extends State<SettingsHealthPermissionsScreen>
    with WidgetsBindingObserver {
  bool _checking = false;
  bool _awaitingHealthReturn = false;
  HealthHubStatus _hubStatus = HealthHubStatus.ready;
  static const _systemChannel = MethodChannel(
    'com.brogrammers.gotmotionapp/system',
  );

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshHubStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingHealthReturn) {
      _awaitingHealthReturn = false;
      _refreshHealthAccess(showMessage: true);
    }
    if (state == AppLifecycleState.resumed) {
      _refreshHubStatus();
    }
  }

  Future<void> _refreshHubStatus() async {
    final status = await healthHubService.status();
    if (!mounted) return;
    setState(() => _hubStatus = status);
  }

  Future<void> _requestAccess() => _refreshHealthAccess(showMessage: true);

  Future<void> _refreshHealthAccess({required bool showMessage}) async {
    if (_checking) return;
    setState(() => _checking = true);
    if (_isAndroid && _hubStatus != HealthHubStatus.ready) {
      await healthHubService.openInstallOrUpdate();
      await _refreshHubStatus();
      if (!mounted) return;
      setState(() => _checking = false);
      if (showMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _hubStatus == HealthHubStatus.ready
                  ? 'Health Connect is ready. Tap Check access again.'
                  : 'Install or update Health Connect, then return here.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    await HealthService.requestAndFetchSteps();
    if (!mounted) return;
    setState(() => _checking = false);
    if (!showMessage) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Health access check finished.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showManageSheet() async {
    if (_isAndroid) {
      await _showManageHealthConnectSheet();
      return;
    }
    final shouldOpen = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: settingsSurface,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) =>
          const SafeArea(top: false, child: _ManageAppleHealthSheet()),
    );
    if (shouldOpen == true) await _openAppleHealth();
  }

  Future<void> _showManageHealthConnectSheet() async {
    await showModalBottomSheet<void>(
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
                'Manage Health Connect',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'On Android 14+: Settings → Security & privacy → Privacy → Health Connect → App permissions → Got Motion.\n\nOn older phones: open the Health Connect app → App permissions → Got Motion.',
                style: TextStyle(
                  color: settingsMuted,
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              if (_hubStatus != HealthHubStatus.ready) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      final userId =
                          Supabase.instance.client.auth.currentUser?.id;
                      if (userId != null) {
                        await healthHubService
                            .clearInstallPromptDismissal(userId);
                      }
                      await healthHubService.openInstallOrUpdate();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: settingsAccent,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      _hubStatus == HealthHubStatus.needsUpdate
                          ? 'Update Health Connect'
                          : 'Get Health Connect',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAppleHealth() async {
    try {
      final opened =
          await _systemChannel.invokeMethod<bool>('openHealthApp') ?? false;
      if (!mounted) return;
      if (opened) {
        _awaitingHealthReturn = true;
        return;
      }
      _showCouldNotOpenHealth();
    } on PlatformException {
      if (mounted) _showCouldNotOpenHealth();
    }
  }

  void _showCouldNotOpenHealth() {
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
                'Could not open Apple Health',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Open the Health app yourself, then: profile picture → Privacy → Apps → Got Motion.',
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

  @override
  Widget build(BuildContext context) {
    final hubTitle = _isAndroid
        ? (_hubStatus == HealthHubStatus.ready
              ? 'Health Connect powers your stats'
              : 'Health Connect required')
        : 'Apple Health powers your stats';
    final hubSubtitle = _isAndroid
        ? (_hubStatus == HealthHubStatus.ready
              ? 'Got Motion reads activity only after you grant access.'
              : 'Older Android phones need Google’s free Health Connect app first. Newer phones already have it.')
        : 'Got Motion reads activity only after you grant access.';
    final manageLabel =
        _isAndroid ? 'Manage in Health Connect' : 'Manage in Apple Health';

    return Scaffold(
      backgroundColor: settingsBackground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: [
            const SettingsPageHeader(
              title: 'Health access',
              subtitle: 'Control the activity data used by Got Motion.',
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
                            0xFFFF5A67,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: Color(0xFFFF5A67),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hubTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              hubSubtitle,
                              style: const TextStyle(
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
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _checking ? null : _requestAccess,
                      style: FilledButton.styleFrom(
                        backgroundColor: settingsAccent,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: _checking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _isAndroid &&
                                      _hubStatus != HealthHubStatus.ready
                                  ? Icons.download_rounded
                                  : Icons.sync_rounded,
                            ),
                      label: Text(
                        _checking
                            ? 'Checking access...'
                            : (_isAndroid &&
                                  _hubStatus != HealthHubStatus.ready)
                            ? (_hubStatus == HealthHubStatus.needsUpdate
                                  ? 'Update Health Connect'
                                  : 'Get Health Connect')
                            : 'Check health access',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _showManageSheet,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF5A67),
                        side: const BorderSide(color: Color(0xFF3A4B61)),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: Text(manageLabel),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SettingsPanel(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'No Apple Watch?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'You can optionally log a workout from Profile so exercise minutes and proof show up for your group. Watch users usually don’t need this.',
                    style: TextStyle(
                      color: settingsMuted,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => openWorkoutLogFlow(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF9A73FF),
                        side: const BorderSide(color: Color(0xFF3A4B61)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Log a workout'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            const SettingsSectionTitle('Activity we read'),
            const SizedBox(height: 10),
            SettingsPanel(
              child: Column(
                children: [
                  const SettingsRow(
                    icon: Icons.directions_walk_rounded,
                    iconColor: settingsAccent,
                    title: 'Steps',
                    subtitle: 'Daily movement and leaderboard totals',
                    trailing: _RequestedBadge(),
                  ),
                  const SettingsDivider(),
                  const SettingsRow(
                    icon: Icons.local_fire_department_rounded,
                    iconColor: Color(0xFFFF861F),
                    title: 'Active calories',
                    subtitle: 'Move energy shown in CAL',
                    trailing: _RequestedBadge(),
                  ),
                  const SettingsDivider(),
                  SettingsRow(
                    icon: Icons.timer_outlined,
                    iconColor: const Color(0xFF9B7CFF),
                    title: 'Exercise minutes',
                    subtitle: _isAndroid
                        ? 'From workouts logged in Health Connect'
                        : 'Apple exercise time shown in MIN',
                    trailing: const _RequestedBadge(),
                  ),
                  const SettingsDivider(),
                  const SettingsRow(
                    icon: Icons.fitness_center_rounded,
                    iconColor: Color(0xFFFF5A67),
                    title: 'Workouts',
                    subtitle:
                        'Sessions from watch/band apps that sync to the health hub',
                    trailing: _RequestedBadge(),
                  ),
                  const SettingsDivider(),
                  SettingsRow(
                    icon: Icons.route_rounded,
                    iconColor: const Color(0xFF18D3A2),
                    title: _isAndroid ? 'Distance' : 'Distance & stand',
                    subtitle: _isAndroid
                        ? 'Walking and running distance'
                        : 'Walking distance and Apple stand hours',
                    trailing: const _RequestedBadge(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _isAndroid
                  ? 'Got Motion asks Health Connect for these types. You control access in Health Connect settings. Denied data simply appears unavailable.'
                  : 'REQUESTED means Got Motion asked Apple for that type. Apple does not tell the app whether you allowed or denied it, so these are not confirmed permissions. Denied data simply appears unavailable. Only you can enable or revoke access in Apple Health.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: settingsMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManageAppleHealthSheet extends StatelessWidget {
  const _ManageAppleHealthSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Manage in Apple Health',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Apple Health opens on Summary. To change access:',
            style: TextStyle(color: settingsMuted, fontSize: 15, height: 1.45),
          ),
          const SizedBox(height: 16),
          const _HealthStep(
            number: '1',
            text: 'Tap your profile picture in the top-right.',
          ),
          const SizedBox(height: 12),
          const _HealthStep(number: '2', text: 'Tap Apps under Privacy.'),
          const SizedBox(height: 12),
          const _HealthStep(number: '3', text: 'Select Got Motion.'),
          const SizedBox(height: 12),
          const _HealthStep(
            number: '4',
            text: 'Turn each permission on or off.',
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF5A67),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Open Apple Health'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not now'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthStep extends StatelessWidget {
  const _HealthStep({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFFF5A67).withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: Color(0xFFFF5A67),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RequestedBadge extends StatelessWidget {
  const _RequestedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF38D6C5).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'REQUESTED',
        style: TextStyle(
          color: Color(0xFF38D6C5),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
