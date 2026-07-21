import 'package:flutter/material.dart';
import 'package:mobile/shared/weather/air_quality_thresholds.dart';

/// Friendly environment copy + quick tips for Safety Hub, driven by dashboard weather.
class SafetyEnvironmentAdvice {
  const SafetyEnvironmentAdvice({
    required this.headlineLabel,
    required this.headlineIcon,
    required this.headlineColor,
    required this.quote,
    required this.tipAIcon,
    required this.tipALabel,
    required this.tipBIcon,
    required this.tipBLabel,
  });

  final String headlineLabel;
  final IconData headlineIcon;
  final Color headlineColor;
  final String quote;
  final IconData tipAIcon;
  final String tipALabel;
  final IconData tipBIcon;
  final String tipBLabel;
}

/// Human label for the live weather condition (null when unknown / untrusted).
String? safetyWeatherConditionLabel({
  String? weatherMain,
  String? weatherDescription,
}) {
  final desc = weatherDescription?.trim();
  if (desc != null && desc.isNotEmpty) {
    return desc;
  }
  final main = weatherMain?.trim();
  if (main != null && main.isNotEmpty) {
    return main;
  }
  return null;
}

SafetyEnvironmentAdvice resolveSafetyEnvironmentAdvice({
  required double tempCelsius,
  String? weatherMain,
  String? weatherDescription,
  int? airQualityAqi,
}) {
  final t = tempCelsius;
  final mainNorm = weatherMain?.trim().toLowerCase() ?? '';
  final poorAir = AirQualityThresholds.isPoorUsAqi(airQualityAqi);
  final hasCondition = mainNorm.isNotEmpty;

  if (!hasCondition && t <= 0) {
    return SafetyEnvironmentAdvice(
      headlineLabel: 'Weather unavailable',
      headlineIcon: Icons.cloud_off_outlined,
      headlineColor: Colors.blueGrey,
      quote:
          '"Turn on location to load your real local conditions. Until then, we will not guess the weather for you."',
      tipAIcon: Icons.my_location_outlined,
      tipALabel: 'Enable location',
      tipBIcon: Icons.directions_walk,
      tipBLabel: 'Keep moving',
    );
  }

  if (mainNorm == 'thunderstorm') {
    return SafetyEnvironmentAdvice(
      headlineLabel: 'Storm nearby',
      headlineIcon: Icons.thunderstorm,
      headlineColor: Colors.deepPurple,
      quote:
          '"Skies are active today—prefer indoors if you can, skip open fields, and keep outdoor walks for calmer conditions."',
      tipAIcon: Icons.home_outlined,
      tipALabel: 'Prefer indoors',
      tipBIcon: Icons.flash_off_outlined,
      tipBLabel: 'Avoid open areas',
    );
  }

  if (mainNorm == 'rain' || mainNorm == 'drizzle') {
    final cozy = t >= 26;
    return SafetyEnvironmentAdvice(
      headlineLabel: cozy ? 'Warm rain' : 'Wet conditions',
      headlineIcon: Icons.umbrella,
      headlineColor: Colors.blue.shade700,
      quote:
          '"Rainy day—outdoor walks can wait. Indoor pacing, stairs, or a covered corridor keep you moving without getting wet."',
      tipAIcon: Icons.home_outlined,
      tipALabel: 'Move indoors',
      tipBIcon: Icons.stairs_outlined,
      tipBLabel: 'Stairs / pacing',
    );
  }

  if (mainNorm == 'snow') {
    return SafetyEnvironmentAdvice(
      headlineLabel: 'Cold & snowy',
      headlineIcon: Icons.ac_unit,
      headlineColor: Colors.lightBlue.shade700,
      quote:
          '"Bundle up in warm layers today—steady footing on icy bits, and time indoors afterward if the cold bites."',
      tipAIcon: Icons.layers_outlined,
      tipALabel: 'Warm layers',
      tipBIcon: Icons.directions_walk,
      tipBLabel: 'Mind footing',
    );
  }

  final dustyAir = <String>{
    'dust',
    'sand',
    'smoke',
    'ash',
    'haze',
  }.contains(mainNorm);

  if (poorAir || dustyAir) {
    return SafetyEnvironmentAdvice(
      headlineLabel: poorAir ? 'Air quality watch' : 'Hazy skies',
      headlineIcon: Icons.air,
      headlineColor: Colors.orange.shade800,
      quote:
          '"The air is a bit harsh today—prefer shorter outdoor bursts, easy pacing, and a pause when dust bothers you."',
      tipAIcon: Icons.masks_outlined,
      tipALabel: 'Limit outdoors',
      tipBIcon: Icons.self_improvement_outlined,
      tipBLabel: 'Rest between bursts',
    );
  }

  if (mainNorm == 'clouds') {
    final mild = t >= 20 && t < 30;
    return SafetyEnvironmentAdvice(
      headlineLabel: mild ? 'Soft skies' : 'Mostly cloudy',
      headlineIcon: Icons.cloud_outlined,
      headlineColor: Colors.blueGrey.shade600,
      quote: t >= 28
          ? '"Cloud cover softens the sun today—light fabrics and short breaks help if you head out."'
          : '"Soft light today—an easy walk suits the conditions. Keep a light layer handy if a breeze picks up."',
      tipAIcon: Icons.directions_walk,
      tipALabel: 'Easy outing',
      tipBIcon: Icons.beach_access_outlined,
      tipBLabel: 'Take shade breaks',
    );
  }

  // Clear or unknown — lean on temperature when we have a real reading.
  if (t >= 32 || (mainNorm == 'clear' && t >= 30)) {
    return SafetyEnvironmentAdvice(
      headlineLabel: 'Sunny & warm',
      headlineIcon: Icons.wb_sunny_outlined,
      headlineColor: Colors.amber.shade700,
      quote:
          '"The sun is quite strong today—light cotton, a hat if you like, and shade breaks when you need them."',
      tipAIcon: Icons.checkroom_outlined,
      tipALabel: 'Light cotton',
      tipBIcon: Icons.beach_access_outlined,
      tipBLabel: 'Seek shade',
    );
  }

  if (t >= 26) {
    return SafetyEnvironmentAdvice(
      headlineLabel: 'Pleasant warmth',
      headlineIcon: Icons.wb_sunny_outlined,
      headlineColor: Colors.amber.shade600,
      quote:
          '"Warm outside—a breathable outfit, a hat if you like, and breaks in the shade help you stay comfortable."',
      tipAIcon: Icons.checkroom_outlined,
      tipALabel: 'Breathable wear',
      tipBIcon: Icons.beach_access_outlined,
      tipBLabel: 'Pause in shade',
    );
  }

  if (t >= 18) {
    return SafetyEnvironmentAdvice(
      headlineLabel: 'Mild & comfy',
      headlineIcon: Icons.wb_cloudy_outlined,
      headlineColor: Colors.teal.shade600,
      quote:
          '"Gentle weather today—easy for moving at a comfortable pace. Keep a light layer nearby if a breeze shows up."',
      tipAIcon: Icons.directions_walk,
      tipALabel: 'Easy movement',
      tipBIcon: Icons.layers_outlined,
      tipBLabel: 'Light layer',
    );
  }

  if (t > 0) {
    return SafetyEnvironmentAdvice(
      headlineLabel: 'Cool air',
      headlineIcon: Icons.ac_unit_outlined,
      headlineColor: Colors.blueGrey.shade700,
      quote:
          '"Cooler day—warm layers, comfy socks, and shorter trips outside if you chill easily."',
      tipAIcon: Icons.dry_cleaning_outlined,
      tipALabel: 'Warm layers',
      tipBIcon: Icons.home_outlined,
      tipBLabel: 'Warm up indoors',
    );
  }

  return SafetyEnvironmentAdvice(
    headlineLabel: 'Weather unavailable',
    headlineIcon: Icons.cloud_off_outlined,
    headlineColor: Colors.blueGrey,
    quote:
        '"Turn on location to load your real local conditions. Until then, we will not guess the weather for you."',
    tipAIcon: Icons.my_location_outlined,
    tipALabel: 'Enable location',
    tipBIcon: Icons.directions_walk,
    tipBLabel: 'Keep moving',
  );
}
