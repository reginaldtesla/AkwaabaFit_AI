import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/dashboard/presentation/dashboard_screen.dart';
import 'package:mobile/features/fitness/presentation/activity_tracking_screen.dart';
import 'package:mobile/shared/weather/device_weather_service.dart';

/// Live weather for Stride — device Open-Meteo first, then activity/dashboard API.
class StrideWeatherSnapshot {
  const StrideWeatherSnapshot({
    required this.tempCelsius,
    required this.location,
    this.weatherMain,
    this.weatherDescription,
    this.airQualityAqi,
    this.strideTip,
    this.fromActivityApi = false,
  });

  final double tempCelsius;
  final String location;
  final String? weatherMain;
  final String? weatherDescription;
  final int? airQualityAqi;
  final String? strideTip;
  final bool fromActivityApi;

  bool get hasCondition =>
      weatherMain != null && weatherMain!.trim().isNotEmpty;

  factory StrideWeatherSnapshot.fromActivity(ActivityData data) {
    return StrideWeatherSnapshot(
      tempCelsius: data.tempCelsius ?? 0,
      location: data.weatherLocation ?? 'Your area',
      weatherMain: data.weatherMain,
      weatherDescription: data.weatherDescription,
      airQualityAqi: data.airQualityAqi,
      strideTip: data.strideTip,
      fromActivityApi: true,
    );
  }

  factory StrideWeatherSnapshot.fromDashboard(DashboardData data) {
    return StrideWeatherSnapshot(
      tempCelsius: data.tempCelsius,
      location: data.location,
      weatherMain: data.weatherMain,
      weatherDescription: data.weatherDescription,
      airQualityAqi: data.airQualityAqi,
    );
  }
}

/// Merges device Open-Meteo weather with dashboard / activity API fallbacks.
final strideWeatherProvider = Provider<StrideWeatherSnapshot?>((ref) {
  final device = ref.watch(deviceWeatherProvider).valueOrNull;
  if (device != null && device.isUsable) {
    return StrideWeatherSnapshot(
      tempCelsius: device.tempCelsius,
      location: device.location,
      weatherMain: device.weatherMain,
      weatherDescription: device.weatherDescription,
      airQualityAqi: device.airQualityAqi,
    );
  }

  final activity = ref.watch(activityDataProvider).valueOrNull;
  if (activity?.weatherMain != null && activity!.weatherMain!.trim().isNotEmpty) {
    return StrideWeatherSnapshot.fromActivity(activity);
  }
  if (activity?.strideTip != null && activity!.strideTip!.trim().isNotEmpty) {
    return StrideWeatherSnapshot.fromActivity(activity);
  }

  final dash = ref.watch(dashboardDataProvider).valueOrNull;
  if (dash != null && dash.weatherMain != null && dash.weatherMain!.trim().isNotEmpty) {
    return StrideWeatherSnapshot.fromDashboard(dash);
  }
  if (activity != null &&
      (activity.tempCelsius != null || activity.weatherLocation != null)) {
    return StrideWeatherSnapshot.fromActivity(activity);
  }
  return null;
});
