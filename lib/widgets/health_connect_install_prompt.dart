import 'package:flutter/material.dart';

import '../services/health_hub_service.dart';
import 'settings_ui.dart';

/// Prompt older Android phones to install Health Connect from Play Store.
Future<void> showHealthConnectInstallPrompt(
  BuildContext context, {
  required String userId,
  required HealthHubStatus status,
}) async {
  final needsUpdate = status == HealthHubStatus.needsUpdate;
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
                color: const Color(0xFF3B82F6).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.health_and_safety_rounded,
                color: Color(0xFF3B82F6),
                size: 28,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              needsUpdate
                  ? 'Update Health Connect'
                  : 'One more app for your steps',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              needsUpdate
                  ? 'Your phone needs an updated Health Connect so Got Motion can read steps, calories, and workouts — the same idea as Apple Health on iPhone.'
                  : 'This phone doesn’t include Health Connect yet. It’s a free Google app that stores your fitness data. Newer Android phones already have it built in.',
              style: const TextStyle(
                color: settingsMuted,
                fontSize: 15,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                await healthHubService.openInstallOrUpdate();
                await healthHubService.markInstallPromptDismissed(userId);
              },
              style: FilledButton.styleFrom(
                backgroundColor: settingsAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                needsUpdate
                    ? 'Update Health Connect'
                    : 'Get Health Connect',
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                await healthHubService.markInstallPromptDismissed(userId);
              },
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    ),
  );
}
