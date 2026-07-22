import 'package:mobile/features/dashboard/presentation/dashboard_screen.dart';
import 'package:mobile/shared/weather/device_weather_snapshot.dart';
import 'package:mobile/shared/weather/environmental_alert.dart';

DashboardData applyDeviceWeatherToDashboard(
  DashboardData base,
  DeviceWeatherSnapshot? weather,
) {
  if (weather == null || !weather.isUsable) return base;
  // Require a real condition string — never invent drizzle / air alerts.
  final main = weather.weatherMain?.trim();
  if (main == null || main.isEmpty) {
    return base;
  }

  final alert = EnvironmentalAlert.build(
    tempCelsius: weather.tempCelsius,
    airQualityAqi: weather.airQualityAqi,
    pm25: weather.pm25,
    pm10: weather.pm10,
    weatherMain: weather.weatherMain,
    weatherDescription: weather.weatherDescription,
  );

  return base.copyWith(
    tempCelsius: weather.tempCelsius,
    location: weather.location,
    weatherMain: weather.weatherMain,
    weatherDescription: weather.weatherDescription,
    alertTitle: alert.title,
    alertMessage: alert.message,
    airQualityAqi: weather.airQualityAqi ?? base.airQualityAqi,
  );
}
