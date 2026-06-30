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
    // If backend returns localhost URLs, rewrite to the configured host.
    final localhost = RegExp(r'http://localhost:\d+');
    if (!localhost.hasMatch(url)) return url;
    return url.replaceFirst(localhost, serverBaseUrl);
  }

  /// Minimum AI confidence before showing a scan result (matches server default).
  static const double minScanConfidence = 0.30;
}

