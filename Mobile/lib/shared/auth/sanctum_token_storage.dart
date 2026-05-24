import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const sanctumTokenKey = 'sanctum_token';

/// Some devices briefly return null right after [FlutterSecureStorage.write].
Future<String?> readSanctumToken({
  FlutterSecureStorage storage = const FlutterSecureStorage(),
  int maxAttempts = 8,
}) async {
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    final token = await storage.read(key: sanctumTokenKey);
    if (token != null && token.trim().isNotEmpty) {
      return token.trim();
    }
    if (attempt < maxAttempts - 1) {
      await Future<void>.delayed(
        Duration(milliseconds: 50 * (attempt + 1)),
      );
    }
  }
  return null;
}
