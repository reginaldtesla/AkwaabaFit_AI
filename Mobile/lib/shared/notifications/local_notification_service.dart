import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
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
  static const int _stepsEnableConfirmId = 999;
  static const int _consultBase = 9000;

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

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
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

  /// Confirm booking immediately and schedule reminders for the appointment time.
  ///
  /// - Posts an instant confirmation notification
  /// - Schedules reminders 2 hours before, 30 minutes before, and at start time
  Future<void> scheduleConsultationReminders({
    required DateTime scheduledAt,
    required String professionalName,
  }) async {
    await ensureInitialized();
    final permissionGranted = await _requestNotificationPermission();
    if (!permissionGranted) return;

    final now = tz.TZDateTime.now(tz.local);
    final when = tz.TZDateTime.from(scheduledAt, tz.local);
    if (!when.isAfter(now)) return;

    final pretty =
        '${when.year.toString().padLeft(4, '0')}-${when.month.toString().padLeft(2, '0')}-${when.day.toString().padLeft(2, '0')} '
        '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';

    const bookTitle = 'Nutrition session scheduled';
    final bookBody = 'With $professionalName • $pretty';
    await _recordInbox(
      title: bookTitle,
      body: bookBody,
      category: 'booking',
    );
    await _plugin.show(
      id: _consultBase,
      title: bookTitle,
      body: bookBody,
      notificationDetails: NotificationDetails(
        android: _androidReminderDetails(bookBody),
      ),
    );

    int idFor(int offset) => _consultBase + offset;

    // Cancel any prior reminders for this session signature (best-effort).
    for (final id in [idFor(1), idFor(2), idFor(3)]) {
      await _plugin.cancel(id: id);
    }

    Future<void> scheduleAt(int id, tz.TZDateTime at, String title, String body) async {
      if (!at.isAfter(now)) return;
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: at,
        notificationDetails: NotificationDetails(
          android: _androidReminderDetails(body),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }

    await scheduleAt(
      idFor(1),
      when.subtract(const Duration(hours: 2)),
      'Upcoming nutrition session',
      'In 2 hours • $professionalName • $pretty',
    );
    await scheduleAt(
      idFor(2),
      when.subtract(const Duration(minutes: 30)),
      'Upcoming nutrition session',
      'In 30 minutes • $professionalName • $pretty',
    );
    await scheduleAt(
      idFor(3),
      when,
      'Nutrition session starting',
      'Now • $professionalName • Open Advice to chat.',
    );
  }

  /// Immediate OS notification (e.g. session just went live while app is open).
  Future<void> showInstant({
    required String title,
    required String body,
    String category = 'booking',
  }) async {
    await ensureInitialized();
    final permissionGranted = await _requestNotificationPermission();
    if (!permissionGranted) return;

    await _recordInbox(title: title, body: body, category: category);
    await _plugin.show(
      id: _consultBase + 99,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: _androidReminderDetails(body),
      ),
    );
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

  Future<void> _recordInbox({
    required String title,
    required String body,
    required String category,
  }) async {
    try {
      final inbox = await NotificationInboxService.getInstance();
      await inbox.add(title: title, body: body, category: category);
    } catch (_) {}
  }

  AndroidNotificationDetails _androidReminderDetails(String expandedBody) {
    return AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Daily goals, step reminders, and wellness nudges',
      importance: Importance.max,
      priority: Priority.high,
      color: const Color(0xFF43C763),
      styleInformation: BigTextStyleInformation(expandedBody),
    );
  }
}

final localNotificationServiceProvider = Provider<LocalNotificationService>(
  (ref) => LocalNotificationService(),
);
