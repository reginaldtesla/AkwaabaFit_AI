import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/shared/fitness/foreground_notification_prefs.dart';
import 'package:mobile/shared/notifications/akwaaba_android_notifications.dart';
import 'package:mobile/shared/notifications/notification_inbox.dart';

/// Soft “time to move” nudge when the user has been idle.
///
/// Designed to stay out of the way:
/// - quiet channel (no sound / vibration / heads-up)
/// - only daytime hours
/// - at most one nudge per day
/// - skipped when already close to the step goal
abstract final class IdleMovementNudgeNotifier {
  static const _channelId = 'movement_nudge_quiet';
  static const _channelName = 'Movement nudges';

  static const _lastMoveAtMsKey = 'akwaaba_idle_last_move_at_ms';
  static const _lastStepsKey = 'akwaaba_idle_last_steps';
  static const _nudgeDayKey = 'akwaaba_idle_nudge_day';
  static const _notifId = 3300;

  /// No meaningful step progress for this long → consider idle.
  static const idleAfter = Duration(minutes: 90);

  /// Ignore tiny sensor jitter when deciding “moved”.
  static const minStepDeltaToCountAsMove = 40;

  /// Don’t nudge once the user is nearly done for the day.
  static const skipWhenGoalProgress = 0.8;

  static const quietStartHour = 10;
  static const quietEndHourExclusive = 20;

  static FlutterLocalNotificationsPlugin? _plugin;
  static bool _initialized = false;

  static const _messages = <({String title, String body})>[
    (
      title: 'A little movement helps',
      body:
          'You’ve been still for a while. A short stretch or walk is good for your heart and energy.',
    ),
    (
      title: 'Time for a gentle walk?',
      body:
          'Standing up and walking a few minutes can ease stiffness and lift your mood.',
    ),
    (
      title: 'Your body will thank you',
      body:
          'Idle stretch tip: roll your shoulders, stand tall, and take a short stroll when you can.',
    ),
    (
      title: 'Keep the habit going',
      body:
          'Even 5–10 minutes of walking helps blood flow and keeps today’s steps on track.',
    ),
    (
      title: 'Fresh air break',
      body:
          'If you can, step outside briefly — light movement supports focus and overall health.',
    ),
  ];

  static String _dayKey([DateTime? now]) =>
      (now ?? DateTime.now()).toIso8601String().substring(0, 10);

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _plugin = FlutterLocalNotificationsPlugin();
    await _plugin!.initialize(
      settings: const InitializationSettings(
        android: AkwaabaAndroidNotifications.initSettings,
      ),
    );

    if (Platform.isAndroid) {
      final android = _plugin!
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: 'Occasional quiet reminders to move when idle',
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
          showBadge: false,
        ),
      );
    }
    _initialized = true;
  }

  static Future<bool> _permissionGranted() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      return status.isGranted;
    }
    return true;
  }

  /// Call whenever today’s step total is known (foreground or background).
  static Future<void> onSteps(int steps) async {
    if (steps < 0) return;
    final prefs = await SharedPreferences.getInstance();
    final prev = prefs.getInt(_lastStepsKey);
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    if (prev == null) {
      await prefs.setInt(_lastStepsKey, steps);
      await prefs.setInt(_lastMoveAtMsKey, nowMs);
      return;
    }

    // Midnight / sensor reset: treat as a fresh day baseline.
    if (steps + minStepDeltaToCountAsMove < prev) {
      await prefs.setInt(_lastStepsKey, steps);
      await prefs.setInt(_lastMoveAtMsKey, nowMs);
      return;
    }

    if (steps >= prev + minStepDeltaToCountAsMove) {
      await prefs.setInt(_lastStepsKey, steps);
      await prefs.setInt(_lastMoveAtMsKey, nowMs);
      return;
    }

    // Steps stayed flat or barely moved — keep last move time, refresh snapshot.
    if (steps != prev) {
      await prefs.setInt(_lastStepsKey, steps);
    }
  }

  /// Periodic check (e.g. every 15 minutes from the background service).
  static Future<void> checkIdle({int? stepsOverride}) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    if (now.hour < quietStartHour || now.hour >= quietEndHourExclusive) {
      return;
    }

    if (prefs.getString(_nudgeDayKey) == _dayKey(now)) {
      return;
    }

    final steps = stepsOverride ?? prefs.getInt(_lastStepsKey) ?? 0;
    final goalRaw = prefs.getInt(ForegroundNotificationPrefs.stepGoalKey);
    final goal = (goalRaw != null && goalRaw > 0) ? goalRaw : 10000;
    if (goal > 0 && steps >= (goal * skipWhenGoalProgress).round()) {
      return;
    }

    final lastMoveMs = prefs.getInt(_lastMoveAtMsKey);
    if (lastMoveMs == null) {
      await prefs.setInt(_lastMoveAtMsKey, now.millisecondsSinceEpoch);
      await prefs.setInt(_lastStepsKey, steps);
      return;
    }

    final idleFor = now.difference(
      DateTime.fromMillisecondsSinceEpoch(lastMoveMs),
    );
    if (idleFor < idleAfter) return;

    if (!await _permissionGranted()) return;
    await _ensureInitialized();

    final pick = _messages[Random().nextInt(_messages.length)];
    await prefs.setString(_nudgeDayKey, _dayKey(now));

    try {
      final inbox = await NotificationInboxService.getInstance();
      await inbox.add(
        title: pick.title,
        body: pick.body,
        category: 'reminder',
      );
    } catch (_) {}

    await _plugin!.show(
      id: _notifId,
      title: pick.title,
      body: pick.body,
      notificationDetails: NotificationDetails(
        android: AkwaabaAndroidNotifications.details(
          channelId: _channelId,
          channelName: _channelName,
          channelDescription: 'Occasional quiet reminders to move when idle',
          expandedBody: pick.body,
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
  static Future<void> clearStateForTests() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastMoveAtMsKey);
    await prefs.remove(_lastStepsKey);
    await prefs.remove(_nudgeDayKey);
  }
}
