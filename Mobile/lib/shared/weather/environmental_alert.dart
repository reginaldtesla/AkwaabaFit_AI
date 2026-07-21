/// Dashboard-style environmental alerts (mirrors Laravel `buildEnvironmentalAlert`).
class EnvironmentalAlert {
  const EnvironmentalAlert({required this.title, required this.message});

  final String title;
  final String message;

  static EnvironmentalAlert build({
    required double tempCelsius,
    int? airQualityAqi,
    double? pm25,
    double? pm10,
    String? weatherMain,
    String? weatherDescription,
  }) {
    final isHighHeat = tempCelsius >= 32.0;
    final isPoorAir = airQualityAqi != null && airQualityAqi >= 4;
    final desc = (weatherDescription ?? '').toLowerCase();
    final isDusty = desc.contains('dust') ||
        desc.contains('sand') ||
        desc.contains('haze') ||
        desc.contains('fog');

    if (isPoorAir || isDusty) {
      final pmParts = <String>[];
      if (pm25 != null && pm25 > 0) {
        pmParts.add('PM2.5 ${pm25.round()}µg/m³');
      }
      if (pm10 != null && pm10 > 0) {
        pmParts.add('PM10 ${pm10.round()}µg/m³');
      }
      final extra = pmParts.isEmpty ? '' : ' (${pmParts.join(', ')})';

      return EnvironmentalAlert(
        title: 'Air Quality Alert',
        message:
            'Air quality is poor today$extra. Limit intense outdoor workouts, keep workouts lighter today, and consider a mask if sensitive.',
      );
    }

    if (isHighHeat) {
      return EnvironmentalAlert(
        title: 'High Heat Advisory',
        message:
            'It’s hot today. Prefer shade, rest breaks, and lower-intensity movement.',
      );
    }

    final main = (weatherMain ?? '').toLowerCase().trim();
    if (main == 'thunderstorm') {
      return EnvironmentalAlert(
        title: 'Storm Advisory',
        message:
            'Thunderstorms nearby. Stay indoors when you can—marching, stairs, and light home cardio still count toward your steps.',
      );
    }
    if (main == 'rain' || main == 'drizzle') {
      return EnvironmentalAlert(
        title: 'Rain Advisory',
        message:
            'Wet conditions today. Skip the outdoor walk if you prefer—indoor steps count the same (home pacing, stairs, or a covered corridor).',
      );
    }

    return const EnvironmentalAlert(
      title: 'No Alerts',
      message: 'All clear. Keep moving steadily today.',
    );
  }
}
