import 'ghanaian_meal_suggestions.dart';

class DietitianBodyMetrics {
  const DietitianBodyMetrics({
    this.weightKg,
    this.heightCm,
    this.bmi,
    this.bmiCategory,
    this.goal,
    this.todaySteps = 0,
    this.stepGoal = 0,
    this.burnedKcal = 0,
    this.consumedKcal = 0,
    this.netKcal = 0,
    this.dailyCaloriesTarget = 0,
    this.netRemainingKcal,
  });

  final double? weightKg;
  final double? heightCm;
  final double? bmi;
  final String? bmiCategory;
  final String? goal;
  final int todaySteps;
  final int stepGoal;
  final int burnedKcal;
  final int consumedKcal;
  final int netKcal;
  final int dailyCaloriesTarget;
  final int? netRemainingKcal;

  bool get hasProfile => weightKg != null && heightCm != null && weightKg! > 0 && heightCm! > 0;

  factory DietitianBodyMetrics.fromJson(Map<String, dynamic> json) {
    return DietitianBodyMetrics(
      weightKg: _toDouble(json['weightKg']),
      heightCm: _toDouble(json['heightCm']),
      bmi: _toDouble(json['bmi']),
      bmiCategory: json['bmiCategory']?.toString(),
      goal: json['goal']?.toString(),
      todaySteps: _toInt(json['todaySteps']),
      stepGoal: _toInt(json['stepGoal']),
      burnedKcal: _toInt(json['burnedKcal']),
      consumedKcal: _toInt(json['consumedKcal']),
      netKcal: _toInt(json['netKcal']),
      dailyCaloriesTarget: _toInt(json['dailyCaloriesTarget']),
      netRemainingKcal: json['netRemainingKcal'] == null
          ? null
          : _toInt(json['netRemainingKcal']),
    );
  }

  factory DietitianBodyMetrics.fromDashboardContext({
    required String? goal,
    required double? weightKg,
    required double? heightCm,
    required int todaySteps,
    required int stepGoal,
    required int burnedKcal,
    required int consumedKcal,
    required int dailyCaloriesTarget,
  }) {
    final bmi = computeBmi(weightKg, heightCm);
    final netKcal = (consumedKcal - burnedKcal).clamp(0, 99999);
    final netRemaining = dailyCaloriesTarget > 0 ? dailyCaloriesTarget - netKcal : null;

    return DietitianBodyMetrics(
      weightKg: weightKg,
      heightCm: heightCm,
      bmi: bmi,
      bmiCategory: bmiCategoryFor(bmi),
      goal: (goal ?? '').trim().isEmpty ? null : goal!.trim(),
      todaySteps: todaySteps,
      stepGoal: stepGoal,
      burnedKcal: burnedKcal,
      consumedKcal: consumedKcal,
      netKcal: netKcal,
      dailyCaloriesTarget: dailyCaloriesTarget,
      netRemainingKcal: netRemaining,
    );
  }

  static double? computeBmi(double? weightKg, double? heightCm) {
    if (weightKg == null || heightCm == null || weightKg <= 0 || heightCm <= 0) {
      return null;
    }
    final heightM = heightCm / 100;
    final bmi = weightKg / (heightM * heightM);
    return double.parse(bmi.toStringAsFixed(1));
  }

  static String? bmiCategoryFor(double? bmi) {
    if (bmi == null) return null;
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal weight';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }
}

class DietitianRecommendation {
  const DietitianRecommendation({
    required this.category,
    required this.title,
    required this.detail,
  });

  final String category;
  final String title;
  final String detail;

  factory DietitianRecommendation.fromJson(Map<String, dynamic> json) {
    return DietitianRecommendation(
      category: (json['category'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      detail: (json['detail'] ?? '').toString(),
    );
  }
}

class DietitianNextMeal {
  const DietitianNextMeal({
    required this.suggestion,
    required this.reason,
  });

  final String suggestion;
  final String reason;

  factory DietitianNextMeal.fromJson(Map<String, dynamic> json) {
    return DietitianNextMeal(
      suggestion: (json['suggestion'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
    );
  }
}

class DietitianAdvice {
  const DietitianAdvice({
    required this.headline,
    required this.summary,
    required this.recommendations,
    this.nextMeal,
    this.hydrationTip,
    this.portionTip,
    this.bodyMetrics,
    this.source = 'rules',
  });

  final String headline;
  final String summary;
  final List<DietitianRecommendation> recommendations;
  final DietitianNextMeal? nextMeal;
  final String? hydrationTip;
  final String? portionTip;
  final DietitianBodyMetrics? bodyMetrics;
  final String source;

  bool get isAiPowered => source == 'gemini';

  factory DietitianAdvice.fromJson(Map<String, dynamic> json) {
    final recsRaw = json['recommendations'];
    final recs = recsRaw is List
        ? recsRaw
            .whereType<Map>()
            .map((e) => DietitianRecommendation.fromJson(
                  e.map((k, v) => MapEntry(k.toString(), v)),
                ))
            .toList()
        : <DietitianRecommendation>[];

    final nextRaw = json['nextMeal'];
    DietitianNextMeal? nextMeal;
    if (nextRaw is Map) {
      nextMeal = DietitianNextMeal.fromJson(
        nextRaw.map((k, v) => MapEntry(k.toString(), v)),
      );
    }

    final metricsRaw = json['bodyMetrics'];
    DietitianBodyMetrics? bodyMetrics;
    if (metricsRaw is Map) {
      bodyMetrics = DietitianBodyMetrics.fromJson(
        metricsRaw.map((k, v) => MapEntry(k.toString(), v)),
      );
    }

    return DietitianAdvice(
      headline: (json['headline'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      recommendations: recs,
      nextMeal: nextMeal,
      hydrationTip: json['hydrationTip']?.toString(),
      portionTip: json['portionTip']?.toString(),
      bodyMetrics: bodyMetrics,
      source: (json['source'] ?? 'rules').toString(),
    );
  }

  /// Offline fallback when API cache has no dietitian block.
  factory DietitianAdvice.fromDashboardContext({
    required String userName,
    required String? goal,
    required int dailyCaloriesTarget,
    required int consumedKcal,
    required int proteinG,
    required int targetProteinG,
    required int mealsLoggedToday,
    required int mealsLogged7Days,
    required int burnedKcal,
    required int todaySteps,
    required int stepGoal,
    double? weightKg,
    double? heightCm,
    String? alertTitle,
    String? alertMessage,
  }) {
    final name = _firstName(userName);
    final goalText = (goal ?? '').trim();
    final metrics = DietitianBodyMetrics.fromDashboardContext(
      goal: goal,
      weightKg: weightKg,
      heightCm: heightCm,
      todaySteps: todaySteps,
      stepGoal: stepGoal,
      burnedKcal: burnedKcal,
      consumedKcal: consumedKcal,
      dailyCaloriesTarget: dailyCaloriesTarget,
    );
    final remaining = metrics.netRemainingKcal ?? 0;
    final proteinGap = targetProteinG > 0 ? targetProteinG - proteinG : 0;

    final recs = <DietitianRecommendation>[];

    final bmi = metrics.bmi;
    final bmiCategory = metrics.bmiCategory;
    if (bmi != null && bmiCategory != null) {
      recs.add(DietitianRecommendation(
        category: 'body',
        title: 'BMI ${bmi.toStringAsFixed(1)} — $bmiCategory',
        detail: _bmiCoachingLine(bmi, bmiCategory, goalText),
      ));
    }

    final alert = (alertTitle ?? '').trim();
    final alertMsg = (alertMessage ?? '').trim();
    if (alert.isNotEmpty &&
        alertMsg.isNotEmpty &&
        !alert.toLowerCase().contains('no alert')) {
      recs.add(DietitianRecommendation(
        category: 'environment',
        title: alert,
        detail: alertMsg,
      ));
    }

    if (stepGoal > 0) {
      final pct = ((todaySteps / stepGoal) * 100).round();
      if (todaySteps >= stepGoal) {
        recs.add(DietitianRecommendation(
          category: 'activity',
          title: 'Step goal reached',
          detail:
              '$todaySteps steps today—that activity gives you extra calorie room and supports your goal.',
        ));
      } else if (pct < 50) {
        recs.add(DietitianRecommendation(
          category: 'activity',
          title: 'Move a bit more today',
          detail:
              '$todaySteps of $stepGoal steps. A short walk before supper helps balance chop bar meals.',
        ));
      }
    }

    if (mealsLoggedToday == 0) {
      recs.add(DietitianRecommendation(
        category: 'habit',
        title: 'Log your first meal',
        detail: mealsLogged7Days > 0
            ? "You've logged $mealsLogged7Days meals this week—scan your next plate so I can coach you."
            : 'Log whatever you eat next. Tracking is the first step to better portions.',
      ));
    } else if (proteinGap > 15) {
      recs.add(DietitianRecommendation(
        category: 'protein',
        title: 'Add protein next',
        detail:
            'Try banku and tilapia, waakye with egg and fish, or red-red with plantain.',
      ));
    }

    if (dailyCaloriesTarget > 0 && remaining > 400) {
      final burnedNote =
          burnedKcal > 0 ? ' (after ~$burnedKcal kcal from your steps)' : '';
      recs.add(DietitianRecommendation(
        category: 'calories',
        title: 'Calories still available',
        detail: goalText == 'Lose weight'
            ? 'About $remaining kcal left net$burnedNote—choose lean protein and vegetables next.'
            : 'About $remaining kcal left net$burnedNote—balance starch, protein, and veg.',
      ));
    } else if (dailyCaloriesTarget > 0 && remaining < -300) {
      recs.add(DietitianRecommendation(
        category: 'calories',
        title: "Above today's target",
        detail:
            'Net intake is high after food and steps—go lighter at dinner with grilled fish or light soup.',
      ));
    }

    final next = GhanaianMealSuggestions.nextMeal(
      mealsLoggedToday: mealsLoggedToday,
      goal: goalText,
      remainingKcal: remaining,
      proteinGap: proteinGap,
    );

    return DietitianAdvice(
      headline: "$name, your dietitian coach is here.",
      summary: goalText.isEmpty
          ? 'I use your BMI, steps, logged meals, and targets for practical Ghana-friendly coaching.'
          : "I'm aligning guidance with your goal: $goalText, your activity, and today's net calories.",
      recommendations: recs,
      nextMeal: DietitianNextMeal(
        suggestion: next.suggestion,
        reason: next.reason,
      ),
      hydrationTip:
          'Drink water steadily—especially with spicy stews, jollof, or waakye.',
      portionTip: _portionHint(bmi, goalText),
      bodyMetrics: metrics,
      source: 'rules',
    );
  }
}

class MealDietitianAdvice {
  const MealDietitianAdvice({
    required this.insight,
    this.pairing,
    this.portion,
  });

  final String insight;
  final String? pairing;
  final String? portion;

  factory MealDietitianAdvice.fromJson(Map<String, dynamic> json) {
    return MealDietitianAdvice(
      insight: (json['insight'] ?? '').toString(),
      pairing: json['pairing']?.toString(),
      portion: json['portion']?.toString(),
    );
  }

  /// Client-side meal tip when offline (mirrors backend food tips).
  factory MealDietitianAdvice.forFood({
    required String name,
    String? className,
    int calories = 0,
    String goal = '',
  }) {
    final slug = (className ?? name).toLowerCase();
    String insight;

    if (slug.contains('jollof')) {
      insight =
          'Jollof is party food—pair with chicken or fish and salad, not eaten plain.';
    } else if (slug.contains('banku')) {
      insight =
          'Banku with okro stew or tilapia and shito—that is the chop people actually eat.';
    } else if (slug.contains('fufu')) {
      insight =
          'Fufu with light soup or groundnut soup—one ball is the usual serving.';
    } else if (slug.contains('kenkey')) {
      insight =
          'Kenkey and fried fish with shito is the classic evening plate.';
    } else if (slug.contains('waakye')) {
      insight =
          'Waakye chop: shito, gari, egg, plantain—pick your sides like at the vendor.';
    } else if (slug.contains('kelewele') || slug.contains('fried')) {
      insight =
          'Kelewele and fried plantain are side chops—pair with rice, jollof, or gobe.';
    } else if (slug.contains('koko')) {
      insight =
          'Hausa koko fits morning or afternoon—with koose or bofrot, not as a late-night meal.';
    } else if (calories >= 700) {
      insight =
          '$name is a full chop bar portion—hydrate and go lighter on starch next time.';
    } else {
      insight =
          'Good logging $name. Consistent tracking helps me tune your Ghanaian meal plan.';
    }

    if (goal == 'Lose weight' &&
        (slug.contains('kelewele') || slug.contains('fried'))) {
      insight += ' For weight loss, enjoy fried treats occasionally.';
    }

    final pairing = GhanaianMealSuggestions.pairingForFood(slug);

    return MealDietitianAdvice(insight: insight, pairing: pairing);
  }
}

String _bmiCoachingLine(double bmi, String category, String goal) {
  if (goal == 'Lose weight' &&
      (category == 'Overweight' || category == 'Obese')) {
    return 'Your BMI is in the $category range—smaller starch portions and more grilled fish or beans support your goal.';
  }
  if (goal == 'Gain weight' && category == 'Underweight') {
    return 'Your BMI is underweight—regular chops plus groundnut snacks support healthy gain.';
  }
  if (category == 'Normal weight') {
    return 'Your BMI is in a healthy range—keep steady portions and stay active.';
  }
  return 'BMI category: $category. I will align portions with your goal.';
}

String _portionHint(double? bmi, String goal) {
  final category = DietitianBodyMetrics.bmiCategoryFor(bmi);
  if (goal == 'Lose weight' ||
      category == 'Overweight' ||
      category == 'Obese') {
    return 'Palm-sized fish or meat, one ball of swallow, extra kontomire or salad.';
  }
  if (goal == 'Gain weight' || category == 'Underweight') {
    return 'Full chop portions are fine—add groundnut soup, egg, or fish for steady gain.';
  }
  return 'Palm-sized protein, one ball of banku/fufu/kenkey, plenty of soup or stew.';
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse('$value') ?? 0;
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}

String _firstName(String full) {
  final parts = full.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return 'there';
  return parts.first;
}
