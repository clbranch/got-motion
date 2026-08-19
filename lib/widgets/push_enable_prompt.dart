import 'package:flutter/material.dart';

import '../services/notification_preferences_service.dart';
import '../services/push_notification_service.dart';
import '../services/push_prompt_service.dart';
import 'settings_ui.dart';

/// One-time opt-in sheet so new users can enable push without visiting Settings.
Future<void> showPushEnablePrompt(
  BuildContext context, {
  required String userId,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: settingsSurface,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
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
            ),
            const SizedBox(height: 18),
            const Text(
              'Stay in the competition',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Get a heads-up when someone in your group is moving, when you’re close to first place, and for morning and evening recaps.',
              style: TextStyle(
                color: settingsMuted,
                fontSize: 15,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                final result = await pushNotificationService.enablePush();
                if (result == PushPermissionState.granted ||
                    result == PushPermissionState.provisional) {
                  final prefs = await notificationPreferencesService.load();
                  await notificationPreferencesService.save(
                    prefs.copyWith(pushEnabled: true),
                  );
                } else if (context.mounted) {
                  await _showDeniedSheet(context);
                }
                await pushPromptService.markDone(userId);
              },
              style: FilledButton.styleFrom(
                backgroundColor: settingsAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Enable notifications'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                await pushPromptService.markDone(userId);
              },
              child: const Text(
                'Not now',
                style: TextStyle(color: settingsMuted, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _showDeniedSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
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
