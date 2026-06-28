import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bump after meal logs so dashboard refetches dietitian advice.
final nutritionDashboardRefreshProvider = StateProvider<int>((ref) => 0);

void bumpNutritionDashboardRefresh(Ref ref) {
  ref.read(nutritionDashboardRefreshProvider.notifier).state++;
}
