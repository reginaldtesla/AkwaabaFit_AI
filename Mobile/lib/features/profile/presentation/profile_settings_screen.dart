import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/dashboard/presentation/dashboard_screen.dart';
import 'package:mobile/features/fitness/presentation/activity_tracking_screen.dart';
import 'package:mobile/features/nutrition/presentation/nutrition_history_screen.dart';
import 'package:mobile/features/safety/presentation/health_safety_hub_screen.dart';
import 'package:mobile/shared/navigation/app_bottom_nav.dart';

// =====================================================================
// 1. STATE MANAGEMENT & DATA MODELS
// =====================================================================

class UserProfile {
  final String name;
  final String membershipId;
  final String avatarUrl;
  final double weightKg;
  final int heightCm;
  final String bloodType;
  final bool isBiometricEnabled;

  UserProfile({
    required this.name,
    required this.membershipId,
    required this.avatarUrl,
    required this.weightKg,
    required this.heightCm,
    required this.bloodType,
    required this.isBiometricEnabled,
  });

  UserProfile copyWith({
    String? name,
    String? membershipId,
    String? avatarUrl,
    double? weightKg,
    int? heightCm,
    String? bloodType,
    bool? isBiometricEnabled,
  }) {
    return UserProfile(
      name: name ?? this.name,
      membershipId: membershipId ?? this.membershipId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      bloodType: bloodType ?? this.bloodType,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
    );
  }
}

final profileProvider =
    StateNotifierProvider<ProfileNotifier, AsyncValue<UserProfile>>((ref) {
  return ProfileNotifier();
});

class ProfileNotifier extends StateNotifier<AsyncValue<UserProfile>> {
  ProfileNotifier() : super(const AsyncValue.loading()) {
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    await Future.delayed(const Duration(milliseconds: 600));
    state = AsyncValue.data(
      UserProfile(
        name: 'Amara Okafor',
        membershipId: '884-012',
        avatarUrl: 'https://i.pravatar.cc/300?img=25',
        weightKg: 64.5,
        heightCm: 168,
        bloodType: 'O+',
        isBiometricEnabled: true,
      ),
    );
  }

  void toggleBiometrics(bool value) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(isBiometricEnabled: value));
  }

  Future<void> saveProfile() async {
    debugPrint('Saving profile to backend...');
  }
}

// =====================================================================
// 2. THE UI SCREEN
// =====================================================================

class ProfileSettingsScreen extends ConsumerWidget {
  const ProfileSettingsScreen({super.key});

  // Brand Colors
  final Color primary = const Color(0xFF0A3D2E);
  final Color medicalBg = const Color(0xFFF9FAFB);
  final Color textDark = const Color(0xFF2D3132);
  final Color textLight = const Color(0xFF64748B);
  final Color dividerColor = const Color(0xFFE5E9EB);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(context, ref),
      body: profileState.when(
        loading: () => Center(child: CircularProgressIndicator(color: primary)),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (data) => _buildContent(context, ref, data),
      ),
      bottomNavigationBar: AppBottomNav(
        activeTab: AppTab.profile,
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
        return;
    }
  }

  // --- UI Components ---

  PreferredSizeWidget _buildAppBar(BuildContext context, WidgetRef ref) {
    return AppBar(
      backgroundColor: Colors.white.withOpacity(0.9),
      elevation: 0,
      scrolledUnderElevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFF0F0F0), height: 1),
      ),
      leadingWidth: 90,
      leading: TextButton.icon(
        onPressed: () => Navigator.pop(context),
        icon: Icon(Icons.chevron_left, color: primary, size: 28),
        label: Text(
          'Back',
          style: GoogleFonts.inter(
            color: primary,
            fontSize: 17,
            fontWeight: FontWeight.w400,
          ),
        ),
        style: TextButton.styleFrom(padding: EdgeInsets.zero),
      ),
      title: Text(
        'Profile Settings',
        style: GoogleFonts.inter(
          color: textDark,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
      ),
      centerTitle: true,
      actions: [
        TextButton(
          onPressed: () => ref.read(profileProvider.notifier).saveProfile(),
          child: Text(
            'Save',
            style: GoogleFonts.inter(
              color: primary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, UserProfile data) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildProfileHeader(data),
          _buildStatsRow(data),
          Container(
            color: medicalBg,
            padding: const EdgeInsets.only(top: 24, bottom: 48),
            child: Column(
              children: [
                _buildHealthGoals(),
                const SizedBox(height: 24),
                _buildEmergencyContact(),
                const SizedBox(height: 24),
                _buildAccountSafety(ref, data),
                const SizedBox(height: 24),
                _buildSignOutButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(UserProfile data) {
    return Container(
      width: double.infinity,
      color: medicalBg,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black.withOpacity(0.05)),
                  image: DecorationImage(
                    image: NetworkImage(data.avatarUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.photo_camera, color: Colors.white, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            data.name,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textDark,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Premium Member • ID: ${data.membershipId}',
            style: GoogleFonts.inter(fontSize: 14, color: textLight),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(UserProfile data) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border.symmetric(horizontal: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Row(
        children: [
          Expanded(child: _buildStatItem('Weight', '${data.weightKg}', 'kg', true)),
          Expanded(child: _buildStatItem('Height', '${data.heightCm}', 'cm', true)),
          Expanded(
            child: _buildStatItem(
              'Blood',
              data.bloodType,
              '',
              false,
              valueColor: Colors.red.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    String unit,
    bool showBorder, {
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: showBorder ? const Border(right: BorderSide(color: Color(0xFFF0F0F0))) : null,
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF94A3B8),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? textDark,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 2),
                Text(unit, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8))),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthGoals() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Health Goals'),
          Container(
            decoration: _cardDecoration(),
            child: Column(
              children: [
                _buildListTile(
                  icon: Icons.restaurant,
                  title: 'Low Sodium Diet',
                  subtitle: 'Managing Hypertension',
                  trailing: Icon(Icons.check_circle, color: primary, size: 20),
                  showBorder: true,
                ),
                _buildListTile(
                  icon: Icons.fitness_center,
                  title: 'Activity Goal',
                  subtitle: '10,000 steps daily',
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1), size: 20),
                  showBorder: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyContact() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Emergency Contact'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Icon(Icons.medical_services, color: Colors.red.shade600),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'David Okafor',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Spouse • +233 24 555 0192',
                        style: GoogleFonts.inter(fontSize: 13, color: textLight),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    'Change',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSafety(WidgetRef ref, UserProfile data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Account & Safety'),
          Container(
            decoration: _cardDecoration(),
            child: Column(
              children: [
                _buildListTile(
                  icon: Icons.fingerprint,
                  title: 'Biometric Login',
                  trailing: CupertinoSwitch(
                    value: data.isBiometricEnabled,
                    activeColor: primary,
                    onChanged: (val) => ref.read(profileProvider.notifier).toggleBiometrics(val),
                  ),
                  showBorder: true,
                  isMinimal: true,
                ),
                _buildListTile(
                  icon: Icons.notifications,
                  title: 'Medical Alerts',
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1)),
                  showBorder: true,
                  isMinimal: true,
                ),
                _buildListTile(
                  icon: Icons.shield,
                  title: 'Data Privacy',
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1)),
                  showBorder: false,
                  isMinimal: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignOutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: () {
                // TODO: Handle Sanctum Logout
              },
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.red,
                side: const BorderSide(color: Color(0xFFE5E9EB)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              icon: const Icon(Icons.logout, size: 20),
              label: Text('Sign Out', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'AKWAABAFIT AI v2.4.1 (MEDICAL EDITION)',
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8), letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: textLight,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget trailing,
    required bool showBorder,
    bool isMinimal = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: showBorder ? const Border(bottom: BorderSide(color: Color(0xFFF0F0F0))) : null,
      ),
      child: Row(
        children: [
          if (!isMinimal)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFE7F0ED),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: primary),
            )
          else
            Icon(icon, color: primary, size: 22),
          SizedBox(width: isMinimal ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: isMinimal ? FontWeight.normal : FontWeight.w600,
                    color: textDark,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: GoogleFonts.inter(fontSize: 13, color: textLight)),
                ],
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: dividerColor),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.02),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}

