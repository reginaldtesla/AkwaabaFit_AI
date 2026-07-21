import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/shared/connectivity/connectivity_utils.dart';
import 'package:mobile/features/auth/presentation/auth_screen.dart';
import 'package:mobile/features/dashboard/presentation/dashboard_screen.dart';
import 'package:mobile/features/fitness/presentation/daily_leaderboard_screen.dart';
import 'package:mobile/features/fitness/data/steps_today_provider.dart';
import 'package:mobile/features/nutrition/presentation/nutrition_history_screen.dart';
import 'package:mobile/features/profile/presentation/profile_settings_screen.dart';
import 'package:mobile/features/safety/presentation/health_safety_hub_screen.dart';
import 'package:mobile/shared/profile/profile_repository.dart';
import 'package:mobile/shared/navigation/app_bottom_nav.dart';
import 'package:mobile/shared/config/app_config.dart';
import 'package:mobile/shared/offline/sqlite_offline_db.dart';
import 'package:mobile/shared/ui/network_error_view.dart';
import 'package:mobile/shared/ui/user_friendly_errors.dart';
import 'package:mobile/shared/fitness/stride_weather_guidance.dart';
import 'package:mobile/shared/fitness/stride_weather_provider.dart';

// =====================================================================
// 1. STATE MANAGEMENT (RIVERPOD DATA MODELS)
// =====================================================================

/// Same heuristics as Laravel `ActivityController`: ~0.04 kcal/step walk estimate.
int _kcalBurnedFromSteps(int steps) => (steps * 0.04).round();

/// ~0.8 m average stride → km walked (matches backend rounding).
double _distanceKmFromSteps(int steps) =>
    (steps * 0.0008 * 100).round() / 100;

List<int> _parseHourlyBucketSteps(Map<String, dynamic> json) {
  final raw = json['hourlyBucketSteps'];
  if (raw is! List || raw.length != 8) return List.filled(8, 0);
  return List<int>.generate(
    8,
    (i) => (raw[i] as num?)?.toInt() ?? 0,
    growable: false,
  );
}

/// Yesterday's steps from local device log (same table used for today's merge).
final yesterdayStepsLocalProvider = FutureProvider<int?>((ref) async {
  final db = await SqliteOfflineDb.getInstance();
  final y = DateTime.now()
      .subtract(const Duration(days: 1))
      .toIso8601String()
      .substring(0, 10);
  return db.getStepsLocalForDate(y);
});

/// Compact trend for calories/distance cards (both track steps).
class ActivityTrendBadge {
  const ActivityTrendBadge({
    required this.arrowIcon,
    required this.accentColor,
    required this.percentText,
  });

  final IconData arrowIcon;
  final Color accentColor;
  final String percentText;
}

ActivityTrendBadge activityTrendBadgeForSteps(int todaySteps, int? yesterdaySteps) {
  const neutral = Color(0xFF94A3B8);

  if (yesterdaySteps == null) {
    return const ActivityTrendBadge(
      arrowIcon: Icons.arrow_drop_up,
      accentColor: neutral,
      percentText: 'n/a',
    );
  }
  if (yesterdaySteps <= 0) {
    if (todaySteps <= 0) {
      return const ActivityTrendBadge(
        arrowIcon: Icons.arrow_drop_up,
        accentColor: neutral,
        percentText: 'n/a',
      );
    }
    return const ActivityTrendBadge(
      arrowIcon: Icons.arrow_drop_up,
      accentColor: Color(0xFF15803D),
      percentText: 'New',
    );
  }

  final raw =
      ((todaySteps - yesterdaySteps) / yesterdaySteps * 100).round().clamp(-999, 999);
  if (raw > 0) {
    return ActivityTrendBadge(
      arrowIcon: Icons.arrow_drop_up,
      accentColor: const Color(0xFF15803D),
      percentText: '+$raw%',
    );
  }
  if (raw < 0) {
    return ActivityTrendBadge(
      arrowIcon: Icons.arrow_drop_down,
      accentColor: const Color(0xFFDC2626),
      percentText: '$raw%',
    );
  }
  return const ActivityTrendBadge(
    arrowIcon: Icons.arrow_drop_up,
    accentColor: neutral,
    percentText: '0%',
  );
}

class ActivityData {
  final int stepsToday;
  /// Server-backed steps for calendar yesterday when available (`DailyStepLog`).
  final int? stepsYesterday;
  final int stepGoal;
  final int streakDays;
  final int calories;
  final double distanceKm;
  final List<double> hourlyData; // Values between 0.0 and 1.0 for the bar chart
  /// Step totals per 3-hour bucket (aligned with [hourlyData] indices).
  final List<int> hourlyBucketSteps;
  final bool fromOfflineCache;
  /// Weather via `GET /activity/today` (Open-Meteo on server; device GPS when online).
  final double? tempCelsius;
  final String? weatherLocation;
  final String? weatherMain;
  final String? weatherDescription;
  final int? airQualityAqi;
  final String? strideTip;

  ActivityData({
    required this.stepsToday,
    this.stepsYesterday,
    required this.stepGoal,
    required this.streakDays,
    required this.calories,
    required this.distanceKm,
    required this.hourlyData,
    required this.hourlyBucketSteps,
    this.fromOfflineCache = false,
    this.tempCelsius,
    this.weatherLocation,
    this.weatherMain,
    this.weatherDescription,
    this.airQualityAqi,
    this.strideTip,
  });

  int get stepsLeft => stepGoal - stepsToday > 0 ? stepGoal - stepsToday : 0;
  double get progress => stepGoal <= 0 ? 0 : stepsToday / stepGoal;

  ActivityData copyWith({
    int? stepsToday,
    int? stepsYesterday,
    int? stepGoal,
    int? streakDays,
    int? calories,
    double? distanceKm,
    List<double>? hourlyData,
    List<int>? hourlyBucketSteps,
    bool? fromOfflineCache,
    double? tempCelsius,
    String? weatherLocation,
    String? weatherMain,
    String? weatherDescription,
    int? airQualityAqi,
    String? strideTip,
  }) {
    return ActivityData(
      stepsToday: stepsToday ?? this.stepsToday,
      stepsYesterday: stepsYesterday ?? this.stepsYesterday,
      stepGoal: stepGoal ?? this.stepGoal,
      streakDays: streakDays ?? this.streakDays,
      calories: calories ?? this.calories,
      distanceKm: distanceKm ?? this.distanceKm,
      hourlyData: hourlyData ?? this.hourlyData,
      hourlyBucketSteps: hourlyBucketSteps ?? this.hourlyBucketSteps,
      fromOfflineCache: fromOfflineCache ?? this.fromOfflineCache,
      tempCelsius: tempCelsius ?? this.tempCelsius,
      weatherLocation: weatherLocation ?? this.weatherLocation,
      weatherMain: weatherMain ?? this.weatherMain,
      weatherDescription: weatherDescription ?? this.weatherDescription,
      airQualityAqi: airQualityAqi ?? this.airQualityAqi,
      strideTip: strideTip ?? this.strideTip,
    );
  }

  factory ActivityData.fromJson(Map<String, dynamic> json) {
    final raw = (json['hourlyData'] as List?) ?? const [];
    final values = raw
        .map((e) => (e as num?)?.toDouble() ?? 0.0)
        .toList(growable: false);

    final steps = (json['stepsToday'] as num?)?.toInt() ?? 0;
    final syRaw = json['stepsYesterday'];
    final sy = syRaw == null ? null : (syRaw as num?)?.toInt();
    final hourlyResolved =
        values.length == 8 ? values : List<double>.filled(8, 0.0);
    final weather = json['weather'];
    final weatherMap = weather is Map
        ? weather.map((k, v) => MapEntry(k.toString(), v))
        : null;

    return ActivityData(
      stepsToday: steps,
      stepsYesterday: sy,
      stepGoal: (json['stepGoal'] as num?)?.toInt() ?? 10000,
      streakDays: (json['streakDays'] as num?)?.toInt() ?? 0,
      calories: _kcalBurnedFromSteps(steps),
      distanceKm: _distanceKmFromSteps(steps),
      hourlyData: hourlyResolved,
      hourlyBucketSteps: _parseHourlyBucketSteps(json),
      fromOfflineCache: false,
      tempCelsius: weatherMap != null
          ? (weatherMap['tempCelsius'] as num?)?.toDouble()
          : null,
      weatherLocation: weatherMap?['location']?.toString(),
      weatherMain: weatherMap?['main']?.toString(),
      weatherDescription: weatherMap?['description']?.toString(),
      airQualityAqi: weatherMap != null
          ? (weatherMap['airQualityAqi'] as num?)?.toInt()
          : null,
      strideTip: json['strideTip']?.toString(),
    );
  }
}

Future<int?> _readLocalStepGoalActivity(Ref ref) async {
  try {
    final local = await ref.read(profileRepositoryProvider).readLocalProfile();
    final v = local?['step_goal'];
    final localGoal = (v is int) ? v : int.tryParse((v ?? '').toString());
    if (localGoal != null && localGoal > 0) return localGoal;
  } catch (_) {}
  return null;
}

// Live provider - fetch from Laravel `GET /api/activity/today`
final activityDataProvider = FutureProvider<ActivityData>((ref) async {
  const storage = FlutterSecureStorage();
  final token = await storage.read(key: 'sanctum_token');
  if (token == null || token.isEmpty) {
    throw Exception('Missing auth token. Please login again.');
  }

  final db = await SqliteOfflineDb.getInstance();
  final today = DateTime.now().toIso8601String().substring(0, 10);

  Future<ActivityData?> activityFromLocalStepsOnly() async {
    final localSteps = await db.getStepsLocalForDate(today);
    if (localSteps == null) return null;
    final localGoal = await _readLocalStepGoalActivity(ref);
    final g = localGoal ?? 10000;
    return ActivityData(
      stepsToday: localSteps,
      stepsYesterday: null,
      stepGoal: g,
      streakDays: 0,
      calories: _kcalBurnedFromSteps(localSteps),
      distanceKm: _distanceKmFromSteps(localSteps),
      hourlyData: List.filled(8, 0.0),
      hourlyBucketSteps: List.filled(8, 0),
      fromOfflineCache: true,
    );
  }

  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 5),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ),
  );

  final online = await isDeviceOnline();

  if (!online) {
    final cached = await db.getActivityCache();
    final localSteps = await db.getStepsLocalForDate(today);
    final localGoal = await _readLocalStepGoalActivity(ref);

    if (cached != null) {
      final base = ActivityData.fromJson(cached);
      final mergedSteps = localSteps ?? base.stepsToday;
      return base.copyWith(
        stepsToday: mergedSteps,
        stepGoal: (localGoal != null && localGoal > 0) ? localGoal : base.stepGoal,
        calories: _kcalBurnedFromSteps(mergedSteps),
        distanceKm: _distanceKmFromSteps(mergedSteps),
        fromOfflineCache: true,
      );
    }

    final fallback = await activityFromLocalStepsOnly();
    if (fallback != null) return fallback;

    return ActivityData(
      stepsToday: 0,
      stepsYesterday: null,
      stepGoal: localGoal ?? 10000,
      streakDays: 0,
      calories: 0,
      distanceKm: 0,
      hourlyData: List.filled(8, 0.0),
      hourlyBucketSteps: List.filled(8, 0),
      fromOfflineCache: true,
    );
  }

  try {
    // Use cached coords — never block on live GPS for the API call.
    double lat = 5.6035;
    double lon = -0.1869;
    try {
      final weatherCache = await db.getWeatherCache();
      if (weatherCache != null &&
          weatherCache['latitude'] != null &&
          weatherCache['longitude'] != null) {
        lat = (weatherCache['latitude'] as num).toDouble();
        lon = (weatherCache['longitude'] as num).toDouble();
      }
    } catch (_) {}
    final response = await dio.get(
      '/activity/today',
      queryParameters: {
        'lat': lat.toStringAsFixed(5),
        'lon': lon.toStringAsFixed(5),
      },
    );
    final raw = response.data;
    if (raw is! Map) {
      throw Exception('Unexpected activity response.');
    }

    final json = raw.map((key, dynamic v) => MapEntry(key.toString(), v));
    await db.putActivityCache(json);
    final base = ActivityData.fromJson(json);

    final localGoal = await _readLocalStepGoalActivity(ref);
    if (localGoal != null && localGoal > 0) {
      final s = base.stepsToday;
      return base.copyWith(
        stepGoal: localGoal,
        calories: _kcalBurnedFromSteps(s),
        distanceKm: _distanceKmFromSteps(s),
      );
    }

    return base;
  } catch (_) {
    final cached = await db.getActivityCache();
    final localSteps = await db.getStepsLocalForDate(today);
    final localGoal = await _readLocalStepGoalActivity(ref);

    if (cached != null) {
      final base = ActivityData.fromJson(cached);
      final mergedSteps = localSteps ?? base.stepsToday;
      return base.copyWith(
        stepsToday: mergedSteps,
        stepGoal: (localGoal != null && localGoal > 0) ? localGoal : base.stepGoal,
        calories: _kcalBurnedFromSteps(mergedSteps),
        distanceKm: _distanceKmFromSteps(mergedSteps),
        fromOfflineCache: true,
      );
    }

    final fallback = await activityFromLocalStepsOnly();
    if (fallback != null) return fallback;

    final localGoalCatch = await _readLocalStepGoalActivity(ref);
    return ActivityData(
      stepsToday: 0,
      stepsYesterday: null,
      stepGoal: localGoalCatch ?? 10000,
      streakDays: 0,
      calories: 0,
      distanceKm: 0,
      hourlyData: List.filled(8, 0.0),
      hourlyBucketSteps: List.filled(8, 0),
      fromOfflineCache: true,
    );
  }
});

/// Live speed (km/h) and pace (min/km) from pedometer step deltas (~0.8 m/step).
class _PaceSpeedLiveCard extends ConsumerStatefulWidget {
  const _PaceSpeedLiveCard();

  @override
  ConsumerState<_PaceSpeedLiveCard> createState() => _PaceSpeedLiveCardState();
}

class _PaceSpeedLiveCardState extends ConsumerState<_PaceSpeedLiveCard> {
  static const double _strideKm = 0.0008;

  Timer? _timer;
  int? _prevSteps;
  DateTime? _prevAt;
  DateTime? _lastMovementAt;

  double _kmh = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 400), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    final steps = ref.read(stepsTodayProvider).valueOrNull ?? 0;
    final now = DateTime.now();

    if (_prevSteps != null && _prevAt != null) {
      final dtSec = now.difference(_prevAt!).inMilliseconds / 1000.0;
      if (dtSec >= 0.2) {
        final delta = steps - _prevSteps!;
        if (delta > 0) {
          _lastMovementAt = now;
          _kmh = ((delta * _strideKm / dtSec) * 3600).clamp(0, 25);
        }
      }
    }

    if (_lastMovementAt != null &&
        now.difference(_lastMovementAt!).inMilliseconds > 2200) {
      _kmh = 0;
    }

    _prevSteps = steps;
    _prevAt = now;
    setState(() {});
  }

  String _paceLabel() {
    if (_kmh < 0.08) return '—';
    final minPerKm = 60.0 / _kmh;
    final m = minPerKm.floor().clamp(0, 999);
    final s = ((minPerKm - m) * 60).round().clamp(0, 59);
    return '$m:${s.toString().padLeft(2, '0')} /km';
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(stepsTodayProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ActivityTrackingScreen.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.blueGrey.shade50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _metricHalf(
              icon: Icons.speed_rounded,
              iconBg: Colors.blue.shade50,
              iconColor: ActivityTrackingScreen.secondaryBlue,
              title: 'Speed',
              value: '${_kmh.toStringAsFixed(1)} km/h',
              subtitle: 'live',
            ),
          ),
          Container(
            width: 1,
            height: 88,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: Colors.blueGrey.shade100,
          ),
          Expanded(
            child: _metricHalf(
              icon: Icons.timer_outlined,
              iconBg: Colors.green.shade50,
              iconColor: ActivityTrackingScreen.primaryGreen,
              title: 'Pace',
              value: _paceLabel(),
              subtitle: _kmh < 0.08 ? 'standing still' : 'min per km',
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricHalf({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: ActivityTrackingScreen.textDark,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: ActivityTrackingScreen.slateCustom,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: ActivityTrackingScreen.slateCustom.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }
}

/// Eye-catching entry to the daily leaderboard on Stride / Activity.
class _LeaderboardAttentionButton extends StatefulWidget {
  const _LeaderboardAttentionButton();

  @override
  State<_LeaderboardAttentionButton> createState() =>
      _LeaderboardAttentionButtonState();
}

class _LeaderboardAttentionButtonState extends State<_LeaderboardAttentionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  static const _goldMid = Color(0xFFF59E0B);
  static const _goldDeep = Color(0xFFD97706);

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const DailyLeaderboardScreen()),
          );
        },
        borderRadius: BorderRadius.circular(40),
        child: Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) {
                  final t =
                      Curves.easeInOut.transform(_pulse.value);
                  final scale = 1.0 + 0.07 * t;
                  final glow = 8.0 + 16.0 * t;
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFFFE066),
                            _goldMid,
                            _goldDeep,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _goldMid.withValues(alpha: 0.45),
                            blurRadius: glow,
                            spreadRadius: 1,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(color: Colors.white, width: 2.5),
                      ),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _goldMid.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _goldMid.withValues(alpha: 0.35)),
                ),
                child: Text(
                  'LEADERBOARD',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _goldDeep,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// 2. THE UI SCREEN
// =====================================================================

class ActivityTrackingScreen extends ConsumerStatefulWidget {
  const ActivityTrackingScreen({super.key});

  // Theme Colors from Design
  static const Color primaryGreen = Color(0xFF10B981);
  static const Color secondaryBlue = Color(0xFF3B82F6);
  static const Color slateCustom = Color(0xFF64748B);
  static const Color cardBg = Color(0xFFFAFAFA);
  static const Color textDark = Color(0xFF0F172A);
  static const Color dashboardGreen = Color(0xFF1A5D1A);

  @override
  ConsumerState<ActivityTrackingScreen> createState() =>
      _ActivityTrackingScreenState();
}

class _ActivityTrackingScreenState extends ConsumerState<ActivityTrackingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(activityDataProvider);
      ref.invalidate(dashboardDataProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final activityState = ref.watch(activityDataProvider);
    final stepsTodayAsync = ref.watch(stepsTodayProvider);
    final stepGoalAsync = ref.watch(stepGoalProvider);
    final localStepGoal = stepGoalAsync.valueOrNull;

    if (activityState.hasError &&
        activityState.error.toString().contains('Missing auth token')) {
      return const AuthScreen();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: activityState.when(
          loading: () =>
              const Center(
                  child: CircularProgressIndicator(
                      color: ActivityTrackingScreen.secondaryBlue)),
          error: (err, stack) => NetworkErrorView(
            title: 'Activity unavailable',
            message: userFriendlyDataLoadMessage(err),
            onRetry: () => ref.invalidate(activityDataProvider),
          ),
          data: (data) {
            final liveSteps = stepsTodayAsync.valueOrNull;
            final merged = liveSteps == null
                ? data
                : data.copyWith(
                    stepsToday: liveSteps,
                    stepGoal: (localStepGoal != null && localStepGoal > 0)
                        ? localStepGoal
                        : data.stepGoal,
                    calories: _kcalBurnedFromSteps(liveSteps),
                    distanceKm: _distanceKmFromSteps(liveSteps),
                  );

            return RefreshIndicator(
              color: ActivityTrackingScreen.secondaryBlue,
              onRefresh: () async {
                ref.invalidate(activityDataProvider);
                ref.invalidate(dashboardDataProvider);
                ref.invalidate(yesterdayStepsLocalProvider);
                await ref.read(activityDataProvider.future);
              },
              child: _buildContent(context, ref, merged),
            );
          },
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        activeTab: AppTab.stats,
        onTabSelected: (tab) => _handleTab(context, tab),
      ),
    );
  }

  void _handleTab(BuildContext context, AppTab tab) {
    switch (tab) {
      case AppTab.home:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
        return;
      case AppTab.history:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const NutritionHistoryScreen()),
        );
        return;
      case AppTab.stats:
        return;
      case AppTab.safety:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HealthSafetyHubScreen()),
        );
        return;
      case AppTab.profile:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()),
        );
        return;
    }
  }

  // --- UI Components ---

  Widget _buildContent(BuildContext context, WidgetRef ref, ActivityData data) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
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
                      'Offline — showing last synced activity',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          _buildHeader(context),
          const SizedBox(height: 32),
          _buildProgressRing(data),
          const SizedBox(height: 32),
          _buildQuickStats(data),
          const SizedBox(height: 24),
          _buildMetricsGrid(ref, data),
          const SizedBox(height: 24),
          const _PaceSpeedLiveCard(),
          const SizedBox(height: 24),
          _WellnessAdviceLiveCard(data: data),
          const SizedBox(height: 24),
          _IndoorStrideTipsWhenRain(),
          const _StrideWeatherContextCard(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Activity',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: ActivityTrackingScreen.textDark,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'Today',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: ActivityTrackingScreen.slateCustom,
              ),
            ),
          ],
        ),
        const _LeaderboardAttentionButton(),
      ],
    );
  }

  Widget _buildProgressRing(ActivityData data) {
    final int percent = (data.progress * 100).toInt();

    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: 1.0,
            strokeWidth: 12,
            color: Colors.blueGrey.shade50,
          ),
          CircularProgressIndicator(
            value: data.progress.clamp(0.0, 1.0),
            strokeWidth: 12,
            color: ActivityTrackingScreen.dashboardGreen,
            backgroundColor: Colors.transparent,
            strokeCap: StrokeCap.round,
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Steps Today',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: ActivityTrackingScreen.slateCustom,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${data.stepsToday}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  color: ActivityTrackingScreen.textDark,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.shade100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt, color: Colors.green.shade600, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '$percent% OF DAILY GOAL',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(ActivityData data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatColumn('GOAL', '${data.stepGoal}', ActivityTrackingScreen.textDark),
          Container(width: 1, height: 40, color: Colors.blueGrey.shade100),
          _buildStatColumn('LEFT', '${data.stepsLeft}', ActivityTrackingScreen.secondaryBlue),
          Container(width: 1, height: 40, color: Colors.blueGrey.shade100),
          _buildStatColumn('STREAK', '${data.streakDays} Days', ActivityTrackingScreen.primaryGreen),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey.shade400,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsGrid(WidgetRef ref, ActivityData data) {
    final yesterdayAsync = ref.watch(yesterdayStepsLocalProvider);
    final trend = data.stepsYesterday != null
        ? activityTrendBadgeForSteps(data.stepsToday, data.stepsYesterday)
        : yesterdayAsync.when(
            data: (y) => activityTrendBadgeForSteps(data.stepsToday, y),
            loading: () => activityTrendBadgeForSteps(data.stepsToday, null),
            error: (Object _, StackTrace _) =>
                activityTrendBadgeForSteps(data.stepsToday, null),
          );

    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            icon: Icons.local_fire_department,
            iconColor: ActivityTrackingScreen.secondaryBlue,
            bgColor: Colors.blue.shade50,
            trend: trend,
            value: '${data.calories}',
            label: 'Calories (kcal)',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
            icon: Icons.near_me,
            iconColor: ActivityTrackingScreen.primaryGreen,
            bgColor: Colors.green.shade50,
            trend: trend,
            value: data.distanceKm.toStringAsFixed(2),
            label: 'Distance (km)',
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required ActivityTrendBadge trend,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ActivityTrackingScreen.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.blueGrey.shade50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration:
                    BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        trend.arrowIcon,
                        color: trend.accentColor,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        trend.percentText,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: trend.accentColor,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: ActivityTrackingScreen.textDark,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
                  color: ActivityTrackingScreen.slateCustom,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

}

/// Encouragement tied to live steps, goal, and streak — updates as you move.
class _StrideWeatherContextCard extends ConsumerWidget {
  const _StrideWeatherContextCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(strideWeatherProvider);
    if (snap == null || !snap.hasCondition && snap.tempCelsius <= 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.blueGrey.shade100),
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined, color: Colors.blueGrey.shade600),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Local weather unavailable right now. Stride still tracks your steps.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.35,
                  color: Colors.blueGrey.shade700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final tip = (snap.strideTip?.trim().isNotEmpty == true)
        ? snap.strideTip!.trim()
        : StrideWeatherGuidance.summaryLine(
            weatherMain: snap.weatherMain,
            tempCelsius: snap.tempCelsius,
            airQualityAqi: snap.airQualityAqi,
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade50,
            Colors.green.shade50.withValues(alpha: 0.35),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                StrideWeatherGuidance.iconFor(snap.weatherMain),
                color: Colors.blue.shade800,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${snap.tempCelsius.toStringAsFixed(0)}°C · ${StrideWeatherGuidance.labelFor(snap.weatherMain)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: ActivityTrackingScreen.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      snap.location,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.blueGrey.shade600,
                      ),
                    ),
                    if (snap.weatherDescription != null &&
                        snap.weatherDescription!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        snap.weatherDescription!,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.blueGrey.shade500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (snap.fromActivityApi)
                Tooltip(
                  message: 'Live local weather',
                  child: Icon(
                    Icons.cloud_done_outlined,
                    size: 20,
                    color: Colors.green.shade700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            tip,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w500,
              color: Colors.blueGrey.shade800,
            ),
          ),
        ],
      ),
    );
  }
}

class _IndoorStrideTipsWhenRain extends ConsumerWidget {
  const _IndoorStrideTipsWhenRain();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherMain = ref.watch(strideWeatherProvider)?.weatherMain;
    if (!StrideWeatherGuidance.discouragesOutdoorWalk(weatherMain)) {
      return const SizedBox.shrink();
    }

    final tips = StrideWeatherGuidance.indoorAlternatives(
      isStorm: StrideWeatherGuidance.isStorm(weatherMain),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  StrideWeatherGuidance.isStorm(weatherMain)
                      ? Icons.thunderstorm_outlined
                      : Icons.umbrella_outlined,
                  color: Colors.blue.shade800,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    StrideWeatherGuidance.isStorm(weatherMain)
                        ? 'Storm today — move indoors'
                        : 'Rain today — stay dry',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: ActivityTrackingScreen.textDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Outdoor walks can wait. Your phone still counts steps at home.',
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.4,
                color: Colors.blueGrey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tips
                  .map(
                    (t) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Text(
                        t,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.blueGrey.shade800,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _WellnessAdviceLiveCard extends ConsumerStatefulWidget {
  const _WellnessAdviceLiveCard({required this.data});

  final ActivityData data;

  @override
  ConsumerState<_WellnessAdviceLiveCard> createState() =>
      _WellnessAdviceLiveCardState();
}

class _WellnessAdviceLiveCardState extends ConsumerState<_WellnessAdviceLiveCard> {
  Timer? _movingPulseTimer;
  bool _movingPulse = false;

  @override
  void dispose() {
    _movingPulseTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _WellnessAdviceLiveCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final prev = oldWidget.data.stepsToday;
    final next = widget.data.stepsToday;
    if (next > prev) {
      _movingPulseTimer?.cancel();
      setState(() => _movingPulse = true);
      _movingPulseTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _movingPulse = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps =
        ref.watch(stepsTodayProvider).valueOrNull ?? widget.data.stepsToday;
    final goal =
        widget.data.stepGoal <= 0 ? 10000 : widget.data.stepGoal;
    final progress = goal <= 0 ? 0.0 : steps / goal;
    final left = (goal - steps).clamp(0, goal);

    final streak = widget.data.streakDays;
    final streakNote = streak >= 2
        ? 'Your $streak-day streak shows real consistency. '
        : '';

    final weatherMain = ref.watch(strideWeatherProvider)?.weatherMain;
    final rainBody = StrideWeatherGuidance.wellnessBody(
      steps: steps,
      goal: goal,
      progress: progress,
      left: left,
      weatherMain: weatherMain,
      streakNote: streakNote,
    );

    String body;
    if (rainBody.isNotEmpty) {
      body = rainBody;
    } else if (progress >= 1.0) {
      body =
          '${streakNote}You already hit your step goal today — outstanding. Celebrate the habit you\'re building, '
          'and recover well tonight.';
    } else if (progress >= 0.92) {
      body =
          '${streakNote}You\'re close to your goal — about $left steps left. Finish when it fits your day; '
          'you\'ve already done most of the work.';
    } else if (progress >= 0.75) {
      body =
          '${streakNote}Three quarters of your goal are done. Keep a steady pace — another short bout of walking adds up.';
    } else if (progress >= 0.5) {
      body =
          '${streakNote}Halfway there today. That\'s meaningful movement — keep stacking small wins.';
    } else if (progress >= 0.25) {
      body =
          '${streakNote}You\'re building momentum. A few extra minutes on your feet later still adds up.';
    } else if (steps > 0) {
      body =
          '${streakNote}Nice start — every step counts. Move when it fits your day; '
          'no pressure to sprint.';
    } else {
      body =
          'Today is wide open. When you\'re ready, a short walk is a solid place to begin.';
    }

    final pulseLine = _movingPulse
        ? 'You\'re adding steps right now — keep going!'
        : null;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.blueGrey.shade100.withValues(alpha: 0.5),
              ),
            ),
            child: Icon(
              progress >= 1.0 ? Icons.celebration_rounded : Icons.favorite_rounded,
              color: progress >= 1.0
                  ? ActivityTrackingScreen.primaryGreen
                  : ActivityTrackingScreen.secondaryBlue,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Wellness',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: ActivityTrackingScreen.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$steps / $goal steps · ${(progress * 100).clamp(0, 999).toStringAsFixed(0)}%',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ActivityTrackingScreen.slateCustom,
                  ),
                ),
                if (pulseLine != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    pulseLine,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      height: 1.45,
                      fontWeight: FontWeight.w700,
                      color: ActivityTrackingScreen.primaryGreen,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  body,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                    color: ActivityTrackingScreen.slateCustom,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

