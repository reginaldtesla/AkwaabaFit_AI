/// Nutrition profile for one detected food class (bundled, cached, or server).
class FoodNutritionInfo {
  const FoodNutritionInfo({
    required this.className,
    required this.displayName,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.ironMg,
    required this.folateMcg,
    required this.safetyStatus,
    this.insightMessage,
    this.source = 'bundled',
    this.portionLabel = '1 serving',
    this.isGenericFallback = false,
  });

  final String className;
  final String displayName;
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final double ironMg;
  final int folateMcg;
  final String safetyStatus;
  final String? insightMessage;

  /// bundled | cache | server
  final String source;

  /// e.g. "1 serving" — macros are for this portion, not the photographed plate.
  final String portionLabel;

  /// True when class has no catalog row (generic 350 kcal / 15·40·12 placeholder).
  final bool isGenericFallback;

  factory FoodNutritionInfo.fromJson(
    Map<String, dynamic> json, {
    String source = 'bundled',
  }) {
    final className = (json['class_name'] ?? json['className'] ?? '')
        .toString()
        .toLowerCase();
    return FoodNutritionInfo(
      className: className,
      displayName: (json['display_name'] ?? json['displayName'] ?? className)
          .toString(),
      calories: _int(json['calories']),
      proteinG: _int(json['protein_g'] ?? json['proteinG']),
      carbsG: _int(json['carbs_g'] ?? json['carbsG']),
      fatG: _int(json['fat_g'] ?? json['fatG']),
      ironMg: _double(json['iron_mg'] ?? json['ironMg']),
      folateMcg: _int(json['folate_mcg'] ?? json['folateMcg']),
      safetyStatus: (json['safety_status'] ?? json['safetyStatus'] ?? 'safe')
          .toString(),
      insightMessage:
          (json['insight_message'] ?? json['insightMessage'])?.toString(),
      source: source,
      portionLabel: (json['portion_label'] ??
              json['portionLabel'] ??
              '1 serving')
          .toString(),
      isGenericFallback: json['is_generic_fallback'] == true ||
          json['isGenericFallback'] == true,
    );
  }

  Map<String, dynamic> toCacheJson() => {
        'class_name': className,
        'display_name': displayName,
        'calories': calories,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
        'iron_mg': ironMg,
        'folate_mcg': folateMcg,
        'safety_status': safetyStatus,
        'insight_message': insightMessage,
        'portion_label': portionLabel,
        'is_generic_fallback': isGenericFallback,
      };

  Map<String, dynamic> toMealFields() => {
        'name': displayName,
        'calories': calories,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
        'safety_status': safetyStatus,
        'insight_message': insightMessage,
      };

  bool isMeaningfullyDifferentFrom(FoodNutritionInfo other) {
    return calories != other.calories ||
        proteinG != other.proteinG ||
        carbsG != other.carbsG ||
        fatG != other.fatG ||
        (insightMessage ?? '') != (other.insightMessage ?? '') ||
        safetyStatus != other.safetyStatus ||
        displayName != other.displayName;
  }

  static int _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static double _double(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }
}
