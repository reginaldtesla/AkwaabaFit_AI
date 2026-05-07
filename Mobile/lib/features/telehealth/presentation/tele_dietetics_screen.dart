import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/dashboard/presentation/dashboard_screen.dart';
import 'package:mobile/features/fitness/presentation/activity_tracking_screen.dart';
import 'package:mobile/features/nutrition/presentation/nutrition_history_screen.dart';
import 'package:mobile/features/profile/presentation/profile_settings_screen.dart';
import 'package:mobile/features/safety/presentation/health_safety_hub_screen.dart';
import 'package:mobile/shared/navigation/app_bottom_nav.dart';

// =====================================================================
// 1. STATE MANAGEMENT & DATA MODELS
// =====================================================================

class Dietitian {
  final String id;
  final String name;
  final String specialty;
  final String category;
  final double rating;
  final int hourlyRate;
  final String imageUrl;

  Dietitian({
    required this.id,
    required this.name,
    required this.specialty,
    required this.category,
    required this.rating,
    required this.hourlyRate,
    required this.imageUrl,
  });
}

final selectedCategoryProvider = StateProvider<String>((ref) => 'All');

final dietitiansProvider = FutureProvider<List<Dietitian>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 600));

  final allDietitians = [
    Dietitian(
      id: '1',
      name: 'Dr. Kwame Osei',
      specialty: 'Post-Natal Nutrition',
      category: 'Post-Natal',
      rating: 4.9,
      hourlyRate: 150,
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCFN01rKnYW7Wuc9CPEu2beYvmvu7wRissG3_Mv2uKgUIWMRSrqk5_KCUdWhO4aU5YPeS4Srn5CTP_dkKeJzu25tgqEW-lIOj-WmpX44T4bsm3DAwszoZHOOe7iUW2zqZ5GAsNswbFuuqmn0Igmh9PRC-k9fjyGtM50BWq_ja5ftZ1hctGd9fjvV_sj9imezKr7fEYXm9y5FzAoa_TGMhT_EFnOk3sa31w-C3-sgDM3WVAIBnZMXAU7wuPDbdWEA6cG29yfyZ2MxpI',
    ),
    Dietitian(
      id: '2',
      name: 'Ama Mensah',
      specialty: 'Sports Dietician',
      category: 'Athletic',
      rating: 4.7,
      hourlyRate: 120,
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCfqPT5OmEljlMpiKnXwVnsCI_2SBFd0FHIOLfkNsAvFQHWuVT4qyeD7d7p8nEf6JSvSi_8M09ypiJ4UfMiQebQx5jSW6ZmxRhPTgA_StTYJ8M3iV-0USUJDIxuQ1fV9rgtkAVStSEBLs44YHnhNGudE2rkschjh5a65iKpVhY-ynbPNKiL8buPaMjVvc6n8-pM6lmOA4sLZBIfGOKEJPV0XX4S8ID3YZqCqYgFOt_wJD3XD6ZS2JH05_eNjGSCw9ZvYpiPs806rrc',
    ),
  ];

  final selectedCategory = ref.watch(selectedCategoryProvider);

  if (selectedCategory == 'All') return allDietitians;
  return allDietitians.where((d) => d.category == selectedCategory).toList();
});

// =====================================================================
// 2. THE UI SCREEN
// =====================================================================

class TeleDieteticsScreen extends ConsumerWidget {
  const TeleDieteticsScreen({super.key});

  final Color primary = const Color(0xFF0FBD74);
  final Color bgLight = const Color(0xFFFDFBF7);
  final Color surface = const Color(0xFFFFFFFF);
  final Color textMain = const Color(0xFF1A1A1A);
  final Color muted = const Color(0xFF8C8C8C);
  final Color accent = const Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          _buildFilterRow(ref),
          Expanded(child: _buildDietitianList(ref)),
        ],
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

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: bgLight.withOpacity(0.9),
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: textMain),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Tele-Dietetics',
        style: GoogleFonts.spaceGrotesk(
          color: textMain,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFilterRow(WidgetRef ref) {
    final categories = ['All', 'Post-Natal', 'Diabetes', 'Athletic'];
    final selectedCategory = ref.watch(selectedCategoryProvider);

    return Container(
      height: 60,
      color: bgLight.withOpacity(0.95),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == selectedCategory;

          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => ref.read(selectedCategoryProvider.notifier).state = category,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? primary : surface,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isSelected ? primary : Colors.grey.shade200,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: primary.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  category,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? Colors.white : muted,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDietitianList(WidgetRef ref) {
    final listState = ref.watch(dietitiansProvider);

    return listState.when(
      loading: () => Center(child: CircularProgressIndicator(color: primary)),
      error: (err, stack) => Center(
        child: Text(
          'Error loading providers',
          style: GoogleFonts.spaceGrotesk(),
        ),
      ),
      data: (dietitians) {
        if (dietitians.isEmpty) {
          return Center(
            child: Text(
              'No dietitians found for this category.',
              style: GoogleFonts.spaceGrotesk(color: muted, fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: dietitians.length,
          itemBuilder: (context, index) {
            return _buildProviderCard(context, dietitians[index]);
          },
        );
      },
    );
  }

  Widget _buildProviderCard(BuildContext context, Dietitian dietitian) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(10, 46, 31, 0.08),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
              image: DecorationImage(
                image: NetworkImage(dietitian.imageUrl),
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
                            dietitian.name,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textMain,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dietitian.specialty,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 14,
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF9E6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, color: accent, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            dietitian.rating.toString(),
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: textMain,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textMain,
                        ),
                        children: [
                          TextSpan(text: '₵${dietitian.hourlyRate}'),
                          TextSpan(
                            text: ' / hr',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 14,
                              fontWeight: FontWeight.normal,
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        _showBookingConfirmation(context, dietitian);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'BOOK',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBookingConfirmation(BuildContext context, Dietitian dietitian) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Initiating Paystack for ${dietitian.name}...',
          style: GoogleFonts.spaceGrotesk(),
        ),
        backgroundColor: textMain,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

