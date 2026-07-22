import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mobile/shared/fitness/steps_offline_recorder.dart';
import 'package:mobile/shared/fitness/background_step_tracking_bootstrap.dart';
import 'package:mobile/shared/fitness/idle_movement_nudge_notifier.dart';
import 'package:mobile/shared/fitness/today_steps_from_sensor.dart';

final stepsTodayProvider = StreamProvider<int>((ref) async* {
  // Request permission (Android 10+). iOS uses motion permission string.
  final status = await Permission.activityRecognition.request();
  if (!status.isGranted) {
    final cached = await StepsOfflineRecorder.cachedTodayStepsOrNull();
    yield cached ?? 0;
    return;
  }
  await BackgroundStepTrackingBootstrap.onActivityPermissionGranted();

  final controller = StreamController<int>();
  ref.onDispose(controller.close);

  String dayKey(DateTime d) => d.toIso8601String().substring(0, 10);

  var currentDay = dayKey(DateTime.now());
  var calc = TodayStepsFromSensor();

  // Show last known steps immediately so Stride is not stuck at 0 while the
  // pedometer stream warms up. First real sensor tick corrects a bad cache.
  final seed = await StepsOfflineRecorder.cachedTodayStepsOrNull();
  if (seed != null && seed > 0) {
    controller.add(seed);
    unawaited(IdleMovementNudgeNotifier.onSteps(seed));
  }

  // Day rollover can happen without a step event; reset UI to 0 at midnight.
  final rollover = Timer.periodic(const Duration(minutes: 1), (_) async {
    final nowDay = dayKey(DateTime.now());
    if (nowDay == currentDay) return;
    currentDay = nowDay;
    calc = TodayStepsFromSensor();
    controller.add(0);
    unawaited(StepsOfflineRecorder.onStepsChanged(0));
    unawaited(IdleMovementNudgeNotifier.onSteps(0));
  });
  ref.onDispose(rollover.cancel);

  // Soft idle check while the app is open (background service also checks).
  final idleCheck = Timer.periodic(const Duration(minutes: 15), (_) {
    unawaited(IdleMovementNudgeNotifier.checkIdle());
  });
  ref.onDispose(idleCheck.cancel);

  StreamSubscription<StepCount>? sub;
  try {
    sub = Pedometer.stepCountStream.listen(
      (event) async {
        final cached =
            await StepsOfflineRecorder.cachedTodayStepsOrNull() ?? 0;
        final today = await calc.update(event.steps, floor: cached);
        controller.add(today);
        unawaited(StepsOfflineRecorder.onStepsChanged(today));
        unawaited(IdleMovementNudgeNotifier.onSteps(today));
      },
      onError: (_) async {
        final cached = await StepsOfflineRecorder.cachedTodayStepsOrNull();
        if (cached != null) {
          controller.add(cached);
        }
      },
      cancelOnError: false,
    );
  } catch (_) {
    final cached = await StepsOfflineRecorder.cachedTodayStepsOrNull();
    controller.add(cached ?? 0);
  }

  ref.onDispose(() => sub?.cancel());
  yield* controller.stream;
});
