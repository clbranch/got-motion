import 'package:flutter/material.dart';

import '../screens/workout_detail_screen.dart';

/// Lets celebration flows and notification taps jump to a main-nav tab.
class MainNavService {
  MainNavService._();
  static final MainNavService instance = MainNavService._();

  void Function(int tabIndex)? selectTab;
  GlobalKey<NavigatorState>? navigatorKey;
  int? _pendingTab;
  String? _pendingWorkoutId;

  void goToProfile() => goToTab(2);
  void goToGroup() => goToTab(3);

  void goToTab(int tabIndex) {
    final select = selectTab;
    if (select != null) {
      select(tabIndex);
    } else {
      _pendingTab = tabIndex;
    }
  }

  /// Open a logged workout detail (from push / inbox).
  void openWorkout(String workoutId) {
    final nav = navigatorKey?.currentState;
    if (nav != null) {
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => WorkoutDetailScreen(workoutId: workoutId),
        ),
      );
      return;
    }
    _pendingWorkoutId = workoutId;
  }

  void bind(
    void Function(int tabIndex) select, {
    GlobalKey<NavigatorState>? navigatorKey,
  }) {
    selectTab = select;
    if (navigatorKey != null) this.navigatorKey = navigatorKey;
    final pending = _pendingTab;
    if (pending != null) {
      _pendingTab = null;
      select(pending);
    }
    final workoutId = _pendingWorkoutId;
    if (workoutId != null) {
      _pendingWorkoutId = null;
      // Defer until frame so navigator is ready.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        openWorkout(workoutId);
      });
    }
  }

  void unbind(void Function(int tabIndex) select) {
    if (selectTab == select) selectTab = null;
  }
}

final mainNavService = MainNavService.instance;
