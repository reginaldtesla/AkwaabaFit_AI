import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/shared/config/app_config.dart';

class DietitianAskResult {
  const DietitianAskResult({
    required this.answer,
    required this.source,
  });

  final String answer;
  final String source;

  bool get isAiPowered => source == 'gemini';
}

/// Asks AkwaabaFit AI a diet / health question via the backend dietitian coach.
class DietitianAskApi {
  DietitianAskApi({
    Dio? dio,
    FlutterSecureStorage? storage,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.apiBaseUrl.endsWith('/')
                    ? AppConfig.apiBaseUrl
                    : '${AppConfig.apiBaseUrl}/',
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 60),
              ),
            ),
        _storage = storage ?? const FlutterSecureStorage();

  final Dio _dio;
  final FlutterSecureStorage _storage;

  Future<DietitianAskResult> ask(String question) async {
    final token = await _storage.read(key: 'sanctum_token');
    if (token == null || token.isEmpty) {
      throw StateError('Sign in to ask the dietitian.');
    }

    final resp = await _dio.post(
      'nutrition/advice/ask',
      data: {'question': question.trim()},
      options: Options(
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
    );

    final raw = resp.data;
    if (raw is! Map) {
      throw StateError('Unexpected dietitian answer response.');
    }
    final answer = (raw['answer'] ?? '').toString().trim();
    if (answer.isEmpty) {
      throw StateError('No answer returned. Try again.');
    }

    return DietitianAskResult(
      answer: answer,
      source: (raw['source'] ?? 'rules').toString(),
    );
  }
}
