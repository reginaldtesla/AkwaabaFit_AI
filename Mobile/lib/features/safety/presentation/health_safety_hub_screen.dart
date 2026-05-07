import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/ai_scanner/presentation/ai_scanner_screen.dart';
import 'package:mobile/features/dashboard/presentation/dashboard_screen.dart';
import 'package:mobile/features/fitness/presentation/activity_tracking_screen.dart';
import 'package:mobile/features/nutrition/presentation/nutrition_history_screen.dart';
import 'package:mobile/features/safety/presentation/emergency_sos_screen.dart';
import 'package:mobile/features/placeholders/presentation/placeholder_screen.dart';
import 'package:mobile/features/profile/presentation/profile_settings_screen.dart';
import 'package:mobile/features/telehealth/presentation/tele_dietetics_screen.dart';
import 'package:mobile/shared/navigation/app_bottom_nav.dart';

// =====================================================================
// 1. STATE MANAGEMENT & DATA MODELS
// =====================================================================

class SafetyHubData {
  final String userName;
  final int? feelingRating;
  final double currentHydration;
  final double hydrationGoal;
  final String location;
  final int temperatureCelsius;

  SafetyHubData({
    required this.userName,
    this.feelingRating,
    required this.currentHydration,
    required this.hydrationGoal,
    required this.location,
    required this.temperatureCelsius,
  });

  SafetyHubData copyWith({
    String? userName,
    int? feelingRating,
    double? currentHydration,
    double? hydrationGoal,
    String? location,
    int? temperatureCelsius,
  }) {
    return SafetyHubData(
      userName: userName ?? this.userName,
      feelingRating: feelingRating ?? this.feelingRating,
      currentHydration: currentHydration ?? this.currentHydration,
      hydrationGoal: hydrationGoal ?? this.hydrationGoal,
      location: location ?? this.location,
      temperatureCelsius: temperatureCelsius ?? this.temperatureCelsius,
    );
  }
}

final safetyHubProvider =
    StateNotifierProvider<SafetyHubNotifier, AsyncValue<SafetyHubData>>((ref) {
      return SafetyHubNotifier();
    });

class SafetyHubNotifier extends StateNotifier<AsyncValue<SafetyHubData>> {
  SafetyHubNotifier() : super(const AsyncValue.loading()) {
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.delayed(const Duration(milliseconds: 600));
    state = AsyncValue.data(
      SafetyHubData(
        userName: 'Alex',
        feelingRating: null,
        currentHydration: 2.4,
        hydrationGoal: 3.5,
        location: 'Accra, GH',
        temperatureCelsius: 32,
      ),
    );
  }

  void setFeelingRating(int rating) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(feelingRating: rating));
  }

  void logWater(double amount) {
    final current = state.value;
    if (current == null) return;
    final newAmount = (current.currentHydration + amount).clamp(
      0.0,
      current.hydrationGoal,
    );
    state = AsyncValue.data(current.copyWith(currentHydration: newAmount));
  }
}

// =====================================================================
// 2. THE UI SCREEN
// =====================================================================

class HealthSafetyHubScreen extends ConsumerWidget {
  const HealthSafetyHubScreen({super.key});

  // Brand Colors
  static const Color primary = Color(0xFF4A90E2);
  static const Color softBlue = Color(0xFFF0F7FF);
  static const Color calmBlue = Color(0xFFD1E9FF);
  static const Color background = Color(0xFFF9FBFE);
  static const Color textMain = Color(0xFF334155);
  static const Color textLight = Color(0xFF64748B);
  static const Color dashboardGreen = Color(0xFF1A5D1A);

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
        data: (data) => _buildContent(context, ref, data),
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
      backgroundColor: background.withOpacity(0.8),
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 80,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Safety Hub',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textMain,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.verified_user, color: primary, size: 16),
              const SizedBox(width: 4),
              Text(
                'Your Personal Health Guide',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: primary,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 24),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blueGrey.shade100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.notifications_outlined,
                  color: textLight,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
                  ],
                  image: const DecorationImage(
                    image: NetworkImage('https://i.pravatar.cc/150?img=12'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, SafetyHubData data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
      child: Column(
        children: [
          _buildWelcomeCard(data.userName),
          const SizedBox(height: 16),
          _buildTeleDieteticsButton(context),
          const SizedBox(height: 24),
          _buildWellnessCheck(ref, data),
          const SizedBox(height: 24),
          _buildHydrationCard(ref, data),
          const SizedBox(height: 24),
          _buildEnvironmentCard(data),
          const SizedBox(height: 32),
          _buildEmergencyButton(context),
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

  Widget _buildWelcomeCard(String name) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueGrey.shade50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: softBlue,
              shape: BoxShape.circle,
              border: Border.all(color: calmBlue.withOpacity(0.5)),
            ),
            child: const Icon(Icons.spa, color: primary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, $name',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textMain,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Let\'s stay comfortable and hydrated today.',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: textLight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeleDieteticsButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TeleDieteticsScreen()),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 6,
          shadowColor: primary.withOpacity(0.25),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.support_agent),
            const SizedBox(width: 10),
            Text(
              'Tele‑Dietetics',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWellnessCheck(WidgetRef ref, SafetyHubData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'WELLNESS CHECK',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: textLight,
                letterSpacing: 1.0,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: softBlue,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: calmBlue.withOpacity(0.5)),
              ),
              child: Text(
                'DAILY GUIDE',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: primary,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: _cardDecoration(),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: softBlue,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: calmBlue.withOpacity(0.5)),
                    ),
                    child: const Icon(Icons.favorite, color: primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How are you feeling?',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: textMain,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Checking in helps tailor your day.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: textLight,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(5, (index) {
                  final rating = index + 1;
                  final isSelected = data.feelingRating == rating;
                  return GestureDetector(
                    onTap: () =>
                        ref.read(safetyHubProvider.notifier).setFeelingRating(rating),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? softBlue
                            : Colors.blueGrey.shade50.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? primary : Colors.blueGrey.shade100,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: primary.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : [],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        rating == 5 ? '5+' : '$rating',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? primary : textLight,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHydrationCard(WidgetRef ref, SafetyHubData data) {
    final progress = data.hydrationGoal <= 0
        ? 0.0
        : (data.currentHydration / data.hydrationGoal);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: softBlue,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: calmBlue.withOpacity(0.5)),
                ),
                child: const Icon(Icons.water_drop, color: primary),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'CURRENT PROGRESS',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: primary,
                      letterSpacing: 1.0,
                    ),
                  ),
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: textMain,
                      ),
                      children: [
                        TextSpan(text: '${data.currentHydration.toStringAsFixed(1)}L '),
                        TextSpan(
                          text: '/ ${data.hydrationGoal}L',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                            color: textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Stay Fluid, Stay Energized',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: textMain,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Small, frequent sips keep you steady.',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: textLight, height: 1.4),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.blueGrey.shade100,
              color: primary,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => ref.read(safetyHubProvider.notifier).logWater(0.25),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                shadowColor: primary.withOpacity(0.4),
              ),
              child: Text(
                'Log a glass of water',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnvironmentCard(SafetyHubData data) {
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
                Icon(Icons.light_mode, color: Colors.amber.shade600, size: 16),
                const SizedBox(width: 4),
                Text(
                  'High Intensity',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade600,
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
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(32)),
                        color: Colors.blueGrey.shade100,
                      ),
                    ),
                    Positioned(
                      bottom: 20,
                      left: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data.location.toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: primary,
                              letterSpacing: 1.0,
                            ),
                          ),
                          Text(
                            '${data.temperatureCelsius}°C',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: textMain,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: softBlue,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: calmBlue.withOpacity(0.3)),
                      ),
                      child: Text(
                        '"The sun is quite strong today. Wearing light cotton and staying in the shade will keep you feeling refreshed."',
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
                        Expanded(child: _buildAdvicePill(Icons.checkroom, 'Cotton Wear')),
                        const SizedBox(width: 16),
                        Expanded(child: _buildAdvicePill(Icons.umbrella, 'Seek Shade')),
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
        color: Colors.blueGrey.shade50.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueGrey.shade100),
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

  Widget _buildEmergencyButton(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const EmergencySosScreen(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.pink.shade50),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 24,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.pink.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.pink.shade100.withOpacity(0.5)),
              ),
              child: Icon(Icons.support_agent, color: Colors.pink.shade500, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Emergency Support',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textMain,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Instant alert to your care network',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: textLight),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.blueGrey.shade300),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(32),
      border: Border.all(color: Colors.blueGrey.shade50),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 24,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}

