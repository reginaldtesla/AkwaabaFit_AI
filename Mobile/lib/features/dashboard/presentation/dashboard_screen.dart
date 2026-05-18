import 'dart:async';
import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/shared/connectivity/connectivity_utils.dart';
import 'package:mobile/features/ai_scanner/presentation/ai_scanner_screen.dart';
import 'package:mobile/features/auth/presentation/auth_screen.dart';
import 'package:mobile/features/fitness/presentation/activity_tracking_screen.dart';
import 'package:mobile/features/fitness/data/steps_today_provider.dart';
import 'package:mobile/features/nutrition/presentation/nutrition_history_screen.dart';
import 'package:mobile/features/profile/presentation/profile_settings_screen.dart';
import 'package:mobile/features/telehealth/presentation/tele_dietetics_screen.dart';
import 'package:mobile/shared/fitness/foreground_notification_prefs.dart';
import 'package:mobile/shared/notifications/local_notification_service.dart';
import 'package:mobile/shared/notifications/notification_inbox_provider.dart';
import 'package:mobile/shared/notifications/notifications_modal.dart';
import 'package:mobile/shared/profile/profile_repository.dart';
import 'package:mobile/shared/navigation/app_bottom_nav.dart';
import 'package:mobile/shared/config/app_config.dart';
import 'package:mobile/shared/offline/sqlite_offline_db.dart';
import 'package:mobile/shared/ui/network_error_view.dart';
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
  /// Grams inferred from calorie-goal macro split when logged meals had no P/C/F data.
  final bool macrosEstimated;

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
    this.macrosEstimated = false,
  });

  DashboardData copyWith({
    int? currentSteps,
    int? stepGoal,
    int? dailyCaloriesTarget,
  }) {
    return DashboardData(
      userName: userName,
      avatarUrl: avatarUrl,
      goal: goal,
      netKcal: netKcal,
      consumedKcal: consumedKcal,
      burnedKcal: burnedKcal,
      tempCelsius: tempCelsius,
      location: location,
      weatherMain: weatherMain,
      weatherDescription: weatherDescription,
      alertTitle: alertTitle,
      alertMessage: alertMessage,
      currentSteps: currentSteps ?? this.currentSteps,
      stepGoal: stepGoal ?? this.stepGoal,
      dailyCaloriesTarget: dailyCaloriesTarget ?? this.dailyCaloriesTarget,
      proteinG: proteinG,
      carbsG: carbsG,
      fatG: fatG,
      targetProteinG: targetProteinG,
      targetCarbsG: targetCarbsG,
      targetFatG: targetFatG,
      airQualityAqi: airQualityAqi,
      workoutPreferredTime: workoutPreferredTime,
      workoutDaysPerWeek: workoutDaysPerWeek,
      mealsLoggedToday: mealsLoggedToday,
      mealsLogged7Days: mealsLogged7Days,
      fromOfflineCache: fromOfflineCache,
      macrosEstimated: macrosEstimated,
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
      macrosEstimated: _dashboardJsonBool(
        json['macrosEstimated'] ?? json['macros_estimated'],
      ),
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
    return DashboardData(
      userName: userName,
      avatarUrl: avatarUrl,
      goal: goal,
      netKcal: net,
      consumedKcal: consumed,
      burnedKcal: burnedKcal,
      tempCelsius: tempCelsius,
      location: location,
      weatherMain: weatherMain,
      weatherDescription: weatherDescription,
      alertTitle: alertTitle,
      alertMessage: alertMessage,
      currentSteps: currentSteps,
      stepGoal: stepGoal,
      dailyCaloriesTarget: dailyCaloriesTarget,
      proteinG: proteinG + pendingProteinG,
      carbsG: carbsG + pendingCarbsG,
      fatG: fatG + pendingFatG,
      targetProteinG: targetProteinG,
      targetCarbsG: targetCarbsG,
      targetFatG: targetFatG,
      airQualityAqi: airQualityAqi,
      workoutPreferredTime: workoutPreferredTime,
      workoutDaysPerWeek: workoutDaysPerWeek,
      mealsLoggedToday: mealsLoggedToday,
      mealsLogged7Days: mealsLogged7Days,
      fromOfflineCache: fromOfflineCache,
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
  return DashboardData(
    userName: data.userName,
    avatarUrl: data.avatarUrl,
    goal: data.goal,
    netKcal: data.netKcal,
    consumedKcal: data.consumedKcal,
    burnedKcal: data.burnedKcal,
    tempCelsius: data.tempCelsius,
    location: data.location,
    weatherMain: data.weatherMain,
    weatherDescription: data.weatherDescription,
    alertTitle: data.alertTitle,
    alertMessage: data.alertMessage,
    currentSteps: data.currentSteps,
    stepGoal: data.stepGoal,
    dailyCaloriesTarget: data.dailyCaloriesTarget,
    proteinG: aligned.p,
    carbsG: aligned.c,
    fatG: aligned.f,
    targetProteinG: data.targetProteinG,
    targetCarbsG: data.targetCarbsG,
    targetFatG: data.targetFatG,
    airQualityAqi: data.airQualityAqi,
    workoutPreferredTime: data.workoutPreferredTime,
    workoutDaysPerWeek: data.workoutDaysPerWeek,
    mealsLoggedToday: data.mealsLoggedToday,
    mealsLogged7Days: data.mealsLogged7Days,
    fromOfflineCache: data.fromOfflineCache,
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

  return DashboardData(
    userName: data.userName,
    avatarUrl: data.avatarUrl,
    goal: data.goal,
    netKcal: data.netKcal,
    consumedKcal: data.consumedKcal,
    burnedKcal: data.burnedKcal,
    tempCelsius: data.tempCelsius,
    location: data.location,
    weatherMain: data.weatherMain,
    weatherDescription: data.weatherDescription,
    alertTitle: data.alertTitle,
    alertMessage: data.alertMessage,
    currentSteps: data.currentSteps,
    stepGoal: data.stepGoal,
    dailyCaloriesTarget: data.dailyCaloriesTarget,
    proteinG: p,
    carbsG: c,
    fatG: f,
    targetProteinG: data.targetProteinG,
    targetCarbsG: data.targetCarbsG,
    targetFatG: data.targetFatG,
    airQualityAqi: data.airQualityAqi,
    workoutPreferredTime: data.workoutPreferredTime,
    workoutDaysPerWeek: data.workoutDaysPerWeek,
    mealsLoggedToday: data.mealsLoggedToday,
    mealsLogged7Days: data.mealsLogged7Days,
    fromOfflineCache: data.fromOfflineCache,
    macrosEstimated: true,
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

  return DashboardData(
    userName: merged.userName,
    avatarUrl: merged.avatarUrl,
    goal: merged.goal,
    netKcal: merged.netKcal,
    consumedKcal: merged.consumedKcal,
    burnedKcal: merged.burnedKcal,
    tempCelsius: merged.tempCelsius,
    location: merged.location,
    weatherMain: merged.weatherMain,
    weatherDescription: merged.weatherDescription,
    alertTitle: merged.alertTitle,
    alertMessage: merged.alertMessage,
    currentSteps: merged.currentSteps,
    stepGoal: merged.stepGoal,
    dailyCaloriesTarget: merged.dailyCaloriesTarget,
    proteinG: localDayTotals.proteinG,
    carbsG: localDayTotals.carbsG,
    fatG: localDayTotals.fatG,
    targetProteinG: merged.targetProteinG,
    targetCarbsG: merged.targetCarbsG,
    targetFatG: merged.targetFatG,
    airQualityAqi: merged.airQualityAqi,
    workoutPreferredTime: merged.workoutPreferredTime,
    workoutDaysPerWeek: merged.workoutDaysPerWeek,
    mealsLoggedToday: merged.mealsLoggedToday,
    mealsLogged7Days: merged.mealsLogged7Days,
    fromOfflineCache: merged.fromOfflineCache,
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
    if (localGoal != null && localGoal > 0) {
      return DashboardData(
        userName: base.userName,
        avatarUrl: base.avatarUrl,
        goal: base.goal,
        netKcal: base.netKcal,
        consumedKcal: base.consumedKcal,
        burnedKcal: base.burnedKcal,
        tempCelsius: base.tempCelsius,
        location: base.location,
        weatherMain: base.weatherMain,
        weatherDescription: base.weatherDescription,
        alertTitle: base.alertTitle,
        alertMessage: base.alertMessage,
        currentSteps: base.currentSteps,
        stepGoal: localGoal,
        dailyCaloriesTarget: base.dailyCaloriesTarget,
        proteinG: base.proteinG,
        carbsG: base.carbsG,
        fatG: base.fatG,
        targetProteinG: base.targetProteinG,
        targetCarbsG: base.targetCarbsG,
        targetFatG: base.targetFatG,
        airQualityAqi: base.airQualityAqi,
        workoutPreferredTime: base.workoutPreferredTime,
        workoutDaysPerWeek: base.workoutDaysPerWeek,
        mealsLoggedToday: base.mealsLoggedToday,
        mealsLogged7Days: base.mealsLogged7Days,
        fromOfflineCache: base.fromOfflineCache,
        macrosEstimated: base.macrosEstimated,
      );
    }
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
    macrosEstimated: false,
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

// In production, this will use Dio to fetch from Laravel `GET /api/dashboard`.
final dashboardDataProvider = FutureProvider<DashboardData>((ref) async {
  const storage = FlutterSecureStorage();
  final token = await storage.read(key: 'sanctum_token');
  if (token == null || token.isEmpty) {
    throw Exception('Missing auth token. Please login again.');
  }

  final db = await SqliteOfflineDb.getInstance();

  Future<DashboardData?> loadCachedDashboard() async {
    final cached = await db.getDashboardCache();
    if (cached == null) return null;
    return DashboardData.fromJson(cached, fromOfflineCache: true);
  }

  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ),
  );

  final online = await isDeviceOnline();

  if (!online) {
    final cached = await loadCachedDashboard();
    if (cached != null) {
      final merged = await _mergePendingNutritionIntoDashboard(cached, db);
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

  try {
    final response = await dio.get(
      '/dashboard',
      queryParameters: _dashboardLocalDayQueryParams(),
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
  } catch (_) {
    final cached = await loadCachedDashboard();
    if (cached != null) {
      final merged = await _mergePendingNutritionIntoDashboard(cached, db);
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
    rethrow;
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
  const DashboardScreen({super.key});

  // Brand Colors
  static const Color primary = Color(0xFF1A5D1A);
  static const Color bgSoft = Color(0xFFF9FAFB);
  static const Color slate900 = Color(0xFF0F172A);

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

    final dashboardState = ref.watch(dashboardDataProvider);
    final stepsTodayAsync = ref.watch(stepsTodayProvider);
    final stepGoalAsync = ref.watch(stepGoalProvider);
    final dailyKcalAsync = ref.watch(dailyCaloriesGoalProvider);
    final localStepGoal = stepGoalAsync.valueOrNull;
    final localDailyKcal = dailyKcalAsync.valueOrNull;

    if (dashboardState.hasError &&
        dashboardState.error.toString().contains('Missing auth token')) {
      return const AuthScreen();
    }

    return Scaffold(
      backgroundColor: bgSoft,
      body: dashboardState.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: primary),
        ),
        error: (err, stack) => NetworkErrorView(
          title: 'Dashboard unavailable',
          message: userFriendlyDataLoadMessage(err),
          onRetry: () => ref.invalidate(dashboardDataProvider),
        ),
        data: (data) {
          final liveSteps = stepsTodayAsync.valueOrNull;
          final merged = data.copyWith(
            currentSteps: liveSteps ?? data.currentSteps,
            stepGoal: _effectiveDashboardStepGoal(data, localStepGoal),
            dailyCaloriesTarget:
                _effectiveDashboardDailyCalories(data, localDailyKcal),
          );
          return _buildContent(context, merged, ref);
        },
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 20), // Lift above bottom nav
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 8, right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                'SCAN MEAL',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: primary,
                ),
              ),
            ),
            FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AiScannerScreen()),
                );
              },
              backgroundColor: primary,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.photo_camera,
                color: Colors.white,
                size: 28,
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: AppBottomNav(
        activeTab: AppTab.home,
        onTabSelected: (tab) => _handleTab(context, tab),
      ),
    );
  }

  void _handleTab(BuildContext context, AppTab tab) {
    switch (tab) {
      case AppTab.home:
        return;
      case AppTab.history:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const NutritionHistoryScreen()),
        );
        return;
      case AppTab.stats:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ActivityTrackingScreen()),
        );
        return;
      case AppTab.safety:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const TeleDieteticsScreen()),
        );
        return;
      case AppTab.profile:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()),
        );
        return;
    }
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
          padding: const EdgeInsets.fromLTRB(
            24,
            16,
            24,
            120,
          ), // Bottom padding for FAB/Nav
          child: Column(
            children: [
            if (data.fromOfflineCache) ...[
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cloud_off_outlined,
                        size: 18, color: Colors.blueGrey.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Offline — showing last synced dashboard',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.blueGrey.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            _buildHeader(context, ref, data.userName, data.avatarUrl),
            const SizedBox(height: 24),
            _buildCalorieCard(data),
            const SizedBox(height: 16),
            _buildWeatherStepsCard(data),
            const SizedBox(height: 16),
            _buildAIInsightCard(context, data),
            ],
          ),
        ),
      ),
    );
  }

  // --- Components ---

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    String name,
    String avatarUrl,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: primary.withOpacity(0.1),
                  width: 2,
                ),
                image: DecorationImage(
                  image: NetworkImage(avatarUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MEDICAL WELLNESS',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: primary,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  'Hello, $name',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: slate900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
        InkWell(
          onTap: () => showNotificationsModal(context, ref),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.notifications_none, color: Colors.blueGrey.shade600),
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
                          horizontal: 5,
                          vertical: 2,
                        ),
                        constraints: const BoxConstraints(minWidth: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade500,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          count > 9 ? '9+' : '$count',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
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
      ],
    );
  }

  Widget _buildCalorieCard(DashboardData data) {
    final net = data.netKcal;
    final netFigure = net == 0 ? '0' : (net > 0 ? '+$net' : '$net');
    final consumedTowardGoal = data.dailyCaloriesTarget > 0
        ? (data.consumedKcal / data.dailyCaloriesTarget).clamp(0.0, 1.0)
        : 0.0;

    const double ringSize = 158.0;
    final macrosLogged = data.proteinG + data.carbsG + data.fatG;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: _calorieBalanceCardDecoration(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.restaurant_rounded, color: primary, size: 22),
              const SizedBox(width: 10),
              Text(
                'CALORIE BALANCE',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: primary,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: ringSize,
            height: ringSize,
            child: Stack(
              alignment: Alignment.center,
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 10,
                  color: Colors.blueGrey.shade200,
                ),
                CircularProgressIndicator(
                  value: consumedTowardGoal,
                  strokeWidth: 10,
                  backgroundColor: Colors.transparent,
                  color: primary,
                  strokeCap: StrokeCap.round,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              netFigure,
                              style: GoogleFonts.inter(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: slate900,
                                height: 1,
                                letterSpacing: -0.8,
                              ),
                            ),
                            Text(
                              ' kcal',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: primary,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Net today',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.blueGrey.shade700,
                          letterSpacing: 0.35,
                        ),
                      ),
                      if (data.dailyCaloriesTarget > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Goal ${data.dailyCaloriesTarget} kcal',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.blueGrey.shade500,
                            letterSpacing: 0.2,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMacroStat(
                  'Eaten',
                  '${data.consumedKcal}',
                  'kcal',
                  primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMacroStat(
                  'Burned',
                  '${data.burnedKcal}',
                  'kcal',
                  Colors.blueGrey.shade400,
                ),
              ),
            ],
          ),
          if (data.consumedKcal > 0 || macrosLogged > 0) ...[
            const SizedBox(height: 14),
            Text(
              'TODAY\'S LOGGED FOOD',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                height: 1.2,
                color: primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.05,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${data.consumedKcal} kcal today · broken down by macros',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.25,
                color: Colors.blueGrey.shade700,
                fontWeight: FontWeight.w600,
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

  /// Parts of today's logged intake (sums from all meals today).
  Widget _macroBreakdownRow(DashboardData data) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _macroCompactCell(
            icon: Icons.fitness_center_rounded,
            label: 'Protein',
            grams: data.proteinG,
            hint: _macroBreakdownTooltipHint(
              gramsLogged: data.proteinG,
              target: data.targetProteinG,
              nutrientName: 'Protein',
            ),
            accent: const Color(0xFF0D9488),
            tint: const Color(0xFFCCFBF1),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _macroCompactCell(
            icon: Icons.grain_rounded,
            label: 'Carbs',
            grams: data.carbsG,
            hint: _macroBreakdownTooltipHint(
              gramsLogged: data.carbsG,
              target: data.targetCarbsG,
              nutrientName: 'Carbs',
            ),
            accent: const Color(0xFFD97706),
            tint: const Color(0xFFFEF3C7),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _macroCompactCell(
            icon: Icons.pie_chart_outline_rounded,
            label: 'Fat',
            grams: data.fatG,
            hint: _macroBreakdownTooltipHint(
              gramsLogged: data.fatG,
              target: data.targetFatG,
              nutrientName: 'Fat',
            ),
            accent: const Color(0xFF7C3AED),
            tint: const Color(0xFFEDE9FE),
          ),
        ),
      ],
    );
  }

  Widget _macroCompactCell({
    required IconData icon,
    required String label,
    required int grams,
    required String hint,
    required Color accent,
    required Color tint,
  }) {
    return Tooltip(
      message: hint,
      triggerMode: TooltipTriggerMode.longPress,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.20)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
              const SizedBox(height: 6),
              Text(
                '${grams}g',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: slate900,
                  height: 1,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.blueGrey.shade600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMacroStat(
    String label,
    String valueDigits,
    String unit,
    Color accent,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              Text(
                label.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: Colors.blueGrey.shade500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                valueDigits,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: slate900,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey.shade500,
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
    final bool isPoorAir = (data.airQualityAqi ?? 0) >= 4;
    final stepGoal = data.stepGoal <= 0 ? 1 : data.stepGoal;
    final stepsPct = data.currentSteps / stepGoal;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.wb_sunny,
                        color: Colors.amber.shade500,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '${data.tempCelsius.toInt()}°C',
                                style: GoogleFonts.inter(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: slate900,
                                ),
                              ),
                              if (isHighHeat)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'HIGH HEAT',
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                ),
                              if (!isHighHeat && isPoorAir)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'HARMATTAN',
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data.location,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.blueGrey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: 1,
                    height: 64,
                    color: Colors.blueGrey.shade100,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.directions_walk,
                            color: Colors.green.shade600,
                            size: 18,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            '${_formatStepsCompact(data.currentSteps, decimals: true)} / ${_formatStepsCompact(data.stepGoal, decimals: false)}',
                            textAlign: TextAlign.end,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: slate900,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: stepsPct.clamp(0.0, 1.0),
                        minHeight: 9,
                        backgroundColor: Colors.blueGrey.shade100,
                        color: Colors.green.shade500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'DAILY STEPS',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isHighHeat) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primary.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SAFETY TIP',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Take shade breaks & pace activity',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey.shade700,
                      height: 1.2,
                    ),
                  ),
                ],
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

  Widget _buildAIInsightCard(BuildContext context, DashboardData data) {
    final msg = _buildPersonalizedInsight(data);
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TeleDieteticsScreen()),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.psychology, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Wellness Insight',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  msg,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.9),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  String _buildPersonalizedInsight(DashboardData data) {
    final stepsGoal = data.stepGoal <= 0 ? 1 : data.stepGoal;
    final stepsPct = (data.currentSteps / stepsGoal).clamp(0.0, 1.5);

    final isPoorAir = (data.airQualityAqi ?? 0) >= 4;
    final isHighHeat = data.tempCelsius >= 32.0;

    final target = data.dailyCaloriesTarget;
    final consumed = data.consumedKcal;
    final burned = data.burnedKcal;
    final net = data.netKcal;
    final goal = (data.goal ?? '').trim();
    final mealsToday = data.mealsLoggedToday ?? 0;
    final meals7 = data.mealsLogged7Days ?? 0;
    final preferredTime = (data.workoutPreferredTime ?? '').trim();
    final daysPerWeek = data.workoutDaysPerWeek;

    final alertTitle = (data.alertTitle ?? '').trim();
    final alertMessage = (data.alertMessage ?? '').trim();

    String name = data.userName.trim().split(' ').first;
    if (name.isEmpty) name = 'You';

    // Template rotation (stable per user/day).
    final seed = '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}|$name';
    final variant = seed.hashCode.abs() % 3;

    // Priority 0: backend alert text when present (already localized to weather/air).
    if (alertTitle.isNotEmpty && alertMessage.isNotEmpty) {
      return variant == 0
          ? '$name: $alertTitle — $alertMessage'
          : variant == 1
              ? '$alertTitle for $name. $alertMessage'
              : '$name, quick heads‑up: $alertMessage';
    }

    // Priority 1: environment
    if (isPoorAir) {
      return '$name, air quality is poor today (Harmattan conditions). Keep workouts indoors and take it easier if your breathing feels irritated.';
    }
    if (isHighHeat) {
      return '$name, it’s hot outside (${data.tempCelsius.toInt()}°C). Prefer shade, shorter outings, and low-intensity movement today.';
    }

    // Priority 2: steps gaps
    if (stepsPct < 0.45) {
      return '$name, you’re at ${(stepsPct * 100).round()}% of your steps goal. Try a 12-minute brisk walk this evening to close the gap.';
    }

    // Priority 2.5: consistency (meals logged)
    if (mealsToday >= 2) {
      final targetP = data.targetProteinG > 0
          ? 'Keep the next meal protein-forward to match your target (P ${data.targetProteinG}g).'
          : 'Keep your next meal balanced and protein-aware.';
      return variant == 0
          ? '$name, nice consistency—$mealsToday meals logged today. $targetP'
          : variant == 1
              ? '$name, you’ve logged $mealsToday meals today (great). Stay steady and finish the day with a short walk.'
              : '$name, good job logging meals today. That consistency makes your targets much more accurate.';
    }
    if (mealsToday == 0 && meals7 > 0) {
      return '$name, you’ve logged $meals7 meals this week—log your next meal and I’ll tune your insight more precisely today.';
    }

    // Priority 3: calorie alignment (only if target is known)
    if (target > 0) {
      final remaining = target - consumed;
      if (remaining > 450) {
        final goalHint = goal.isEmpty
            ? 'Prioritize protein + fiber'
            : goal == 'Lose weight'
                ? 'Keep it protein + fiber-heavy'
                : goal == 'Gain weight'
                    ? 'Add a balanced snack'
                    : 'Stay balanced';
        final macroTargetsSuffix = data.targetProteinG > 0 &&
                data.targetCarbsG >= 0 &&
                data.targetFatG >= 0
            ? ' (macro targets: P ${data.targetProteinG}g • C ${data.targetCarbsG}g • F ${data.targetFatG}g).'
            : '';
        return '$name, you have about $remaining kcal left toward your target. $goalHint$macroTargetsSuffix';
      }
      if (remaining < -250) {
        return '$name, you’re above your target by ${remaining.abs()} kcal. A light walk (and a lighter dinner) can bring your net calories back in range.';
      }
    }

    // Priority 4: workout preference reminder
    if (preferredTime.isNotEmpty || daysPerWeek != null) {
      final d = daysPerWeek == null ? '' : '$daysPerWeek days/week';
      final t = preferredTime.isEmpty ? '' : preferredTime;
      final sep = (d.isNotEmpty && t.isNotEmpty) ? ' • ' : '';
      final plan = (d + sep + t).trim();
      if (plan.isNotEmpty) {
        return '$name, keep your plan simple today: $plan. Even 15 minutes counts—consistency beats intensity.';
      }
    }

    // Default: positive reinforcement with today’s net.
    final sign = net >= 0 ? '+' : '-';
    return '$name, you’re on a good track today. Net calories: $sign${net.abs()} kcal (burned ~$burned kcal from steps). Keep the same rhythm to finish strong.';
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.blueGrey.shade50),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  BoxDecoration _calorieBalanceCardDecoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          primary.withValues(alpha: 0.10),
          Colors.white,
        ],
      ),
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: primary.withValues(alpha: 0.18),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}

