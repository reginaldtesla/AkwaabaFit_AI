import 'package:dio/dio.dart';
import 'package:geocoding/geocoding.dart';
import 'package:mobile/shared/weather/device_weather_snapshot.dart';

/// Resolves GPS coordinates to a human-readable place name for weather UI.
abstract final class LocationLabelResolver {
  static const _nominatimUrl = 'https://nominatim.openstreetmap.org/reverse';
  static const _userAgent = 'AkwaabaFit/1.0 (weather; contact: support@akwaabafit.com)';

  static Future<String> resolve(
    double lat,
    double lon, {
    Dio? dio,
  }) async {
    if (isFallbackWeatherCoordinates(lat, lon)) {
      return deviceWeatherLocationUnavailableLabel;
    }

    final native = await _fromNativePlacemark(lat, lon);
    if (native != null && native.isNotEmpty) {
      return native;
    }

    final remote = await _fromNominatim(lat, lon, dio: dio);
    if (remote != null && remote.isNotEmpty) {
      return remote;
    }

    return _coordinateLabel(lat, lon);
  }

  static Future<String?> _fromNativePlacemark(double lat, double lon) async {
    try {
      final marks = await Geocoding().placemarkFromCoordinates(lat, lon);
      if (marks.isEmpty) return null;
      return _formatPlacemark(marks.first);
    } catch (_) {
      return null;
    }
  }

  static String? _formatPlacemark(Placemark place) {
    final city = _firstNonEmpty([
      place.locality,
      place.subAdministrativeArea,
      place.subLocality,
      place.administrativeArea,
    ]);
    final region = _firstNonEmpty([
      place.administrativeArea,
      place.subAdministrativeArea,
    ]);
    final country = place.country?.trim();

    final parts = <String>[];
    if (city != null) parts.add(city);
    if (region != null && region != city) parts.add(region);
    if (country != null && country.isNotEmpty) parts.add(country);

    if (parts.isNotEmpty) {
      return parts.take(3).join(', ');
    }

    final name = place.name?.trim();
    return (name != null && name.isNotEmpty) ? name : null;
  }

  static Future<String?> _fromNominatim(
    double lat,
    double lon, {
    Dio? dio,
  }) async {
    final client = dio ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 8),
            headers: {'User-Agent': _userAgent},
          ),
        );

    try {
      final resp = await client.get<Map<String, dynamic>>(
        _nominatimUrl,
        queryParameters: {
          'lat': lat.toString(),
          'lon': lon.toString(),
          'format': 'json',
          'addressdetails': 1,
          'accept-language': 'en',
          'zoom': 10,
        },
        options: Options(headers: {'User-Agent': _userAgent}),
      );

      final data = resp.data;
      if (data == null) return null;

      final address = data['address'];
      if (address is Map) {
        final map = address.map((k, v) => MapEntry(k.toString(), v));
        final city = _firstNonEmpty([
          map['city']?.toString(),
          map['town']?.toString(),
          map['village']?.toString(),
          map['municipality']?.toString(),
          map['suburb']?.toString(),
          map['county']?.toString(),
        ]);
        final region = _firstNonEmpty([
          map['state']?.toString(),
          map['region']?.toString(),
        ]);
        final country = map['country']?.toString().trim();

        final parts = <String>[];
        if (city != null) parts.add(city);
        if (region != null && region != city) parts.add(region);
        if (country != null && country.isNotEmpty) parts.add(country);
        if (parts.isNotEmpty) {
          return parts.take(3).join(', ');
        }
      }

      final display = data['display_name']?.toString().trim();
      if (display != null && display.isNotEmpty) {
        final chunks = display.split(',').map((s) => s.trim()).toList();
        if (chunks.length >= 2) {
          return '${chunks.first}, ${chunks.last}';
        }
        return display;
      }
    } catch (_) {}

    return null;
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }

  static String _coordinateLabel(double lat, double lon) {
    final latH = lat >= 0 ? 'N' : 'S';
    final lonH = lon >= 0 ? 'E' : 'W';
    return '${lat.abs().toStringAsFixed(2)}°$latH, ${lon.abs().toStringAsFixed(2)}°$lonH';
  }
}
