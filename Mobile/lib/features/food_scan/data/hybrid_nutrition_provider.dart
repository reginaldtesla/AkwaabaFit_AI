import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/features/food_scan/data/hybrid_nutrition_service.dart';
import 'package:mobile/shared/config/app_config.dart';
import 'package:mobile/shared/offline/sqlite_offline_db.dart';

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
