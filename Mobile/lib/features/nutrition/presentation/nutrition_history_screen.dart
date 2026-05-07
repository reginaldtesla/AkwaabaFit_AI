import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/ai_scanner/presentation/ai_scanner_screen.dart';
import 'package:mobile/features/dashboard/presentation/dashboard_screen.dart';
import 'package:mobile/features/fitness/presentation/activity_tracking_screen.dart';
import 'package:mobile/features/placeholders/presentation/placeholder_screen.dart';
import 'package:mobile/features/profile/presentation/profile_settings_screen.dart';
import 'package:mobile/features/safety/presentation/health_safety_hub_screen.dart';
import 'package:mobile/shared/navigation/app_bottom_nav.dart';

// =====================================================================
// 1. STATE MANAGEMENT & DATA MODELS
// =====================================================================

enum SafetyStatus { safe, watch, alert }

class MealLog {
  final String id;
  final String name;
  final String time;
  final String category;
  final int? protein;
  final int? carbs;
  final int? fat;
  final SafetyStatus status;
  final String? insightMessage;
  final String imageUrl;

  MealLog({
    required this.id,
    required this.name,
    required this.time,
    required this.category,
    this.protein,
    this.carbs,
    this.fat,
    required this.status,
    this.insightMessage,
    required this.imageUrl,
  });
}

class DailyNutrition {
  final String dayLabel;
  final int totalKcal;
  final List<MealLog> meals;

  DailyNutrition({
    required this.dayLabel,
    required this.totalKcal,
    required this.meals,
  });
}

// Mock Provider - Replace later with a Dio GET request (e.g. /api/nutrition/history)
final nutritionHistoryProvider = FutureProvider<List<DailyNutrition>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 600));
  return [
    DailyNutrition(
      dayLabel: 'Today',
      totalKcal: 1420,
      meals: [
        MealLog(
          id: '1',
          name: 'Avocado & Egg Toast',
          time: '08:30 AM',
          category: 'Breakfast',
          protein: 12,
          carbs: 24,
          fat: 18,
          status: SafetyStatus.safe,
          imageUrl:
              'https://images.unsplash.com/photo-1525351484163-7529414344d8?w=200&fit=crop',
        ),
        MealLog(
          id: '2',
          name: 'Mediterranean Quinoa',
          time: '01:15 PM',
          category: 'Lunch',
          status: SafetyStatus.watch,
          insightMessage:
              'Slightly high sodium content for today\'s health target.',
          imageUrl:
              'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=200&fit=crop',
        ),
      ],
    ),
  ];
});

// =====================================================================
// 2. THE UI SCREEN
// =====================================================================

class NutritionHistoryScreen extends ConsumerStatefulWidget {
  const NutritionHistoryScreen({super.key});

  @override
  ConsumerState<NutritionHistoryScreen> createState() =>
      _NutritionHistoryScreenState();
}

class _NutritionHistoryScreenState extends ConsumerState<NutritionHistoryScreen> {
  // Theme Colors
  final Color primary = const Color(0xFF5C5A30);
  final Color slate800 = const Color(0xFF1E293B);
  final Color dashboardGreen = const Color(0xFF1A5D1A);

  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Breakfast', 'Lunch', 'Dinner', 'Snacks'];

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(nutritionHistoryProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            _buildFilters(),
            Expanded(
              child: historyState.when(
                loading: () =>
                    Center(child: CircularProgressIndicator(color: primary)),
                error: (err, stack) =>
                    const Center(child: Text('Error loading history')),
                data: (days) => ListView.builder(
                  padding:
                      const EdgeInsets.only(left: 24, right: 24, bottom: 120),
                  itemCount: days.length,
                  itemBuilder: (context, index) {
                    return _buildDailySection(days[index]);
                  },
                ),
              ),
            ),
          ],
        ),
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
        activeTab: AppTab.history,
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

  // --- UI Components ---

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MEDICAL WELLNESS',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: primary.withOpacity(0.6),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Nutrition History',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: slate800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blueGrey.shade100),
                ),
                child: Icon(Icons.tune, color: Colors.blueGrey.shade500, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search history...',
                hintStyle:
                    GoogleFonts.plusJakartaSans(color: Colors.blueGrey.shade400),
                prefixIcon: Icon(Icons.search, color: Colors.blueGrey.shade400),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 70,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = filter == _selectedFilter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilter = filter),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? primary : Colors.blueGrey.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border:
                      isSelected ? null : Border.all(color: Colors.blueGrey.shade100),
                ),
                alignment: Alignment.center,
                child: Text(
                  filter,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.blueGrey.shade500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDailySection(DailyNutrition daily) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16, top: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                daily.dayLabel,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: slate800,
                ),
              ),
              Text(
                '${daily.totalKcal} kcal total',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.blueGrey.shade400,
                ),
              ),
            ],
          ),
        ),
        ...daily.meals.map((meal) => _buildMealItem(meal)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMealItem(MealLog meal) {
    Color bgColor;
    Color textColor;
    String statusText;
    IconData? insightIcon;

    switch (meal.status) {
      case SafetyStatus.safe:
        bgColor = const Color(0xFFF0F9F4);
        textColor = const Color(0xFF4F8B6F);
        statusText = 'SAFE';
        insightIcon = Icons.check_circle;
        break;
      case SafetyStatus.watch:
        bgColor = const Color(0xFFFFF9EB);
        textColor = const Color(0xFFB38B3E);
        statusText = 'WATCH';
        insightIcon = Icons.info;
        break;
      case SafetyStatus.alert:
        bgColor = const Color(0xFFFFF5F5);
        textColor = const Color(0xFFC16B6B);
        statusText = 'ALERT';
        insightIcon = null;
        break;
    }

    final isMacro = meal.insightMessage == null &&
        (meal.protein != null || meal.carbs != null || meal.fat != null);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.blueGrey.shade50)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              image: DecorationImage(
                image: NetworkImage(meal.imageUrl),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meal.name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: slate800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${meal.time} • ${meal.category}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: Colors.blueGrey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: textColor.withOpacity(0.1)),
                      ),
                      child: Text(
                        statusText,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                if (meal.insightMessage != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: bgColor.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (insightIcon != null) ...[
                          Icon(insightIcon, size: 16, color: textColor),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            meal.insightMessage!,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: textColor,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (isMacro) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (meal.protein != null) _buildMacroText('${meal.protein}g', 'P'),
                      if (meal.carbs != null) _buildMacroText('${meal.carbs}g', 'C'),
                      if (meal.fat != null) _buildMacroText('${meal.fat}g', 'F'),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroText(String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.blueGrey.shade600,
          ),
          children: [
            TextSpan(text: value),
            const TextSpan(text: ' '),
            TextSpan(
              text: label,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.normal,
                color: Colors.blueGrey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

