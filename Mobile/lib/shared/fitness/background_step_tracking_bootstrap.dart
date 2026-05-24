import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:mobile/shared/fitness/background_step_service.dart';
import 'package:mobile/shared/fitness/battery_optimization_helper.dart';
import 'package:mobile/shared/fitness/persistent_step_tracking_prefs.dart';
import 'package:permission_handler/permission_handler.dart';

/// Starts / restores the foreground step service (boot, app launch, resume).
abstract final class BackgroundStepTrackingBootstrap {
  /// Call from [main] before [runApp].
  static Future<void> initializeOnAppStart() async {
    if (!Platform.isAndroid) return;
    await BackgroundStepService.ensureStarted();
    await PersistentStepTrackingPrefs.markConfigured();

    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      await service.startService();
    }
  }

  /// Call when the app returns to foreground — restarts service if the OS killed it.
  static Future<void> ensureRunningOnResume() async {
    if (!Platform.isAndroid) return;
    if (!await PersistentStepTrackingPrefs.isConfigured()) return;

    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      await BackgroundStepService.ensureStarted();
      await service.startService();
    }
  }

  /// After activity recognition is granted (dashboard / activity screen).
  static Future<void> onActivityPermissionGranted() async {
    if (!Platform.isAndroid) return;

    await Permission.notification.request();
    await initializeOnAppStart();
  }

  static Future<void> promptBatteryIfNeeded(BuildContext context) async {
    if (!Platform.isAndroid || !context.mounted) return;
    if (await BatteryOptimizationHelper.isIgnoringOptimizations()) return;
    if (await PersistentStepTrackingPrefs.wasBatteryOptimizationPrompted()) {
      return;
    }
    await PersistentStepTrackingPrefs.markBatteryOptimizationPrompted();
    if (!context.mounted) return;
    await BatteryOptimizationHelper.maybePrompt(context);
  }
}
