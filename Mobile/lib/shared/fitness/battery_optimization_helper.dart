import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Helps step tracking survive Doze / manufacturer battery savers (Samsung, Xiaomi, etc.).
abstract final class BatteryOptimizationHelper {
  static Future<bool> isIgnoringOptimizations() async {
    if (!Platform.isAndroid) return true;
    return Permission.ignoreBatteryOptimizations.isGranted;
  }

  static Future<bool> requestExemption() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.ignoreBatteryOptimizations.request();
    return status.isGranted;
  }

  /// One-time dialog after login explaining why unrestricted battery helps 24/7 steps.
  static Future<void> maybePrompt(BuildContext context) async {
    if (!Platform.isAndroid) return;
    if (!context.mounted) return;
    if (await isIgnoringOptimizations()) return;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keep step tracking running'),
        content: const Text(
          'For steps to update when the app is closed for days — and after you restart your phone — '
          'allow AkwaabaFit to run without battery restrictions.\n\n'
          'On Samsung / Xiaomi / Oppo, also enable Auto-start for AkwaabaFit in system settings if steps stop.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Allow'),
          ),
        ],
      ),
    );
    if (proceed == true) {
      await requestExemption();
    }
  }
}
