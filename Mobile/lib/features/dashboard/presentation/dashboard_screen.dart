import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/features/ai_scanner/presentation/ai_scanner_screen.dart';
import 'package:mobile/features/auth/presentation/auth_screen.dart';
import 'package:mobile/features/fitness/presentation/activity_tracking_screen.dart';
import 'package:mobile/features/fitness/data/steps_today_provider.dart';
import 'package:mobile/features/placeholders/presentation/placeholder_screen.dart';
import 'package:mobile/features/nutrition/presentation/nutrition_history_screen.dart';
import 'package:mobile/features/profile/presentation/profile_settings_screen.dart';
import 'package:mobile/features/safety/presentation/health_safety_hub_screen.dart';
import 'package:mobile/shared/navigation/app_bottom_nav.dart';

// =====================================================================
// 1. STATE MANAGEMENT (RIVERPOD DATA MODELS)
// =====================================================================

class DashboardData {
  final String userName;
  final String avatarUrl;
  final int netKcal;
  final int consumedKcal;
  final int burnedKcal;
  final double tempCelsius;
  final String location;
  final double hydrationLiters;
  final double hydrationGoal;
  final int currentSteps;
  final int stepGoal;

  DashboardData({
    required this.userName,
    required this.avatarUrl,
    required this.netKcal,
    required this.consumedKcal,
    required this.burnedKcal,
    required this.tempCelsius,
    required this.location,
    required this.hydrationLiters,
    required this.hydrationGoal,
    required this.currentSteps,
    required this.stepGoal,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      userName: (json['userName'] ?? '').toString(),
      avatarUrl: (json['avatarUrl'] ?? 'https://i.pravatar.cc/150?img=5')
          .toString(),
      netKcal: (json['netKcal'] as num?)?.toInt() ?? 0,
      consumedKcal: (json['consumedKcal'] as num?)?.toInt() ?? 0,
      burnedKcal: (json['burnedKcal'] as num?)?.toInt() ?? 0,
      tempCelsius: (json['tempCelsius'] as num?)?.toDouble() ?? 0.0,
      location: (json['location'] ?? '—').toString(),
      hydrationLiters: (json['hydrationLiters'] as num?)?.toDouble() ?? 0.0,
      hydrationGoal: (json['hydrationGoal'] as num?)?.toDouble() ?? 0.0,
      currentSteps: (json['currentSteps'] as num?)?.toInt() ?? 0,
      stepGoal: (json['stepGoal'] as num?)?.toInt() ?? 0,
    );
  }
}

// In production, this will use Dio to fetch from Laravel `GET /api/dashboard`.
final dashboardDataProvider = FutureProvider<DashboardData>((ref) async {
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

  final response = await dio.get('/dashboard');
  if (response.data is! Map<String, dynamic>) {
    throw Exception('Unexpected dashboard response.');
  }
  return DashboardData.fromJson(response.data as Map<String, dynamic>);
});

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
    final dashboardState = ref.watch(dashboardDataProvider);
    final stepsTodayAsync = ref.watch(stepsTodayProvider);

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
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (data) {
          final liveSteps = stepsTodayAsync.valueOrNull;
          final merged = liveSteps == null
              ? data
              : DashboardData(
                  userName: data.userName,
                  avatarUrl: data.avatarUrl,
                  netKcal: data.netKcal,
                  consumedKcal: data.consumedKcal,
                  burnedKcal: data.burnedKcal,
                  tempCelsius: data.tempCelsius,
                  location: data.location,
                  hydrationLiters: data.hydrationLiters,
                  hydrationGoal: data.hydrationGoal,
                  currentSteps: liveSteps,
                  stepGoal: data.stepGoal,
                );
          return _buildContent(context, merged);
        },
      ),

      // Floating Action Button (Scan Meal)
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

      // Custom Bottom Navigation
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

  Widget _buildContent(BuildContext context, DashboardData data) {
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          24,
          16,
          24,
          120,
        ), // Bottom padding for FAB/Nav
        child: Column(
          children: [
            _buildHeader(data.userName, data.avatarUrl),
            const SizedBox(height: 24),
            _buildCalorieCard(data),
            const SizedBox(height: 16),
            _buildWeatherSafetyCard(data),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildHydrationCard(data)),
                const SizedBox(width: 16),
                Expanded(child: _buildStepsCard(data)),
              ],
            ),
            const SizedBox(height: 16),
            _buildAIInsightCard(context),
          ],
        ),
      ),
    );
  }

  // --- Components ---

  Widget _buildHeader(String name, String avatarUrl) {
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
        Container(
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
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.red.shade500,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalorieCard(DashboardData data) {
    final double progress =
        data.netKcal / (data.consumedKcal > 0 ? data.consumedKcal : 1);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Text(
            'CALORIE BALANCE',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey.shade400,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 12,
                  color: Colors.blueGrey.shade100,
                ),
                CircularProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  strokeWidth: 12,
                  backgroundColor: Colors.transparent,
                  color: primary,
                  strokeCap: StrokeCap.round,
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '+${data.netKcal}',
                      style: GoogleFonts.inter(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: slate900,
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      'NET KCAL TODAY',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey.shade400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: _buildMacroStat(
                  'CONSUMED',
                  data.consumedKcal.toString(),
                  primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMacroStat(
                  'BURNED',
                  data.burnedKcal.toString(),
                  Colors.blueGrey.shade300,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey.shade500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: slate900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherSafetyCard(DashboardData data) {
    final bool isHighHeat = data.tempCelsius >= 32.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.wb_sunny, color: Colors.amber.shade500, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${data.tempCelsius.toInt()}°C',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: slate900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isHighHeat)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'HIGH HEAT',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                  ],
                ),
                Text(
                  data.location,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.blueGrey.shade400,
                  ),
                ),
              ],
            ),
          ),
          if (isHighHeat)
            Container(
              width: 100,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primary.withOpacity(0.1)),
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
                    'Increase water intake by 500ml',
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
      ),
    );
  }

  Widget _buildHydrationCard(DashboardData data) {
    final goal = data.hydrationGoal <= 0 ? 1.0 : data.hydrationGoal;
    return _buildProgressCard(
      icon: Icons.local_drink,
      iconColor: Colors.lightBlue.shade600,
      iconBg: Colors.lightBlue.shade50,
      title: 'Hydration',
      current: '${data.hydrationLiters}',
      goal: '${data.hydrationGoal}L',
      progressColor: Colors.lightBlue.shade500,
      progressValue: data.hydrationLiters / goal,
    );
  }

  Widget _buildStepsCard(DashboardData data) {
    final goal = data.stepGoal <= 0 ? 1 : data.stepGoal;
    return _buildProgressCard(
      icon: Icons.directions_walk,
      iconColor: Colors.green.shade600,
      iconBg: Colors.green.shade50,
      title: 'Daily Steps',
      current: '${(data.currentSteps / 1000).toStringAsFixed(1)}k',
      goal: '${(data.stepGoal / 1000).toStringAsFixed(0)}k',
      progressColor: Colors.green.shade500,
      progressValue: data.currentSteps / goal,
    );
  }

  Widget _buildProgressCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String current,
    required String goal,
    required Color progressColor,
    required double progressValue,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              Text(
                '$current / $goal',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: slate900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressValue.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.blueGrey.shade100,
              color: progressColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIInsightCard(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const HealthSafetyHubScreen()),
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
                  'Your heart rate recovery has improved by 4% this week. Consider a 15-min light jog tonight to maintain progress.',
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
}

