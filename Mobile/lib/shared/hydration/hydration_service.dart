import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/shared/config/app_config.dart';
import 'package:mobile/shared/connectivity/connectivity_utils.dart';
import 'package:mobile/shared/offline/sqlite_offline_db.dart';
import 'package:mobile/shared/offline/sqlite_offline_sync_service.dart';

class HydrationToday {
  const HydrationToday({
    required this.totalMl,
    required this.goalMl,
    this.fromCache = false,
  });

  final int totalMl;
  final int goalMl;
  final bool fromCache;

  factory HydrationToday.fromJson(Map<String, dynamic> json) {
    return HydrationToday(
      totalMl: _int(json['totalMl']),
      goalMl: _int(json['goalMl']),
    );
  }

  static int _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse('$v') ?? 0;
  }
}

class HydrationLogResult {
  const HydrationLogResult({
    required this.success,
    required this.totalMl,
    this.syncedOnline = false,
  });

  final bool success;
  final int totalMl;
  final bool syncedOnline;
}

class HydrationService {
  HydrationService({
    required FlutterSecureStorage storage,
    required Connectivity connectivity,
    required Future<SqliteOfflineDb> dbFuture,
  })  : _storage = storage,
        _connectivity = connectivity,
        _dbFuture = dbFuture;

  final FlutterSecureStorage _storage;
  final Connectivity _connectivity;
  final Future<SqliteOfflineDb> _dbFuture;

  Future<SqliteOfflineDb> get _db async => _dbFuture;

  static String _todayKey() =>
      DateTime.now().toIso8601String().substring(0, 10);

  Dio _client(String token) {
    final base = AppConfig.apiBaseUrl.endsWith('/')
        ? AppConfig.apiBaseUrl
        : '${AppConfig.apiBaseUrl}/';
    return Dio(
      BaseOptions(
        baseUrl: base,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          ...AppConfig.apiHeaders,
          'Authorization': 'Bearer $token',
        },
      ),
    );
  }

  Future<int> _goalMlFromProfile(SqliteOfflineDb db) async {
    final profile = await db.getProfileCache();
    final raw = profile?['water_goal_ml'];
    final parsed = raw is int
        ? raw
        : (raw is num ? raw.round() : int.tryParse('$raw'));
    if (parsed != null && parsed >= 1500) {
      return parsed.clamp(1500, 5000);
    }
    return 2000;
  }

  Future<HydrationToday?> fetchToday({
    int seedTotalMl = 0,
    int seedGoalMl = 2000,
  }) async {
    final token = await _storage.read(key: 'sanctum_token');
    if (token == null || token.isEmpty) return null;

    final db = await _db;
    final today = _todayKey();
    final goalSeed = seedGoalMl.clamp(1500, 5000);
    var local = await db.getHydrationLocalForDate(today);
    if (local == null && (seedTotalMl > 0 || seedGoalMl > 0)) {
      await db.upsertHydrationLocal(
        logDate: today,
        totalMl: seedTotalMl,
        goalMl: goalSeed,
      );
      local = (totalMl: seedTotalMl, goalMl: goalSeed);
    }

    if (!await isDeviceOnline()) {
      if (local != null) {
        return HydrationToday(
          totalMl: local.totalMl,
          goalMl: local.goalMl,
          fromCache: true,
        );
      }
      return HydrationToday(
        totalMl: seedTotalMl,
        goalMl: goalSeed,
        fromCache: true,
      );
    }

    try {
      final res = await _client(token).get('hydration/today');
      final data = res.data;
      if (data is Map && data['status'] == 'success') {
        final server = HydrationToday.fromJson(
          data.map((k, v) => MapEntry(k.toString(), v)),
        );
        final mergedTotal = [
          server.totalMl,
          local?.totalMl ?? 0,
          seedTotalMl,
        ].reduce((a, b) => a > b ? a : b);
        final mergedGoal = server.goalMl > 0 ? server.goalMl : goalSeed;
        await db.upsertHydrationLocal(
          logDate: today,
          totalMl: mergedTotal,
          goalMl: mergedGoal,
        );
        return HydrationToday(totalMl: mergedTotal, goalMl: mergedGoal);
      }
    } catch (_) {}

    if (local != null) {
      return HydrationToday(
        totalMl: local.totalMl,
        goalMl: local.goalMl,
        fromCache: true,
      );
    }
    return HydrationToday(
      totalMl: seedTotalMl,
      goalMl: goalSeed,
      fromCache: true,
    );
  }

  Future<HydrationLogResult> logGlass({
    int ml = 250,
    int goalMl = 2000,
  }) async {
    final token = await _storage.read(key: 'sanctum_token');
    if (token == null || token.isEmpty) {
      return const HydrationLogResult(success: false, totalMl: 0);
    }

    final db = await _db;
    final today = _todayKey();
    final goal = goalMl.clamp(1500, 5000);
    final profileGoal = await _goalMlFromProfile(db);
    final effectiveGoal = profileGoal > 0 ? profileGoal : goal;

    final totalMl = await db.addHydrationLocal(
      logDate: today,
      amountMl: ml,
      goalMl: effectiveGoal,
    );

    final payload = {
      'amount_ml': ml,
      'logged_at': DateTime.now().toIso8601String(),
    };
    await db.enqueueOutbox(type: 'hydration_log', payload: payload);

    // Local write is the source of truth for the tap — sync in the background
    // so the button does not wait on remote latency / the full outbox drain.
    final online = await isDeviceOnline();
    if (online) {
      unawaited(syncPendingIfAny());
    }

    return HydrationLogResult(
      success: true,
      totalMl: totalMl,
      syncedOnline: online,
    );
  }

  Future<void> syncPendingIfAny() async {
    if (!await isDeviceOnline()) return;
    final token = await _storage.read(key: 'sanctum_token');
    if (token == null || token.isEmpty) return;

    final db = await _db;
    final base = AppConfig.apiBaseUrl.endsWith('/')
        ? AppConfig.apiBaseUrl
        : '${AppConfig.apiBaseUrl}/';
    final sync = SqliteOfflineSyncService(
      db: db,
      dio: Dio(BaseOptions(baseUrl: base)),
      storage: _storage,
      connectivity: _connectivity,
    );
    await sync.syncOnce();
  }
}

final hydrationServiceProvider = Provider<HydrationService>((ref) {
  return HydrationService(
    storage: const FlutterSecureStorage(),
    connectivity: Connectivity(),
    dbFuture: SqliteOfflineDb.getInstance(),
  );
});
