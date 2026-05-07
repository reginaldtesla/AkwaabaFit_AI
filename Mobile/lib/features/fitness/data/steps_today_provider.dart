import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

final stepsTodayProvider = StreamProvider<int>((ref) async* {
  const storage = FlutterSecureStorage();

  // Request permission (Android 10+). iOS uses motion permission string.
  final status = await Permission.activityRecognition.request();
  if (!status.isGranted) {
    yield 0;
    return;
  }

  final todayKey = DateTime.now().toIso8601String().substring(0, 10);
  final baselineKey = 'steps_baseline_$todayKey';

  int? baseline;
  int? lastTotal;

  // If we already have a baseline for today, reuse it.
  final stored = await storage.read(key: baselineKey);
  if (stored != null) {
    baseline = int.tryParse(stored);
  }

  final stream = Pedometer.stepCountStream;
  await for (final event in stream) {
    final total = event.steps;

    // Set baseline on first event (or if missing).
    baseline ??= total;
    if (stored == null) {
      await storage.write(key: baselineKey, value: baseline.toString());
    }

    // Some devices occasionally reset the counter; guard it.
    if (lastTotal != null && total < lastTotal!) {
      baseline = total;
      await storage.write(key: baselineKey, value: baseline.toString());
    }
    lastTotal = total;

    final today = (total - baseline!).clamp(0, 1 << 31);
    yield today;
  }
});

