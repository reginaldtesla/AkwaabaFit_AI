import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/shared/config/app_config.dart';
import 'package:mobile/shared/offline/sqlite_offline_db.dart';
import 'package:mobile/shared/offline/sqlite_offline_sync_service.dart';

/// Offline-first profile store + outbox sync to Laravel.
///
/// Battery-friendly strategy:
/// - Write locally immediately
/// - Enqueue an outbox job
/// - Sync only on explicit triggers (user action / resume / connectivity restored)
class ProfileRepository {
  ProfileRepository({
    required Dio dio,
    required FlutterSecureStorage storage,
    required Connectivity connectivity,
    required Future<SqliteOfflineDb> dbFuture,
  }) : _dio = dio,
       _storage = storage,
       _connectivity = connectivity,
       _dbFuture = dbFuture;

  final Dio _dio;
  final FlutterSecureStorage _storage;
  final Connectivity _connectivity;
  final Future<SqliteOfflineDb> _dbFuture;

  Future<SqliteOfflineDb> get _db async => _dbFuture;

  Future<bool> _isOnline() async {
    final res = await _connectivity.checkConnectivity();
    return res.contains(ConnectivityResult.wifi) ||
        res.contains(ConnectivityResult.mobile) ||
        res.contains(ConnectivityResult.ethernet);
  }

  Future<Map<String, dynamic>?> readLocalProfile() async {
    return (await _db).getProfileCache();
  }

  Future<void> writeLocalProfile(Map<String, dynamic> profile) async {
    await (await _db).putProfileCache(profile);
  }

  Future<void> saveAndSync(Map<String, dynamic> profile) async {
    final db = await _db;
    final existing = await db.getProfileCache();
    final merged = <String, dynamic>{
      ...(existing ?? const <String, dynamic>{}),
      ...profile,
    };
    await db.putProfileCache(merged);
    // Outbox payload should stay as a PATCH (only changed fields).
    await db.enqueueOutbox(type: 'profile_patch', payload: profile);

    // Attempt an immediate sync only if online.
    if (!await _isOnline()) return;
    await syncPendingIfAny();
  }

  Future<void> syncPendingIfAny() async {
    if (!await _isOnline()) return;
    final token = await _storage.read(key: 'sanctum_token');
    if (token == null || token.isEmpty) return;

    final db = await _db;
    final sync = SqliteOfflineSyncService(
      db: db,
      dio: _dio,
      storage: _storage,
      connectivity: _connectivity,
    );
    await sync.syncOnce();
  }

  Future<Map<String, dynamic>?> fetchRemoteAndCache() async {
    final token = await _storage.read(key: 'sanctum_token');
    if (token == null || token.isEmpty) return null;
    if (!await _isOnline()) return null;

    try {
      final resp = await _dio.get(
        '/profile',
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      final user = (resp.data is Map<String, dynamic>)
          ? (resp.data['user'] as Map<String, dynamic>?)
          : null;
      if (user == null) return null;

      await (await _db).putProfileCache(user);
      return user;
    } catch (_) {
      return null;
    }
  }

  Future<String?> uploadAvatar(File file) async {
    final token = await _storage.read(key: 'sanctum_token');
    if (token == null || token.isEmpty) return null;
    if (!await _isOnline()) return null;

    try {
      final form = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(file.path, filename: file.uri.pathSegments.last),
      });

      final resp = await _dio.post(
        '/profile/avatar',
        data: form,
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      final avatarUrlRaw = (resp.data is Map<String, dynamic>)
          ? (resp.data['avatarUrl'] ?? resp.data['avatar_url'])?.toString()
          : null;
      if (avatarUrlRaw == null || avatarUrlRaw.isEmpty) return null;
      final avatarUrl = AppConfig.normalizeUrlForDevice(avatarUrlRaw);

      final db = await _db;
      final existing = await db.getProfileCache();
      await db.putProfileCache(<String, dynamic>{
        ...(existing ?? const <String, dynamic>{}),
        'avatar_url': avatarUrl,
        'avatarUrl': avatarUrl,
      });

      return avatarUrl;
    } catch (_) {
      return null;
    }
  }

  /// Persist leaderboard visibility immediately (not blocked by a stuck outbox).
  /// Returns false only when online but the server rejected/failed the update.
  Future<bool> setPublicOnLeaderboard(bool enabled) async {
    final db = await _db;
    final existing = await db.getProfileCache();
    final merged = <String, dynamic>{
      ...(existing ?? const <String, dynamic>{}),
      'is_public_on_leaderboard': enabled,
    };
    await db.putProfileCache(merged);

    final token = await _storage.read(key: 'sanctum_token');
    if (token == null || token.isEmpty) return false;

    if (!await _isOnline()) {
      await db.enqueueOutbox(
        type: 'profile_patch',
        payload: {'is_public_on_leaderboard': enabled},
      );
      return true;
    }

    try {
      final resp = await _dio.patch(
        '/profile',
        data: {'is_public_on_leaderboard': enabled},
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );
      final user = (resp.data is Map) ? resp.data['user'] : null;
      if (user is Map) {
        await db.putProfileCache(
          user.map((k, dynamic v) => MapEntry(k.toString(), v)),
        );
      }
      return true;
    } catch (_) {
      await db.enqueueOutbox(
        type: 'profile_patch',
        payload: {'is_public_on_leaderboard': enabled},
      );
      return false;
    }
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );
  const storage = FlutterSecureStorage();
  final connectivity = Connectivity();

  return ProfileRepository(
    dio: dio,
    storage: storage,
    connectivity: connectivity,
    dbFuture: SqliteOfflineDb.getInstance(),
  );
});

