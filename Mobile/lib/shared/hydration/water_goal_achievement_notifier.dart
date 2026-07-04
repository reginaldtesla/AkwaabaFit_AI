import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/shared/notifications/akwaaba_android_notifications.dart';
import 'package:mobile/shared/notifications/notification_inbox.dart';

/// Quiet notification when the user hits their daily water goal.
abstract final class WaterGoalAchievementNotifier {
  static const _channelId = 'hydration_achievements_quiet';
  static const _channelName = 'Hydration achievements';
  static const _reachedDayKey = 'akwaaba_water_goal_reached_day';
  static const int _notifId = 3202;

  static FlutterLocalNotificationsPlugin? _plugin;
  static bool _initialized = false;

  static String _dayKey() => DateTime.now().toIso8601String().substring(0, 10);

  static String _formatLiters(int ml) {
    final liters = ml / 1000;
    if (liters == liters.roundToDouble()) {
      return '${liters.toStringAsFixed(0)} L';
    }
    return '${liters.toStringAsFixed(1)} L';
  }

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _plugin = FlutterLocalNotificationsPlugin();
    const androidInit = AkwaabaAndroidNotifications.initSettings;
    await _plugin!.initialize(
      settings: const InitializationSettings(android: androidInit),
    );

    if (Platform.isAndroid) {
      final android = _plugin!
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: 'Daily water goal achievements',
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

  /// Call after water intake changes (log, refresh, sync).
  static Future<void> evaluate({
    required int totalMl,
    required int goalMl,
  }) async {
    if (totalMl <= 0 || goalMl <= 0 || totalMl < goalMl) return;

    final prefs = await SharedPreferences.getInstance();
    final today = _dayKey();
    if (prefs.getString(_reachedDayKey) == today) return;

    if (!await _permissionGranted()) return;
    await _ensureInitialized();

    final title = 'AkwaabaFit · Hydration goal';
    final body =
        '${_formatLiters(totalMl)} today — you\'ve reached your ${_formatLiters(goalMl)} water goal.';

    await prefs.setString(_reachedDayKey, today);
    await _show(title: title, body: body);
  }

  static Future<void> _show({
    required String title,
    required String body,
  }) async {
    try {
      final inbox = await NotificationInboxService.getInstance();
      await inbox.add(
        title: title,
        body: body,
        category: 'hydration',
      );
    } catch (_) {}

    await _plugin!.show(
      id: _notifId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AkwaabaAndroidNotifications.details(
          channelId: _channelId,
          channelName: _channelName,
          channelDescription: 'Daily water goal achievements',
          expandedBody: body,
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
          enableVibration: false,
          onlyAlertOnce: true,
        ),
      ),
    );
  }

  @visibleForTesting
  static Future<void> clearTodayFlagForTests() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_reachedDayKey);
  }
}
