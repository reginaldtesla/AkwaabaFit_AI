import 'package:flutter/material.dart';

/// Weather-aware copy for Stride (steps) — rain does not block progress.
abstract final class StrideWeatherGuidance {
  static bool isHighHeat(double tempCelsius) => tempCelsius >= 32.0;

  static bool isPoorAir(int? aqi) => aqi != null && aqi >= 4;

  static IconData iconFor(String? weatherMain) {
    final m = weatherMain?.trim().toLowerCase() ?? '';
    return switch (m) {
      'thunderstorm' => Icons.thunderstorm_outlined,
      'rain' || 'drizzle' => Icons.umbrella_outlined,
      'snow' => Icons.ac_unit_outlined,
      'clouds' => Icons.cloud_outlined,
      'clear' => Icons.wb_sunny_outlined,
      'mist' || 'fog' || 'haze' => Icons.cloud_queue_outlined,
      _ => Icons.wb_cloudy_outlined,
    };
  }

  static String labelFor(String? weatherMain) {
    final m = weatherMain?.trim();
    if (m == null || m.isEmpty) return 'Weather';
    return m;
  }

  /// One-line Stride banner when API tip is missing.
  static String summaryLine({
    required String? weatherMain,
    required double tempCelsius,
    int? airQualityAqi,
  }) {
    if (discouragesOutdoorWalk(weatherMain)) {
      return isStorm(weatherMain)
          ? 'Storm — prefer indoor movement; steps still count'
          : 'Rain — indoor steps count toward your goal';
    }
    if (isHighHeat(tempCelsius)) {
      return 'High heat — shorter outings and shade breaks';
    }
    if (isPoorAir(airQualityAqi)) {
      return 'Poor air — prefer indoor movement';
    }
    final m = weatherMain?.toLowerCase() ?? '';
    if (m == 'clear') return 'Clear skies — workable conditions for a walk';
    return 'Move at a pace that feels right for today';
  }

  static bool discouragesOutdoorWalk(String? weatherMain) {
    final m = weatherMain?.trim().toLowerCase() ?? '';
    return m == 'rain' || m == 'drizzle' || m == 'thunderstorm';
  }

  static bool isStorm(String? weatherMain) =>
      weatherMain?.trim().toLowerCase() == 'thunderstorm';

  /// Short list for UI chips on Stride.
  static List<String> indoorAlternatives({required bool isStorm}) {
    if (isStorm) {
      return const [
        'Stay indoors',
        'March in place',
        'Light home cardio',
        'Steps still count',
      ];
    }
    return const [
      'Walk indoors',
      'Use stairs',
      'March in place',
      'Covered corridor',
    ];
  }

  /// Wellness card body when outdoor walking is a poor idea.
  static String wellnessBody({
    required int steps,
    required int goal,
    required double progress,
    required int left,
    required String? weatherMain,
    required String streakNote,
  }) {
    if (!discouragesOutdoorWalk(weatherMain)) return '';

    if (isStorm(weatherMain)) {
      if (progress >= 1.0) {
        return '${streakNote}Stormy weather today, and you still hit your step goal — well done. '
            'Keep movement gentle and indoors while skies are active.';
      }
      if (steps > 0) {
        return '${streakNote}Thunderstorms nearby — prefer indoors. Your $steps steps already count; '
            'add more with marching, stairs, or light cardio at home (~$left to goal).';
      }
      return 'Storms today — skip outdoor walks. Indoor steps count the same: '
          'march in place, use stairs, or walk inside.';
    }

    if (progress >= 1.0) {
      return '${streakNote}Rainy day outside, and you reached your goal — great work. '
          'Indoor movement kept you on track without getting wet.';
    }
    if (progress >= 0.5) {
      return '${streakNote}It\'s raining, so skip the outdoor walk. You\'re already halfway — '
          'stairs or pacing at home close the gap (~$left steps left).';
    }
    if (steps > 0) {
      return '${streakNote}Wet weather today — stay dry. Your phone still counts indoor steps; '
          'try a covered corridor or marching at home (~$left to goal).';
    }
    return 'Rain today — you don\'t need to go outside. Indoor steps count: '
        'walk at home, use stairs, or march in place.';
  }
}
