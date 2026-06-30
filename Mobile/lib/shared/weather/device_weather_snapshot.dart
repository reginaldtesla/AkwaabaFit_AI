import 'package:mobile/shared/weather/open_meteo_weather_codes.dart';

class DeviceWeatherSnapshot {
  const DeviceWeatherSnapshot({
    required this.latitude,
    required this.longitude,
    required this.tempCelsius,
    required this.location,
    this.weatherMain,
    this.weatherDescription,
    this.airQualityAqi,
    this.pm25,
    this.pm10,
    required this.fetchedAt,
    this.fromCache = false,
  });

  final double latitude;
  final double longitude;
  final double tempCelsius;
  final String location;
  final String? weatherMain;
  final String? weatherDescription;
  final int? airQualityAqi;
  final double? pm25;
  final double? pm10;
  final DateTime fetchedAt;
  final bool fromCache;

  bool get isUsable =>
      tempCelsius > 0 ||
      (weatherMain != null && weatherMain!.trim().isNotEmpty);

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'tempCelsius': tempCelsius,
        'location': location,
        'weatherMain': weatherMain,
        'weatherDescription': weatherDescription,
        'airQualityAqi': airQualityAqi,
        'pm25': pm25,
        'pm10': pm10,
        'fetchedAt': fetchedAt.toIso8601String(),
      };

  factory DeviceWeatherSnapshot.fromJson(Map<String, dynamic> json) {
    return DeviceWeatherSnapshot(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      tempCelsius: (json['tempCelsius'] as num?)?.toDouble() ?? 0,
      location: (json['location'] ?? 'Your area').toString(),
      weatherMain: json['weatherMain']?.toString(),
      weatherDescription: json['weatherDescription']?.toString(),
      airQualityAqi: (json['airQualityAqi'] as num?)?.toInt(),
      pm25: (json['pm25'] as num?)?.toDouble(),
      pm10: (json['pm10'] as num?)?.toDouble(),
      fetchedAt: DateTime.tryParse(json['fetchedAt']?.toString() ?? '') ??
          DateTime.now(),
      fromCache: true,
    );
  }

  /// Query params for Laravel dashboard / activity when syncing online.
  Map<String, String> get queryParams => {
        'lat': latitude.toStringAsFixed(5),
        'lon': longitude.toStringAsFixed(5),
      };
}

/// Default Accra coordinates when GPS is unavailable.
const deviceWeatherFallbackLat = 5.6037;
const deviceWeatherFallbackLon = -0.1870;
const deviceWeatherFallbackLabel = 'Accra, GH';

int? _parseWeatherCode(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '');
}

DeviceWeatherSnapshot? deviceWeatherFromOpenMeteoJson({
  required double lat,
  required double lon,
  required Map<String, dynamic> forecast,
  Map<String, dynamic>? airQuality,
  String location = deviceWeatherFallbackLabel,
}) {
  final current = forecast['current'];
  if (current is! Map) return null;

  final map = current.map((k, v) => MapEntry(k.toString(), v));
  final temp = (map['temperature_2m'] as num?)?.toDouble() ?? 0;
  final code = _parseWeatherCode(map['weather_code']);

  int? aqi;
  double? pm25;
  double? pm10;
  if (airQuality != null) {
    final airCurrent = airQuality['current'];
    if (airCurrent is Map) {
      final air = airCurrent.map((k, v) => MapEntry(k.toString(), v));
      final rawAqi = air['us_aqi'];
      if (rawAqi is num) aqi = rawAqi.round();
      pm25 = (air['pm2_5'] as num?)?.toDouble();
      pm10 = (air['pm10'] as num?)?.toDouble();
    }
  }

  return DeviceWeatherSnapshot(
    latitude: lat,
    longitude: lon,
    tempCelsius: temp,
    location: location,
    weatherMain: code != null ? OpenMeteoWeatherCodes.weatherMain(code) : null,
    weatherDescription:
        code != null ? OpenMeteoWeatherCodes.description(code) : null,
    airQualityAqi: aqi,
    pm25: pm25,
    pm10: pm10,
    fetchedAt: DateTime.now(),
  );
}
