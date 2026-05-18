import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/shared/config/app_config.dart';
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
      // Also queue today's step sync (cheap, deduped by updateOrCreate).
      await db.enqueueOutbox(type: 'steps_sync', payload: {
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
      // Sync today's steps (and any queued yesterday snapshot) in the background.
      // We keep it in the outbox so it can retry safely.
      await db.enqueueOutbox(type: 'steps_sync', payload: {
        'step_count': steps,
      });

      await Dio(
        BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      ).post('/activity/hourly/log', data: {'step_count': steps});
      _lastDirectPostAt = now;
      await db.deletePendingActivityHourlyOutbox();
    } catch (_) {
      await db.replacePendingActivityHourlyOutbox({'step_count': steps});
    }
  }
}
