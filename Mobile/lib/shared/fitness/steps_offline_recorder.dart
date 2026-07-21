import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/shared/config/app_config.dart';
import 'package:mobile/shared/fitness/leaderboard_refresh_bus.dart';
import 'package:mobile/shared/offline/sqlite_offline_db.dart';

/// Persists today's steps locally and syncs-or-queues `POST /activity/hourly/log`.
/// Runs from the main isolate (pedometer stream).
class StepsOfflineRecorder {
  StepsOfflineRecorder._();

  static DateTime? _lastDirectPostAt;
  static const _lastStepDateKey = 'steps_last_log_date';
  static const _lastStepCountKey = 'steps_last_log_value';

  /// Last “today” count saved by [onStepsChanged] when its date matches today (background UI seed).
  static Future<int?> cachedTodayStepsOrNull() async {
    const storage = FlutterSecureStorage();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lastDate = await storage.read(key: _lastStepDateKey);
    final raw = await storage.read(key: _lastStepCountKey);
    if (lastDate != today) return null;
    return int.tryParse(raw ?? '');
  }

  /// Clears rollover bookkeeping when switching accounts so steps do not inherit another profile.
  static Future<void> resetSessionCounters() async {
    const storage = FlutterSecureStorage();
    await storage.delete(key: _lastStepDateKey);
    await storage.delete(key: _lastStepCountKey);
  }

  static Future<void> onStepsChanged(int steps) async {
    final db = await SqliteOfflineDb.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await db.upsertStepsLocal(logDate: today, stepCount: steps);

    const storage = FlutterSecureStorage();
    // Option B: daily snapshot rollover. When date changes, persist yesterday and enqueue sync.
    final lastDate = await storage.read(key: _lastStepDateKey);
    final lastValueRaw = await storage.read(key: _lastStepCountKey);
    final lastValue = int.tryParse(lastValueRaw ?? '') ?? 0;
    if (lastDate != null && lastDate.isNotEmpty && lastDate != today) {
      // Store final observed steps for the previous date.
      await db.upsertStepsLocal(logDate: lastDate, stepCount: lastValue);
      await db.enqueueOutbox(type: 'steps_sync', payload: {
        'log_date': lastDate,
        'step_count': lastValue,
      });
    }
    await storage.write(key: _lastStepDateKey, value: today);
    await storage.write(key: _lastStepCountKey, value: steps.toString());

    final token = await storage.read(key: 'sanctum_token');
    if (token == null || token.isEmpty) return;

    final connectivity = Connectivity();
    final results = await connectivity.checkConnectivity();
    final online = results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.ethernet);

    if (!online) {
      await db.replacePendingActivityHourlyOutbox({'step_count': steps});
      await db.enqueueOutbox(type: 'steps_sync', payload: {
        'log_date': today,
        'step_count': steps,
      });
      return;
    }

    final now = DateTime.now();
    if (_lastDirectPostAt != null &&
        now.difference(_lastDirectPostAt!).inSeconds < 120) {
      return;
    }

    try {
      await db.enqueueOutbox(type: 'steps_sync', payload: {
        'log_date': today,
        'step_count': steps,
      });

      final dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );
      await dio.post('/activity/hourly/log', data: {'step_count': steps});
      await dio.post('/steps/sync', data: {
        'step_count': steps,
        'log_date': today,
      });
      _lastDirectPostAt = now;
      await db.deletePendingActivityHourlyOutbox();
      LeaderboardRefreshBus.notify();
    } catch (_) {
      await db.replacePendingActivityHourlyOutbox({'step_count': steps});
    }
  }

  /// Force-sync today's steps to the server (ignores the normal 2‑minute throttle).
  /// Needed so opted-in users appear on the leaderboard without waiting.
  ///
  /// Pass [notifyRefresh]: false when the leaderboard itself is already loading,
  /// so a successful sync does not kick off a second full reload.
  static Future<bool> flushTodayStepsForLeaderboard({
    bool notifyRefresh = true,
  }) async {
    final db = await SqliteOfflineDb.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'sanctum_token');
    if (token == null || token.isEmpty) return false;

    final connectivity = Connectivity();
    final results = await connectivity.checkConnectivity();
    final online = results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.ethernet);
    if (!online) return false;

    var steps = await db.getStepsLocalForDate(today) ?? 0;
    if (steps <= 0) {
      steps = int.tryParse(await storage.read(key: _lastStepCountKey) ?? '') ?? 0;
      final lastDate = await storage.read(key: _lastStepDateKey);
      if (lastDate != today) {
        steps = 0;
      }
    }
    if (steps <= 0) return false;

    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 5),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );
      await dio.post('/steps/sync', data: {
        'step_count': steps,
        'log_date': today,
      });
      _lastDirectPostAt = DateTime.now();
      if (notifyRefresh) {
        LeaderboardRefreshBus.notify();
      }
      return true;
    } catch (_) {
      await db.enqueueOutbox(type: 'steps_sync', payload: {
        'log_date': today,
        'step_count': steps,
      });
      return false;
    }
  }
}
