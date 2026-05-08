import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/ai_scanner/presentation/ai_scanner_screen.dart';
import 'package:mobile/features/auth/presentation/auth_screen.dart';
import 'package:mobile/features/dashboard/presentation/dashboard_screen.dart';
import 'package:mobile/features/fitness/presentation/daily_leaderboard_screen.dart';
import 'package:mobile/features/fitness/data/steps_today_provider.dart';
import 'package:mobile/features/nutrition/presentation/nutrition_history_screen.dart';
import 'package:mobile/features/placeholders/presentation/placeholder_screen.dart';
import 'package:mobile/features/profile/presentation/profile_settings_screen.dart';
import 'package:mobile/features/safety/presentation/health_safety_hub_screen.dart';
import 'package:mobile/shared/navigation/app_bottom_nav.dart';

// =====================================================================
// 1. STATE MANAGEMENT (RIVERPOD DATA MODELS)
// =====================================================================

class ActivityData {
  final int stepsToday;
  final int stepGoal;
  final int streakDays;
  final int calories;
  final double distanceKm;
  final List<double> hourlyData; // Values between 0.0 and 1.0 for the bar chart

  ActivityData({
    required this.stepsToday,
    required this.stepGoal,
    required this.streakDays,
    required this.calories,
    required this.distanceKm,
    required this.hourlyData,
  });

  int get stepsLeft => stepGoal - stepsToday > 0 ? stepGoal - stepsToday : 0;
  double get progress => stepGoal <= 0 ? 0 : stepsToday / stepGoal;

  factory ActivityData.fromJson(Map<String, dynamic> json) {
    final raw = (json['hourlyData'] as List?) ?? const [];
    final values = raw
        .map((e) => (e as num?)?.toDouble() ?? 0.0)
        .toList(growable: false);

    return ActivityData(
      stepsToday: (json['stepsToday'] as num?)?.toInt() ?? 0,
      stepGoal: (json['stepGoal'] as num?)?.toInt() ?? 10000,
      streakDays: (json['streakDays'] as num?)?.toInt() ?? 0,
      calories: (json['calories'] as num?)?.toInt() ?? 0,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      hourlyData: values.length == 8 ? values : List.filled(8, 0.0),
    );
  }
}

// Live provider - fetch from Laravel `GET /api/activity/today`
final activityDataProvider = FutureProvider<ActivityData>((ref) async {
  const storage = FlutterSecureStorage();
  final token = await storage.read(key: 'sanctum_token');
  if (token == null || token.isEmpty) {
    throw Exception('Missing auth token. Please login again.');
  }

  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://10.0.2.2:8000/api',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ),
  );

  final response = await dio.get('/activity/today');
  if (response.data is! Map<String, dynamic>) {
    throw Exception('Unexpected activity response.');
  }

  return ActivityData.fromJson(response.data as Map<String, dynamic>);
});

// =====================================================================
// 2. THE UI SCREEN
// =====================================================================

class ActivityTrackingScreen extends ConsumerWidget {
  const ActivityTrackingScreen({super.key});

  // Theme Colors from Design
  static const Color primaryGreen = Color(0xFF10B981);
  static const Color secondaryBlue = Color(0xFF3B82F6);
  static const Color slateCustom = Color(0xFF64748B);
  static const Color cardBg = Color(0xFFFAFAFA);
  static const Color textDark = Color(0xFF0F172A);
  static const Color dashboardGreen = Color(0xFF1A5D1A);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityState = ref.watch(activityDataProvider);
    final stepsTodayAsync = ref.watch(stepsTodayProvider);

    if (activityState.hasError &&
        activityState.error.toString().contains('Missing auth token')) {
      return const AuthScreen();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: activityState.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: secondaryBlue)),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (data) {
          final liveSteps = stepsTodayAsync.valueOrNull;
          final merged = liveSteps == null
              ? data
              : ActivityData(
                  stepsToday: liveSteps,
                  stepGoal: data.stepGoal,
                  streakDays: data.streakDays,
                  calories: data.calories,
                  distanceKm: data.distanceKm,
                  hourlyData: data.hourlyData,
                );
          return _buildContent(context, merged);
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 20),
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
                  color: dashboardGreen,
                ),
              ),
            ),
            FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AiScannerScreen()),
                );
              },
              backgroundColor: dashboardGreen,
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

  Widget _buildContent(BuildContext context, ActivityData data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildHeader(context),
          const SizedBox(height: 32),
          _buildProgressRing(data),
          const SizedBox(height: 32),
          _buildQuickStats(data),
          const SizedBox(height: 24),
          _buildMetricsGrid(data),
          const SizedBox(height: 24),
          _buildHourlyChart(data),
          const SizedBox(height: 24),
          _buildWellnessAdvice(),
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
                color: textDark,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'Today',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: slateCustom,
              ),
            ),
          ],
        ),
        Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DailyLeaderboardScreen()),
                );
              },
              child: _buildIconButton(Icons.emoji_events_outlined),
            ),
            const SizedBox(width: 12),
            _buildIconButton(Icons.account_circle),
          ],
        ),
      ],
    );
  }

  Widget _buildIconButton(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Icon(icon, color: Colors.blueGrey.shade600, size: 20),
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
            color: secondaryBlue,
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
                  color: slateCustom,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${data.stepsToday}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  color: textDark,
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
          _buildStatColumn('GOAL', '${data.stepGoal}', textDark),
          Container(width: 1, height: 40, color: Colors.blueGrey.shade100),
          _buildStatColumn('LEFT', '${data.stepsLeft}', secondaryBlue),
          Container(width: 1, height: 40, color: Colors.blueGrey.shade100),
          _buildStatColumn('STREAK', '${data.streakDays} Days', primaryGreen),
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

  Widget _buildMetricsGrid(ActivityData data) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            icon: Icons.local_fire_department,
            iconColor: secondaryBlue,
            bgColor: Colors.blue.shade50,
            badgeText: '+5%',
            value: '${data.calories}',
            label: 'Calories (kcal)',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
            icon: Icons.near_me,
            iconColor: primaryGreen,
            bgColor: Colors.green.shade50,
            badgeText: '+2%',
            value: '${data.distanceKm}',
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
    required String badgeText,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.blueGrey.shade50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration:
                    BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              Text(
                badgeText,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
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
              color: textDark,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: slateCustom,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyChart(ActivityData data) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.blueGrey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hourly Analysis',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
              Row(
                children: [
                  Icon(Icons.share, color: Colors.blueGrey.shade400, size: 20),
                  const SizedBox(width: 12),
                  Icon(Icons.more_horiz, color: Colors.blueGrey.shade400, size: 20),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(data.hourlyData.length, (index) {
                Color barColor = Colors.blue.shade100;
                if (index == 3 || index == 4) barColor = secondaryBlue;
                if (index == 5) barColor = primaryGreen;
                if (index == 6 || index == 7) barColor = Colors.green.shade100;

                return Container(
                  width: 24,
                  height: 120 * data.hourlyData[index],
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWellnessAdvice() {
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
              border: Border.all(color: Colors.blueGrey.shade100.withOpacity(0.5)),
            ),
            child: const Icon(Icons.psychology, color: secondaryBlue, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Wellness Advice',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Based on your current pace, you are on track to exceed your goal. A short walk after dinner will optimize your metabolic rate for better sleep.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                    color: slateCustom,
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

