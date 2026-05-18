import 'package:mobile/features/ai_scanner/data/food_nutrition_info.dart';

/// Back-compat wrapper — prefer [HybridNutritionService] via provider.
class FoodNutritionLookup {
  FoodNutritionLookup._();

  static FoodNutritionInfo legacyFromClass(String className) {
    final key = className.trim().toLowerCase();
    return FoodNutritionInfo(
      className: key,
      displayName: _titleCase(key),
      calories: 350,
      proteinG: 15,
      carbsG: 40,
      fatG: 12,
      ironMg: 2.0,
      folateMcg: 50,
      safetyStatus: 'safe',
    );
  }

  static String _titleCase(String raw) {
    if (raw.isEmpty) return 'Unknown food';
    return raw
        .replaceAll('-', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
