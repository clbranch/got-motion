import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserGoals {
  const UserGoals({
    this.steps = 10000,
    this.activeCalories = 500,
    this.exerciseMinutes = 30,
    this.miles = 5,
  });

  final int steps;
  final int activeCalories;
  final int exerciseMinutes;
  final double miles;

  factory UserGoals.fromMetadata(Map<String, dynamic>? metadata) {
    int intValue(String key, int fallback) =>
        (metadata?[key] as num?)?.round() ?? fallback;
    double doubleValue(String key, double fallback) =>
        (metadata?[key] as num?)?.toDouble() ?? fallback;
    return UserGoals(
      steps: intValue('daily_step_goal', 10000),
      activeCalories: intValue('daily_calorie_goal', 500),
      exerciseMinutes: intValue('daily_exercise_goal', 30),
      miles: doubleValue('daily_miles_goal', 5),
    );
  }
}

class GoalService extends ChangeNotifier {
  UserGoals _goals = UserGoals.fromMetadata(
    Supabase.instance.client.auth.currentUser?.userMetadata,
  );

  UserGoals get goals => _goals;

  void reloadFromCurrentUser() {
    _goals = UserGoals.fromMetadata(
      Supabase.instance.client.auth.currentUser?.userMetadata,
    );
    notifyListeners();
  }

  Future<void> save(UserGoals goals) async {
    _goals = goals;
    notifyListeners();
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(
        data: {
          'daily_step_goal': goals.steps,
          'daily_calorie_goal': goals.activeCalories,
          'daily_exercise_goal': goals.exerciseMinutes,
          'daily_miles_goal': goals.miles,
        },
      ),
    );
  }
}

GoalService get goalService => _goalService;
final GoalService _goalService = GoalService();
