import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/shared/fitness/steps_offline_recorder.dart';
import 'package:mobile/shared/offline/offline_prefs.dart';
import 'package:mobile/shared/offline/sqlite_offline_db.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Offline SQLite caches are shared across accounts on one phone (no user_id column).
/// Wipe them on logout and whenever a different server user signs in.
///
/// Meal history for an account lives on the server (`meal_logs`). Before wipe,
/// the app syncs pending nutrition logs so logout/login can rehydrate history
/// for that user via `GET /nutrition/history`. A different account on the same
/// phone gets an empty local cache, then loads *their* meals from the API.
class OfflineSessionCleanup {
  OfflineSessionCleanup._();

  static const _offlineScopeUserIdKey = 'offline_scope_user_id';

  static Future<void> _clearRecentStepBaselines() async {
    const storage = FlutterSecureStorage();
    final today = DateTime.now();
    final cal = DateTime(today.year, today.month, today.day);
    for (var i = 0; i < 3; i++) {
      final d = cal.subtract(Duration(days: i));
      final key =
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      await storage.delete(key: 'steps_baseline_$key');
      await storage.delete(key: 'steps_carry_$key');
    }
    final utcStyle = today.toIso8601String().substring(0, 10);
    await storage.delete(key: 'steps_baseline_$utcStyle');
    await storage.delete(key: 'steps_carry_$utcStyle');
  }

  static Future<void> wipeDeviceCachesForAccountSwitch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(OfflinePrefsKeys.profileCompleteCached);
    } catch (_) {}
    final db = await SqliteOfflineDb.getInstance();
    await db.wipeSessionCaches();
    await StepsOfflineRecorder.resetSessionCounters();
    await _clearRecentStepBaselines();
  }

  /// Call after tokens are cleared / user leaves the app session.
  static Future<void> markSignedOut() async {
    const storage = FlutterSecureStorage();
    await storage.delete(key: _offlineScopeUserIdKey);
    await wipeDeviceCachesForAccountSwitch();
  }

  /// Call after a successful login/register once the Sanctum token is saved.
  static Future<void> onAuthenticatedUserId(String serverUserId) async {
    if (serverUserId.isEmpty) return;
    const storage = FlutterSecureStorage();
    final prev = await storage.read(key: _offlineScopeUserIdKey);
    if (prev != null && prev != serverUserId) {
      await wipeDeviceCachesForAccountSwitch();
    }
    await storage.write(key: _offlineScopeUserIdKey, value: serverUserId);
  }
}
