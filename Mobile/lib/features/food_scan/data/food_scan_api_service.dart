import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/shared/config/app_config.dart';

class FoodScanDetection {
  const FoodScanDetection({
    required this.className,
    required this.displayName,
    required this.confidence,
    required this.source,
  });

  final String className;
  final String displayName;
  final double confidence;
  final String source;

  factory FoodScanDetection.fromJson(Map<String, dynamic> json) {
    return FoodScanDetection(
      className: (json['class_name'] ?? json['className'] ?? '').toString(),
      displayName: (json['display_name'] ?? json['displayName'] ?? '').toString(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      source: (json['source'] ?? 'hybrid').toString(),
    );
  }
}

class FoodScanApiService {
  FoodScanApiService({
    Dio? dio,
    FlutterSecureStorage? storage,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.apiBaseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 120),
              ),
            ),
        _storage = storage ?? const FlutterSecureStorage();

  final Dio _dio;
  final FlutterSecureStorage _storage;

  Future<
      ({
        String provider,
        String strategy,
        List<FoodScanDetection> detections,
        String? message,
      })> scanImage(String imagePath) async {
    final token = await _storage.read(key: 'sanctum_token');
    if (token == null || token.isEmpty) {
      throw StateError('Sign in to scan food.');
    }

    final form = FormData.fromMap({
      'image': await MultipartFile.fromFile(imagePath, filename: 'scan.jpg'),
    });

    final resp = await _dio.post(
      '/nutrition/scan',
      data: form,
      options: Options(
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
    );

    final raw = resp.data;
    if (raw is! Map) {
      throw StateError('Unexpected scan response.');
    }

    final map = raw.map((k, v) => MapEntry(k.toString(), v));
    if (map['status'] != 'success') {
      throw StateError(map['message']?.toString() ?? 'Food scan failed.');
    }

    final detections = <FoodScanDetection>[];
    final list = map['detections'];
    if (list is List) {
      for (final item in list) {
        if (item is Map) {
          detections.add(
            FoodScanDetection.fromJson(
              item.map((k, v) => MapEntry(k.toString(), v)),
            ),
          );
        }
      }
    }

    return (
      provider: map['provider']?.toString() ?? 'hybrid',
      strategy: map['strategy']?.toString() ?? 'unknown',
      detections: detections,
      message: map['message']?.toString(),
    );
  }

  Future<({
    String insight,
    String? pairing,
    String? portion,
    String source,
  })> fetchMealAdvice({
    required String name,
    String? className,
    int calories = 0,
    int proteinG = 0,
    int carbsG = 0,
    int fatG = 0,
  }) async {
    final token = await _storage.read(key: 'sanctum_token');
    if (token == null || token.isEmpty) {
      throw StateError('Sign in for dietitian advice.');
    }

    final resp = await _dio.post(
      '/nutrition/advice/meal',
      data: {
        'name': name,
        if (className != null && className.isNotEmpty) 'class_name': className,
        'calories': calories,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
      },
      options: Options(
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
    );

    final raw = resp.data;
    if (raw is! Map) {
      throw StateError('Unexpected dietitian advice response.');
    }
    final map = raw.map((k, v) => MapEntry(k.toString(), v));
    if (map['status'] != 'success') {
      throw StateError(map['message']?.toString() ?? 'Dietitian advice failed.');
    }

    final advice = map['advice'];
    if (advice is! Map) {
      throw StateError('Missing advice payload.');
    }
    final a = advice.map((k, v) => MapEntry(k.toString(), v));

    return (
      insight: (a['insight'] ?? '').toString(),
      pairing: a['pairing']?.toString(),
      portion: a['portion']?.toString(),
      source: (a['source'] ?? 'rules').toString(),
    );
  }
}

final foodScanApiProvider = Provider<FoodScanApiService>((ref) {
  return FoodScanApiService();
});
