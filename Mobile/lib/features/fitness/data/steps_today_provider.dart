import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mobile/shared/fitness/steps_offline_recorder.dart';
import 'package:mobile/shared/fitness/today_steps_from_sensor.dart';

final stepsTodayProvider = StreamProvider<int>((ref) async* {
  // Request permission (Android 10+). iOS uses motion permission string.
  final status = await Permission.activityRecognition.request();
  if (!status.isGranted) {
    yield 0;
    return;
  }

  final controller = StreamController<int>();
  ref.onDispose(controller.close);

  String dayKey(DateTime d) => d.toIso8601String().substring(0, 10);

  var currentDay = dayKey(DateTime.now());
  var calc = TodayStepsFromSensor();

  // Day rollover can happen without a step event; reset UI to 0 at midnight.
  final rollover = Timer.periodic(const Duration(minutes: 1), (_) async {
    final nowDay = dayKey(DateTime.now());
    if (nowDay == currentDay) return;
    currentDay = nowDay;
    calc = TodayStepsFromSensor();
    controller.add(0);
    unawaited(StepsOfflineRecorder.onStepsChanged(0));
  });
  ref.onDispose(rollover.cancel);

  StreamSubscription<StepCount>? sub;
  try {
    sub = Pedometer.stepCountStream.listen(
      (event) async {
        final today = await calc.update(event.steps);
        controller.add(today);
        unawaited(StepsOfflineRecorder.onStepsChanged(today));
      },
      onError: (_) {
        controller.add(0);
      },
      cancelOnError: false,
    );
  } catch (_) {
    controller.add(0);
  }

  ref.onDispose(() => sub?.cancel());
  yield* controller.stream;
});

