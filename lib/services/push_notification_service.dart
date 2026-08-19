import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'push_device_service.dart';

enum PushPermissionState {
  notDetermined,
  denied,
  granted,
  provisional,
  restricted,
}

/// App-side push permission + APNs token registration.
/// Does not request permission at launch — only when the user opts in.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  static const _channel = MethodChannel('com.brogrammers.gotmotionapp/push');

  String? _apnsToken;
  bool _handlersReady = false;

  String? get apnsToken => _apnsToken;

  Future<void> ensureHandlers() async {
    if (_handlersReady) return;
    _handlersReady = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onToken':
          final token = call.arguments?.toString();
          if (token != null && token.isNotEmpty) {
            _apnsToken = token;
            await pushDeviceService.upsertToken(
              token: token,
              platform: Platform.isIOS ? 'ios' : 'android',
              enabled: true,
            );
          }
          return null;
        case 'onTokenError':
          if (kDebugMode) {
            debugPrint('[Push] token error: ${call.arguments}');
          }
          return null;
        default:
          return null;
      }
    });
  }

  Future<PushPermissionState> currentPermission() async {
    if (kIsWeb) return PushPermissionState.restricted;
    final status = await Permission.notification.status;
    if (status.isGranted) return PushPermissionState.granted;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return PushPermissionState.denied;
    }
    if (status.isDenied) return PushPermissionState.notDetermined;
    if (status.isLimited) return PushPermissionState.provisional;
    return PushPermissionState.notDetermined;
  }

  /// Requests OS permission, then registers for remote notifications.
  /// Returns the resulting permission state.
  Future<PushPermissionState> enablePush() async {
    await ensureHandlers();
    final status = await Permission.notification.request();
    if (!(status.isGranted || status.isLimited)) {
      return PushPermissionState.denied;
    }

    if (!kIsWeb && Platform.isIOS) {
      try {
        // Registration is async; token is delivered via onToken handler.
        final existing = await _channel.invokeMethod<String>(
          'registerForRemoteNotifications',
        );
        if (existing != null && existing.isNotEmpty) {
          _apnsToken = existing;
          await pushDeviceService.upsertToken(
            token: existing,
            platform: 'ios',
            enabled: true,
          );
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[Push] register failed: $e');
      }
    }

    return PushPermissionState.granted;
  }

  Future<void> disablePushOnDevice() async {
    await ensureHandlers();
    final token = _apnsToken;
    if (token != null) {
      await pushDeviceService.setEnabledForToken(
        token: token,
        platform: Platform.isIOS ? 'ios' : 'android',
        enabled: false,
      );
    }
    if (!kIsWeb && Platform.isIOS) {
      try {
        await _channel.invokeMethod<void>('unregisterForRemoteNotifications');
      } catch (e) {
        if (kDebugMode) debugPrint('[Push] unregister failed: $e');
      }
    }
  }

  Future<bool> openSystemSettings() async {
    return openAppSettings();
  }
}

final pushNotificationService = PushNotificationService.instance;
