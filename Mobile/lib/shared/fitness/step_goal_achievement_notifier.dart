import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/shared/fitness/foreground_notification_prefs.dart';
import 'package:mobile/shared/notifications/notification_inbox.dart';

/// Samsung Health–style alerts when the user hits their step goal (and optional daily targets).
abstract final class StepGoalAchievementNotifier {
  static const _channelId = 'activity_achievements_quiet';
  static const _channelName = 'Activity achievements';

  static const _stepReachedDayKey = 'akwaaba_step_goal_reached_day';
  static const _dailyAllReachedDayKey = 'akwaaba_daily_all_targets_day';

  static const int _notifIdStepReached = 3200;
  static const int _notifIdDailyAll = 3201;

  static FlutterLocalNotificationsPlugin? _plugin;
  static bool _initialized = false;

  static String _dayKey() => DateTime.now().toIso8601String().substring(0, 10);

  static String formatSteps(int value) {
    final negative = value < 0;
    final digits = negative ? (-value).toString() : value.toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return negative ? '-$buf' : buf.toString();
  }

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _plugin = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin!.initialize(settings: const InitializationSettings(android: androidInit));

    if (Platform.isAndroid) {
      final android = _plugin!
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await android?.deleteNotificationChannel(
        channelId: 'activity_achievements',
      );
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: 'Step goal and daily activity achievements',
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
        ),
      );
    }
    _initialized = true;
  }

  static Future<bool> _permissionGranted() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    return true;
  }

  /// Call when step count changes (foreground, dashboard, or background service).
  static Future<void> evaluate({
    required int steps,
    int? calorieConsumed,
    int? calorieTarget,
    int? mealsLoggedToday,
  }) async {
    if (steps < 0) return;

    final prefs = await SharedPreferences.getInstance();
    final goalRaw = prefs.getInt(ForegroundNotificationPrefs.stepGoalKey);
    final goal = (goalRaw != null && goalRaw > 0) ? goalRaw : 10000;

    final consumed = calorieConsumed ??
        prefs.getInt(ForegroundNotificationPrefs.caloriesConsumedKey);
    final kcalTarget = calorieTarget ??
        prefs.getInt(ForegroundNotificationPrefs.calorieGoalKey);
    final meals = mealsLoggedToday ??
        prefs.getInt(ForegroundNotificationPrefs.mealsLoggedTodayKey);

    if (goal > 0 && steps >= goal) {
      await _maybeNotifyStepGoalReached(steps: steps, goal: goal);
    }

    await _maybeNotifyDailyTargetsReached(
      steps: steps,
      stepGoal: goal,
      consumedKcal: consumed ?? 0,
      calorieTarget: kcalTarget ?? 0,
      mealsLoggedToday: meals ?? 0,
    );
  }

  static Future<void> _maybeNotifyStepGoalReached({
    required int steps,
    required int goal,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dayKey();
    if (prefs.getString(_stepReachedDayKey) == today) return;

    if (!await _permissionGranted()) return;
    await _ensureInitialized();

    final pct = goal > 0 ? ((steps * 100) / goal).round() : 100;
    final title = '${formatSteps(steps)} steps';
    final body =
        "You've achieved $pct% of your step goal.";

    await prefs.setString(_stepReachedDayKey, today);
    await _show(
      id: _notifIdStepReached,
      title: title,
      body: body,
      category: 'achievement',
    );
  }

  static Future<void> _maybeNotifyDailyTargetsReached({
    required int steps,
    required int stepGoal,
    required int consumedKcal,
    required int calorieTarget,
    required int mealsLoggedToday,
  }) async {
    if (stepGoal <= 0 || steps < stepGoal) return;

    final goals = <bool>[
      true, // steps (already >= goal)
      mealsLoggedToday >= 1,
    ];
    if (calorieTarget > 0) {
      final low = (calorieTarget * 0.85).round();
      final high = (calorieTarget * 1.15).round();
      goals.add(consumedKcal >= low && consumedKcal <= high);
    }

    final met = goals.where((g) => g).length;
    if (met < goals.length) return;

    final prefs = await SharedPreferences.getInstance();
    final today = _dayKey();
    if (prefs.getString(_dailyAllReachedDayKey) == today) return;

    if (!await _permissionGranted()) return;
    await _ensureInitialized();

    final total = goals.length;
    final title = 'Daily activity target reached';
    final body =
        'Congrats! You met all $total of your goals today.';

    await prefs.setString(_dailyAllReachedDayKey, today);
    await _show(
      id: _notifIdDailyAll,
      title: title,
      body: body,
      category: 'achievement',
    );
  }

  static Future<void> _show({
    required int id,
    required String title,
    required String body,
    required String category,
  }) async {
    try {
      final inbox = await NotificationInboxService.getInstance();
      await inbox.add(title: title, body: body, category: category);
    } catch (_) {}

    await _plugin!.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Step goal and daily activity achievements',
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
          enableVibration: false,
          onlyAlertOnce: true,
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
    );
  }

  /// Clears “already notified today” flags (e.g. midnight rollover in background).
  @visibleForTesting
  static Future<void> clearTodayFlagsForTests() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_stepReachedDayKey);
    await prefs.remove(_dailyAllReachedDayKey);
  }
}
