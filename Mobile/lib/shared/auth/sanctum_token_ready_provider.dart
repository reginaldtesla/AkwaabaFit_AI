import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/shared/auth/sanctum_token_storage.dart';

/// True when a Sanctum token is available (retries for post-login timing).
final sanctumTokenReadyProvider = FutureProvider<bool>((ref) async {
  final token = await readSanctumToken(maxAttempts: 12);
  return token != null;
});
