class AppConfig {
  /// API base URL — set at build/run time with `--dart-define=API_BASE_URL=...`
  ///
  /// **Production (hosted server):** default below — [https://api.tesnet.xyz](https://api.tesnet.xyz/)
  /// **Android emulator + local Laravel:** `http://10.0.2.2:8080/api`
  /// **Physical phone on same Wi‑Fi as PC:** `http://YOUR-PC-LAN-IP:8080/api`
  ///
  /// Example:
  /// `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api`
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
}

