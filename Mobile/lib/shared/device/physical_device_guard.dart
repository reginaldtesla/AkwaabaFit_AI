import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// AkwaabaFit is intended for real phones only (steps, camera scan, notifications).
class PhysicalDeviceGuard {
  PhysicalDeviceGuard._();

  /// Set `ALLOW_EMULATOR=true` only for automated CI — not for normal use.
  static const bool allowEmulator = bool.fromEnvironment(
    'ALLOW_EMULATOR',
    defaultValue: false,
  );

  /// Returns null when the device is allowed; otherwise a short user-facing reason.
  static Future<String?> blockReason() async {
    if (allowEmulator) return null;

    if (kIsWeb) {
      return 'AkwaabaFit runs on the Android or iPhone app—not in a browser.';
    }

    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return 'Install AkwaabaFit on your Android phone or iPhone.';
    }

    final plugin = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final android = await plugin.androidInfo;
      if (!android.isPhysicalDevice) {
        return 'Emulators are not supported. Install the app on a real Android phone.';
      }
      return null;
    }

    if (Platform.isIOS) {
      final ios = await plugin.iosInfo;
      if (!ios.isPhysicalDevice) {
        return 'The iOS Simulator is not supported. Install on a real iPhone.';
      }
      return null;
    }

    return 'This device is not supported.';
  }
}
