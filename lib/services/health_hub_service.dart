import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether Android Health Connect (or iOS Health) is ready for Got Motion.
enum HealthHubStatus {
  /// iOS, or Android with Health Connect ready.
  ready,

  /// Older Android: need the Health Connect app from Play Store.
  needsInstall,

  /// Health Connect installed but Play Services / provider update required.
  needsUpdate,

  /// Device cannot use Health Connect (rare).
  unavailable,
}

/// Android Health Connect setup + one-time install prompts.
///
/// On Android 14+ Health Connect is built in → [HealthHubStatus.ready].
/// On older phones we detect the missing app and can open Play Store.
class HealthHubService {
  HealthHubService._();
  static final HealthHubService instance = HealthHubService._();

  static final Health _health = Health();

  static String _dismissedKey(String userId) =>
      'health_connect_install_dismissed_$userId';

  /// Current hub status. Always [HealthHubStatus.ready] on iOS / non-Android.
  Future<HealthHubStatus> status() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return HealthHubStatus.ready;
    }
    try {
      await _health.configure();
      final sdk = await _health.getHealthConnectSdkStatus();
      switch (sdk) {
        case HealthConnectSdkStatus.sdkAvailable:
          return HealthHubStatus.ready;
        case HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired:
          return HealthHubStatus.needsUpdate;
        case HealthConnectSdkStatus.sdkUnavailable:
        case null:
          return HealthHubStatus.needsInstall;
      }
    } catch (_) {
      return HealthHubStatus.needsInstall;
    }
  }

  Future<bool> isReady() async =>
      await status() == HealthHubStatus.ready;

  /// Opens Play Store to install / update Health Connect (Android only).
  Future<void> openInstallOrUpdate() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _health.configure();
      await _health.installHealthConnect();
    } catch (_) {}
  }

  Future<bool> shouldPromptInstall(String userId) async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    final hub = await status();
    if (hub == HealthHubStatus.ready) return false;
    if (hub == HealthHubStatus.unavailable) return false;
    final store = await SharedPreferences.getInstance();
    return store.getBool(_dismissedKey(userId)) != true;
  }

  Future<void> markInstallPromptDismissed(String userId) async {
    final store = await SharedPreferences.getInstance();
    await store.setBool(_dismissedKey(userId), true);
  }

  /// Clear dismissal so Settings can re-show the install CTA.
  Future<void> clearInstallPromptDismissal(String userId) async {
    final store = await SharedPreferences.getInstance();
    await store.remove(_dismissedKey(userId));
  }
}

final healthHubService = HealthHubService.instance;
