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
import 'package:mobile/shared/fitness/step_goal_achievement_notifier.dart';
import 'package:mobile/shared/fitness/today_steps_from_sensor.dart';

class BackgroundStepService {
  /// Low-importance channel: ongoing tracking without heads-up popups.
  static const _channelId = 'akwaabafit_steps_quiet';
  static const _notificationId = 20260508;

  /// How often the foreground notification text may refresh at most.
  static const _foregroundRefreshMinInterval = Duration(minutes: 5);

  /// Only refresh when steps move by at least this much (reduces shade churn).
  static const _foregroundRefreshStepDelta = 250;

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
          'Background step tracking (silent, no alerts).',
      importance: Importance.low,
      showBadge: false,
      playSound: false,
      enableVibration: false,
    );
    final androidPlugin = notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);
    // Drop legacy channels so users are not stuck on high-importance settings.
    for (final legacy in [
      'akwaabafit_step_tracking',
      'akwaabafit_steps_live',
    ]) {
      await androidPlugin?.deleteNotificationChannel(channelId: legacy);
    }

    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: backgroundServiceOnStart,
        isForegroundMode: true,
        autoStart: true,
        autoStartOnBoot: true,
        foregroundServiceTypes: const [AndroidForegroundType.health],
        foregroundServiceNotificationId: _notificationId,
        initialNotificationTitle: 'AkwaabaFit · Steps',
        initialNotificationContent: 'Tracking in the background',
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

Future<void> _onStepsUpdated(int steps) async {
  unawaited(StepGoalAchievementNotifier.evaluate(steps: steps));
}

int? _lastForegroundSteps;
DateTime? _lastForegroundRefreshAt;

/// Updates the required foreground notification only when needed (quiet mode).
Future<void> _applySamsungStyleForeground(
  AndroidServiceInstance android,
  int steps, {
  bool force = false,
}) async {
  final now = DateTime.now();
  final lastAt = _lastForegroundRefreshAt;
  final lastSteps = _lastForegroundSteps;
  if (!force && lastSteps != null && lastAt != null) {
    final stepDelta = (steps - lastSteps).abs();
    final elapsed = now.difference(lastAt);
    if (stepDelta < BackgroundStepService._foregroundRefreshStepDelta &&
        elapsed < BackgroundStepService._foregroundRefreshMinInterval) {
      return;
    }
  }

  final prefs = await SharedPreferences.getInstance();
  final rawGoal = prefs.getInt(ForegroundNotificationPrefs.stepGoalKey);
  final goal = (rawGoal != null && rawGoal > 0) ? rawGoal : 10000;

  await android.setForegroundNotificationInfo(
    title: 'AkwaabaFit · Steps',
    content:
        '${_formatSteps(steps)} today · goal ${_formatSteps(goal)}',
  );
  _lastForegroundSteps = steps;
  _lastForegroundRefreshAt = now;
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
    final initial = latestTodaySteps ?? 0;
    await _applySamsungStyleForeground(android, initial, force: true);
    await _onStepsUpdated(initial);
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
        await _applySamsungStyleForeground(
          a,
          latestTodaySteps ?? 0,
          force: true,
        );
      }
    },
  );

  if (android != null) {
    final fgAndroid = android;
    fgTicker = Timer.periodic(
      BackgroundStepService._foregroundRefreshMinInterval,
      (_) async {
        await _applySamsungStyleForeground(fgAndroid, latestTodaySteps ?? 0);
      },
    );

    // Day rollover may happen without a step event; reset to 0 promptly.
    rolloverTicker = Timer.periodic(const Duration(minutes: 1), (_) async {
      final nowKey = DateTime.now().toIso8601String().substring(0, 10);
      if (nowKey == currentDayKey) return;
      currentDayKey = nowKey;
      latestTodaySteps = 0;
      await _applySamsungStyleForeground(fgAndroid, 0, force: true);
      unawaited(_onStepsUpdated(0));
    });
  }

  try {
    stepSub = Pedometer.stepCountStream.listen(
      (event) async {
        final cached =
            await StepsOfflineRecorder.cachedTodayStepsOrNull() ?? 0;
        latestTodaySteps =
            await todaySteps.update(event.steps, floor: cached);
        final s = latestTodaySteps ?? 0;
        if (s >= cached) {
          unawaited(StepsOfflineRecorder.onStepsChanged(s));
        }
        unawaited(_onStepsUpdated(s));
        if (android != null) {
          final fgAndroid = android;
          // Keep the shade notification on the same total as Stride.
          debounceFg?.cancel();
          debounceFg = Timer(const Duration(seconds: 5), () {
            _applySamsungStyleForeground(fgAndroid, s);
          });
          // Immediate refresh when the shown value would jump a lot (e.g. after
          // aligning with the cached day total).
          final lastShown = _lastForegroundSteps;
          if (lastShown == null || (s - lastShown).abs() >= 100) {
            await _applySamsungStyleForeground(fgAndroid, s, force: true);
          }
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

