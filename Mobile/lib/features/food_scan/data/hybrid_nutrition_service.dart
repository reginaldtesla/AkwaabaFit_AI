import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/features/food_scan/data/food_nutrition_info.dart';
import 'package:mobile/shared/config/app_config.dart';
import 'package:mobile/shared/offline/sqlite_offline_db.dart';

class HybridNutritionService {
  HybridNutritionService({
    required Dio dio,
    required FlutterSecureStorage storage,
    required Connectivity connectivity,
    required Future<SqliteOfflineDb> dbFuture,
  })  : _dio = dio,
        _storage = storage,
        _connectivity = connectivity,
        _dbFuture = dbFuture;

  static const _defaultsAsset = 'assets/data/food_nutrition_defaults.json';

  final Dio _dio;
  final FlutterSecureStorage _storage;
  final Connectivity _connectivity;
  final Future<SqliteOfflineDb> _dbFuture;

  Map<String, FoodNutritionInfo>? _bundled;

  Future<bool> isOnline() async {
    final res = await _connectivity.checkConnectivity();
    return res.contains(ConnectivityResult.wifi) ||
        res.contains(ConnectivityResult.mobile) ||
        res.contains(ConnectivityResult.ethernet);
  }

  Future<Map<String, FoodNutritionInfo>> _loadBundled() async {
    if (_bundled != null) return _bundled!;
    final raw = await rootBundle.loadString(_defaultsAsset);
    final list = jsonDecode(raw) as List<dynamic>;
    _bundled = {
      for (final item in list)
        if (item is Map)
          FoodNutritionInfo.fromJson(
            item.map((k, v) => MapEntry(k.toString(), v)),
            source: 'bundled',
          ).className: FoodNutritionInfo.fromJson(
            item.map((k, v) => MapEntry(k.toString(), v)),
            source: 'bundled',
          ),
    };
    return _bundled!;
  }

  Future<FoodNutritionInfo> resolve(String className) async {
    final key = className.trim().toLowerCase();
    final db = await _dbFuture;
    final cached = await db.getNutritionFoodCache(key);
    if (cached != null) {
      return FoodNutritionInfo.fromJson(cached, source: 'cache');
    }

    final bundled = await _loadBundled();
    if (bundled.containsKey(key)) {
      return bundled[key]!;
    }

    return FoodNutritionInfo(
      className: key,
      displayName: _titleCase(key),
      calories: 350,
      proteinG: 15,
      carbsG: 40,
      fatG: 12,
      ironMg: 2.0,
      folateMcg: 50,
      safetyStatus: 'safe',
      source: 'bundled',
      isGenericFallback: true,
    );
  }

  Future<FoodNutritionInfo?> refreshFromServer(String className) async {
    if (!await isOnline()) return null;

    final token = await _storage.read(key: 'sanctum_token');
    if (token == null || token.isEmpty) return null;

    try {
      final resp = await _dio.get(
        '/nutrition/food',
        queryParameters: {'class_name': className.trim().toLowerCase()},
        options: Options(headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        }),
      );

      final raw = resp.data;
      if (raw is! Map) return null;
      final map = raw.map((k, v) => MapEntry(k.toString(), v));
      if (map['status'] != 'success' || map['food'] is! Map) return null;

      final food = FoodNutritionInfo.fromJson(
        (map['food'] as Map).map((k, v) => MapEntry(k.toString(), v)),
        source: 'server',
      );

      final db = await _dbFuture;
      await db.upsertNutritionFoodCache(food.toCacheJson());
      return food;
    } catch (_) {
      return null;
    }
  }

  static String _titleCase(String raw) {
    if (raw.isEmpty) return 'Unknown food';
    return raw
        .replaceAll('-', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}

final hybridNutritionProvider = FutureProvider<HybridNutritionService>((ref) async {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 90),
    ),
  );
  return HybridNutritionService(
    dio: dio,
    storage: const FlutterSecureStorage(),
    connectivity: Connectivity(),
    dbFuture: SqliteOfflineDb.getInstance(),
  );
});
