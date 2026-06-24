import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/shared/offline/sqlite_offline_db.dart';
import 'package:mobile/shared/offline/sqlite_offline_sync_service.dart';
import 'package:mobile/shared/config/app_config.dart';

class NutritionRepository {
  NutritionRepository({
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

  /// Returns local row ids for offline meal sync.
  Future<({int mealCacheId, int outboxId})> logMeal(
    Map<String, dynamic> meal,
  ) async {
    final db = await _db;
    final mealCacheId = await db.insertMealCache(meal);
    final outboxId = await db.enqueueOutbox(
      type: 'nutrition_log',
      payload: meal,
    );

    if (await _isOnline()) {
      await syncPendingIfAny();
    }

    return (mealCacheId: mealCacheId, outboxId: outboxId);
  }

  Future<void> updateLoggedMeal({
    required int mealCacheId,
    required int outboxId,
    required Map<String, dynamic> meal,
  }) async {
    final db = await _db;
    await db.updateMealCache(mealCacheId, meal);
    await db.updateOutboxPayload(outboxId, meal);
    if (await _isOnline()) {
      await syncPendingIfAny();
    }
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

  Future<Map<String, dynamic>> fetchHistory({
    required DateTime from,
    required DateTime to,
  }) async {
    Future<Map<String, dynamic>> localFallback() async {
      try {
        final rows = await (await _db).getMealCacheBetween(from: from, to: to);
        return _localRowsToHistory(from: from, to: to, rows: rows);
      } catch (_) {
        return {
          'status': 'success',
          'days': <dynamic>[],
          'from': from.toIso8601String().substring(0, 10),
          'to': to.toIso8601String().substring(0, 10),
        };
      }
    }

    final token = await _storage.read(key: 'sanctum_token');
    if (token == null || token.isEmpty) {
      return localFallback();
    }

    // If offline, fall back to local meal cache.
    if (!await _isOnline()) {
      return localFallback();
    }

    try {
      final resp = await _dio.get(
        '/nutrition/history',
        queryParameters: {
          'from': from.toIso8601String().substring(0, 10),
          'to': to.toIso8601String().substring(0, 10),
        },
        options: Options(headers: {
          ...AppConfig.apiHeaders,
          'Authorization': 'Bearer $token',
        }),
      );

      final raw = resp.data;
      if (raw is! Map) {
        return localFallback();
      }
      final map = raw.map((k, dynamic v) => MapEntry(k.toString(), v));

      // Never block history UI if SQLite merge fails.
      try {
        await _mergeHistoryDaysIntoCache(map['days']);
      } catch (_) {}

      if (map['days'] is! List) {
        map['days'] = <dynamic>[];
      }
      map['status'] = map['status'] ?? 'success';
      return _mergeLocalMealsIntoHistoryResponse(
        map,
        from: from,
        to: to,
      );
    } catch (_) {
      return localFallback();
    }
  }

  /// When online, the API may be empty while scans are still in the local cache / outbox.
  Future<Map<String, dynamic>> _mergeLocalMealsIntoHistoryResponse(
    Map<String, dynamic> serverMap, {
    required DateTime from,
    required DateTime to,
  }) async {
    final localRows = await (await _db).getMealCacheBetween(from: from, to: to);
    if (localRows.isEmpty) return serverMap;

    final localHistory =
        _localRowsToHistory(from: from, to: to, rows: localRows);
    final localDays = localHistory['days'];
    if (localDays is! List || localDays.isEmpty) return serverMap;

    final serverDaysRaw = serverMap['days'];
    final serverDays = <Map<String, dynamic>>[];
    if (serverDaysRaw is List) {
      for (final raw in serverDaysRaw) {
        if (raw is Map) {
          serverDays.add(
            raw.map((k, dynamic v) => MapEntry(k.toString(), v)),
          );
        }
      }
    }

    final byDate = <String, Map<String, dynamic>>{
      for (final day in serverDays)
        if ((day['date'] ?? '').toString().isNotEmpty)
          (day['date'] ?? '').toString(): day,
    };

    for (final rawDay in localDays) {
      if (rawDay is! Map) continue;
      final day = rawDay.map((k, dynamic v) => MapEntry(k.toString(), v));
      final date = (day['date'] ?? '').toString();
      if (date.isEmpty) continue;

      final localMeals = day['meals'] is List ? day['meals'] as List : const [];
      final serverDay = byDate[date];
      if (serverDay == null) {
        byDate[date] = day;
        continue;
      }

      final serverMeals =
          serverDay['meals'] is List ? serverDay['meals'] as List : <dynamic>[];
      final seen = <String>{};
      for (final raw in serverMeals) {
        if (raw is! Map) continue;
        final m = raw.map((k, dynamic v) => MapEntry(k.toString(), v));
        final id = m['id']?.toString() ?? '';
        if (id.isNotEmpty) seen.add('id:$id');
        seen.add(_mealDedupeKey(m));
      }

      final merged = List<dynamic>.from(serverMeals);
      for (final raw in localMeals) {
        if (raw is! Map) continue;
        final m = raw.map((k, dynamic v) => MapEntry(k.toString(), v));
        final id = m['id']?.toString() ?? '';
        if (id.isNotEmpty && seen.contains('id:$id')) continue;
        final key = _mealDedupeKey(m);
        if (seen.contains(key)) continue;
        merged.add(m);
        seen.add(key);
      }

      merged.sort((a, b) {
        final aIso = a is Map ? (a['eatenAt'] ?? '').toString() : '';
        final bIso = b is Map ? (b['eatenAt'] ?? '').toString() : '';
        return bIso.compareTo(aIso);
      });

      final totalKcal = merged.fold<int>(0, (sum, item) {
        if (item is! Map) return sum;
        final c = item['calories'];
        if (c is int) return sum + c;
        if (c is num) return sum + c.round();
        return sum + (int.tryParse(c?.toString() ?? '') ?? 0);
      });

      byDate[date] = {
        'date': date,
        'totalKcal': totalKcal,
        'meals': merged,
      };
    }

    final mergedDays = byDate.values.toList()
      ..sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

    return {
      ...serverMap,
      'days': mergedDays,
    };
  }

  String _mealDedupeKey(Map<String, dynamic> m) {
    final eaten = (m['eatenAt'] ?? m['eaten_at'] ?? '').toString();
    final name = (m['name'] ?? '').toString();
    final cal = m['calories'];
    return '$eaten|$name|$cal';
  }

  Map<String, dynamic> _localRowsToHistory({
    required DateTime from,
    required DateTime to,
    required List<Map<String, dynamic>> rows,
  }) {
    final byDate = <String, List<Map<String, dynamic>>>{};
    for (final r in rows) {
      final eatenRaw =
          (r['eaten_at'] ?? DateTime.now().toIso8601String()).toString();
      final date = _calendarDateKeyFromEatenAt(eatenRaw);
      byDate.putIfAbsent(date, () => []).add(r);
    }

    final days = byDate.entries.map((e) {
      final meals = e.value.map((m) {
        Map<String, dynamic>? meta;
        final metaJson = m['meta_json'] as String?;
        if (metaJson != null && metaJson.isNotEmpty) {
          try {
            meta = jsonDecode(metaJson) as Map<String, dynamic>;
          } catch (_) {
            meta = null;
          }
        }

        return {
          'id': (m['server_id'] ?? m['id'] ?? '').toString(),
          'name': (m['name'] ?? '').toString(),
          'eatenAt': (m['eaten_at'] ?? '').toString(),
          'mealType': m['meal_type'],
          'calories':
              (m['calories'] is int)
                  ? m['calories'] as int
                  : int.tryParse((m['calories'] ?? 0).toString()) ?? 0,
          'proteinG': m['protein_g'],
          'carbsG': m['carbs_g'],
          'fatG': m['fat_g'],
          'safetyStatus': m['safety_status'],
          'insightMessage': m['insight_message'],
          'imageUrl': m['image_url'],
          'meta': meta,
          'source': m['source'],
        };
      }).toList();

      final totalKcal = meals.fold<int>(0, (sum, m) => sum + ((m['calories'] ?? 0) as int));

      return {
        'date': e.key,
        'totalKcal': totalKcal,
        'meals': meals,
      };
    }).toList();

    days.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

    return {
      'status': 'success',
      'from': from.toIso8601String().substring(0, 10),
      'to': to.toIso8601String().substring(0, 10),
      'days': days,
    };
  }

  /// YYYY-MM-DD for grouping; avoids substring crashes on short/malformed strings.
  String _calendarDateKeyFromEatenAt(String eatenAt) {
    final t = eatenAt.trim();
    if (t.length >= 10 && RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(t)) {
      return t.substring(0, 10);
    }
    final dt = DateTime.tryParse(t);
    if (dt != null) {
      return '${dt.year.toString().padLeft(4, '0')}-'
          '${dt.month.toString().padLeft(2, '0')}-'
          '${dt.day.toString().padLeft(2, '0')}';
    }
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _mergeHistoryDaysIntoCache(dynamic rawDays) async {
    if (rawDays is! List || rawDays.isEmpty) return;

    final rows = <Map<String, dynamic>>[];
    for (final day in rawDays) {
      if (day is! Map) continue;
      final meals = day['meals'];
      if (meals is! List) continue;
      for (final raw in meals) {
        if (raw is! Map) continue;
        final m = raw.map((k, dynamic v) => MapEntry(k.toString(), v));
        final sid = m['id']?.toString();
        if (sid == null || sid.isEmpty) continue;

        final eatenAt = (m['eatenAt'] ?? '').toString();
        if (eatenAt.isEmpty) continue;

        final imageRaw = m['imageUrl']?.toString().trim();
        final imageUrl = (imageRaw != null && imageRaw.isNotEmpty)
            ? AppConfig.normalizeUrlForDevice(imageRaw)
            : null;

        final meta = m['meta'];
        String? metaJson;
        if (meta is Map) {
          metaJson = jsonEncode(meta);
        }

        rows.add({
          'server_id': sid,
          'eaten_at': eatenAt,
          'meal_type': m['mealType'],
          'name': (m['name'] ?? '').toString(),
          'calories': (m['calories'] as num?)?.toInt() ?? 0,
          'protein_g': m['proteinG'],
          'carbs_g': m['carbsG'],
          'fat_g': m['fatG'],
          'safety_status': m['safetyStatus'],
          'insight_message': m['insightMessage'],
          'image_url': imageUrl,
          'source': (m['source'] ?? 'scan').toString(),
          'meta_json': metaJson,
        });
      }
    }

    await (await _db).mergeServerMealsIntoCache(rows);
  }
}

final nutritionRepositoryProvider = Provider<NutritionRepository>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: AppConfig.apiHeaders,
    ),
  );
  const storage = FlutterSecureStorage();
  final connectivity = Connectivity();

  return NutritionRepository(
    dio: dio,
    storage: storage,
    connectivity: connectivity,
    dbFuture: SqliteOfflineDb.getInstance(),
  );
});

