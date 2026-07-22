import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mobile/shared/config/app_config.dart';
import 'package:mobile/shared/notifications/akwaaba_android_notifications.dart';
import 'package:mobile/shared/notifications/local_notification_service.dart';
import 'package:mobile/shared/notifications/notification_inbox.dart';

/// Top-level handler for FCM when the app is in background / terminated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await _persistAdminMessageToInbox(message);
}

Future<void> _persistAdminMessageToInbox(RemoteMessage message) async {
  final data = message.data;
  final title = (message.notification?.title ?? data['title'] ?? 'AkwaabaFit')
      .toString()
      .trim();
  final body =
      (message.notification?.body ?? data['body'] ?? '').toString().trim();
  if (title.isEmpty && body.isEmpty) return;

  final announcementId = (data['announcement_id'] ?? '').toString().trim();
  final id = announcementId.isNotEmpty
      ? 'admin_$announcementId'
      : 'fcm_${message.messageId ?? DateTime.now().microsecondsSinceEpoch}';

  try {
    final inbox = await NotificationInboxService.getInstance();
    await inbox.add(
      id: id,
      title: title.isEmpty ? 'AkwaabaFit' : title,
      body: body,
      category: 'push',
    );
  } catch (_) {}
}

/// Firebase Cloud Messaging: register device tokens + show admin broadcasts.
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  static const _tokenStorageKey = 'fcm_device_token_v1';
  static const _adminChannelId = 'akwaaba_admin_broadcast';

  final _storage = const FlutterSecureStorage();
  final _local = LocalNotificationService();
  final _plugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      _initialized = true;
      return;
    }

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await _ensureAdminChannel();
      await _local.ensureInitialized();

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (Platform.isAndroid) {
        await Permission.notification.request();
      }

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      _foregroundSub ??= FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      _tokenRefreshSub ??= messaging.onTokenRefresh.listen((token) {
        unawaited(_registerTokenWithApi(token));
      });

      _initialized = true;
    } catch (e, st) {
      debugPrint('FCM init failed: $e\n$st');
      _initialized = true; // don't retry forever on broken Firebase config
    }
  }

  /// Call after login / when a Sanctum session already exists.
  Future<void> syncRegistration() async {
    await ensureInitialized();
    if (!_firebaseReady) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await _registerTokenWithApi(token);
    } catch (e) {
      debugPrint('FCM token sync failed: $e');
    }
  }

  /// Call on logout (while Sanctum token is still available).
  Future<void> unregister() async {
    final fcmToken = await _storage.read(key: _tokenStorageKey);
    final sanctum = await _storage.read(key: 'sanctum_token');
    if (fcmToken == null ||
        fcmToken.isEmpty ||
        sanctum == null ||
        sanctum.isEmpty) {
      await _storage.delete(key: _tokenStorageKey);
      return;
    }

    try {
      final base = AppConfig.apiBaseUrl.endsWith('/')
          ? AppConfig.apiBaseUrl
          : '${AppConfig.apiBaseUrl}/';
      await Dio(
        BaseOptions(
          baseUrl: base,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      ).delete(
        'device-tokens',
        data: {'token': fcmToken},
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $sanctum',
          },
        ),
      );
    } catch (_) {}

    try {
      if (_firebaseReady) {
        await FirebaseMessaging.instance.deleteToken();
      }
    } catch (_) {}

    await _storage.delete(key: _tokenStorageKey);
  }

  bool get _firebaseReady {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _ensureAdminChannel() async {
    if (!Platform.isAndroid) return;
    const channel = AndroidNotificationChannel(
      _adminChannelId,
      'AkwaabaFit announcements',
      description: 'Messages from AkwaabaFit admin',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _registerTokenWithApi(String fcmToken) async {
    final sanctum = await _storage.read(key: 'sanctum_token');
    if (sanctum == null || sanctum.isEmpty) return;

    final base = AppConfig.apiBaseUrl.endsWith('/')
        ? AppConfig.apiBaseUrl
        : '${AppConfig.apiBaseUrl}/';
    await Dio(
      BaseOptions(
        baseUrl: base,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ),
    ).post(
      'device-tokens',
      data: {
        'token': fcmToken,
        'platform': Platform.isIOS ? 'ios' : 'android',
      },
      options: Options(
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $sanctum',
        },
      ),
    );
    await _storage.write(key: _tokenStorageKey, value: fcmToken);
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final data = message.data;
    final title = (message.notification?.title ?? data['title'] ?? 'AkwaabaFit')
        .toString()
        .trim();
    final body =
        (message.notification?.body ?? data['body'] ?? '').toString().trim();
    if (body.isEmpty && title.isEmpty) return;

    final announcementId =
        int.tryParse((data['announcement_id'] ?? '').toString()) ?? 0;
    if (announcementId > 0) {
      await _local.showAdminBroadcast(
        announcementId: announcementId,
        title: title,
        body: body,
      );
      return;
    }

    await _persistAdminMessageToInbox(message);
    await _local.ensureInitialized();
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      title: title.isEmpty ? 'AkwaabaFit' : title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AkwaabaAndroidNotifications.details(
          channelId: _adminChannelId,
          channelName: 'AkwaabaFit announcements',
          channelDescription: 'Messages from AkwaabaFit admin',
          expandedBody: body,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
