/// Realistic Ghanaian meal pairings with time-of-day awareness.
class GhanaianMealSuggestion {
  const GhanaianMealSuggestion({
    required this.suggestion,
    required this.reason,
    this.slots = const [],
  });

  final String suggestion;
  final String reason;
  final List<String> slots;
}

class GhanaianMealSuggestions {
  static const _earlyMorning = 'early_morning';
  static const _lateMorning = 'late_morning';
  static const _lunch = 'lunch';
  static const _afternoon = 'afternoon';
  static const _evening = 'evening';
  static const _lateNight = 'late_night';

  static GhanaianMealSuggestion nextMeal({
    int mealsLoggedToday = 0,
    String goal = '',
    int remainingKcal = 0,
    int proteinGap = 0,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final hour = clock.hour;
    final occasion = _resolveOccasion(hour, mealsLoggedToday);

    if (proteinGap > 25) {
      return _pickForOccasion(_proteinRichMeals(), occasion, hour);
    }

    if (remainingKcal < -250) {
      return _pickForOccasion(_lighterMeals(), occasion, hour);
    }

    if (goal == 'Gain weight' && remainingKcal > 450) {
      return _pickForOccasion(_calorieDenseMeals(), occasion, hour);
    }

    return _pickForOccasion(_mealsForOccasion(occasion), occasion, hour);
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
    if (s.contains('koko')) {
      return 'Koose or bofrot—morning or afternoon, not a supper plate.';
    }
    return null;
  }

  static String _resolveOccasion(int hour, int mealsLoggedToday) {
    if (mealsLoggedToday == 0) {
      return _slotForHour(hour);
    }
    if (mealsLoggedToday == 1) {
      if (hour < 12) return _lunch;
      if (hour < 17) return _afternoon;
      return _evening;
    }
    if (hour < 17) return _afternoon;
    if (hour < 22) return _evening;
    return _lateNight;
  }

  static String _slotForHour(int hour) {
    if (hour >= 5 && hour < 10) return _earlyMorning;
    if (hour >= 10 && hour < 12) return _lateMorning;
    if (hour >= 12 && hour < 15) return _lunch;
    if (hour >= 15 && hour < 17) return _afternoon;
    if (hour >= 17 && hour < 22) return _evening;
    return _lateNight;
  }

  static List<GhanaianMealSuggestion> _proteinRichMeals() => [
        const GhanaianMealSuggestion(
          suggestion: 'Waakye with boiled egg, shito and fish',
          reason:
              'Morning or afternoon waakye chop—protein without losing familiar flavours.',
          slots: [_earlyMorning, _lateMorning, _lunch, _afternoon],
        ),
        const GhanaianMealSuggestion(
          suggestion: 'Banku with grilled tilapia and shito',
          reason: 'Lunch or early-evening plate—fish for protein, banku for energy.',
          slots: [_lunch, _evening],
        ),
        const GhanaianMealSuggestion(
          suggestion: 'Red-red (gobe) with fried ripe plantain',
          reason: 'Beans stew and plantain—good for lunch or afternoon.',
          slots: [_lunch, _afternoon],
        ),
        const GhanaianMealSuggestion(
          suggestion: 'Kenkey with grilled fish and pepper',
          reason: 'Classic supper protein—kenkey belongs in the evening.',
          slots: [_evening],
        ),
      ];

  static List<GhanaianMealSuggestion> _lighterMeals() => [
        const GhanaianMealSuggestion(
          suggestion: 'Kenkey with grilled fish and pepper (small ball)',
          reason: 'Lighter supper after a heavy day.',
          slots: [_evening],
        ),
        const GhanaianMealSuggestion(
          suggestion: 'Light soup with a small fufu ball',
          reason: 'Warm evening soup with less starch.',
          slots: [_evening, _lateNight],
        ),
        const GhanaianMealSuggestion(
          suggestion: 'Hausa koko with koose',
          reason: 'Light koko for late morning or afternoon.',
          slots: [_lateMorning, _afternoon],
        ),
        const GhanaianMealSuggestion(
          suggestion: 'Tea bread with eggs',
          reason: 'Simple morning bite when you want something lighter.',
          slots: [_earlyMorning, _lateMorning],
        ),
      ];

  static List<GhanaianMealSuggestion> _calorieDenseMeals() => [
        const GhanaianMealSuggestion(
          suggestion: 'Waakye chop — stew, gari, egg and plantain',
          reason: 'Full waakye for morning or afternoon.',
          slots: [_earlyMorning, _lateMorning, _lunch, _afternoon],
        ),
        const GhanaianMealSuggestion(
          suggestion: 'Fufu with groundnut soup and meat',
          reason: 'Hearty lunch chop—not a breakfast plate.',
          slots: [_lunch],
        ),
        const GhanaianMealSuggestion(
          suggestion: 'Jollof rice with chicken and salad',
          reason: 'Midday jollof when chop bars serve the main meal.',
          slots: [_lunch],
        ),
      ];

  static List<GhanaianMealSuggestion> _mealsForOccasion(String occasion) {
    const catalog = <GhanaianMealSuggestion>[
      GhanaianMealSuggestion(
        suggestion: 'Waakye with shito, gari, egg and plantain',
        reason: 'Morning waakye from the vendor—how many start the day.',
        slots: [_earlyMorning, _lateMorning],
      ),
      GhanaianMealSuggestion(
        suggestion: 'Hausa koko with koose',
        reason: 'Porridge for morning or afternoon—with koose like the sellers make it.',
        slots: [_earlyMorning, _lateMorning, _afternoon],
      ),
      GhanaianMealSuggestion(
        suggestion: 'Tea bread with eggs',
        reason: 'Quick urban breakfast before the day gets busy.',
        slots: [_earlyMorning, _lateMorning],
      ),
      GhanaianMealSuggestion(
        suggestion: 'Banku with grilled tilapia and pepper',
        reason: 'Iconic lunch—chop bars up and down the coast.',
        slots: [_lunch],
      ),
      GhanaianMealSuggestion(
        suggestion: 'Jollof with chicken or fish',
        reason: 'Party jollof, office jollof, chop bar jollof—all lunch-hour food.',
        slots: [_lunch],
      ),
      GhanaianMealSuggestion(
        suggestion: 'Fufu with light soup',
        reason: 'Proper midday soup and swallow.',
        slots: [_lunch],
      ),
      GhanaianMealSuggestion(
        suggestion: 'Plain rice with stew and kontomire',
        reason: 'Household lunch plate many still eat.',
        slots: [_lunch],
      ),
      GhanaianMealSuggestion(
        suggestion: 'Waakye with stew and egg (smaller portion)',
        reason: 'Afternoon waakye—vendors still have the pot going.',
        slots: [_afternoon],
      ),
      GhanaianMealSuggestion(
        suggestion: 'Kelewele with groundnuts',
        reason: 'Afternoon street snack—not a full dinner.',
        slots: [_afternoon],
      ),
      GhanaianMealSuggestion(
        suggestion: 'Boiled yam with kontomire stew and egg',
        reason: 'Light afternoon ampesi before supper.',
        slots: [_afternoon],
      ),
      GhanaianMealSuggestion(
        suggestion: 'Kenkey with fried fish and shito',
        reason: 'Classic Ga supper—kenkey belongs in the evening.',
        slots: [_evening],
      ),
      GhanaianMealSuggestion(
        suggestion: 'Banku with okro stew',
        reason: 'Evening banku—many eat okro after work.',
        slots: [_evening],
      ),
      GhanaianMealSuggestion(
        suggestion: 'Waakye with stew and egg',
        reason: 'Early-evening waakye before vendors pack up.',
        slots: [_evening],
      ),
      GhanaianMealSuggestion(
        suggestion: 'Light soup with small fufu',
        reason: 'Late night—soup beats a heavy plate.',
        slots: [_lateNight],
      ),
    ];

    return catalog.where((meal) => meal.slots.contains(occasion)).toList();
  }

  static GhanaianMealSuggestion _pickForOccasion(
    List<GhanaianMealSuggestion> options,
    String occasion,
    int hour,
  ) {
    var filtered = options.where((meal) => meal.slots.contains(occasion)).toList();
    if (filtered.isEmpty) {
      filtered = _mealsForOccasion(occasion);
    }
    if (filtered.isEmpty) {
      filtered = _mealsForOccasion(_slotForHour(hour));
    }
    return _pick(filtered);
  }

  static GhanaianMealSuggestion _pick(List<GhanaianMealSuggestion> options) {
    if (options.isEmpty) {
      return const GhanaianMealSuggestion(
        suggestion: 'Banku with okro stew',
        reason: 'A familiar Ghanaian plate for the evening.',
      );
    }
    final index = DateTime.now().day % options.length;
    return options[index];
  }
}
