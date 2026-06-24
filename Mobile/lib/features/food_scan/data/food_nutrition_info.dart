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
    this.portionLabel = '1 serving',
    this.source = 'bundled',
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
  final String portionLabel;
  final String source;
  final bool isGenericFallback;

  factory FoodNutritionInfo.fromJson(
    Map<String, dynamic> json, {
    String source = 'bundled',
  }) {
    return FoodNutritionInfo(
      className: (json['class_name'] ?? json['className'] ?? '').toString(),
      displayName: (json['display_name'] ?? json['displayName'] ?? 'Food').toString(),
      calories: (json['calories'] as num?)?.toInt() ?? 0,
      proteinG: (json['protein_g'] as num?)?.toInt() ?? (json['proteinG'] as num?)?.toInt() ?? 0,
      carbsG: (json['carbs_g'] as num?)?.toInt() ?? (json['carbsG'] as num?)?.toInt() ?? 0,
      fatG: (json['fat_g'] as num?)?.toInt() ?? (json['fatG'] as num?)?.toInt() ?? 0,
      ironMg: (json['iron_mg'] as num?)?.toDouble() ?? (json['ironMg'] as num?)?.toDouble() ?? 0,
      folateMcg: (json['folate_mcg'] as num?)?.toInt() ?? (json['folateMcg'] as num?)?.toInt() ?? 0,
      safetyStatus: (json['safety_status'] ?? json['safetyStatus'] ?? 'safe').toString(),
      insightMessage: (json['insight_message'] ?? json['insightMessage'])?.toString(),
      portionLabel: (json['portion_label'] ?? json['portionLabel'] ?? '1 serving').toString(),
      source: source,
      isGenericFallback: json['is_generic_fallback'] == true || json['isGenericFallback'] == true,
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
      };
}
