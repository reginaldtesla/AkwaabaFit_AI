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

  return DashboardData(
    userName: base.userName,
    avatarUrl: base.avatarUrl,
    goal: base.goal,
    netKcal: base.netKcal,
    consumedKcal: base.consumedKcal,
    burnedKcal: base.burnedKcal,
    tempCelsius: weather.tempCelsius,
    location: weather.location,
    weatherMain: weather.weatherMain,
    weatherDescription: weather.weatherDescription,
    alertTitle: alert.title,
    alertMessage: alert.message,
    currentSteps: base.currentSteps,
    stepGoal: base.stepGoal,
    dailyCaloriesTarget: base.dailyCaloriesTarget,
    proteinG: base.proteinG,
    carbsG: base.carbsG,
    fatG: base.fatG,
    targetProteinG: base.targetProteinG,
    targetCarbsG: base.targetCarbsG,
    targetFatG: base.targetFatG,
    airQualityAqi: weather.airQualityAqi ?? base.airQualityAqi,
    workoutPreferredTime: base.workoutPreferredTime,
    workoutDaysPerWeek: base.workoutDaysPerWeek,
    mealsLoggedToday: base.mealsLoggedToday,
    mealsLogged7Days: base.mealsLogged7Days,
    fromOfflineCache: base.fromOfflineCache,
    macrosEstimated: base.macrosEstimated,
    weightKg: base.weightKg,
    heightCm: base.heightCm,
    waterTotalMl: base.waterTotalMl,
    waterGoalMl: base.waterGoalMl,
    dietitianAdvice: base.dietitianAdvice,
  );
}
