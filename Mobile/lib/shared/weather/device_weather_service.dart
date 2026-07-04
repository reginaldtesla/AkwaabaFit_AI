import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile/shared/connectivity/connectivity_utils.dart';
import 'package:mobile/shared/offline/sqlite_offline_db.dart';
import 'package:mobile/shared/weather/device_weather_snapshot.dart';
import 'package:mobile/shared/weather/location_label_resolver.dart';

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
      final cacheCoordsOk = !isFallbackWeatherCoordinates(
        snap.latitude,
        snap.longitude,
      );
      if (allowStaleCache && age < _cacheTtl && cacheCoordsOk) {
        final staleLabel = snap.location.trim().toLowerCase();
        final needsRelabel = staleLabel == 'your area' ||
            staleLabel == 'accra, gh' ||
            staleLabel == deviceWeatherLocationUnavailableLabel.toLowerCase();
        if (!needsRelabel) {
          return snap;
        }
      }
    }

    if (!await isDeviceOnline()) {
      if (cached != null) {
        return DeviceWeatherSnapshot.fromJson(cached);
      }
      return null;
    }

    try {
      final coords = await _resolveCoordinates();
      final snap = await _fetchOpenMeteo(
        coords.lat,
        coords.lon,
        locationLabel: coords.isFallback
            ? deviceWeatherLocationUnavailableLabel
            : null,
      );
      if (snap != null && !coords.isFallback) {
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

  /// Coordinates for API query params — prefers live GPS over stale Accra fallback.
  Future<({double lat, double lon})> resolveCoordinates() async {
    final fresh = await _resolveCoordinates();
    return (lat: fresh.lat, lon: fresh.lon);
  }

  Future<({double lat, double lon, bool isFallback})> _resolveCoordinates() async {
    final db = await _dbFuture;
    final cached = await db.getWeatherCache();
    if (cached != null) {
      final snap = DeviceWeatherSnapshot.fromJson(cached);
      if (!isFallbackWeatherCoordinates(snap.latitude, snap.longitude)) {
        return (lat: snap.latitude, lon: snap.longitude, isFallback: false);
      }
    }

    try {
      final servicesOn = await Geolocator.isLocationServiceEnabled();
      if (!servicesOn) {
        return _fallbackCoords();
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          return (
            lat: last.latitude,
            lon: last.longitude,
            isFallback: false,
          );
        }
        return _fallbackCoords();
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return (lat: pos.latitude, lon: pos.longitude, isFallback: false);
    } catch (_) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          return (
            lat: last.latitude,
            lon: last.longitude,
            isFallback: false,
          );
        }
      } catch (_) {}
      return _fallbackCoords();
    }
  }

  ({double lat, double lon, bool isFallback}) _fallbackCoords() => (
        lat: deviceWeatherFallbackLat,
        lon: deviceWeatherFallbackLon,
        isFallback: true,
      );

  Future<DeviceWeatherSnapshot?> _fetchOpenMeteo(
    double lat,
    double lon, {
    String? locationLabel,
  }) async {
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

    final label = locationLabel ??
        await LocationLabelResolver.resolve(lat, lon, dio: _dio);
    return deviceWeatherFromOpenMeteoJson(
      lat: lat,
      lon: lon,
      forecast: forecast,
      airQuality: airJson,
      location: label,
    );
  }
}
