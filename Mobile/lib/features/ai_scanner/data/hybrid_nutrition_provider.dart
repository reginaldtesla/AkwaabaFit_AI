import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/features/ai_scanner/data/hybrid_nutrition_service.dart';
import 'package:mobile/shared/config/app_config.dart';
import 'package:mobile/shared/offline/sqlite_offline_db.dart';

final hybridNutritionProvider = FutureProvider<HybridNutritionService>((ref) async {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );
  const storage = FlutterSecureStorage();
  final service = HybridNutritionService(
    dio: dio,
    storage: storage,
    connectivity: Connectivity(),
    dbFuture: SqliteOfflineDb.getInstance(),
  );

  // Background catalog sync when app loads scanner stack (no-op offline).
  await service.syncCatalogIfOnline();
  return service;
});
