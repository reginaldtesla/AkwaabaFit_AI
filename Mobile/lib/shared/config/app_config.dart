class AppConfig {
  /// Configure per environment using:
  /// `flutter run --dart-define=API_BASE_URL=http://192.168.88.240:8000/api`
  ///
  /// Realtime: the API exposes `GET /broadcasting/client-config` (auth) for Laravel Reverb / Echo.
  /// The mobile app uses a fast `messages/delta` poll; a native Reverb client needs a host-capable Pusher SDK.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
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
    if (!url.contains('localhost:8000')) return url;
    return url.replaceFirst('http://localhost:8000', serverBaseUrl);
  }
}

