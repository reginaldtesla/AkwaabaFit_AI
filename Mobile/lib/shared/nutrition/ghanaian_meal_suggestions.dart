/// Realistic Ghanaian meal pairings for offline dietitian tips.
class GhanaianMealSuggestion {
  const GhanaianMealSuggestion({
    required this.suggestion,
    required this.reason,
  });

  final String suggestion;
  final String reason;
}

class GhanaianMealSuggestions {
  static GhanaianMealSuggestion nextMeal({
    int mealsLoggedToday = 0,
    String goal = '',
    int remainingKcal = 0,
    int proteinGap = 0,
    DateTime? now,
  }) {
    final hour = (now ?? DateTime.now()).hour;

    if (proteinGap > 25) {
      return _pick([
        const GhanaianMealSuggestion(
          suggestion: 'Banku with grilled tilapia and shito',
          reason: 'Proper Accra-style chop—fish for protein, banku for energy.',
        ),
        const GhanaianMealSuggestion(
          suggestion: 'Waakye with boiled egg, shito and fish',
          reason: 'Street waakye chop—protein without losing the flavours you know.',
        ),
        const GhanaianMealSuggestion(
          suggestion: 'Red-red (gobe) with fried ripe plantain',
          reason: 'Beans stew and plantain—real Ghanaian plant protein.',
        ),
      ]);
    }

    if (remainingKcal < -250) {
      return _pick([
        const GhanaianMealSuggestion(
          suggestion: 'Kenkey with grilled fish and pepper',
          reason: 'Classic lighter dinner—keep the kenkey ball modest.',
        ),
        const GhanaianMealSuggestion(
          suggestion: 'Light soup with a small fufu ball',
          reason: 'Warm soup, less starch—how many families eat a light evening meal.',
        ),
      ]);
    }

    if (goal == 'Gain weight' && remainingKcal > 450) {
      return _pick([
        const GhanaianMealSuggestion(
          suggestion: 'Waakye chop — stew, gari, egg and plantain',
          reason: 'Full waakye plate is filling and very Ghana.',
        ),
        const GhanaianMealSuggestion(
          suggestion: 'Fufu with groundnut soup and meat',
          reason: 'Hearty chop that fills you up the Ghanaian way.',
        ),
      ]);
    }

    if (mealsLoggedToday == 0) {
      return _mealForHour(hour);
    }

    if (mealsLoggedToday == 1) {
      return _pick([
        const GhanaianMealSuggestion(
          suggestion: 'Jollof rice with chicken and salad',
          reason: 'Chop bar lunch—tomato rice plus protein.',
        ),
        const GhanaianMealSuggestion(
          suggestion: 'Banku with okro stew',
          reason: 'Banku and okro is home for many Ghanaians.',
        ),
        const GhanaianMealSuggestion(
          suggestion: 'Kenkey with fried fish and shito',
          reason: 'Coastal evening favourite—fish, pepper, kenkey.',
        ),
      ]);
    }

    return _pick([
      const GhanaianMealSuggestion(
        suggestion: 'Boiled yam with kontomire stew and egg',
        reason: 'Kontomire with ampesi yam—not odd pairings.',
      ),
      const GhanaianMealSuggestion(
        suggestion: 'Plain rice with stew and kontomire',
        reason: 'Simple household plate many still eat.',
      ),
    ]);
  }

  static String? pairingForFood(String slug) {
    final s = slug.toLowerCase();
    if (s.contains('banku')) {
      return 'Okro stew, tilapia with shito, or palm nut soup.';
    }
    if (s.contains('kenkey')) {
      return 'Fried or grilled fish with shito and pepper.';
    }
    if (s.contains('fufu')) {
      return 'Light soup, groundnut soup, or palm nut soup.';
    }
    if (s.contains('jollof')) {
      return 'Chicken, fish, or kelewele on the side.';
    }
    if (s.contains('waakye')) {
      return 'Shito, gari, spaghetti, egg, plantain—the waakye vendor spread.';
    }
    if (s.contains('beans') || s.contains('gobe') || s.contains('red')) {
      return 'Fried ripe plantain (red-red) or rice.';
    }
    if (s.contains('yam')) {
      return 'Kontomire stew or garden eggs stew.';
    }
    return null;
  }

  static GhanaianMealSuggestion _mealForHour(int hour) {
    if (hour >= 5 && hour < 11) {
      return _pick([
        const GhanaianMealSuggestion(
          suggestion: 'Waakye with shito, gari, egg and plantain',
          reason: 'Morning waakye from the vendor—how many start the day.',
        ),
        const GhanaianMealSuggestion(
          suggestion: 'Hausa koko with koose',
          reason: 'Koko and koose/bofrot—not koko with random sides.',
        ),
        const GhanaianMealSuggestion(
          suggestion: 'Tea bread with eggs',
          reason: 'Quick urban breakfast before the day gets busy.',
        ),
      ]);
    }
    if (hour >= 11 && hour < 16) {
      return _pick([
        const GhanaianMealSuggestion(
          suggestion: 'Banku with grilled tilapia and pepper',
          reason: 'Iconic lunch—chop bars up and down the coast.',
        ),
        const GhanaianMealSuggestion(
          suggestion: 'Jollof with chicken or fish',
          reason: 'Party jollof, office jollof, chop bar jollof.',
        ),
        const GhanaianMealSuggestion(
          suggestion: 'Fufu with light soup',
          reason: 'Proper midday soup and swallow.',
        ),
      ]);
    }
    if (hour >= 16 && hour < 23) {
      return _pick([
        const GhanaianMealSuggestion(
          suggestion: 'Kenkey with fried fish and shito',
          reason: 'Classic supper—Ga kenkey and fish.',
        ),
        const GhanaianMealSuggestion(
          suggestion: 'Banku with okro stew',
          reason: 'Lighter than big fufu but still fully Ghanaian.',
        ),
        const GhanaianMealSuggestion(
          suggestion: 'Waakye with stew and egg',
          reason: 'Waakye for supper is normal—not only morning food.',
        ),
      ]);
    }
    return const GhanaianMealSuggestion(
      suggestion: 'Light soup with small fufu',
      reason: 'Late night—soup beats a heavy plate.',
    );
  }

  static GhanaianMealSuggestion _pick(List<GhanaianMealSuggestion> options) {
    if (options.isEmpty) {
      return const GhanaianMealSuggestion(
        suggestion: 'Banku with okro stew',
        reason: 'A familiar Ghanaian plate.',
      );
    }
    final index = DateTime.now().day % options.length;
    return options[index];
  }
}
