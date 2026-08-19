import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_preferences_service.dart';
import 'push_notification_service.dart';

/// Tracks whether the user has seen the in-app push opt-in prompt.
class PushPromptService {
  PushPromptService._();
  static final PushPromptService instance = PushPromptService._();

  static String _doneKey(String userId) => 'push_prompt_done_$userId';

  Future<bool> shouldPrompt(String userId) async {
    if (kIsWeb) return false;

    final store = await SharedPreferences.getInstance();
    if (store.getBool(_doneKey(userId)) == true) return false;

    await pushNotificationService.ensureHandlers();
    final permission = await pushNotificationService.currentPermission();
    if (permission == PushPermissionState.denied ||
        permission == PushPermissionState.restricted) {
      return false;
    }

    final prefs = await notificationPreferencesService.load();
    return !prefs.pushEnabled;
  }

  Future<void> markDone(String userId) async {
    final store = await SharedPreferences.getInstance();
    await store.setBool(_doneKey(userId), true);
  }
}

final pushPromptService = PushPromptService.instance;
