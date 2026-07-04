import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Lightweight offline DB (no codegen) to avoid battery-heavy polling.
/// Stores:
/// - profile_cache: latest profile snapshot
/// - outbox: queued sync jobs to push to Laravel when online
class SqliteOfflineDb {
  SqliteOfflineDb._(this._db);

  final Database _db;

  static SqliteOfflineDb? _instance;

  static Future<SqliteOfflineDb> getInstance() async {
    if (_instance != null) return _instance!;

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'akwaaba_offline.db');
    final db = await openDatabase(
      path,
      version: 8,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE profile_cache (
            key TEXT PRIMARY KEY,
            json TEXT NOT NULL,
            updated_at TEXT NOT NULL
          );
        ''');

        await db.execute('''
          CREATE TABLE meal_cache (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            eaten_at TEXT NOT NULL,
            meal_type TEXT NULL,
            name TEXT NOT NULL,
            calories INTEGER NOT NULL DEFAULT 0,
            protein_g INTEGER NULL,
            carbs_g INTEGER NULL,
            fat_g INTEGER NULL,
            safety_status TEXT NULL,
            insight_message TEXT NULL,
            image_url TEXT NULL,
            source TEXT NOT NULL DEFAULT 'scan',
            meta_json TEXT NULL,
            created_at TEXT NOT NULL,
            server_id TEXT NULL
          );
        ''');

        await db.execute('''
          CREATE TABLE outbox (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'pending',
            attempt_count INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            last_attempt_at TEXT NULL
          );
        ''');

        await db.execute('''
          CREATE TABLE dashboard_cache (
            key TEXT PRIMARY KEY,
            json TEXT NOT NULL,
            updated_at TEXT NOT NULL
          );
        ''');

        await db.execute('''
          CREATE TABLE activity_cache (
            key TEXT PRIMARY KEY,
            json TEXT NOT NULL,
            updated_at TEXT NOT NULL
          );
        ''');

        await db.execute('''
          CREATE TABLE steps_local (
            log_date TEXT PRIMARY KEY,
            step_count INTEGER NOT NULL,
            updated_at TEXT NOT NULL
          );
        ''');

        await db.execute('''
          CREATE TABLE nutrition_food_cache (
            class_name TEXT PRIMARY KEY,
            json TEXT NOT NULL,
            updated_at TEXT NOT NULL
          );
        ''');

        await db.execute('''
          CREATE TABLE weather_cache (
            key TEXT PRIMARY KEY,
            json TEXT NOT NULL,
            updated_at TEXT NOT NULL
          );
        ''');

        await db.execute('''
          CREATE TABLE leaderboard_cache (
            key TEXT PRIMARY KEY,
            json TEXT NOT NULL,
            updated_at TEXT NOT NULL
          );
        ''');

        await db.execute('''
          CREATE TABLE hydration_local (
            log_date TEXT PRIMARY KEY,
            total_ml INTEGER NOT NULL,
            goal_ml INTEGER NOT NULL,
            updated_at TEXT NOT NULL
          );
        ''');
      },
      onOpen: (db) async {
        // Defensive: hot restarts / old installs can leave the DB without newer tables.
        // Ensure required tables exist before any inserts run.
        await db.execute('''
          CREATE TABLE IF NOT EXISTS profile_cache (
            key TEXT PRIMARY KEY,
            json TEXT NOT NULL,
            updated_at TEXT NOT NULL
          );
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS meal_cache (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            eaten_at TEXT NOT NULL,
            meal_type TEXT NULL,
            name TEXT NOT NULL,
            calories INTEGER NOT NULL DEFAULT 0,
            protein_g INTEGER NULL,
            carbs_g INTEGER NULL,
            fat_g INTEGER NULL,
            safety_status TEXT NULL,
            insight_message TEXT NULL,
            image_url TEXT NULL,
            source TEXT NOT NULL DEFAULT 'scan',
            meta_json TEXT NULL,
            created_at TEXT NOT NULL,
            server_id TEXT NULL
          );
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS outbox (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'pending',
            attempt_count INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            last_attempt_at TEXT NULL
          );
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS dashboard_cache (
            key TEXT PRIMARY KEY,
            json TEXT NOT NULL,
            updated_at TEXT NOT NULL
          );
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS activity_cache (
            key TEXT PRIMARY KEY,
            json TEXT NOT NULL,
            updated_at TEXT NOT NULL
          );
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS steps_local (
            log_date TEXT PRIMARY KEY,
            step_count INTEGER NOT NULL,
            updated_at TEXT NOT NULL
          );
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS nutrition_food_cache (
            class_name TEXT PRIMARY KEY,
            json TEXT NOT NULL,
            updated_at TEXT NOT NULL
          );
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS weather_cache (
            key TEXT PRIMARY KEY,
            json TEXT NOT NULL,
            updated_at TEXT NOT NULL
          );
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS leaderboard_cache (
            key TEXT PRIMARY KEY,
            json TEXT NOT NULL,
            updated_at TEXT NOT NULL
          );
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS hydration_local (
            log_date TEXT PRIMARY KEY,
            total_ml INTEGER NOT NULL,
            goal_ml INTEGER NOT NULL,
            updated_at TEXT NOT NULL
          );
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS meal_cache (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              eaten_at TEXT NOT NULL,
              meal_type TEXT NULL,
              name TEXT NOT NULL,
              calories INTEGER NOT NULL DEFAULT 0,
              protein_g INTEGER NULL,
              carbs_g INTEGER NULL,
              fat_g INTEGER NULL,
              safety_status TEXT NULL,
              insight_message TEXT NULL,
              image_url TEXT NULL,
              source TEXT NOT NULL DEFAULT 'scan',
              meta_json TEXT NULL,
              created_at TEXT NOT NULL
            );
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS dashboard_cache (
              key TEXT PRIMARY KEY,
              json TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS activity_cache (
              key TEXT PRIMARY KEY,
              json TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS steps_local (
              log_date TEXT PRIMARY KEY,
              step_count INTEGER NOT NULL,
              updated_at TEXT NOT NULL
            );
          ''');
        }
        if (oldVersion < 4) {
          final cols = await db.rawQuery("PRAGMA table_info('meal_cache')");
          final hasServerId =
              cols.any((c) => c['name']?.toString() == 'server_id');
          if (!hasServerId) {
            await db.execute(
              'ALTER TABLE meal_cache ADD COLUMN server_id TEXT NULL',
            );
          }
        }
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS nutrition_food_cache (
              class_name TEXT PRIMARY KEY,
              json TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );
          ''');
        }
        if (oldVersion < 6) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS weather_cache (
              key TEXT PRIMARY KEY,
              json TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );
          ''');
        }
        if (oldVersion < 7) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS leaderboard_cache (
              key TEXT PRIMARY KEY,
              json TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );
          ''');
        }
        if (oldVersion < 8) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS hydration_local (
              log_date TEXT PRIMARY KEY,
              total_ml INTEGER NOT NULL,
              goal_ml INTEGER NOT NULL,
              updated_at TEXT NOT NULL
            );
          ''');
        }
      },
    );
    final instance = SqliteOfflineDb._(db);
    _instance = instance;
    return instance;
  }

  Future<void> close() async {
    await _db.close();
    _instance = null;
  }

  Future<void> putProfileCache(Map<String, dynamic> profile) async {
    await _db.insert(
      'profile_cache',
      {
        'key': 'current',
        'json': jsonEncode(profile),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getProfileCache() async {
    final rows = await _db.query(
      'profile_cache',
      columns: ['json'],
      where: 'key = ?',
      whereArgs: ['current'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      return jsonDecode(rows.first['json'] as String) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<int> enqueueOutbox({
    required String type,
    required Map<String, dynamic> payload,
  }) async {
    return _db.insert('outbox', {
      'type': type,
      'payload_json': jsonEncode(payload),
      'status': 'pending',
      'attempt_count': 0,
      'created_at': DateTime.now().toIso8601String(),
      'last_attempt_at': null,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingOutbox({int limit = 25}) async {
    return _db.query(
      'outbox',
      columns: ['id', 'type', 'payload_json', 'attempt_count'],
      where: "status = 'pending'",
      orderBy: 'created_at ASC',
      limit: limit,
    );
  }

  Future<void> markOutboxAttempt(int id) async {
    await _db.update(
      'outbox',
      {'last_attempt_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markOutboxSuccess(int id) async {
    await _db.update(
      'outbox',
      {'status': 'synced'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markOutboxFailed(int id) async {
    await _db.rawUpdate(
      'UPDATE outbox SET attempt_count = attempt_count + 1, last_attempt_at = ? WHERE id = ?',
      [DateTime.now().toIso8601String(), id],
    );
  }

  Future<Map<String, dynamic>?> getNutritionFoodCache(String className) async {
    final rows = await _db.query(
      'nutrition_food_cache',
      columns: ['json'],
      where: 'class_name = ?',
      whereArgs: [className.trim().toLowerCase()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      final decoded = jsonDecode(rows.first['json'] as String);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {}
    return null;
  }

  Future<void> upsertNutritionFoodCache(Map<String, dynamic> food) async {
    final className = (food['class_name'] ?? food['className'])
        ?.toString()
        .trim()
        .toLowerCase();
    if (className == null || className.isEmpty) return;

    final jsonMap = food.map((k, v) => MapEntry(k.toString(), v));

    await _db.insert(
      'nutrition_food_cache',
      {
        'class_name': className,
        'json': jsonEncode(jsonMap),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateMealCache(int id, Map<String, dynamic> fields) async {
    final patch = <String, Object?>{};
    if (fields.containsKey('name')) patch['name'] = fields['name'];
    if (fields.containsKey('calories')) {
      patch['calories'] = (fields['calories'] is int)
          ? fields['calories'] as int
          : int.tryParse(fields['calories'].toString()) ?? 0;
    }
    if (fields.containsKey('protein_g') || fields.containsKey('proteinG')) {
      patch['protein_g'] = fields['protein_g'] ?? fields['proteinG'];
    }
    if (fields.containsKey('carbs_g') || fields.containsKey('carbsG')) {
      patch['carbs_g'] = fields['carbs_g'] ?? fields['carbsG'];
    }
    if (fields.containsKey('fat_g') || fields.containsKey('fatG')) {
      patch['fat_g'] = fields['fat_g'] ?? fields['fatG'];
    }
    if (fields.containsKey('safety_status') ||
        fields.containsKey('safetyStatus')) {
      patch['safety_status'] =
          fields['safety_status'] ?? fields['safetyStatus'];
    }
    if (fields.containsKey('insight_message') ||
        fields.containsKey('insightMessage')) {
      patch['insight_message'] =
          fields['insight_message'] ?? fields['insightMessage'];
    }
    if (patch.isEmpty) return;
    await _db.update('meal_cache', patch, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateOutboxPayload(int outboxId, Map<String, dynamic> payload) async {
    await _db.update(
      'outbox',
      {'payload_json': jsonEncode(payload)},
      where: 'id = ?',
      whereArgs: [outboxId],
    );
  }

  Future<int> insertMealCache(Map<String, dynamic> meal) async {
    return _db.insert(
      'meal_cache',
      {
        'eaten_at': (meal['eaten_at'] ?? DateTime.now().toIso8601String())
            .toString(),
        'meal_type': meal['meal_type'],
        'name': meal['name'] ?? '',
        'calories': (meal['calories'] is int)
            ? meal['calories'] as int
            : int.tryParse((meal['calories'] ?? 0).toString()) ?? 0,
        'protein_g': meal['protein_g'] ?? meal['proteinG'],
        'carbs_g': meal['carbs_g'] ?? meal['carbsG'],
        'fat_g': meal['fat_g'] ?? meal['fatG'],
        'safety_status': meal['safety_status'],
        'insight_message': meal['insight_message'],
        'image_url': meal['image_url'],
        'source': (meal['source'] ?? 'scan').toString(),
        'meta_json': meal['meta'] == null ? null : jsonEncode(meal['meta']),
        'created_at': DateTime.now().toIso8601String(),
        'server_id': meal['server_id'],
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Upserts meals originating from `GET /nutrition/history` (dedupe by [server_id]).
  Future<void> mergeServerMealsIntoCache(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return;
    await _db.transaction((txn) async {
      for (final row in rows) {
        final sid = row['server_id']?.toString();
        if (sid == null || sid.isEmpty) continue;

        Map<String, dynamic>? prev;
        final existingBySid = await txn.query(
          'meal_cache',
          where: 'server_id = ?',
          whereArgs: [sid],
          limit: 1,
        );
        if (existingBySid.isNotEmpty) {
          prev = existingBySid.first;
        } else {
          final eatenAt = row['eaten_at']!.toString();
          final name = (row['name'] ?? '').toString();
          final cal = (row['calories'] is int)
              ? row['calories'] as int
              : int.tryParse((row['calories'] ?? 0).toString()) ?? 0;
          final pendingMatch = await txn.query(
            'meal_cache',
            where:
                "(COALESCE(server_id, '') = '') AND eaten_at = ? AND name = ? AND calories = ?",
            whereArgs: [eatenAt, name, cal],
            limit: 1,
          );
          if (pendingMatch.isNotEmpty) prev = pendingMatch.first;
        }

        int? coalesceMacro(dynamic serverVal, dynamic localVal) {
          if (serverVal != null) {
            if (serverVal is int) return serverVal;
            if (serverVal is num) return serverVal.round();
            return int.tryParse(serverVal.toString());
          }
          if (localVal == null) return null;
          if (localVal is int) return localVal;
          if (localVal is num) return localVal.round();
          return int.tryParse(localVal.toString());
        }

        await txn.delete(
          'meal_cache',
          where: 'server_id = ?',
          whereArgs: [sid],
        );
        await txn.insert(
          'meal_cache',
          {
            'eaten_at': row['eaten_at']!.toString(),
            'meal_type': row['meal_type'],
            'name': (row['name'] ?? '').toString(),
            'calories': (row['calories'] is int)
                ? row['calories'] as int
                : int.tryParse((row['calories'] ?? 0).toString()) ?? 0,
            'protein_g': coalesceMacro(row['protein_g'], prev?['protein_g']),
            'carbs_g': coalesceMacro(row['carbs_g'], prev?['carbs_g']),
            'fat_g': coalesceMacro(row['fat_g'], prev?['fat_g']),
            'safety_status': row['safety_status'],
            'insight_message': row['insight_message'],
            'image_url': row['image_url'],
            'source': (row['source'] ?? 'scan').toString(),
            'meta_json': row['meta_json'],
            'created_at': DateTime.now().toIso8601String(),
            'server_id': sid,
          },
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> getMealCacheBetween({
    required DateTime from,
    required DateTime to,
  }) async {
    return _db.query(
      'meal_cache',
      where: 'eaten_at >= ? AND eaten_at <= ?',
      whereArgs: [from.toIso8601String(), to.toIso8601String()],
      orderBy: 'eaten_at DESC',
    );
  }

  /// Calories logged on this device for [dayLocal]'s calendar day that are not
  /// linked to a server row yet (`server_id` empty). Matches Nutrition History
  /// showing offline meals the API dashboard does not know about.
  Future<int> sumPendingSyncCaloriesForLocalDay(DateTime dayLocal) async {
    final start = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
    final endExclusive = start.add(const Duration(days: 1));
    final rows = await _db.rawQuery(
      '''
      SELECT COALESCE(SUM(calories), 0) AS total
      FROM meal_cache
      WHERE (server_id IS NULL OR server_id = '')
        AND eaten_at >= ?
        AND eaten_at < ?
      ''',
      [start.toIso8601String(), endExclusive.toIso8601String()],
    );
    final v = rows.first['total'];
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  /// All meals on [dayLocal]'s calendar day (synced + pending) — source of truth on device.
  Future<({int proteinG, int carbsG, int fatG, int mealCount})>
      sumMealCacheMacrosAllForLocalCalendarDay(DateTime dayLocal) async {
    final start = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
    final endExclusive = start.add(const Duration(days: 1));
    final rows = await _db.rawQuery(
      '''
      SELECT
        COUNT(*) AS cnt,
        COALESCE(SUM(COALESCE(protein_g, 0)), 0) AS p,
        COALESCE(SUM(COALESCE(carbs_g, 0)), 0) AS c,
        COALESCE(SUM(COALESCE(fat_g, 0)), 0) AS f
      FROM meal_cache
      WHERE eaten_at >= ?
        AND eaten_at < ?
      ''',
      [start.toIso8601String(), endExclusive.toIso8601String()],
    );
    final row = rows.first;
    int pick(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.round();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    return (
      proteinG: pick(row['p']),
      carbsG: pick(row['c']),
      fatG: pick(row['f']),
      mealCount: pick(row['cnt']),
    );
  }

  /// Total calories from all cached meals on [dayLocal]'s calendar day (synced + pending).
  Future<int> sumMealCacheCaloriesAllForLocalCalendarDay(DateTime dayLocal) async {
    final start = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
    final endExclusive = start.add(const Duration(days: 1));
    final rows = await _db.rawQuery(
      '''
      SELECT COALESCE(SUM(calories), 0) AS total
      FROM meal_cache
      WHERE eaten_at >= ?
        AND eaten_at < ?
      ''',
      [start.toIso8601String(), endExclusive.toIso8601String()],
    );
    final v = rows.first['total'];
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  /// Protein/carbs/fat grams for pending (unsynced) meals on [dayLocal]'s calendar day.
  Future<({int proteinG, int carbsG, int fatG})> sumPendingSyncMacrosForLocalDay(
    DateTime dayLocal,
  ) async {
    final start = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
    final endExclusive = start.add(const Duration(days: 1));
    final rows = await _db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(COALESCE(protein_g, 0)), 0) AS p,
        COALESCE(SUM(COALESCE(carbs_g, 0)), 0) AS c,
        COALESCE(SUM(COALESCE(fat_g, 0)), 0) AS f
      FROM meal_cache
      WHERE (server_id IS NULL OR server_id = '')
        AND eaten_at >= ?
        AND eaten_at < ?
      ''',
      [start.toIso8601String(), endExclusive.toIso8601String()],
    );
    final row = rows.first;
    int pick(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.round();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    return (
      proteinG: pick(row['p']),
      carbsG: pick(row['c']),
      fatG: pick(row['f']),
    );
  }

  Future<void> attachServerIdToLatestPendingMeal({
    required String eatenAt,
    required String name,
    required int calories,
    required String serverId,
  }) async {
    await _db.rawUpdate(
      '''
      UPDATE meal_cache SET server_id = ?
      WHERE id = (
        SELECT id FROM meal_cache
        WHERE (server_id IS NULL OR server_id = '')
          AND eaten_at = ?
          AND name = ?
          AND calories = ?
        ORDER BY id DESC
        LIMIT 1
      )
      ''',
      [serverId, eatenAt, name, calories],
    );
  }

  Future<void> putDashboardCache(Map<String, dynamic> json) async {
    await _db.insert(
      'dashboard_cache',
      {
        'key': 'current',
        'json': jsonEncode(json),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getDashboardCache() async {
    final rows = await _db.query(
      'dashboard_cache',
      columns: ['json'],
      where: 'key = ?',
      whereArgs: ['current'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      final decoded = jsonDecode(rows.first['json'] as String);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> putWeatherCache(Map<String, dynamic> json) async {
    await _db.insert(
      'weather_cache',
      {
        'key': 'current',
        'json': jsonEncode(json),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getWeatherCache() async {
    final rows = await _db.query(
      'weather_cache',
      columns: ['json'],
      where: 'key = ?',
      whereArgs: ['current'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      final decoded = jsonDecode(rows.first['json'] as String);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> putActivityCache(Map<String, dynamic> json) async {
    await _db.insert(
      'activity_cache',
      {
        'key': 'today',
        'json': jsonEncode(json),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getActivityCache() async {
    final rows = await _db.query(
      'activity_cache',
      columns: ['json'],
      where: 'key = ?',
      whereArgs: ['today'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      final decoded = jsonDecode(rows.first['json'] as String);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> upsertStepsLocal({
    required String logDate,
    required int stepCount,
  }) async {
    await _db.insert(
      'steps_local',
      {
        'log_date': logDate,
        'step_count': stepCount,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int?> getStepsLocalForDate(String logDate) async {
    final rows = await _db.query(
      'steps_local',
      columns: ['step_count'],
      where: 'log_date = ?',
      whereArgs: [logDate],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final v = rows.first['step_count'];
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  Future<({int totalMl, int goalMl})?> getHydrationLocalForDate(
    String logDate,
  ) async {
    final rows = await _db.query(
      'hydration_local',
      columns: ['total_ml', 'goal_ml'],
      where: 'log_date = ?',
      whereArgs: [logDate],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final total = row['total_ml'];
    final goal = row['goal_ml'];
    return (
      totalMl: total is int ? total : int.tryParse('$total') ?? 0,
      goalMl: goal is int ? goal : int.tryParse('$goal') ?? 2000,
    );
  }

  Future<void> upsertHydrationLocal({
    required String logDate,
    required int totalMl,
    required int goalMl,
  }) async {
    await _db.insert(
      'hydration_local',
      {
        'log_date': logDate,
        'total_ml': totalMl,
        'goal_ml': goalMl,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> addHydrationLocal({
    required String logDate,
    required int amountMl,
    int goalMl = 2000,
  }) async {
    final existing = await getHydrationLocalForDate(logDate);
    final nextTotal = (existing?.totalMl ?? 0) + amountMl;
    final nextGoal = existing?.goalMl ?? goalMl;
    await upsertHydrationLocal(
      logDate: logDate,
      totalMl: nextTotal,
      goalMl: nextGoal,
    );
    return nextTotal;
  }

  /// Keeps a single pending hourly step job so the outbox does not grow with every sensor tick.
  Future<void> replacePendingActivityHourlyOutbox(
    Map<String, dynamic> payload,
  ) async {
    await _db.transaction((txn) async {
      await txn.delete(
        'outbox',
        where: "type = ? AND status = 'pending'",
        whereArgs: ['activity_hourly_log'],
      );
      await txn.insert('outbox', {
        'type': 'activity_hourly_log',
        'payload_json': jsonEncode(payload),
        'status': 'pending',
        'attempt_count': 0,
        'created_at': DateTime.now().toIso8601String(),
        'last_attempt_at': null,
      });
    });
  }

  Future<void> deletePendingActivityHourlyOutbox() async {
    await _db.delete(
      'outbox',
      where: "type = ? AND status = 'pending'",
      whereArgs: ['activity_hourly_log'],
    );
  }

  /// Clears rows that are not scoped per-user (same DB file for every account on this device).
  Future<void> wipeSessionCaches() async {
    await _db.transaction((txn) async {
      await txn.rawDelete('DELETE FROM dashboard_cache');
      await txn.rawDelete('DELETE FROM activity_cache');
      await txn.rawDelete('DELETE FROM meal_cache');
      await txn.rawDelete('DELETE FROM steps_local');
      await txn.rawDelete('DELETE FROM profile_cache');
      await txn.rawDelete('DELETE FROM outbox');
      await txn.rawDelete('DELETE FROM nutrition_food_cache');
      await txn.rawDelete('DELETE FROM leaderboard_cache');
      await txn.rawDelete('DELETE FROM hydration_local');
    });
  }

  Future<void> clearLeaderboardCache() async {
    await _db.delete('leaderboard_cache');
  }

  Future<void> putLeaderboardCache(String key, Map<String, dynamic> json) async {
    await _db.insert(
      'leaderboard_cache',
      {
        'key': key,
        'json': jsonEncode(json),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getLeaderboardCache(String key) async {
    final rows = await _db.query(
      'leaderboard_cache',
      columns: ['json'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      final decoded = jsonDecode(rows.first['json'] as String);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {}
    return null;
  }
}

