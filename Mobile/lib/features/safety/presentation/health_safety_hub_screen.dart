import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/dashboard/presentation/dashboard_screen.dart';
import 'package:mobile/features/fitness/presentation/activity_tracking_screen.dart';
import 'package:mobile/features/nutrition/presentation/nutrition_history_screen.dart';
import 'package:mobile/features/profile/presentation/profile_settings_screen.dart';
import 'package:mobile/shared/profile/profile_repository.dart';
import 'package:mobile/features/safety/data/safety_environment_advice.dart';
import 'package:mobile/features/safety/data/safety_health_tips.dart';
import 'package:mobile/shared/navigation/app_bottom_nav.dart';
import 'package:mobile/shared/weather/dashboard_weather_merge.dart';
import 'package:mobile/shared/weather/device_weather_service.dart';

// =====================================================================
// 1. STATE MANAGEMENT & DATA MODELS
// =====================================================================

class SafetyHubData {
  final String userName;
  final String location;
  final int temperatureCelsius;

  SafetyHubData({
    required this.userName,
    required this.location,
    required this.temperatureCelsius,
  });
}

final safetyHubProvider =
    StateNotifierProvider<SafetyHubNotifier, AsyncValue<SafetyHubData>>((ref) {
      return SafetyHubNotifier(ref);
    });

class SafetyHubNotifier extends StateNotifier<AsyncValue<SafetyHubData>> {
  SafetyHubNotifier(this._ref) : super(const AsyncValue.loading()) {
    void applyDashboard(AsyncValue<DashboardData> next) {
      next.when(
        data: (dashboard) {
          state = AsyncValue.data(
            SafetyHubData(
              userName: dashboard.userName,
              location: dashboard.location,
              temperatureCelsius: dashboard.tempCelsius.toInt(),
            ),
          );
        },
        loading: () {
          if (!state.hasValue) {
            state = const AsyncValue.loading();
          }
        },
        error: (err, stack) {
          state = const AsyncValue.loading();
          Future.microtask(() async {
            try {
              final local =
                  await _ref.read(profileRepositoryProvider).readLocalProfile();
              if (local == null) {
                state = AsyncValue.error(err, stack);
                return;
              }
              state = AsyncValue.data(
                SafetyHubData(
                  userName: (local['name'] ?? 'Member').toString(),
                  location: 'Offline — weather unavailable',
                  temperatureCelsius: 0,
                ),
              );
            } catch (_) {
              state = AsyncValue.error(err, stack);
            }
          });
        },
      );
    }

    // Same `/dashboard` payload as the home screen — weather stays in sync.
    _ref.listen<AsyncValue<DashboardData>>(
      dashboardDataProvider,
      (_, next) => applyDashboard(next),
      fireImmediately: true,
    );
  }

  final Ref _ref;
}

/// Visual treatment for the environment temperature strip from OpenWeather-style `main`.
class _WeatherBannerLook {
  const _WeatherBannerLook({
    required this.gradient,
    required this.icon,
    required this.iconTint,
  });

  final Gradient gradient;
  final IconData icon;
  final Color iconTint;
}

_WeatherBannerLook _weatherBannerLook(String? weatherMain) {
  final key = (weatherMain ?? '').toLowerCase().trim();

  if (key.contains('thunder')) {
    return _WeatherBannerLook(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFD7CCC8),
          Color(0xFFB0BEC5),
        ],
      ),
      icon: Icons.thunderstorm_rounded,
      iconTint: Color(0xFF5D4037),
    );
  }
  if (key.contains('drizzle') || key == 'rain') {
    return _WeatherBannerLook(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFDDEAE5),
          Color(0xFFC5D9D0),
        ],
      ),
      icon: Icons.water_drop_rounded,
      iconTint: Color(0xFF1B5E20),
    );
  }
  if (key.contains('snow') || key.contains('sleet')) {
    return _WeatherBannerLook(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFECEFF1),
          Color(0xFFDDE8E4),
        ],
      ),
      icon: Icons.ac_unit_rounded,
      iconTint: Color(0xFF455A64),
    );
  }
  if (key.contains('mist') ||
      key.contains('fog') ||
      key.contains('haze') ||
      key.contains('smoke') ||
      key.contains('dust') ||
      key.contains('sand') ||
      key.contains('ash')) {
    return _WeatherBannerLook(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFE8EBE9),
          Color(0xFFD5DDD8),
        ],
      ),
      icon: Icons.blur_on_rounded,
      iconTint: Color(0xFF546E7A),
    );
  }
  if (key.contains('cloud')) {
    return _WeatherBannerLook(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFEEF1EE),
          Color(0xFFDDE6DD),
        ],
      ),
      icon: Icons.cloud_rounded,
      iconTint: Color(0xFF455A64),
    );
  }
  if (key.contains('clear')) {
    return _WeatherBannerLook(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFFDE7),
          Color(0xFFE8F5E9),
        ],
      ),
      icon: Icons.wb_sunny_rounded,
      iconTint: Color(0xFFF57F17),
    );
  }
  if (key.contains('tornado') || key.contains('squall')) {
    return _WeatherBannerLook(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFB0BEC5),
          Color(0xFF90A4AE),
        ],
      ),
      icon: Icons.air_rounded,
      iconTint: Color(0xFF37474F),
    );
  }

  return _WeatherBannerLook(
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFF2F8F2),
        Color(0xFFE8F5E9),
      ],
    ),
    icon: Icons.wb_cloudy_rounded,
    iconTint: Color(0xFF1A5D1A),
  );
}

// =====================================================================
// 2. THE UI SCREEN
// =====================================================================

class HealthSafetyHubScreen extends ConsumerWidget {
  const HealthSafetyHubScreen({super.key});

  // Brand colors — match Dashboard (`primary` green, no blue accent).
  static const Color primary = Color(0xFF1A5D1A);
  static const Color softTint = Color(0xFFF2F8F2);
  static const Color calmTint = Color(0xFFDCEADC);
  static const Color background = Color(0xFFF9FAFB);
  static const Color textMain = Color(0xFF334155);
  static const Color textLight = Color(0xFF64748B);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final safetyState = ref.watch(safetyHubProvider);

    return Scaffold(
      backgroundColor: background,
      appBar: _buildAppBar(),
      body: safetyState.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: primary)),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (data) => RefreshIndicator(
          color: primary,
          onRefresh: () async {
            ref.invalidate(dashboardDataProvider);
            await ref.read(dashboardDataProvider.future);
          },
          child: _buildContent(context, ref, data),
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        activeTab: AppTab.safety,
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
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ActivityTrackingScreen()),
        );
        return;
      case AppTab.safety:
        return;
      case AppTab.profile:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()),
        );
        return;
    }
  }

  // --- UI Components ---

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: background.withValues(alpha: 0.8),
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Text(
        'Safety Hub',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: textMain,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, SafetyHubData data) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
      child: Column(
        children: [
          _RotatingHealthTipsCard(
            tempCelsius: data.temperatureCelsius.toDouble(),
          ),
          const SizedBox(height: 24),
          _buildEnvironmentCard(ref, data),
          const SizedBox(height: 24),
          Text(
            'This guide provides supportive health information. Always consult your doctor for medical advice.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: textLight,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnvironmentCard(WidgetRef ref, SafetyHubData data) {
    // Read weather from the same provider as the dashboard — avoids drift from
    // StateNotifier listen timing (Hub showed 30°C vs dashboard 29°C).
    final rawDash = ref.watch(dashboardDataProvider).valueOrNull;
    final dashSnapshot = rawDash != null
        ? applyDeviceWeatherToDashboard(
            rawDash,
            ref.watch(deviceWeatherProvider).valueOrNull,
          )
        : null;
    final tempDisplay = dashSnapshot != null
        ? dashSnapshot.tempCelsius.toInt()
        : data.temperatureCelsius;
    final locationDisplay =
        dashSnapshot?.location ?? data.location;

    final advice = resolveSafetyEnvironmentAdvice(
      tempCelsius:
          dashSnapshot?.tempCelsius ?? data.temperatureCelsius.toDouble(),
      weatherMain: dashSnapshot?.weatherMain,
      weatherDescription: dashSnapshot?.weatherDescription,
      airQualityAqi: dashSnapshot?.airQualityAqi,
    );
    final weatherBanner = _weatherBannerLook(dashSnapshot?.weatherMain);
    final conditionLabel = safetyWeatherConditionLabel(
      weatherMain: dashSnapshot?.weatherMain,
      weatherDescription: dashSnapshot?.weatherDescription,
    );
    final hasTrustedTemp = (dashSnapshot?.tempCelsius ??
            data.temperatureCelsius.toDouble()) >
        0;
    final showTemp = hasTrustedTemp &&
        (dashSnapshot?.weatherMain != null ||
            (dashSnapshot?.tempCelsius ?? 0) > 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'LOCAL ENVIRONMENT',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: textLight,
                letterSpacing: 1.0,
              ),
            ),
            Row(
              children: [
                Icon(advice.headlineIcon, color: advice.headlineColor, size: 16),
                const SizedBox(width: 4),
                Text(
                  advice.headlineLabel,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: advice.headlineColor,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: _cardDecoration(),
          child: Column(
            children: [
              SizedBox(
                height: 180,
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(32)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: weatherBanner.gradient,
                        ),
                      ),
                      Positioned(
                        right: -12,
                        top: 16,
                        child: Icon(
                          weatherBanner.icon,
                          size: 152,
                          color: weatherBanner.iconTint.withValues(alpha: 0.2),
                        ),
                      ),
                      Positioned(
                        bottom: 20,
                        left: 24,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              locationDisplay.toUpperCase(),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: primary,
                                letterSpacing: 1.0,
                              ),
                            ),
                            if (showTemp)
                              Text(
                                '$tempDisplay°C',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: textMain,
                                ),
                              )
                            else
                              Text(
                                '—',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: textMain,
                                ),
                              ),
                            if (conditionLabel != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                conditionLabel,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: textLight,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: softTint,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: calmTint.withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        advice.quote,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                          color: textMain,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _buildAdvicePill(
                            advice.tipAIcon,
                            advice.tipALabel,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildAdvicePill(
                            advice.tipBIcon,
                            advice.tipBLabel,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdvicePill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Icon(icon, color: primary, size: 26),
          const SizedBox(height: 12),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: textLight,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(32),
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 24,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}

/// Shows the local dietitian tip bank immediately; Gemini refreshes in new tips.
class _RotatingHealthTipsCard extends ConsumerStatefulWidget {
  const _RotatingHealthTipsCard({this.tempCelsius});

  final double? tempCelsius;

  @override
  ConsumerState<_RotatingHealthTipsCard> createState() =>
      _RotatingHealthTipsCardState();
}

class _RotatingHealthTipsCardState extends ConsumerState<_RotatingHealthTipsCard>
    with SingleTickerProviderStateMixin {
  static const Color _primary = Color(0xFF1A5D1A);
  static const Color _softTint = Color(0xFFF2F8F2);
  static const Color _textMain = Color(0xFF334155);
  static const Color _textLight = Color(0xFF64748B);
  static const Color _rule = Color(0xFFE2E8F0);
  static const Duration _interval = Duration(seconds: 15);

  List<SafetyHealthTip> _tips =
      List<SafetyHealthTip>.from(kSafetyHealthTipsLocal);
  int _index = 0;
  bool _refreshing = false;
  String _source = 'local';
  SafetyMealRecommendations? _mealRecommendations;
  Timer? _timer;
  late final AnimationController _progress;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(vsync: this, duration: _interval);
    _startRotation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadTips(refresh: false, resetIndex: false));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _progress.dispose();
    super.dispose();
  }

  void _startRotation() {
    _timer?.cancel();
    if (_tips.isEmpty) return;
    _progress
      ..reset()
      ..forward();
    _timer = Timer.periodic(_interval, (_) => unawaited(_advance()));
  }

  Future<void> _advance() async {
    if (!mounted || _tips.isEmpty) return;
    final next = _index + 1;
    if (next >= _tips.length) {
      await _loadTips(refresh: true, resetIndex: true);
      return;
    }
    setState(() => _index = next);
    _progress
      ..reset()
      ..forward();
  }

  Future<void> _loadTips({
    required bool refresh,
    required bool resetIndex,
  }) async {
    setState(() => _refreshing = true);
    final dash = ref.read(dashboardDataProvider).valueOrNull;
    final weather = ref.read(deviceWeatherProvider).valueOrNull;
    final merged = dash != null
        ? applyDeviceWeatherToDashboard(dash, weather)
        : null;

    final batch = await fetchSafetyHealthTips(
      tempCelsius: merged?.tempCelsius ?? widget.tempCelsius,
      weatherMain: merged?.weatherMain,
      airQualityAqi: merged?.airQualityAqi,
      refresh: refresh,
    );

    if (!mounted) return;
    setState(() {
      _tips = batch.tips.isNotEmpty
          ? batch.tips
          : List<SafetyHealthTip>.from(kSafetyHealthTipsLocal);
      _source = batch.source;
      _mealRecommendations = batch.mealRecommendations;
      if (resetIndex) _index = 0;
      if (_index >= _tips.length) _index = 0;
      _refreshing = false;
    });
    _startRotation();
  }

  @override
  Widget build(BuildContext context) {
    final tip = _tips.isEmpty
        ? kSafetyHealthTipsLocal.first
        : _tips[_index.clamp(0, _tips.length - 1)];
    final total = _tips.isEmpty ? 1 : _tips.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'YOUR DIETITIAN',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _textLight,
                letterSpacing: 1.0,
              ),
            ),
            const Spacer(),
            if (_refreshing)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _primary,
                ),
              )
            else
              Text(
                '${_index + 1} / $total',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _textLight,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _rule),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.08),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Row(
                  key: ValueKey<String>('${_source}_$_index'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: _softTint,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(tip.icon, color: _primary, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tip.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _textMain,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            tip.body,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _textLight,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AnimatedBuilder(
                animation: _progress,
                builder: (context, _) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: _progress.value,
                      minHeight: 3,
                      backgroundColor: _rule,
                      color: _primary,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        if (_mealRecommendations != null &&
            _mealRecommendations!.recommendations.isNotEmpty) ...[
          const SizedBox(height: 16),
          _MealHistoryRecommendationsCard(advice: _mealRecommendations!),
        ],
      ],
    );
  }
}

class _MealHistoryRecommendationsCard extends StatelessWidget {
  const _MealHistoryRecommendationsCard({required this.advice});

  final SafetyMealRecommendations advice;

  static const Color _primary = Color(0xFF1A5D1A);
  static const Color _softTint = Color(0xFFF2F8F2);
  static const Color _textMain = Color(0xFF334155);
  static const Color _textLight = Color(0xFF64748B);
  static const Color _rule = Color(0xFFE2E8F0);

  IconData _iconFor(String category) {
    switch (category.toLowerCase()) {
      case 'protein':
        return Icons.egg_outlined;
      case 'balance':
      case 'fibre':
        return Icons.eco_outlined;
      case 'hydration':
        return Icons.water_drop_outlined;
      case 'portion':
        return Icons.restaurant_outlined;
      case 'energy':
        return Icons.bolt_outlined;
      default:
        return Icons.favorite_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: _softTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.restaurant_menu, color: _primary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      advice.headline,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _textMain,
                      ),
                    ),
                    Text(
                      advice.mealsReviewed == 0
                          ? 'From Nutrition History'
                          : 'Based on ${advice.mealsReviewed} logged meal${advice.mealsReviewed == 1 ? '' : 's'}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _textLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (advice.summary.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              advice.summary,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _textLight,
                height: 1.45,
              ),
            ),
          ],
          if (advice.recentMeals.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: advice.recentMeals.take(5).map((name) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _softTint,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    name,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _primary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 14),
          ...advice.recommendations.map((rec) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_iconFor(rec.category), color: _primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rec.title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _textMain,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          rec.detail,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _textLight,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

