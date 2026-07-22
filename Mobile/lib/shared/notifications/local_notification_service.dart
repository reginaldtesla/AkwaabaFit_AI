import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:mobile/shared/notifications/akwaaba_android_notifications.dart';
import 'package:mobile/shared/notifications/notification_inbox.dart';
import 'package:timezone/data/latest.dart' as tzdata;

/// Local reminders: step check-ins and one morning **daily goal** summary.
class LocalNotificationService {
  LocalNotificationService() : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const String _channelId = 'health_reminders_channel';
  static const String _channelName = 'Health Reminders';

  static const int _stepsBase = 2000;
  static const int _dailyGoalNotifId = 3100;
  static const int _mealReminderBase = 3200;
  static const int _stepsEnableConfirmId = 999;

  static const List<({int hour, int minute})> _stepsTimes = [
    (hour: 10, minute: 30),
    (hour: 14, minute: 30),
    (hour: 18, minute: 30),
  ];

  Future<void> ensureInitialized() async {
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Africa/Accra'));
    } catch (_) {}

    const androidInit = AkwaabaAndroidNotifications.initSettings;
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(settings: initSettings);
  }

  Future<bool> _requestNotificationPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      if (!status.isGranted) return false;
    }
    return true;
  }

  Future<void> _cancelStepsSchedulesOnly() async {
    for (var i = 0; i < _stepsTimes.length; i++) {
      await _plugin.cancel(id: _stepsBase + i);
    }
  }

  /// Repeating step nudges (does **not** cancel the morning daily goal).
  Future<void> enableHealthReminders() async {
    await ensureInitialized();
    final permissionGranted = await _requestNotificationPermission();
    if (!permissionGranted) return;

    await _cancelStepsSchedulesOnly();

    for (var i = 0; i < _stepsTimes.length; i++) {
      final t = _stepsTimes[i];
      final id = _stepsBase + i;
      await _scheduleDailyAt(
        id: id,
        title: 'Steps Check-in',
        body: 'Quick boost: check your steps and move a bit today.',
        hour: t.hour,
        minute: t.minute,
      );
    }

    const confirmTitle = 'Reminders enabled';
    const confirmBody = 'We’ll remind you to check your steps today.';
    await _recordInbox(
      title: confirmTitle,
      body: confirmBody,
      category: 'reminder',
    );
    await _plugin.show(
      id: _stepsEnableConfirmId,
      title: confirmTitle,
      body: confirmBody,
      notificationDetails: NotificationDetails(
        android: _androidReminderDetails(confirmBody),
      ),
    );
  }

  /// Morning summary aligned with dashboard targets (reschedule when goals change).
  Future<void> scheduleDailyGoalReminder({
    required int stepGoal,
    int calorieTarget = 0,
  }) async {
    await ensureInitialized();
    final permissionGranted = await _requestNotificationPermission();
    if (!permissionGranted) return;

    final steps = stepGoal <= 0 ? 10000 : stepGoal;
    final body = calorieTarget > 0
        ? 'Today: reach $steps steps and eat toward ~$calorieTarget kcal. Log meals in AkwaabaFit to stay on track.'
        : 'Today: aim for $steps steps and log your meals. Open AkwaabaFit to complete your daily goal.';

    await _plugin.cancel(id: _dailyGoalNotifId);

    await _scheduleDailyAt(
      id: _dailyGoalNotifId,
      title: 'Your daily goal',
      body: body,
      hour: 8,
      minute: 0,
    );
  }

  /// Ghana meal-time nudges (Accra timezone).
  Future<void> scheduleGhanaMealReminders() async {
    await ensureInitialized();
    final permissionGranted = await _requestNotificationPermission();
    if (!permissionGranted) return;

    for (var i = 0; i < 4; i++) {
      await _plugin.cancel(id: _mealReminderBase + i);
    }

    const slots = <({int hour, int minute, String title, String body})>[
      (
        hour: 7,
        minute: 30,
        title: 'Morning chop',
        body: 'Waakye or koko time—log breakfast so your coach can balance the day.',
      ),
      (
        hour: 12,
        minute: 30,
        title: 'Lunch hour',
        body: 'Banku, jollof, or fufu lunch—scan or log your plate.',
      ),
      (
        hour: 15,
        minute: 30,
        title: 'Afternoon',
        body: 'Light koko, fruit, or a small snack if you are hungry.',
      ),
      (
        hour: 18,
        minute: 30,
        title: 'Supper',
        body: 'Kenkey, soup, or lighter waakye—evening food fits now.',
      ),
    ];

    for (var i = 0; i < slots.length; i++) {
      final s = slots[i];
      await _scheduleDailyAt(
        id: _mealReminderBase + i,
        title: s.title,
        body: s.body,
        hour: s.hour,
        minute: s.minute,
      );
    }
  }

  Future<void> _scheduleDailyAt({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final androidDetails = _androidReminderDetails(body);

    final notificationDetails = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> showAdminBroadcast({
    required int announcementId,
    required String title,
    required String body,
  }) async {
    await ensureInitialized();

    final safeTitle = title.trim().isEmpty ? 'AkwaabaFit' : title.trim();
    final safeBody = body.trim();
    if (safeBody.isEmpty) return;

    final inboxId = 'admin_$announcementId';
    try {
      final inbox = await NotificationInboxService.getInstance();
      if (inbox.items.any((n) => n.id == inboxId)) return;
    } catch (_) {}

    final permissionGranted = await _requestNotificationPermission();

    await _recordInbox(
      title: safeTitle,
      body: safeBody,
      category: 'push',
      id: inboxId,
    );

    if (!permissionGranted) return;

    await _plugin.show(
      id: 900000 + (announcementId % 100000),
      title: safeTitle,
      body: safeBody,
      notificationDetails: NotificationDetails(
        android: AkwaabaAndroidNotifications.details(
          channelId: 'akwaaba_admin_broadcast',
          channelName: 'AkwaabaFit announcements',
          channelDescription: 'Messages from AkwaabaFit admin',
          expandedBody: safeBody,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  Future<void> _recordInbox({
    required String title,
    required String body,
    required String category,
    String? id,
  }) async {
    try {
      final inbox = await NotificationInboxService.getInstance();
      await inbox.add(
        title: title,
        body: body,
        category: category,
        id: id,
      );
    } catch (_) {}
  }

  AndroidNotificationDetails _androidReminderDetails(String expandedBody) {
    return AkwaabaAndroidNotifications.details(
      channelId: _channelId,
      channelName: _channelName,
      channelDescription: 'Daily goals, step reminders, and wellness nudges',
      expandedBody: expandedBody,
      importance: Importance.max,
      priority: Priority.high,
      color: const Color(0xFF43C763),
    );
  }
}

final localNotificationServiceProvider = Provider<LocalNotificationService>(
  (ref) => LocalNotificationService(),
);
