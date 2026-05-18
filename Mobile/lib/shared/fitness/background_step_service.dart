import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/shared/config/app_config.dart';
import 'package:mobile/shared/fitness/foreground_notification_prefs.dart';
import 'package:mobile/shared/fitness/steps_offline_recorder.dart';
import 'package:mobile/shared/fitness/today_steps_from_sensor.dart';

class BackgroundStepService {
  static const _channelId = 'akwaabafit_step_tracking';
  static const _notificationId = 20260508;

  @pragma('vm:entry-point')
  static Future<void> ensureStarted() async {
    if (!defaultTargetPlatform.toString().contains('android')) return;

    // Android 13+/14+: foreground services must post a valid notification.
    // Ensure the channel exists before starting the service.
    final notifications = FlutterLocalNotificationsPlugin();
    const channel = AndroidNotificationChannel(
      _channelId,
      'AkwaabaFit · Steps',
      description:
          'Today’s steps and your activity targets while tracking runs.',
      importance: Importance.low,
      showBadge: false,
    );
    await notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: backgroundServiceOnStart,
        isForegroundMode: true,
        autoStart: true,
        foregroundServiceNotificationId: _notificationId,
        initialNotificationTitle: 'Steps',
        initialNotificationContent: 'Syncing today’s total…',
        notificationChannelId: _channelId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: backgroundServiceOnStart,
      ),
    );

    await service.startService();
  }
}

String _formatSteps(int value) {
  final negative = value < 0;
  final digits = negative ? (-value).toString() : value.toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return negative ? '-$buf' : buf.toString();
}

Future<void> _applySamsungStyleForeground(
  AndroidServiceInstance android,
  int steps,
) async {
  final prefs = await SharedPreferences.getInstance();
  final rawGoal = prefs.getInt(ForegroundNotificationPrefs.stepGoalKey);
  final goal = (rawGoal != null && rawGoal > 0) ? rawGoal : 10000;
  final rawKcal = prefs.getInt(ForegroundNotificationPrefs.calorieGoalKey);
  final kcal = rawKcal ?? 0;

  final stepsLine = 'Target steps ${_formatSteps(goal)}.';
  final subtitle = kcal > 0
      ? '$stepsLine ${_formatSteps(kcal)} kcal/day'
      : stepsLine;

  await android.setForegroundNotificationInfo(
    title: '${_formatSteps(steps)} steps',
    content: subtitle,
  );
}

@pragma('vm:entry-point')
Future<void> backgroundServiceOnStart(ServiceInstance service) async {
  Timer? debounceFg;
  Timer? fgTicker;
  Timer? rolloverTicker;

  final todaySteps = TodayStepsFromSensor();
  int? latestTodaySteps;

  AndroidServiceInstance? android;
  if (service is AndroidServiceInstance) {
    android = service;
    android.setAsForegroundService();
    latestTodaySteps = await StepsOfflineRecorder.cachedTodayStepsOrNull();
    await _applySamsungStyleForeground(android, latestTodaySteps ?? 0);
  }

  StreamSubscription<StepCount>? stepSub;
  Timer? flushTimer;

  DateTime? lastSentAt;
  String currentDayKey = DateTime.now().toIso8601String().substring(0, 10);

  Future<void> sendHourly(int steps) async {
    // Throttle: at most once per 2 minutes.
    final now = DateTime.now();
    if (lastSentAt != null && now.difference(lastSentAt!).inSeconds < 120) {
      return;
    }
    lastSentAt = now;

    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'sanctum_token');
    if (token == null || token.isEmpty) return;

    try {
      await Dio(
        BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      ).post('/activity/hourly/log', data: {'step_count': steps});
    } catch (_) {
      // ignore: best-effort in background
    }
  }

  void stopAll() {
    debounceFg?.cancel();
    fgTicker?.cancel();
    rolloverTicker?.cancel();
    stepSub?.cancel();
    flushTimer?.cancel();
    debounceFg = null;
    fgTicker = null;
    rolloverTicker = null;
    stepSub = null;
    flushTimer = null;
  }

  service.on('stop').listen((_) {
    stopAll();
    service.stopSelf();
  });

  service.on(ForegroundNotificationPrefs.refreshForegroundNotificationEvent).listen(
    (_) async {
      final a = android;
      if (a != null) {
        await _applySamsungStyleForeground(a, latestTodaySteps ?? 0);
      }
    },
  );

  if (android != null) {
    final fgAndroid = android;
    fgTicker = Timer.periodic(const Duration(seconds: 45), (_) async {
      await _applySamsungStyleForeground(fgAndroid, latestTodaySteps ?? 0);
    });

    // Day rollover may happen without a step event; reset to 0 promptly.
    rolloverTicker = Timer.periodic(const Duration(minutes: 1), (_) async {
      final nowKey = DateTime.now().toIso8601String().substring(0, 10);
      if (nowKey == currentDayKey) return;
      currentDayKey = nowKey;
      latestTodaySteps = 0;
      await _applySamsungStyleForeground(fgAndroid, 0);
    });
  }

  try {
    stepSub = Pedometer.stepCountStream.listen(
      (event) async {
        latestTodaySteps = await todaySteps.update(event.steps);
        if (android != null) {
          final fgAndroid = android;
          debounceFg?.cancel();
          debounceFg = Timer(const Duration(seconds: 2), () {
            _applySamsungStyleForeground(fgAndroid, latestTodaySteps ?? 0);
          });
        }
      },
      onError: (_) {
        // Some devices/emulators don't support step sensors; don't crash the service isolate.
      },
      cancelOnError: false,
    );
  } catch (_) {
    // ignore
  }

  flushTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
    final s = latestTodaySteps;
    if (s == null) return;
    await sendHourly(s);
  });
}

