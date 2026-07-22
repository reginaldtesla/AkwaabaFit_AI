import 'dart:async';
import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/shared/connectivity/connectivity_utils.dart';
import 'package:mobile/features/auth/presentation/auth_screen.dart';
import 'package:mobile/features/fitness/presentation/activity_tracking_screen.dart';
import 'package:mobile/features/fitness/data/steps_today_provider.dart';
import 'package:mobile/features/nutrition/presentation/water_tracker_card.dart';
import 'package:mobile/features/nutrition/presentation/nutrition_history_screen.dart';
import 'package:mobile/shared/nutrition/dietitian_advice.dart';
import 'package:mobile/shared/nutrition/nutrition_refresh.dart';
import 'package:mobile/features/food_scan/presentation/scan_meal_fab.dart';
import 'package:mobile/features/profile/presentation/profile_settings_screen.dart';
import 'package:mobile/features/safety/presentation/health_safety_hub_screen.dart';
import 'package:mobile/shared/fitness/foreground_notification_prefs.dart';
import 'package:mobile/shared/fitness/background_step_tracking_bootstrap.dart';
import 'package:mobile/shared/fitness/step_goal_achievement_notifier.dart';
import 'package:mobile/shared/notifications/local_notification_service.dart';
import 'package:mobile/shared/notifications/notification_inbox_provider.dart';
import 'package:mobile/shared/notifications/notifications_modal.dart';
import 'package:mobile/shared/profile/profile_repository.dart';
import 'package:mobile/shared/navigation/app_bottom_nav.dart';
import 'package:mobile/shared/navigation/main_tab_shell.dart';
import 'package:mobile/shared/auth/sanctum_token_storage.dart';
import 'package:mobile/shared/auth/sanctum_token_ready_provider.dart';
import 'package:mobile/shared/config/app_config.dart';
import 'package:mobile/shared/offline/sqlite_offline_db.dart';
import 'package:mobile/shared/ui/network_error_view.dart';
import 'package:mobile/shared/fitness/stride_weather_guidance.dart';
import 'package:mobile/shared/weather/air_quality_thresholds.dart';
import 'package:mobile/shared/weather/dashboard_weather_merge.dart';
import 'package:mobile/shared/weather/device_weather_service.dart';
import 'package:mobile/shared/ui/user_friendly_errors.dart';

// =====================================================================
// 1. STATE MANAGEMENT (RIVERPOD DATA MODELS)
// =====================================================================

class DashboardData {
  final String userName;
  final String avatarUrl;
  final String? goal;
  final int netKcal;
  final int consumedKcal;
  final int burnedKcal;
  final double tempCelsius;
  final String location;
  final String? weatherMain;
  final String? weatherDescription;
  final String? alertTitle;
  final String? alertMessage;
  final int currentSteps;
  final int stepGoal;
  final int dailyCaloriesTarget;
  /// Grams from today's logged/scanned meals (matches consumed calories window).
  final int proteinG;
  final int carbsG;
  final int fatG;
  /// Daily macro targets from health profile / calorie goal (coaching only).
  final int targetProteinG;
  final int targetCarbsG;
  final int targetFatG;
  final int? airQualityAqi;
  final String? workoutPreferredTime;
  final int? workoutDaysPerWeek;
  final int? mealsLoggedToday;
  final int? mealsLogged7Days;
  final bool fromOfflineCache;
  /// When [fromOfflineCache] is true: device reported a network interface.
  /// false → no transport; true → online but API failed / timed out.
  final bool networkInterfaceUp;
  /// Grams inferred from calorie-goal macro split when logged meals had no P/C/F data.
  final bool macrosEstimated;
  final double? weightKg;
  final double? heightCm;
  final int waterTotalMl;
  final int waterGoalMl;
  final DietitianAdvice? dietitianAdvice;

  DashboardData({
    required this.userName,
    required this.avatarUrl,
    required this.goal,
    required this.netKcal,
    required this.consumedKcal,
    required this.burnedKcal,
    required this.tempCelsius,
    required this.location,
    this.weatherMain,
    this.weatherDescription,
    required this.alertTitle,
    required this.alertMessage,
    required this.currentSteps,
    required this.stepGoal,
    required this.dailyCaloriesTarget,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.targetProteinG,
    required this.targetCarbsG,
    required this.targetFatG,
    required this.airQualityAqi,
    required this.workoutPreferredTime,
    required this.workoutDaysPerWeek,
    required this.mealsLoggedToday,
    required this.mealsLogged7Days,
    this.fromOfflineCache = false,
    this.networkInterfaceUp = true,
    this.macrosEstimated = false,
    this.weightKg,
    this.heightCm,
    this.waterTotalMl = 0,
    this.waterGoalMl = 2000,
    this.dietitianAdvice,
  });

  DietitianAdvice resolveDietitianAdvice() {
    final metricsNeedBody = weightKg != null &&
        heightCm != null &&
        weightKg! > 0 &&
        heightCm! > 0 &&
        (dietitianAdvice?.bodyMetrics == null ||
            dietitianAdvice!.bodyMetrics!.weightKg == null ||
            dietitianAdvice!.bodyMetrics!.heightCm == null ||
            dietitianAdvice!.bodyMetrics!.bmi == null);

    if (dietitianAdvice != null && !metricsNeedBody) {
      return dietitianAdvice!;
    }

    final metrics = DietitianBodyMetrics.fromDashboardContext(
      goal: goal,
      weightKg: weightKg,
      heightCm: heightCm,
      todaySteps: currentSteps,
      stepGoal: stepGoal,
      burnedKcal: burnedKcal,
      consumedKcal: consumedKcal,
      dailyCaloriesTarget: dailyCaloriesTarget,
    );

    if (dietitianAdvice != null) {
      return DietitianAdvice(
        headline: dietitianAdvice!.headline,
        summary: dietitianAdvice!.summary,
        recommendations: dietitianAdvice!.recommendations,
        nextMeal: dietitianAdvice!.nextMeal,
        hydrationTip: dietitianAdvice!.hydrationTip,
        portionTip: dietitianAdvice!.portionTip,
        bodyMetrics: metrics,
        source: dietitianAdvice!.source,
      );
    }

    return DietitianAdvice.fromDashboardContext(
      userName: userName,
      goal: goal,
      dailyCaloriesTarget: dailyCaloriesTarget,
      consumedKcal: consumedKcal,
      proteinG: proteinG,
      targetProteinG: targetProteinG,
      mealsLoggedToday: mealsLoggedToday ?? 0,
      mealsLogged7Days: mealsLogged7Days ?? 0,
      burnedKcal: burnedKcal,
      todaySteps: currentSteps,
      stepGoal: stepGoal,
      weightKg: weightKg,
      heightCm: heightCm,
      alertTitle: alertTitle,
      alertMessage: alertMessage,
    );
  }

  DashboardData copyWith({
    int? currentSteps,
    int? stepGoal,
    int? dailyCaloriesTarget,
    int? burnedKcal,
    int? netKcal,
    int? consumedKcal,
    int? proteinG,
    int? carbsG,
    int? fatG,
    bool? macrosEstimated,
    double? weightKg,
    double? heightCm,
    int? waterTotalMl,
    int? waterGoalMl,
    DietitianAdvice? dietitianAdvice,
    String? weatherMain,
    String? weatherDescription,
    String? alertTitle,
    String? alertMessage,
    double? tempCelsius,
    String? location,
    int? airQualityAqi,
    bool? fromOfflineCache,
    bool? networkInterfaceUp,
  }) {
    return DashboardData(
      userName: userName,
      avatarUrl: avatarUrl,
      goal: goal,
      netKcal: netKcal ?? this.netKcal,
      consumedKcal: consumedKcal ?? this.consumedKcal,
      burnedKcal: burnedKcal ?? this.burnedKcal,
      tempCelsius: tempCelsius ?? this.tempCelsius,
      location: location ?? this.location,
      weatherMain: weatherMain ?? this.weatherMain,
      weatherDescription: weatherDescription ?? this.weatherDescription,
      alertTitle: alertTitle ?? this.alertTitle,
      alertMessage: alertMessage ?? this.alertMessage,
      currentSteps: currentSteps ?? this.currentSteps,
      stepGoal: stepGoal ?? this.stepGoal,
      dailyCaloriesTarget: dailyCaloriesTarget ?? this.dailyCaloriesTarget,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
      targetProteinG: targetProteinG,
      targetCarbsG: targetCarbsG,
      targetFatG: targetFatG,
      airQualityAqi: airQualityAqi ?? this.airQualityAqi,
      workoutPreferredTime: workoutPreferredTime,
      workoutDaysPerWeek: workoutDaysPerWeek,
      mealsLoggedToday: mealsLoggedToday,
      mealsLogged7Days: mealsLogged7Days,
      fromOfflineCache: fromOfflineCache ?? this.fromOfflineCache,
      networkInterfaceUp: networkInterfaceUp ?? this.networkInterfaceUp,
      macrosEstimated: macrosEstimated ?? this.macrosEstimated,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      waterTotalMl: waterTotalMl ?? this.waterTotalMl,
      waterGoalMl: waterGoalMl ?? this.waterGoalMl,
      dietitianAdvice: dietitianAdvice ?? this.dietitianAdvice,
    );
  }

  factory DashboardData.fromJson(
    Map<String, dynamic> json, {
    bool fromOfflineCache = false,
  }) {
    final macros = _dashboardJsonMap(json['macros']);
    final macrosTarget = _dashboardJsonMap(json['macrosTarget']);
    final airQuality = _dashboardJsonMap(json['airQuality']);
    final workoutPlan = _dashboardJsonMap(json['workoutPlan']);
    final weather = _dashboardJsonMap(json['weather']);
    final dietRaw = json['dietitianAdvice'];
    DietitianAdvice? dietitianAdvice;
    if (dietRaw is Map) {
      dietitianAdvice = DietitianAdvice.fromJson(
        dietRaw.map((k, dynamic v) => MapEntry(k.toString(), v)),
      );
    }
    final hydration = _dashboardJsonMap(json['hydration']);

    return DashboardData(
      userName: (json['userName'] ?? '').toString(),
      avatarUrl: _normalizeAvatarUrl(
        (json['avatarUrl'] ?? 'https://i.pravatar.cc/150?img=5').toString(),
      ),
      goal: (json['goal'] as String?)?.toString(),
      netKcal: _dashboardJsonInt(json['netKcal']),
      consumedKcal: _dashboardJsonInt(json['consumedKcal']),
      burnedKcal: _dashboardJsonInt(json['burnedKcal']),
      tempCelsius: _dashboardJsonDouble(json['tempCelsius']),
      location: (json['location'] ?? '—').toString(),
      weatherMain: weather['main']?.toString(),
      weatherDescription: weather['description']?.toString(),
      alertTitle: (json['alertTitle'] as String?)?.toString(),
      alertMessage: (json['alertMessage'] as String?)?.toString(),
      currentSteps: _dashboardJsonInt(json['currentSteps']),
      stepGoal: _dashboardJsonInt(json['stepGoal']),
      dailyCaloriesTarget: _dashboardJsonInt(
        json['dailyCaloriesTarget'] ?? json['daily_calories_target'],
      ),
      proteinG: _dashboardJsonInt(
        macros['proteinG'] ?? macros['protein_g'],
      ),
      carbsG: _dashboardJsonInt(macros['carbsG'] ?? macros['carbs_g']),
      fatG: _dashboardJsonInt(macros['fatG'] ?? macros['fat_g']),
      targetProteinG: _dashboardJsonInt(
        macrosTarget['proteinG'] ?? macrosTarget['protein_g'],
      ),
      targetCarbsG: _dashboardJsonInt(
        macrosTarget['carbsG'] ?? macrosTarget['carbs_g'],
      ),
      targetFatG: _dashboardJsonInt(
        macrosTarget['fatG'] ?? macrosTarget['fat_g'],
      ),
      airQualityAqi: _dashboardJsonIntNullable(airQuality['aqi']),
      workoutPreferredTime:
          (workoutPlan['preferredTime'] as String?)?.toString(),
      workoutDaysPerWeek: _dashboardJsonIntNullable(workoutPlan['daysPerWeek']),
      mealsLoggedToday: _dashboardJsonIntNullable(json['mealsLoggedToday']),
      mealsLogged7Days: _dashboardJsonIntNullable(json['mealsLogged7Days']),
      fromOfflineCache: fromOfflineCache,
      networkInterfaceUp: !fromOfflineCache,
      macrosEstimated: _dashboardJsonBool(
        json['macrosEstimated'] ?? json['macros_estimated'],
      ),
      weightKg: _dashboardJsonDoubleOrNull(json['weightKg']),
      heightCm: _dashboardJsonDoubleOrNull(json['heightCm']),
      waterTotalMl: _dashboardJsonInt(hydration['totalMl']),
      waterGoalMl: _dashboardJsonInt(hydration['goalMl']).clamp(1500, 5000),
      dietitianAdvice: dietitianAdvice,
    );
  }

  /// Offline-first meals stay in SQLite until sync; the API may omit pending
  /// calories/macros. Merge pending rows so the ring and macro row match History.
  DashboardData mergePendingLocalNutrition({
    int pendingKcal = 0,
    int pendingProteinG = 0,
    int pendingCarbsG = 0,
    int pendingFatG = 0,
  }) {
    if (pendingKcal <= 0 &&
        pendingProteinG <= 0 &&
        pendingCarbsG <= 0 &&
        pendingFatG <= 0) {
      return this;
    }
    final consumed =
        pendingKcal > 0 ? consumedKcal + pendingKcal : consumedKcal;
    final net = consumed - burnedKcal;
    return copyWith(
      netKcal: net,
      consumedKcal: consumed,
      proteinG: proteinG + pendingProteinG,
      carbsG: carbsG + pendingCarbsG,
      fatG: fatG + pendingFatG,
      macrosEstimated: macrosEstimated &&
          pendingProteinG <= 0 &&
          pendingCarbsG <= 0 &&
          pendingFatG <= 0,
    );
  }
}

/// Align dashboard macros so 4P+4C+9F matches [consumedKcal] (backend parity).
DashboardData _normalizeDashboardMacrosToConsumedCalories(DashboardData data) {
  if (data.consumedKcal <= 0) return data;

  final p = data.proteinG;
  final c = data.carbsG;
  final f = data.fatG;
  final macroKcal = p * 4 + c * 4 + f * 9;

  if (macroKcal <= 0) {
    return _estimateMacrosWhenNoGrams(data);
  }

  if (macroKcal >= data.consumedKcal) {
    return data;
  }

  final aligned =
      _alignMacroGramsToKcal(data.consumedKcal, p, c, f);
  return data.copyWith(
    proteinG: aligned.p,
    carbsG: aligned.c,
    fatG: aligned.f,
    macrosEstimated: true,
  );
}

({int p, int c, int f}) _alignMacroGramsToKcal(
  int targetKcal,
  int p,
  int c,
  int f,
) {
  if (targetKcal <= 0) {
    return (p: 0, c: 0, f: 0);
  }
  final mkcal = p * 4 + c * 4 + f * 9;
  if (mkcal <= 0) {
    return (p: 0, c: 0, f: 0);
  }

  final scale = targetKcal / mkcal;
  final baseP = max(0, (p * scale).round());
  final baseC = max(0, (c * scale).round());
  final baseF = max(0, (f * scale).round());

  var bestP = baseP;
  var bestC = baseC;
  var bestF = baseF;
  var bestDist =
      (targetKcal - (bestP * 4 + bestC * 4 + bestF * 9)).abs();

  for (var dp = -12; dp <= 12; dp++) {
    for (var dc = -12; dc <= 12; dc++) {
      final tp = max(0, baseP + dp);
      final tc = max(0, baseC + dc);
      final afterPc = tp * 4 + tc * 4;
      if (afterPc > targetKcal) continue;
      final rem = targetKcal - afterPc;
      final tfApprox = (rem / 9).round();
      for (final tf in [tfApprox - 1, tfApprox, tfApprox + 1]) {
        if (tf < 0) continue;
        final got = afterPc + tf * 9;
        final dist = (targetKcal - got).abs();
        if (dist < bestDist) {
          bestDist = dist;
          bestP = tp;
          bestC = tc;
          bestF = tf;
        }
        if (bestDist == 0) {
          return (p: bestP, c: bestC, f: bestF);
        }
      }
    }
  }

  return (p: bestP, c: bestC, f: bestF);
}

DashboardData _estimateMacrosWhenNoGrams(DashboardData data) {
  if (data.consumedKcal <= 0) return data;

  final daily = data.dailyCaloriesTarget;
  final tp = data.targetProteinG;
  final tc = data.targetCarbsG;
  final tf = data.targetFatG;

  late final int p;
  late final int c;
  late final int f;
  if (daily > 0 && tp + tc + tf > 0) {
    final r = data.consumedKcal / daily;
    p = (tp * r).round().clamp(0, 800);
    c = (tc * r).round().clamp(0, 1200);
    f = (tf * r).round().clamp(0, 400);
  } else {
    p = (data.consumedKcal * 0.25 / 4).round().clamp(0, 800);
    c = (data.consumedKcal * 0.50 / 4).round().clamp(0, 1200);
    f = (data.consumedKcal * 0.25 / 9).round().clamp(0, 400);
  }

  return data.copyWith(
    proteinG: p,
    carbsG: c,
    fatG: f,
    macrosEstimated: true,
  );
}

/// Meals, steps, and last API snapshot from SQLite — no network.
Future<DashboardData> _loadDashboardFromDevice(
  Ref ref,
  SqliteOfflineDb db,
) async {
  final cached = await db.getDashboardCache();
  if (cached != null) {
    final base = DashboardData.fromJson(cached, fromOfflineCache: true);
    final merged = await _mergePendingNutritionIntoDashboard(base, db);
    return _applyLocalStepGoalToDashboard(
      ref,
      _normalizeDashboardMacrosToConsumedCalories(merged),
    );
  }

  final pure = await _pureOfflineDashboardFromSqlite(ref, db);
  if (pure != null) {
    return _applyLocalStepGoalToDashboard(
      ref,
      _normalizeDashboardMacrosToConsumedCalories(pure),
    );
  }

  throw Exception(
    'No internet connection and no local activity yet.',
  );
}

Future<DashboardData> _mergePendingNutritionIntoDashboard(
  DashboardData base,
  SqliteOfflineDb db,
) async {
  final pendingKcal =
      await db.sumPendingSyncCaloriesForLocalDay(DateTime.now());
  final pendingMacros =
      await db.sumPendingSyncMacrosForLocalDay(DateTime.now());
  final localDayTotals =
      await db.sumMealCacheMacrosAllForLocalCalendarDay(DateTime.now());

  final merged = base.mergePendingLocalNutrition(
    pendingKcal: pendingKcal,
    pendingProteinG: pendingMacros.proteinG,
    pendingCarbsG: pendingMacros.carbsG,
    pendingFatG: pendingMacros.fatG,
  );

  // Prefer SQLite day sums when they actually carry macro breakdown; if local rows
  // exist but grams were never stored (null), sums are 0 and would wipe good API totals.
  if (localDayTotals.mealCount <= 0) return merged;

  final localMacroSum =
      localDayTotals.proteinG + localDayTotals.carbsG + localDayTotals.fatG;
  final mergedMacroSum =
      merged.proteinG + merged.carbsG + merged.fatG;
  final useLocalMacroTotals =
      localMacroSum >= mergedMacroSum && localMacroSum > 0;

  if (!useLocalMacroTotals) return merged;

  return merged.copyWith(
    proteinG: localDayTotals.proteinG,
    carbsG: localDayTotals.carbsG,
    fatG: localDayTotals.fatG,
    macrosEstimated: false,
  );
}

Future<DashboardData> _applyLocalStepGoalToDashboard(
  Ref ref,
  DashboardData base,
) async {
  try {
    final repo = ref.read(profileRepositoryProvider);
    final local = await repo.readLocalProfile();
    final v = local?['step_goal'];
    final localGoal = (v is int) ? v : int.tryParse((v ?? '').toString());

    final weightRaw = local?['weight'];
    final heightRaw = local?['height'];
    final localWeight = weightRaw is num
        ? weightRaw.toDouble()
        : double.tryParse('$weightRaw');
    final localHeight = heightRaw is num
        ? heightRaw.toDouble()
        : double.tryParse('$heightRaw');

    final nextWeight = (base.weightKg == null || base.weightKg! <= 0) &&
            localWeight != null &&
            localWeight > 0
        ? localWeight
        : base.weightKg;
    final nextHeight = (base.heightCm == null || base.heightCm! <= 0) &&
            localHeight != null &&
            localHeight > 0
        ? localHeight
        : base.heightCm;

    final nextGoal =
        (localGoal != null && localGoal > 0) ? localGoal : base.stepGoal;

    if (nextGoal == base.stepGoal &&
        nextWeight == base.weightKg &&
        nextHeight == base.heightCm) {
      return base;
    }

    return base.copyWith(
      stepGoal: nextGoal,
      weightKg: nextWeight,
      heightCm: nextHeight,
    );
  } catch (_) {
    // ignore
  }
  return base;
}

/// Last resort when there is no API dashboard snapshot yet (fresh offline session).
Future<DashboardData?> _pureOfflineDashboardFromSqlite(
  Ref ref,
  SqliteOfflineDb db,
) async {
  final n = DateTime.now();
  final dayLocal = DateTime(n.year, n.month, n.day);
  final todayStr =
      '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';

  final profile = await db.getProfileCache();
  final macrosToday = await db.sumMealCacheMacrosAllForLocalCalendarDay(dayLocal);
  final todaySteps = await db.getStepsLocalForDate(todayStr);

  final hasSignal = profile != null ||
      macrosToday.mealCount > 0 ||
      (todaySteps != null && todaySteps > 0);
  if (!hasSignal) return null;

  final consumed =
      await db.sumMealCacheCaloriesAllForLocalCalendarDay(dayLocal);
  final steps = todaySteps ?? 0;
  final burned = (steps * 0.04).round();
  final net = consumed - burned;

  final gender = (profile?['gender'] ?? '').toString().toLowerCase();
  final avatarRaw =
      (profile?['avatar_url'] ?? profile?['avatarUrl'] ?? '').toString().trim();
  final avatarUrl = avatarRaw.isNotEmpty
      ? AppConfig.normalizeUrlForDevice(avatarRaw)
      : (gender == 'female'
          ? 'https://i.pravatar.cc/150?img=47'
          : gender == 'male'
              ? 'https://i.pravatar.cc/150?img=12'
              : 'https://i.pravatar.cc/150?img=5');

  int stepGoal() {
    final v = profile?['step_goal'];
    final i = v is int ? v : int.tryParse((v ?? '').toString());
    return (i != null && i > 0) ? i : 10000;
  }

  int dailyCalTarget() {
    final v =
        profile?['daily_calories_target'] ?? profile?['dailyCaloriesTarget'];
    final i = v is int ? v : int.tryParse((v ?? '').toString());
    return (i != null && i > 0) ? i : 0;
  }

  final wdRaw = profile?['workout_days_per_week'];
  final wd =
      wdRaw is int ? wdRaw : int.tryParse((wdRaw ?? '').toString());

  final weightRaw = profile?['weight'];
  final heightRaw = profile?['height'];
  final weightKg = weightRaw is num
      ? weightRaw.toDouble()
      : double.tryParse('$weightRaw');
  final heightCm = heightRaw is num
      ? heightRaw.toDouble()
      : double.tryParse('$heightRaw');

  return DashboardData(
    userName: (profile?['name'] ?? 'Member').toString(),
    avatarUrl: avatarUrl,
    goal: profile?['goal']?.toString(),
    netKcal: net,
    consumedKcal: consumed,
    burnedKcal: burned,
    tempCelsius: 0,
    location: 'Offline — connect for weather',
    weatherMain: null,
    weatherDescription: null,
    alertTitle: 'Offline mode',
    alertMessage:
        'Showing meals and steps saved on this device. Live weather and cloud totals refresh when online.',
    currentSteps: steps,
    stepGoal: stepGoal(),
    dailyCaloriesTarget: dailyCalTarget(),
    proteinG: macrosToday.proteinG,
    carbsG: macrosToday.carbsG,
    fatG: macrosToday.fatG,
    targetProteinG: 0,
    targetCarbsG: 0,
    targetFatG: 0,
    airQualityAqi: null,
    workoutPreferredTime:
        profile?['workout_time_preference']?.toString(),
    workoutDaysPerWeek: wd,
    mealsLoggedToday: macrosToday.mealCount,
    mealsLogged7Days: null,
    fromOfflineCache: true,
    networkInterfaceUp: false,
    macrosEstimated: false,
    weightKg: (weightKg != null && weightKg > 0) ? weightKg : null,
    heightCm: (heightCm != null && heightCm > 0) ? heightCm : null,
  );
}

String _normalizeAvatarUrl(String url) {
  return AppConfig.normalizeUrlForDevice(url);
}


/// Dio / JSON decoding may yield `Map<dynamic, dynamic>`; strict `Map<String, dynamic>` checks drop macros.
Map<String, dynamic> _dashboardJsonMap(dynamic value) {
  if (value == null) return {};
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, dynamic v) => MapEntry(key.toString(), v));
  }
  return {};
}

int _dashboardJsonInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is num) return value.toInt();
  if (value is String) {
    return int.tryParse(value) ?? double.tryParse(value)?.round() ?? 0;
  }
  return 0;
}

int? _dashboardJsonIntNullable(dynamic value) {
  if (value == null) return null;
  return _dashboardJsonInt(value);
}

double _dashboardJsonDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

double? _dashboardJsonDoubleOrNull(dynamic value) {
  if (value == null) return null;
  final parsed = _dashboardJsonDouble(value);
  return parsed > 0 ? parsed : null;
}

bool _dashboardJsonBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final s = value.toString().trim().toLowerCase();
  return s == 'true' || s == '1' || s == 'yes';
}

/// Matches Laravel dashboard filtering to this device's calendar "today".
Map<String, String> _dashboardLocalDayQueryParams() {
  final n = DateTime.now();
  final dayLocal = DateTime(n.year, n.month, n.day);
  final nextLocal = dayLocal.add(const Duration(days: 1));
  final localDate =
      '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  return {
    'local_date': localDate,
    'meals_from': dayLocal.toUtc().toIso8601String(),
    'meals_to': nextLocal.toUtc().toIso8601String(),
  };
}

Future<Map<String, String>> _dashboardApiQueryParams(Ref ref) async {
  final params = _dashboardLocalDayQueryParams();
  try {
    // Cached GPS weather only — Accra is never invented as a default here.
    final db = await SqliteOfflineDb.getInstance();
    final cached = await db.getWeatherCache();
    if (cached != null) {
      final lat = (cached['latitude'] as num?)?.toDouble();
      final lon = (cached['longitude'] as num?)?.toDouble();
      final main = cached['weatherMain']?.toString().trim();
      if (lat != null && lon != null && main != null && main.isNotEmpty) {
        return {
          ...params,
          'lat': lat.toStringAsFixed(5),
          'lon': lon.toStringAsFixed(5),
        };
      }
    }
    return params;
  } catch (_) {
    return params;
  }
}

// In production, this will use Dio to fetch from Laravel `GET /api/dashboard`.
final dashboardDataProvider = FutureProvider<DashboardData>((ref) async {
  ref.watch(nutritionDashboardRefreshProvider);
  const storage = FlutterSecureStorage();
  final token = await readSanctumToken(storage: storage);
  if (token == null) {
    throw Exception('Missing auth token. Please login again.');
  }

  final db = await SqliteOfflineDb.getInstance();

  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 25),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        ...AppConfig.apiHeaders,
      },
    ),
  );

  // Always attempt the API. connectivity_plus can lag or mis-report cellular
  // (e.g. Samsung 4G as "other") while the status bar shows data.
  final online = await isDeviceOnline();

  try {
    final response = await dio.get(
      '/dashboard',
      queryParameters: await _dashboardApiQueryParams(ref),
    );
    final raw = response.data;
    if (raw is! Map) {
      throw Exception('Unexpected dashboard response.');
    }
    final json = raw.map((key, dynamic v) => MapEntry(key.toString(), v));
    await db.putDashboardCache(json);
    final base = DashboardData.fromJson(json);
    final merged = await _mergePendingNutritionIntoDashboard(base, db);
    return _applyLocalStepGoalToDashboard(
      ref,
      _normalizeDashboardMacrosToConsumedCalories(merged),
    );
  } on DioException catch (e) {
    debugPrint(
      'Dashboard refresh failed: ${e.type} '
      'status=${e.response?.statusCode} '
      'message=${e.message}',
    );
    final cached = await _loadDashboardFromDevice(ref, db);
    return cached.copyWith(
      fromOfflineCache: true,
      networkInterfaceUp: online,
    );
  } catch (e) {
    debugPrint('Dashboard refresh failed: $e');
    final cached = await _loadDashboardFromDevice(ref, db);
    return cached.copyWith(
      fromOfflineCache: true,
      networkInterfaceUp: online,
    );
  }
});

int _effectiveDashboardStepGoal(DashboardData data, int? localGoal) {
  if (localGoal != null && localGoal > 0) return localGoal;
  return data.stepGoal;
}

int _effectiveDashboardDailyCalories(DashboardData data, int? localKcal) {
  if (localKcal != null && localKcal > 0) return localKcal;
  return data.dailyCaloriesTarget;
}

/// Prefer cached profile goals over dashboard JSON so notifications stay in sync with Settings.
void _syncForegroundAndScheduledReminders(WidgetRef ref, DashboardData data) {
  final stepGoal = _effectiveDashboardStepGoal(
    data,
    ref.read(stepGoalProvider).valueOrNull,
  );
  final kcal = _effectiveDashboardDailyCalories(
    data,
    ref.read(dailyCaloriesGoalProvider).valueOrNull,
  );
  unawaited(
    ForegroundNotificationPrefs.syncActivityGoalsFromDashboard(
      stepGoal: stepGoal,
      dailyCaloriesTarget: kcal,
      caloriesConsumed: data.consumedKcal,
      mealsLoggedToday: data.mealsLoggedToday ?? 0,
    ),
  );
  unawaited(
    StepGoalAchievementNotifier.evaluate(
      steps: data.currentSteps,
      calorieConsumed: data.consumedKcal,
      calorieTarget: kcal,
      mealsLoggedToday: data.mealsLoggedToday ?? 0,
    ),
  );
  unawaited(
    ref.read(localNotificationServiceProvider).scheduleDailyGoalReminder(
          stepGoal: stepGoal,
          calorieTarget: kcal,
        ),
  );
}

// =====================================================================
// 2. THE UI SCREEN
// =====================================================================

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, this.showBottomNav = true});

  final bool showBottomNav;

  // Ghana editorial + clinical clean
  static const Color primary = Color(0xFF1A5D1A);
  static const Color bgSoft = Color(0xFFF8FAFC);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);
  static const Color rule = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<DashboardData>>(dashboardDataProvider, (previous, next) {
      next.whenData((data) => _syncForegroundAndScheduledReminders(ref, data));
    });
    ref.listen<AsyncValue<int?>>(stepGoalProvider, (previous, next) {
      if (!next.hasValue) return;
      final dash = ref.read(dashboardDataProvider).valueOrNull;
      if (dash != null) _syncForegroundAndScheduledReminders(ref, dash);
    });
    ref.listen<AsyncValue<int?>>(dailyCaloriesGoalProvider, (previous, next) {
      if (!next.hasValue) return;
      final dash = ref.read(dashboardDataProvider).valueOrNull;
      if (dash != null) _syncForegroundAndScheduledReminders(ref, dash);
    });

    final tokenReady = ref.watch(sanctumTokenReadyProvider);

    if (tokenReady.isLoading) {
      return Scaffold(
        backgroundColor: bgSoft,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: primary),
              const SizedBox(height: 16),
              Text(
                'Opening your dashboard…',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (tokenReady.hasError || tokenReady.value != true) {
      return const AuthScreen();
    }

    final dashboardState = ref.watch(dashboardDataProvider);
    final stepsTodayAsync = ref.watch(stepsTodayProvider);
    final stepGoalAsync = ref.watch(stepGoalProvider);
    final dailyKcalAsync = ref.watch(dailyCaloriesGoalProvider);
    final localStepGoal = stepGoalAsync.valueOrNull;
    final localDailyKcal = dailyKcalAsync.valueOrNull;

    if (dashboardState.hasError &&
        dashboardState.error.toString().contains('Missing auth token')) {
      return Scaffold(
        backgroundColor: bgSoft,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: primary),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => ref.invalidate(dashboardDataProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgSoft,
      body: _buildDashboardBody(
        context,
        ref,
        dashboardState,
        stepsTodayAsync,
        localStepGoal,
        localDailyKcal,
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: const ScanMealFab(),

      bottomNavigationBar: showBottomNav
          ? AppBottomNav(
              activeTab: AppTab.home,
              onTabSelected: (tab) => _handleTab(context, tab),
            )
          : null,
    );
  }

  Widget _buildDashboardBody(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<DashboardData> dashboardState,
    AsyncValue<int> stepsTodayAsync,
    int? localStepGoal,
    int? localDailyKcal,
  ) {
    if (dashboardState.hasError && !dashboardState.hasValue) {
      return NetworkErrorView(
        title: 'Dashboard unavailable',
        message: userFriendlyDataLoadMessage(dashboardState.error!),
        onRetry: () => ref.invalidate(dashboardDataProvider),
      );
    }

    if (dashboardState.isLoading && !dashboardState.hasValue) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: primary),
            const SizedBox(height: 16),
            Text(
              'Loading your dashboard…',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    final data = dashboardState.requireValue;
    final deviceWeather = ref.watch(deviceWeatherProvider).valueOrNull;
    final liveSteps = stepsTodayAsync.valueOrNull;
    final merged = applyDeviceWeatherToDashboard(
      data.copyWith(
        // Live pedometer is source of truth when available (server can hold a stale inflate).
        currentSteps: liveSteps ?? data.currentSteps,
        stepGoal: _effectiveDashboardStepGoal(data, localStepGoal),
        dailyCaloriesTarget:
            _effectiveDashboardDailyCalories(data, localDailyKcal),
      ),
      deviceWeather,
    );

    if (liveSteps != null && liveSteps > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        BackgroundStepTrackingBootstrap.promptBatteryIfNeeded(context);
      });
    }

    return Stack(
      children: [
        _buildContent(context, merged, ref),
        if (dashboardState.isLoading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              color: primary,
              minHeight: 3,
            ),
          ),
      ],
    );
  }

  void _handleTab(BuildContext context, AppTab tab) {
    MainTabShell.open(context, tab: tab);
  }

  Widget _buildContent(BuildContext context, DashboardData data, WidgetRef ref) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: primary,
        onRefresh: () async {
          ref.invalidate(dashboardDataProvider);
          await ref.read(dashboardDataProvider.future);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (data.fromOfflineCache) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2F6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: rule),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        data.networkInterfaceUp
                            ? Icons.cloud_sync_outlined
                            : Icons.cloud_off_outlined,
                        size: 18,
                        color: muted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          data.networkInterfaceUp
                              ? "Couldn't refresh — showing last synced dashboard"
                              : 'Offline — showing last synced dashboard',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: slate900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],
              _buildHeader(context, ref, data.userName, data.avatarUrl),
              const SizedBox(height: 22),
              _buildCalorieCard(data),
              const SizedBox(height: 14),
              _buildWeatherStepsCard(data),
              const SizedBox(height: 14),
              WaterTrackerCard(
                initialTotalMl: data.waterTotalMl,
                initialGoalMl: data.waterGoalMl,
              ),
              const SizedBox(height: 14),
              _buildSafetyHubCard(context, data),
            ],
          ),
        ),
      ),
    );
  }

  /// Soft journal panel — warmth without shadow/glow chrome.
  Widget _panel({
    required Widget child,
    Color fill = Colors.white,
    Color? borderColor,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? rule),
      ),
      child: child,
    );
  }

  // --- Components ---

  String _timeOfDayGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _todayDateLine() {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final n = DateTime.now();
    return '${months[n.month - 1]} ${n.day}';
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    String name,
    String avatarUrl,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: primary.withValues(alpha: 0.28),
              width: 2,
            ),
            image: DecorationImage(
              image: NetworkImage(avatarUrl),
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_timeOfDayGreeting()},',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: muted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: slate900,
                  letterSpacing: -0.5,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _todayDateLine(),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: muted,
                ),
              ),
            ],
          ),
        ),
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => showNotificationsModal(context, ref),
            child: Ink(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: rule),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.notifications_none, color: muted, size: 22),
                  Consumer(
                    builder: (context, ref, _) {
                      final unread = ref.watch(notificationUnreadCountProvider);
                      final count = unread.maybeWhen(
                        data: (c) => c,
                        orElse: () => 0,
                      );
                      if (count <= 0) return const SizedBox.shrink();
                      return Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          constraints: const BoxConstraints(minWidth: 14),
                          decoration: const BoxDecoration(
                            color: Color(0xFFB91C1C),
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                          child: Text(
                            count > 9 ? '9+' : '$count',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalorieCard(DashboardData data) {
    final net = data.netKcal;
    final netFigure = net == 0 ? '0' : (net > 0 ? '+$net' : '$net');
    final consumedTowardGoal = data.dailyCaloriesTarget > 0
        ? (data.consumedKcal / data.dailyCaloriesTarget).clamp(0.0, 1.0)
        : 0.0;
    final macrosLogged = data.proteinG + data.carbsG + data.fatG;

    return _panel(
      fill: const Color(0xFFF1F7F1),
      borderColor: primary.withValues(alpha: 0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Calories today',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: primary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                netFigure,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 46,
                  fontWeight: FontWeight.w800,
                  color: slate900,
                  height: 1,
                  letterSpacing: -1.4,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'kcal net',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: primary,
                ),
              ),
            ],
          ),
          if (data.dailyCaloriesTarget > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Goal ${data.dailyCaloriesTarget} kcal',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: muted,
              ),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: consumedTowardGoal,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.85),
                color: primary,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildMacroStat('Eaten', '${data.consumedKcal}', 'kcal'),
                ),
                Container(width: 1, height: 34, color: rule),
                Expanded(
                  child: _buildMacroStat('Burned', '${data.burnedKcal}', 'kcal'),
                ),
              ],
            ),
          ),
          if (data.consumedKcal > 0 || macrosLogged > 0) ...[
            const SizedBox(height: 16),
            Text(
              'Logged food',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: muted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${data.consumedKcal} kcal · macros',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: muted,
              ),
            ),
            const SizedBox(height: 12),
            _macroBreakdownRow(data),
          ],
        ],
      ),
    );
  }

  String _macroBreakdownTooltipHint({
    required int gramsLogged,
    required int target,
    required String nutrientName,
  }) {
    final base =
        '$nutrientName from everything you logged today: ${gramsLogged}g total.';
    if (target <= 0) return base;
    return '$base Your profile target is ${target}g/day (for comparison).';
  }

  Widget _macroBreakdownRow(DashboardData data) {
    return Row(
      children: [
        Expanded(
          child: _macroCompactCell(
            label: 'Protein',
            grams: data.proteinG,
            hint: _macroBreakdownTooltipHint(
              gramsLogged: data.proteinG,
              target: data.targetProteinG,
              nutrientName: 'Protein',
            ),
          ),
        ),
        Expanded(
          child: _macroCompactCell(
            label: 'Carbs',
            grams: data.carbsG,
            hint: _macroBreakdownTooltipHint(
              gramsLogged: data.carbsG,
              target: data.targetCarbsG,
              nutrientName: 'Carbs',
            ),
          ),
        ),
        Expanded(
          child: _macroCompactCell(
            label: 'Fat',
            grams: data.fatG,
            hint: _macroBreakdownTooltipHint(
              gramsLogged: data.fatG,
              target: data.targetFatG,
              nutrientName: 'Fat',
            ),
          ),
        ),
      ],
    );
  }

  Widget _macroCompactCell({
    required String label,
    required int grams,
    required String hint,
  }) {
    return Tooltip(
      message: hint,
      triggerMode: TooltipTriggerMode.longPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${grams}g',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: slate900,
              height: 1,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroStat(
    String label,
    String valueDigits,
    String unit,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: muted,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                valueDigits,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: slate900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherStepsCard(DashboardData data) {
    final bool isHighHeat = data.tempCelsius >= 32.0;
    final bool isPoorAir = AirQualityThresholds.isPoorUsAqi(data.airQualityAqi);
    final bool isRainy =
        StrideWeatherGuidance.discouragesOutdoorWalk(data.weatherMain);
    final stepGoal = data.stepGoal <= 0 ? 1 : data.stepGoal;
    final stepsPct = data.currentSteps / stepGoal;

    String? weatherNote;
    if (isHighHeat) {
      weatherNote = 'High heat — take shade breaks and pace activity.';
    } else if (isRainy) {
      weatherNote = StrideWeatherGuidance.isStorm(data.weatherMain)
          ? 'Stormy — stay indoors; home steps still count.'
          : 'Rainy — walk indoors or use stairs.';
    } else if (isPoorAir) {
      weatherNote = 'Poor air — prefer shorter outdoor walks.';
    }

    return _panel(
      fill: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.wb_sunny_outlined,
                          size: 16,
                          color: const Color(0xFFB45309),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Weather',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${data.tempCelsius.toInt()}°C',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: slate900,
                        height: 1,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data.location,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 78,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                color: rule,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.directions_walk_rounded,
                          size: 16,
                          color: primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Steps',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _formatStepsCompact(data.currentSteps, decimals: true),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: slate900,
                        height: 1,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'of ${_formatStepsCompact(data.stepGoal, decimals: false)}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: muted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: stepsPct.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: const Color(0xFFEEF2F0),
                        color: primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (weatherNote != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAF8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                weatherNote,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: muted,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatStepsCompact(int steps, {required bool decimals}) {
    if (steps < 1000) return steps.toString();
    final v = steps / 1000.0;
    if (steps < 10000) return '${v.toStringAsFixed(decimals ? 1 : 0)}k';
    return '${v.toStringAsFixed(0)}k';
  }

  Widget _buildSafetyHubCard(BuildContext context, DashboardData data) {
    final alert = (data.alertTitle ?? '').trim();
    final alertMsg = (data.alertMessage ?? '').trim();
    final hasAlert = alert.isNotEmpty &&
        alertMsg.isNotEmpty &&
        !alert.toLowerCase().contains('no alert');
    final preview = hasAlert
        ? alertMsg
        : 'Weather, air quality, and health tips for where you are.';
    final headline = hasAlert ? alert : 'Stay safe outdoors today';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const HealthSafetyHubScreen(),
            ),
          );
        },
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFFF3F6F8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 14, 16),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 4,
                    decoration: const BoxDecoration(
                      color: Color(0xFF334155),
                      borderRadius: BorderRadius.horizontal(
                        right: Radius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Safety Hub',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: slate900,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: muted.withValues(alpha: 0.9),
                              size: 22,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          headline,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF334155),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: muted,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            data.location.trim().isEmpty
                                ? 'Open for tips & environment guidance'
                                : '${data.tempCelsius.round()}° · ${data.location}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: slate900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
