import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/shared/config/app_config.dart';

class HydrationToday {
  const HydrationToday({
    required this.totalMl,
    required this.goalMl,
  });

  final int totalMl;
  final int goalMl;

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

class HydrationService {
  HydrationService(this._dio, this._storage);

  final Dio _dio;
  final FlutterSecureStorage _storage;

  Future<HydrationToday?> fetchToday() async {
    final token = await _storage.read(key: 'sanctum_token');
    if (token == null) return null;
    try {
      final res = await _dio.get(
        '/hydration/today',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = res.data;
      if (data is Map && data['status'] == 'success') {
        return HydrationToday.fromJson(
          data.map((k, v) => MapEntry(k.toString(), v)),
        );
      }
    } catch (_) {}
    return null;
  }

  Future<bool> logGlass({int ml = 250}) async {
    final token = await _storage.read(key: 'sanctum_token');
    if (token == null) return false;
    try {
      await _dio.post(
        '/hydration/log',
        data: {'amount_ml': ml},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

final hydrationServiceProvider = Provider<HydrationService>((ref) {
  return HydrationService(
    Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl)),
    const FlutterSecureStorage(),
  );
});
