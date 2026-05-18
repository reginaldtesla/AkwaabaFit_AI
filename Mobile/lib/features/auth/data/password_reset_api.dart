import 'package:dio/dio.dart';
import 'package:mobile/shared/config/app_config.dart';

/// Stateless API calls for password reset (keeps [AuthNotifier] from flipping loading during login).
class PasswordResetApi {
  PasswordResetApi({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.apiBaseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
              ),
            );

  final Dio _dio;

  Future<void> requestReset({required String email}) async {
    await _dio.post<Map<String, dynamic>>(
      '/forgot-password',
      data: {'email': email.trim()},
      options: Options(headers: {'Accept': 'application/json'}),
    );
  }

  Future<void> completeReset({
    required String email,
    required String token,
    required String password,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/reset-password',
      data: {
        'email': email.trim(),
        'token': token.trim(),
        'password': password,
        'password_confirmation': password,
      },
      options: Options(headers: {'Accept': 'application/json'}),
    );
  }
}
