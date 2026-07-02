import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/shared/config/app_config.dart';
import 'package:mobile/shared/fitness/leaderboard_refresh_bus.dart';
import 'package:mobile/shared/offline/sqlite_offline_db.dart';

class SqliteOfflineSyncService {
  SqliteOfflineSyncService({
    required this.db,
    required this.dio,
    required this.storage,
    required this.connectivity,
  });

  final SqliteOfflineDb db;
  final Dio dio;
  final FlutterSecureStorage storage;
  final Connectivity connectivity;

  Future<bool> _isOnline() async {
    final res = await connectivity.checkConnectivity();
    return res.contains(ConnectivityResult.wifi) ||
        res.contains(ConnectivityResult.mobile) ||
        res.contains(ConnectivityResult.ethernet);
  }

  Future<void> syncOnce() async {
    if (!await _isOnline()) return;
    final token = await storage.read(key: 'sanctum_token');
    if (token == null || token.isEmpty) return;

    final jobs = await db.getPendingOutbox(limit: 25);
    if (jobs.isEmpty) return;

    for (final job in jobs) {
      final id = job['id'] as int;
      final type = job['type'] as String;
      final payload = jsonDecode(job['payload_json'] as String) as Map<String, dynamic>;

      await db.markOutboxAttempt(id);

      try {
        switch (type) {
          case 'steps_sync':
            await dio.post(
              '/steps/sync',
              data: payload,
              options: Options(headers: {
                ...AppConfig.apiHeaders,
                'Authorization': 'Bearer $token',
              }),
            );
            await db.markOutboxSuccess(id);
            LeaderboardRefreshBus.notify();
            break;
          case 'profile_patch':
            await dio.patch(
              '/profile',
              data: payload,
              options: Options(headers: {
                ...AppConfig.apiHeaders,
                'Authorization': 'Bearer $token',
              }),
            );
            await db.markOutboxSuccess(id);
            break;
          case 'nutrition_log':
            final resp = await dio.post(
              '/nutrition/log',
              data: payload,
              options: Options(headers: {
                ...AppConfig.apiHeaders,
                'Authorization': 'Bearer $token',
              }),
            );
            await db.markOutboxSuccess(id);
            try {
              final body = resp.data;
              if (body is Map) {
                final mealRaw = body['meal'];
                if (mealRaw is Map) {
                  final m =
                      mealRaw.map((k, dynamic v) => MapEntry(k.toString(), v));
                  final sid = m['id']?.toString();
                  if (sid != null && sid.isNotEmpty) {
                    final eatenAt =
                        (payload['eaten_at'] ?? '').toString();
                    final name = (payload['name'] ?? '').toString();
                    final calRaw = payload['calories'];
                    final calories = calRaw is int
                        ? calRaw
                        : (calRaw as num?)?.round() ??
                            int.tryParse('$calRaw') ??
                            0;
                    await db.attachServerIdToLatestPendingMeal(
                      eatenAt: eatenAt,
                      name: name,
                      calories: calories,
                      serverId: sid,
                    );
                  }
                }
              }
            } catch (_) {}
            break;
          case 'activity_hourly_log':
            await dio.post(
              '/activity/hourly/log',
              data: payload,
              options: Options(headers: {
                ...AppConfig.apiHeaders,
                'Authorization': 'Bearer $token',
              }),
            );
            await db.markOutboxSuccess(id);
            break;
          default:
            await db.markOutboxFailed(id);
            return;
        }
      } catch (_) {
        await db.markOutboxFailed(id);
        // Stop to avoid battery/network burn when server is failing.
        return;
      }
    }
  }
}

