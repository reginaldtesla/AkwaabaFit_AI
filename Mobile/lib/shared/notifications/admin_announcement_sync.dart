import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/shared/config/app_config.dart';
import 'package:mobile/shared/notifications/local_notification_service.dart';

/// Pulls admin announcements into the bell inbox and phone notification tray.
class AdminAnnouncementSync {
  AdminAnnouncementSync({
    Dio? dio,
    FlutterSecureStorage? storage,
    LocalNotificationService? notifications,
  })  : _dio = dio,
        _storage = storage ?? const FlutterSecureStorage(),
        _notifications = notifications ?? LocalNotificationService();

  final Dio? _dio;
  final FlutterSecureStorage _storage;
  final LocalNotificationService _notifications;

  static const _lastIdKey = 'admin_announcements_last_id_v1';

  Future<int> sync() async {
    final token = await _storage.read(key: 'sanctum_token');
    if (token == null || token.isEmpty) return 0;

    final prefs = await SharedPreferences.getInstance();
    final afterId = prefs.getInt(_lastIdKey) ?? 0;

    final base = AppConfig.apiBaseUrl.endsWith('/')
        ? AppConfig.apiBaseUrl
        : '${AppConfig.apiBaseUrl}/';
    final dio = _dio ??
        Dio(
          BaseOptions(
            baseUrl: base,
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 12),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          ),
        );

    final resp = await dio.get(
      'announcements',
      queryParameters: {'after_id': afterId},
      options: Options(
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
    );

    final raw = resp.data;
    if (raw is! Map) return 0;
    final list = raw['announcements'];
    if (list is! List || list.isEmpty) return 0;

    var maxId = afterId;
    var added = 0;

    for (final item in list) {
      if (item is! Map) continue;
      final row = item.map((k, v) => MapEntry(k.toString(), v));
      final id = int.tryParse('${row['id'] ?? ''}') ?? 0;
      if (id <= 0) continue;
      final title = (row['title'] ?? '').toString().trim();
      final body = (row['body'] ?? '').toString().trim();
      if (title.isEmpty && body.isEmpty) continue;

      await _notifications.showAdminBroadcast(
        announcementId: id,
        title: title,
        body: body,
      );
      added++;
      if (id > maxId) maxId = id;
    }

    if (maxId > afterId) {
      await prefs.setInt(_lastIdKey, maxId);
    }

    return added;
  }
}
