import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Shared Android notification branding (small + large icons, accent color).
abstract final class AkwaabaAndroidNotifications {
  static const smallIcon = 'ic_notification';
  static const largeIconDrawable = 'ic_notification_large';
  static const brandColor = Color(0xFF1A5D1A);

  static const initSettings = AndroidInitializationSettings(smallIcon);

  static const largeIcon = DrawableResourceAndroidBitmap(largeIconDrawable);

  static AndroidNotificationDetails details({
    required String channelId,
    required String channelName,
    String? channelDescription,
    required String expandedBody,
    Importance importance = Importance.defaultImportance,
    Priority priority = Priority.defaultPriority,
    bool playSound = true,
    bool enableVibration = true,
    bool onlyAlertOnce = false,
    bool ongoing = false,
    bool showLargeIcon = true,
    Color? color,
  }) {
    return AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      icon: smallIcon,
      largeIcon: showLargeIcon ? largeIcon : null,
      color: color ?? brandColor,
      importance: importance,
      priority: priority,
      playSound: playSound,
      enableVibration: enableVibration,
      onlyAlertOnce: onlyAlertOnce,
      ongoing: ongoing,
      styleInformation: BigTextStyleInformation(expandedBody),
    );
  }
}
