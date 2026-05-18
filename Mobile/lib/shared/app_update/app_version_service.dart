import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/shared/app_update/app_update_info.dart';
import 'package:mobile/shared/config/app_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppVersionService {
  static const _dismissedVersionKey = 'app_update_dismissed_for_version';

  static Future<AppUpdateInfo?> checkForUpdate() async {
    if (kIsWeb) return null;

    final platform = _platform();
    if (platform == null) return null;

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          headers: AppConfig.apiHeaders,
        ),
      );

      final resp = await dio.get<Map<String, dynamic>>(
        '/app/version',
        queryParameters: {
          'platform': platform,
          'version': currentVersion,
        },
      );

      final data = resp.data;
      if (data == null || data['status'] != 'success') return null;

      final updateAvailable = data['update_available'] == true;
      final forceUpdate = data['force_update'] == true;
      final storeUrl = (data['store_url'] ?? '').toString().trim();
      final latest = (data['latest_version'] ?? '').toString();
      final message = (data['message'] ?? 'A new version is available.')
          .toString();

      if (!updateAvailable || storeUrl.isEmpty) {
        return AppUpdateInfo(
          latestVersion: latest,
          storeUrl: storeUrl,
          message: message,
          updateAvailable: false,
          forceUpdate: forceUpdate,
          showBanner: false,
        );
      }

      final prefs = await SharedPreferences.getInstance();
      final dismissedFor =
          prefs.getString(_dismissedVersionKey) ?? '';

      final showBanner = forceUpdate || dismissedFor != latest;

      return AppUpdateInfo(
        latestVersion: latest,
        storeUrl: storeUrl,
        message: message,
        updateAvailable: true,
        forceUpdate: forceUpdate,
        showBanner: showBanner,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> dismissForVersion(String latestVersion) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedVersionKey, latestVersion);
  }

  static String? _platform() {
    if (kIsWeb) return null;
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return null;
  }
}
