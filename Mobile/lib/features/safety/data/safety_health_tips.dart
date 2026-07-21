import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/shared/auth/sanctum_token_storage.dart';
import 'package:mobile/shared/config/app_config.dart';

/// Dietitian tip for Safety Hub (local bank + Gemini refresh).
class SafetyHealthTip {
  const SafetyHealthTip({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;

  factory SafetyHealthTip.fromJson(Map<String, dynamic> json) {
    return SafetyHealthTip(
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      icon: _iconForKey((json['icon'] ?? 'heart').toString()),
    );
  }
}

IconData _iconForKey(String key) {
  switch (key.toLowerCase().trim()) {
    case 'water':
      return Icons.water_drop_outlined;
    case 'shade':
      return Icons.beach_access_outlined;
    case 'food':
      return Icons.eco_outlined;
    case 'walk':
      return Icons.directions_walk_outlined;
    case 'rest':
      return Icons.bedtime_outlined;
    case 'salt':
      return Icons.restaurant_outlined;
    case 'protein':
      return Icons.egg_outlined;
    case 'hygiene':
      return Icons.clean_hands_outlined;
    case 'morning':
      return Icons.wb_twilight_outlined;
    case 'heart':
    default:
      return Icons.favorite_outline;
  }
}

/// Always-available personal dietitian tip bank (Gemini refreshes/extends this).
const List<SafetyHealthTip> kSafetyHealthTipsLocal = [
  SafetyHealthTip(
    title: 'Sip through the day',
    body:
        'As your dietitian, I\'d rather you take small sips all day than wait until thirst hits—especially in the heat.',
    icon: Icons.water_drop_outlined,
  ),
  SafetyHealthTip(
    title: 'Shade over strain',
    body:
        'When the sun is fierce, build shade breaks into your walk. I want you steady outdoors, not drained.',
    icon: Icons.beach_access_outlined,
  ),
  SafetyHealthTip(
    title: 'Eat more colour',
    body:
        'Add leafy greens, garden eggs, or tomatoes to today\'s plate—I coach colour because it quietly lifts iron and fibre.',
    icon: Icons.eco_outlined,
  ),
  SafetyHealthTip(
    title: 'Pace your steps',
    body:
        'If the air feels dusty, keep outdoor walks shorter and easy. Your indoor steps still count toward the goal I set with you.',
    icon: Icons.directions_walk_outlined,
  ),
  SafetyHealthTip(
    title: 'Rest is recovery',
    body:
        'Aim for solid sleep tonight. As your coach, I know rest steadies appetite, mood, and how hard movement feels tomorrow.',
    icon: Icons.bedtime_outlined,
  ),
  SafetyHealthTip(
    title: 'Salt with care',
    body:
        'Seasoned meals are fine—just go easy on extra table salt if we\'re watching your blood pressure habits.',
    icon: Icons.restaurant_outlined,
  ),
  SafetyHealthTip(
    title: 'Protein at meals',
    body:
        'Pair your starch with beans, eggs, fish, or lean meat so your energy lasts between meals.',
    icon: Icons.egg_outlined,
  ),
  SafetyHealthTip(
    title: 'Wash hands, stay well',
    body:
        'Clean hands before meals and after being out—simple hygiene that keeps your nutrition plan on track.',
    icon: Icons.clean_hands_outlined,
  ),
];

class SafetyHealthTipsBatch {
  const SafetyHealthTipsBatch({
    required this.tips,
    required this.source,
  });

  final List<SafetyHealthTip> tips;
  final String source;
}

List<SafetyHealthTip> mergeSafetyTips(
  List<SafetyHealthTip> fresh,
  List<SafetyHealthTip> local,
) {
  final seen = <String>{};
  final out = <SafetyHealthTip>[];
  for (final tip in [...fresh, ...local]) {
    final key = tip.title.trim().toLowerCase();
    if (key.isEmpty || seen.contains(key)) continue;
    seen.add(key);
    out.add(tip);
  }
  return out;
}

Future<SafetyHealthTipsBatch> fetchSafetyHealthTips({
  double? tempCelsius,
  String? weatherMain,
  int? airQualityAqi,
  bool refresh = false,
}) async {
  try {
    const storage = FlutterSecureStorage();
    final token = await readSanctumToken(storage: storage);
    if (token == null || token.isEmpty) {
      return const SafetyHealthTipsBatch(
        tips: kSafetyHealthTipsLocal,
        source: 'local',
      );
    }

    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 45),
        headers: {
          ...AppConfig.apiHeaders,
          'Authorization': 'Bearer $token',
        },
      ),
    );

    final resp = await dio.get(
      '/safety/health-tips',
      queryParameters: {
        if (tempCelsius != null) 'temp_celsius': tempCelsius,
        if (weatherMain != null && weatherMain.trim().isNotEmpty)
          'weather_main': weatherMain,
        if (airQualityAqi != null) 'air_quality_aqi': airQualityAqi,
        if (refresh) 'refresh': 1,
      },
    );

    final raw = resp.data;
    if (raw is! Map) {
      return const SafetyHealthTipsBatch(
        tips: kSafetyHealthTipsLocal,
        source: 'local',
      );
    }

    final tipsRaw = raw['tips'];
    if (tipsRaw is! List || tipsRaw.isEmpty) {
      return const SafetyHealthTipsBatch(
        tips: kSafetyHealthTipsLocal,
        source: 'local',
      );
    }

    final tips = <SafetyHealthTip>[];
    for (final item in tipsRaw) {
      if (item is! Map) continue;
      final tip = SafetyHealthTip.fromJson(
        item.map((k, dynamic v) => MapEntry(k.toString(), v)),
      );
      if (tip.title.trim().isEmpty || tip.body.trim().isEmpty) continue;
      tips.add(tip);
    }

    if (tips.isEmpty) {
      return const SafetyHealthTipsBatch(
        tips: kSafetyHealthTipsLocal,
        source: 'local',
      );
    }

    // Always keep the local bank in the rotation even if the API omits some.
    final merged = mergeSafetyTips(tips, kSafetyHealthTipsLocal);
    final source = (raw['source'] ?? 'mixed').toString();

    return SafetyHealthTipsBatch(
      tips: merged,
      source: source == 'fallback' ? 'local' : source,
    );
  } catch (_) {
    return const SafetyHealthTipsBatch(
      tips: kSafetyHealthTipsLocal,
      source: 'local',
    );
  }
}
