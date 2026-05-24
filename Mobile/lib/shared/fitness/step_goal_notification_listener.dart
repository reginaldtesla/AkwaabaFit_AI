import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/dashboard/presentation/dashboard_screen.dart';
import 'package:mobile/features/fitness/data/steps_today_provider.dart';
import 'package:mobile/features/profile/presentation/profile_settings_screen.dart';
import 'package:mobile/shared/fitness/step_goal_achievement_notifier.dart';

/// Watches live steps + dashboard nutrition data and fires goal notifications.
class StepGoalNotificationListener extends ConsumerWidget {
  const StepGoalNotificationListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<int>>(stepsTodayProvider, (previous, next) {
      final steps = next.valueOrNull;
      if (steps == null) return;
      _evaluateFromRef(ref, stepsOverride: steps);
    });

    ref.listen<AsyncValue<DashboardData>>(dashboardDataProvider, (previous, next) {
      next.whenData((data) {
        final steps = ref.read(stepsTodayProvider).valueOrNull ?? data.currentSteps;
        _evaluate(ref, data, steps);
      });
    });

    return child;
  }

  void _evaluateFromRef(WidgetRef ref, {required int stepsOverride}) {
    final dash = ref.read(dashboardDataProvider).valueOrNull;
    if (dash == null) {
      StepGoalAchievementNotifier.evaluate(steps: stepsOverride);
      return;
    }
    _evaluate(ref, dash, stepsOverride);
  }

  void _evaluate(WidgetRef ref, DashboardData data, int steps) {
    final localKcal = ref.read(dailyCaloriesGoalProvider).valueOrNull;
    final kcalTarget = (localKcal != null && localKcal > 0)
        ? localKcal
        : data.dailyCaloriesTarget;

    StepGoalAchievementNotifier.evaluate(
      steps: steps,
      calorieConsumed: data.consumedKcal,
      calorieTarget: kcalTarget,
      mealsLoggedToday: data.mealsLoggedToday ?? 0,
    );
  }
}
