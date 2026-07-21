/// Shared US AQI helpers (Open-Meteo `us_aqi` is 0–500, not a 1–5 European index).
abstract final class AirQualityThresholds {
  /// Unhealthy for Sensitive Groups and above — only then warn for outdoor activity.
  static const int poorUsAqi = 100;

  static bool isPoorUsAqi(int? aqi) => aqi != null && aqi >= poorUsAqi;
}
