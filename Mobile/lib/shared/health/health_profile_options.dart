/// Health assistant profile options (mirrors backend HealthProfileOptions).
class HealthProfileOptions {
  static const goals = [
    'Gain weight',
    'Lose weight',
    'Maintain weight',
  ];

  static const healthConditions = [
    'None',
    'High blood pressure',
    'Diabetes',
    'Anaemia',
    'Sickle cell',
    'High cholesterol',
  ];

  static const eatingPatterns = [
    'Regular',
    'Ramadan',
    'Lent',
    'Church fast days',
    'Intermittent fasting',
  ];

  static const lifeStages = [
    'General adult',
    'Pregnant',
    'Breastfeeding',
    'Caring for young child',
  ];

  static const mealSourcePreferences = [
    'Chop bar',
    'Home-cooked',
    'Mixed',
  ];

  static const activityContexts = [
    'Office / desk',
    'Market & trotro',
    'Active job',
    'Student',
    'Mixed',
  ];

  static const portionSizes = ['small', 'regular', 'large'];

  static const mealSources = ['chop_bar', 'home_cooked'];

  static int defaultWaterGoalMl(int? weightKg) {
    final base = weightKg != null && weightKg > 0 ? (weightKg * 35).round() : 2000;
    return base.clamp(1500, 4000);
  }

  static int ghanaStepGoal(String context, String activityLevel) {
    var base = switch (context) {
      'Market & trotro' => 12000,
      'Active job' => 11000,
      'Student' => 9000,
      'Office / desk' => 7500,
      _ => 10000,
    };
    return switch (activityLevel) {
      'Sedentary' => (base * 0.85).round(),
      'Very active' || 'Extremely active' => (base * 1.15).round(),
      _ => base,
    };
  }
}
