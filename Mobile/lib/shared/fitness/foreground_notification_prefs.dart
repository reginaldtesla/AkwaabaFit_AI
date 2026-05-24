import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Activity targets for the foreground step notification (Samsung-style lines).
/// Written from the main isolate when dashboard/profile loads.
abstract final class ForegroundNotificationPrefs {
  static const stepGoalKey = 'akwaaba_fg_step_goal';
  /// Daily calorie target from dashboard; `0` means omit from the subtitle.
  static const calorieGoalKey = 'akwaaba_fg_calorie_goal';
  /// Last known consumed kcal / meals today (for achievement notifications).
  static const caloriesConsumedKey = 'akwaaba_fg_calories_consumed';
  static const mealsLoggedTodayKey = 'akwaaba_fg_meals_logged_today';

  static const String refreshForegroundNotificationEvent =
      'refresh_fg_notification';

  static Future<void> _invokeForegroundRefreshIfRunning() async {
    try {
      final bg = FlutterBackgroundService();
      if (await bg.isRunning()) {
        bg.invoke(refreshForegroundNotificationEvent);
      }
    } catch (_) {}
  }

  /// Prefer after dashboard fetch — updates steps + calorie targets together.
  static Future<void> syncActivityGoalsFromDashboard({
    required int stepGoal,
    required int dailyCaloriesTarget,
    int caloriesConsumed = 0,
    int mealsLoggedToday = 0,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(stepGoalKey, stepGoal.clamp(10, 2000000));
    await p.setInt(
      calorieGoalKey,
      dailyCaloriesTarget.clamp(0, 50000),
    );
    await p.setInt(caloriesConsumedKey, caloriesConsumed.clamp(0, 50000));
    await p.setInt(mealsLoggedTodayKey, mealsLoggedToday.clamp(0, 999));
    await _invokeForegroundRefreshIfRunning();
  }

  static Future<void> updateStepGoal(int goal) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(stepGoalKey, goal.clamp(10, 2000000));
    await _invokeForegroundRefreshIfRunning();
  }

  static Future<void> updateCalorieGoal(int kcal) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(calorieGoalKey, kcal.clamp(0, 50000));
    await _invokeForegroundRefreshIfRunning();
  }
}
