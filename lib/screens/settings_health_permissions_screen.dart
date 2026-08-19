import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/health_service.dart';
import '../widgets/settings_ui.dart';

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
  static const _systemChannel = MethodChannel(
    'com.brogrammers.gotmotionapp/system',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
  }

  Future<void> _requestAccess() => _refreshHealthAccess(showMessage: true);

  Future<void> _refreshHealthAccess({required bool showMessage}) async {
    if (_checking) return;
    setState(() => _checking = true);
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

  Future<void> _showManageInAppleHealthSheet() async {
    final shouldOpen = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: settingsSurface,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) =>
          const SafeArea(top: false, child: _ManageHealthSheet()),
    );
    if (shouldOpen == true) await _openAppleHealth();
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
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Apple Health powers your stats',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Got Motion reads activity only after you grant access.',
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
                          : const Icon(Icons.sync_rounded),
                      label: Text(
                        _checking
                            ? 'Checking access...'
                            : 'Check health access',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _showManageInAppleHealthSheet,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF5A67),
                        side: const BorderSide(color: Color(0xFF3A4B61)),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Manage in Apple Health'),
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
                children: const [
                  SettingsRow(
                    icon: Icons.directions_walk_rounded,
                    iconColor: settingsAccent,
                    title: 'Steps',
                    subtitle: 'Daily movement and leaderboard totals',
                    trailing: _RequestedBadge(),
                  ),
                  SettingsDivider(),
                  SettingsRow(
                    icon: Icons.local_fire_department_rounded,
                    iconColor: Color(0xFFFF861F),
                    title: 'Active calories',
                    subtitle: 'Move energy shown in CAL',
                    trailing: _RequestedBadge(),
                  ),
                  SettingsDivider(),
                  SettingsRow(
                    icon: Icons.timer_outlined,
                    iconColor: Color(0xFF9B7CFF),
                    title: 'Exercise minutes',
                    subtitle: 'Apple exercise time shown in MIN',
                    trailing: _RequestedBadge(),
                  ),
                  SettingsDivider(),
                  SettingsRow(
                    icon: Icons.fitness_center_rounded,
                    iconColor: Color(0xFFFF5A67),
                    title: 'Workouts',
                    subtitle: 'Third-party sessions like MyZone that sync to Health',
                    trailing: _RequestedBadge(),
                  ),
                  SettingsDivider(),
                  SettingsRow(
                    icon: Icons.route_rounded,
                    iconColor: Color(0xFF18D3A2),
                    title: 'Distance & stand',
                    subtitle: 'Walking distance and Apple stand hours',
                    trailing: _RequestedBadge(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'REQUESTED means Got Motion asked Apple for that type. Apple does not tell the app whether you allowed or denied it, so these are not confirmed permissions. Denied data simply appears unavailable. Only you can enable or revoke access in Apple Health.',
              textAlign: TextAlign.center,
              style: TextStyle(color: settingsMuted, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManageHealthSheet extends StatelessWidget {
  const _ManageHealthSheet();

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
