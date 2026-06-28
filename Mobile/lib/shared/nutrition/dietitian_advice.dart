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
    this.source = 'rules',
  });

  final String headline;
  final String summary;
  final List<DietitianRecommendation> recommendations;
  final DietitianNextMeal? nextMeal;
  final String? hydrationTip;
  final String? portionTip;
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

    return DietitianAdvice(
      headline: (json['headline'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      recommendations: recs,
      nextMeal: nextMeal,
      hydrationTip: json['hydrationTip']?.toString(),
      portionTip: json['portionTip']?.toString(),
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
    String? alertTitle,
    String? alertMessage,
  }) {
    final name = _firstName(userName);
    final goalText = (goal ?? '').trim();
    final remaining = dailyCaloriesTarget > 0 ? dailyCaloriesTarget - consumedKcal : 0;
    final proteinGap = targetProteinG > 0 ? targetProteinG - proteinG : 0;

    final recs = <DietitianRecommendation>[];

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
            'Try tilapia, beans stew (gobe), eggs, or chicken soup to close your protein gap.',
      ));
    }

    if (dailyCaloriesTarget > 0 && remaining > 400) {
      recs.add(DietitianRecommendation(
        category: 'calories',
        title: 'Calories still available',
        detail: goalText == 'Lose weight'
            ? 'About $remaining kcal left—choose lean protein and vegetables for the next meal.'
            : 'About $remaining kcal left—balance starch, protein, and veg on your plate.',
      ));
    } else if (dailyCaloriesTarget > 0 && remaining < -300) {
      recs.add(DietitianRecommendation(
        category: 'calories',
        title: "Above today's target",
        detail:
            'Go lighter at dinner—vegetable soup, grilled fish, or a smaller starch portion.',
      ));
    }

    DietitianNextMeal? nextMeal;
    if (proteinGap > 20) {
      nextMeal = const DietitianNextMeal(
        suggestion: 'Grilled tilapia with kontomire stew',
        reason: 'High protein, familiar Ghanaian plate, lighter on oil.',
      );
    } else if (mealsLoggedToday == 0) {
      nextMeal = const DietitianNextMeal(
        suggestion: 'Hausa koko with koose or boiled eggs',
        reason: 'Light Ghanaian breakfast with steady protein.',
      );
    }

    return DietitianAdvice(
      headline: "$name, your dietitian coach is here.",
      summary: goalText.isEmpty
          ? 'I use your logged meals and targets to suggest practical Ghana-friendly nutrition—not strict rules.'
          : "I'm aligning guidance with your goal: $goalText.",
      recommendations: recs,
      nextMeal: nextMeal,
      hydrationTip:
          'Drink water steadily—especially with spicy stews, jollof, or waakye.',
      portionTip:
          'Palm-sized protein, fist-sized starch, two hands of vegetables.',
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
          'Jollof is energy-dense—pair with salad or grilled chicken and watch oily sides.';
    } else if (slug.contains('banku') || slug.contains('fufu')) {
      insight =
          'One moderate ball of banku or fufu with lean soup or fish is a balanced portion.';
    } else if (slug.contains('waakye')) {
      insight =
          'Waakye gives lasting energy—add egg or fish and go easy on extra gari.';
    } else if (slug.contains('kelewele') || slug.contains('fried')) {
      insight = 'Keep fried sides small; make protein and vegetables the main event.';
    } else if (calories >= 700) {
      insight =
          '$name is hearty—hydrate well and keep the next meal lighter on starch.';
    } else {
      insight =
          'Good logging $name. Consistent tracking helps me tune your Ghanaian meal plan.';
    }

    if (goal == 'Lose weight' &&
        (slug.contains('kelewele') || slug.contains('fried'))) {
      insight += ' For weight loss, enjoy fried treats occasionally.';
    }

    String? pairing;
    if (slug.contains('banku')) {
      pairing = 'Grilled tilapia and fresh pepper beat extra fried sides.';
    } else if (slug.contains('jollof')) {
      pairing = 'Add salad and grilled chicken for balance.';
    }

    return MealDietitianAdvice(insight: insight, pairing: pairing);
  }
}

String _firstName(String full) {
  final parts = full.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return 'there';
  return parts.first;
}
