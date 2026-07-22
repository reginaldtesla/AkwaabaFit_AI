class AppConfig {
  /// API base URL — set at build/run time with `--dart-define=API_BASE_URL=...`
  ///
  /// **Production:** default `https://api.tesnet.xyz/api`
  /// **Phone on same Wi‑Fi testing local API:** `http://YOUR-PC-LAN-IP:8080/api`
  ///
  /// AkwaabaFit runs on **physical phones only** (not emulators).
  /// Example:
  /// `flutter run --release --dart-define=API_BASE_URL=https://api.tesnet.xyz/api`
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.tesnet.xyz/api',
  );

  /// Google Sign-In Web client ID (OAuth "Web application").
  /// Required so the ID token `aud` matches the backend `GOOGLE_CLIENT_ID`.
  /// Example: `flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxxx.apps.googleusercontent.com`
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  /// Same host as [apiBaseUrl], without `/api`.
  static String get serverBaseUrl {
    final v = apiBaseUrl;
    return v.endsWith('/api') ? v.substring(0, v.length - 4) : v;
  }

  /// Extra headers for dev tunnels (ngrok free tier returns HTML without this).
  static Map<String, String> get apiHeaders => const {
        'Accept': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      };

  static String normalizeUrlForDevice(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;

    // Relative storage paths from Laravel (`/storage/avatars/...`).
    if (trimmed.startsWith('/')) {
      return '$serverBaseUrl$trimmed';
    }

    // Rewrite localhost / loopback hosts to the configured API host.
    final loopback = RegExp(r'https?://(localhost|127\.0\.0\.1)(:\d+)?');
    if (!loopback.hasMatch(trimmed)) return trimmed;
    return trimmed.replaceFirst(loopback, serverBaseUrl);
  }

  /// Minimum AI confidence before showing a scan result (matches server default).
  static const double minScanConfidence = 0.30;
}

