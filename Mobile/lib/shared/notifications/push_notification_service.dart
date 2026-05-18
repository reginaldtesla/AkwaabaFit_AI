import 'dart:async' show unawaited;

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/shared/config/app_config.dart';
import 'package:mobile/shared/notifications/notification_inbox.dart';

/// Push notifications (FCM) + syncing device token to backend.
class PushNotificationService {
  PushNotificationService({
    FirebaseMessaging? messaging,
    FlutterSecureStorage? storage,
    Dio? dio,
    FlutterLocalNotificationsPlugin? localPlugin,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _storage = storage ?? const FlutterSecureStorage(),
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.apiBaseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
              ),
            ),
        _localPlugin = localPlugin ?? FlutterLocalNotificationsPlugin();

  final FirebaseMessaging _messaging;
  final FlutterSecureStorage _storage;
  final Dio _dio;
  final FlutterLocalNotificationsPlugin _localPlugin;

  static const _channelId = 'advice_messages';
  static const _channelName = 'Advice Messages';

  bool _initialized = false;

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;

    // Ensure local notifications are initialized (for foreground display).
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    final initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await _localPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (resp) {
        // App can optionally deep-link using resp.payload later.
      },
    );

    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Chat replies and new advice messages',
      importance: Importance.high,
    );
    await _localPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await _localPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    // Request permission (Android 13+ / iOS).
    await _messaging.requestPermission();

    // Foreground messages: show a local notification so the user sees it.
    FirebaseMessaging.onMessage.listen((m) {
      final title = m.notification?.title ?? 'New message';
      final body = m.notification?.body ?? '';
      final payload = m.data.isNotEmpty ? m.data.toString() : null;
      unawaited(_recordInbox(title: title, body: body, category: 'push'));
      unawaited(_showLocal(title: title, body: body, payload: payload));
    });

    // Token refresh: re-register.
    _messaging.onTokenRefresh.listen((t) {
      unawaited(_registerToken(t));
    });
  }

  Future<void> syncTokenIfLoggedIn() async {
    await ensureInitialized();
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;
    await _registerToken(token);
  }

  Future<void> _registerToken(String token) async {
    final auth = await _storage.read(key: 'sanctum_token');
    if (auth == null || auth.isEmpty) return;

    await _dio.post(
      '/devices/token',
      data: {
        'token': token,
        'platform': (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) ? 'ios' : 'android',
      },
      options: Options(
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $auth',
        },
      ),
    );
  }

  Future<void> _recordInbox({
    required String title,
    required String body,
    required String category,
  }) async {
    try {
      final inbox = await NotificationInboxService.getInstance();
      await inbox.add(title: title, body: body, category: category);
    } catch (_) {}
  }

  Future<void> _showLocal({
    required String title,
    required String body,
    String? payload,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(body),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    await _localPlugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // FCM will show notifications automatically if the message includes a
  // `notification` payload. Data-only messages can be handled here later.
}

