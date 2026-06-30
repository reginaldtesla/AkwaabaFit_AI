import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile/shared/connectivity/connectivity_utils.dart';
import 'package:mobile/shared/offline/sqlite_offline_db.dart';
import 'package:mobile/shared/weather/device_weather_snapshot.dart';

const _cacheTtl = Duration(minutes: 20);

final deviceWeatherServiceProvider = Provider<DeviceWeatherService>((ref) {
  return DeviceWeatherService(
    dio: Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Accept': 'application/json'},
      ),
    ),
    dbFuture: SqliteOfflineDb.getInstance(),
  );
});

/// GPS + Open-Meteo weather cached on device (free, no API key).
final deviceWeatherProvider = FutureProvider<DeviceWeatherSnapshot?>((ref) async {
  final service = ref.watch(deviceWeatherServiceProvider);
  return service.fetchCurrentWeather();
});

class DeviceWeatherService {
  DeviceWeatherService({
    required Dio dio,
    required Future<SqliteOfflineDb> dbFuture,
  })  : _dio = dio,
        _dbFuture = dbFuture;

  final Dio _dio;
  final Future<SqliteOfflineDb> _dbFuture;

  Future<DeviceWeatherSnapshot?> fetchCurrentWeather({
    bool allowStaleCache = true,
  }) async {
    final db = await _dbFuture;
    final cached = await db.getWeatherCache();
    if (cached != null) {
      final snap = DeviceWeatherSnapshot.fromJson(cached);
      final age = DateTime.now().difference(snap.fetchedAt);
      if (allowStaleCache && age < _cacheTtl) {
        return snap;
      }
    }

    if (!await isDeviceOnline()) {
      return cached != null ? DeviceWeatherSnapshot.fromJson(cached) : null;
    }

    try {
      final coords = await _resolveCoordinates();
      final snap = await _fetchOpenMeteo(coords.lat, coords.lon);
      if (snap != null) {
        await db.putWeatherCache(snap.toJson());
      }
      return snap;
    } catch (_) {
      if (cached != null) {
        return DeviceWeatherSnapshot.fromJson(cached);
      }
      return null;
    }
  }

  /// Coordinates for API query params — uses cache or GPS without full weather fetch.
  Future<({double lat, double lon})> resolveCoordinates() async {
    final db = await _dbFuture;
    final cached = await db.getWeatherCache();
    if (cached != null) {
      final snap = DeviceWeatherSnapshot.fromJson(cached);
      if (snap.latitude != 0 || snap.longitude != 0) {
        return (lat: snap.latitude, lon: snap.longitude);
      }
    }

    final coords = await _resolveCoordinates();
    return (lat: coords.lat, lon: coords.lon);
  }

  Future<({double lat, double lon})> _resolveCoordinates() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return (
          lat: deviceWeatherFallbackLat,
          lon: deviceWeatherFallbackLon,
        );
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return (lat: pos.latitude, lon: pos.longitude);
    } catch (_) {
      return (
        lat: deviceWeatherFallbackLat,
        lon: deviceWeatherFallbackLon,
      );
    }
  }

  Future<DeviceWeatherSnapshot?> _fetchOpenMeteo(double lat, double lon) async {
    final forecastResp = await _dio.get<Map<String, dynamic>>(
      'https://api.open-meteo.com/v1/forecast',
      queryParameters: {
        'latitude': lat,
        'longitude': lon,
        'current': 'temperature_2m,weather_code',
        'timezone': 'auto',
      },
    );

    Map<String, dynamic>? airJson;
    try {
      final airResp = await _dio.get<Map<String, dynamic>>(
        'https://air-quality-api.open-meteo.com/v1/air-quality',
        queryParameters: {
          'latitude': lat,
          'longitude': lon,
          'current': 'us_aqi,pm2_5,pm10',
          'timezone': 'auto',
        },
      );
      airJson = airResp.data;
    } catch (_) {}

    final forecast = forecastResp.data;
    if (forecast == null) return null;

    final label = await _reverseGeocode(lat, lon);
    return deviceWeatherFromOpenMeteoJson(
      lat: lat,
      lon: lon,
      forecast: forecast,
      airQuality: airJson,
      location: label,
    );
  }

  Future<String> _reverseGeocode(double lat, double lon) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        'https://geocoding-api.open-meteo.com/v1/reverse',
        queryParameters: {
          'latitude': lat,
          'longitude': lon,
          'language': 'en',
          'count': 1,
        },
      );
      final results = resp.data?['results'];
      if (results is List && results.isNotEmpty) {
        final row = results.first;
        if (row is Map) {
          final name = row['name']?.toString().trim() ?? '';
          final country = row['country_code']?.toString().trim() ?? '';
          final label = [
            if (name.isNotEmpty) name,
            if (country.isNotEmpty) country,
          ].join(', ');
          if (label.isNotEmpty) return label;
        }
      }
    } catch (_) {}
    return deviceWeatherFallbackLabel;
  }
}
