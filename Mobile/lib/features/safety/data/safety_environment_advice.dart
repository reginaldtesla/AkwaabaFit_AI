import 'package:flutter/material.dart';

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

SafetyEnvironmentAdvice resolveSafetyEnvironmentAdvice({
  required double tempCelsius,
  String? weatherMain,
  String? weatherDescription,
  int? airQualityAqi,
}) {
  final t = tempCelsius;
  final mainNorm = weatherMain?.trim().toLowerCase() ?? '';
  final poorAir = airQualityAqi != null && airQualityAqi >= 4;

  if (mainNorm == 'thunderstorm') {
    return SafetyEnvironmentAdvice(
      headlineLabel: 'Storm nearby',
      headlineIcon: Icons.thunderstorm,
      headlineColor: Colors.deepPurple,
      quote:
          '"Skies are acting up today—when thunder rolls, tuck indoors if you can, skip open fields, and save your walk for when things feel calmer. Small choices keep you safer."',
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
          '"A little rain does not have to ruin your day—grab something waterproof, take slow steps on slick paths, and enjoy how fresh everything smells afterward."',
      tipAIcon: Icons.opacity_outlined,
      tipALabel: 'Waterproof layer',
      tipBIcon: Icons.umbrella,
      tipBLabel: 'Carry umbrella',
    );
  }

  if (mainNorm == 'snow') {
    return SafetyEnvironmentAdvice(
      headlineLabel: 'Cold & snowy',
      headlineIcon: Icons.ac_unit,
      headlineColor: Colors.lightBlue.shade700,
      quote:
          '"Bundle up in cozy layers today—warm socks, steady footing on icy bits, and time indoors to warm up afterward make cold weather feel kinder."',
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
    'mist',
    'fog',
  }.contains(mainNorm);

  if (poorAir || dustyAir) {
    return SafetyEnvironmentAdvice(
      headlineLabel: poorAir ? 'Air quality watch' : 'Hazy skies',
      headlineIcon: Icons.air,
      headlineColor: Colors.orange.shade800,
      quote:
          '"The air is a bit harsh today—shorter outdoor bursts, easy pacing, and a damp cloth mask can help if dust bothers you. Pause when you need to and listen to how your body feels."',
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
          ? '"Cloud cover is giving you a little shade today—still lovely for a stroll; light fabrics and short breaks help you stay comfy."'
          : '"Nice cloud-softened light today—perfect for an easy walk. A light layer is plenty if a breeze picks up."',
      tipAIcon: Icons.directions_walk,
      tipALabel: 'Easy outing',
      tipBIcon: Icons.beach_access_outlined,
      tipBLabel: 'Take shade breaks',
    );
  }

  // Clear or unknown — lean on temperature.
  if (t >= 32 || (mainNorm == 'clear' && t >= 30)) {
    return SafetyEnvironmentAdvice(
      headlineLabel: 'Sunny & warm',
      headlineIcon: Icons.wb_sunny_outlined,
      headlineColor: Colors.amber.shade700,
      quote:
          '"The sun is quite strong today—light cotton, a hat if you like, and shade breaks will keep you feeling steadier out there."',
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
          '"Lovely warmth outside—a breathable outfit, a hat if you like, and breaks in the shade help you enjoy it without feeling drained."',
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
          '"Pretty gentle weather today—ideal for moving your body at an easy pace. A light layer nearby is nice if a breeze shows up."',
      tipAIcon: Icons.directions_walk,
      tipALabel: 'Easy movement',
      tipBIcon: Icons.layers_outlined,
      tipBLabel: 'Light layer',
    );
  }

  return SafetyEnvironmentAdvice(
    headlineLabel: 'Cool air',
    headlineIcon: Icons.ac_unit_outlined,
    headlineColor: Colors.blueGrey.shade700,
      quote:
          '"It is a cooler day—warm layers, comfy socks, and shorter trips outside if you chill easily. You will warm up quickly once you are moving."',
      tipAIcon: Icons.dry_cleaning_outlined,
      tipALabel: 'Warm layers',
      tipBIcon: Icons.home_outlined,
      tipBLabel: 'Warm up indoors',
  );
}
