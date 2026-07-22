import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/features/dashboard/presentation/dashboard_screen.dart';
import 'package:mobile/features/safety/presentation/health_safety_hub_screen.dart';
import 'package:mobile/features/auth/presentation/auth_screen.dart';
import 'package:mobile/features/auth/presentation/splash_screen.dart';
import 'package:mobile/features/profile/presentation/accountability_partner_screen.dart';
import 'package:mobile/features/auth/presentation/health_profile_screen.dart';
import 'package:mobile/features/fitness/data/steps_today_provider.dart';
import 'package:mobile/shared/fitness/leaderboard_provider.dart';
import 'package:mobile/shared/fitness/steps_offline_recorder.dart';
import 'package:mobile/shared/profile/profile_repository.dart';
import 'package:mobile/shared/navigation/app_bottom_nav.dart';
import 'package:mobile/shared/navigation/main_tab_shell.dart';
import 'package:mobile/shared/config/app_config.dart';
import 'package:mobile/shared/fitness/foreground_notification_prefs.dart';

// =====================================================================
// 1. STATE MANAGEMENT & DATA MODELS
// =====================================================================

class UserProfile {
  final String name;
  final String membershipId;
  final String avatarUrl;
  final double weightKg;
  final int heightCm;

  UserProfile({
    required this.name,
    required this.membershipId,
    required this.avatarUrl,
    required this.weightKg,
    required this.heightCm,
  });

  UserProfile copyWith({
    String? name,
    String? membershipId,
    String? avatarUrl,
    double? weightKg,
    int? heightCm,
  }) {
    return UserProfile(
      name: name ?? this.name,
      membershipId: membershipId ?? this.membershipId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
    );
  }
}

final profileProvider = StateNotifierProvider.autoDispose<
    ProfileNotifier, AsyncValue<UserProfile>>((ref) {
  return ProfileNotifier(ref);
});

final stepGoalProvider = FutureProvider<int?>((ref) async {
  final repo = ref.read(profileRepositoryProvider);
  final current = await repo.readLocalProfile();
  final v = current?['step_goal'];
  if (v is int) return v;
  return int.tryParse((v ?? '').toString());
});

final dailyCaloriesGoalProvider = FutureProvider<int?>((ref) async {
  final repo = ref.read(profileRepositoryProvider);
  final current = await repo.readLocalProfile();
  final v = current?['daily_calories_target'];
  if (v is int) return v;
  return int.tryParse((v ?? '').toString());
});

final avatarUrlProvider = FutureProvider<String?>((ref) async {
  final repo = ref.read(profileRepositoryProvider);
  final current = await repo.readLocalProfile();
  final v = current?['avatar_url'] ?? current?['avatarUrl'];
  final s = (v ?? '').toString().trim();
  return s.isEmpty ? null : s;
});

final genderProvider = FutureProvider<String?>((ref) async {
  final repo = ref.read(profileRepositoryProvider);
  final current = await repo.readLocalProfile();
  final v = current?['gender'];
  final s = (v ?? '').toString().trim();
  return s.isEmpty ? null : s;
});

final publicLeaderboardProvider = FutureProvider<bool>((ref) async {
  final repo = ref.read(profileRepositoryProvider);
  final current = await repo.readLocalProfile();
  final v = current?['is_public_on_leaderboard'];
  if (v is bool) return v;
  if (v is int) return v == 1;
  return v?.toString() == '1' || v == true;
});

class ProfileNotifier extends StateNotifier<AsyncValue<UserProfile>> {
  ProfileNotifier(this.ref) : super(const AsyncValue.loading()) {
    _loadProfile();
  }

  final Ref ref;

  Future<void> _loadProfile() async {
    final repo = ref.read(profileRepositoryProvider);
    Map<String, dynamic>? local;

    try {
      local = await repo.readLocalProfile();

      if (local != null) {
        state = AsyncValue.data(_userProfileFromCache(local));
      } else {
        state = const AsyncValue.loading();
      }

      await repo.syncPendingIfAny();
      final remote = await repo.fetchRemoteAndCache();

      if (remote != null) {
        state = AsyncValue.data(_userProfileFromCache(remote));
      } else if (local == null) {
        state = AsyncValue.data(_fallbackUserProfile());
      }
    } catch (e, st) {
      if (local == null && state.valueOrNull == null) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  static UserProfile _userProfileFromCache(Map<String, dynamic> u) {
    final gender = (u['gender'] ?? '').toString().toLowerCase();
    final avatarRaw =
        (u['avatar_url'] ?? u['avatarUrl'] ?? '').toString().trim();
    final avatarUrl = avatarRaw.isNotEmpty
        ? AppConfig.normalizeUrlForDevice(avatarRaw)
        : (gender == 'female'
            ? 'https://i.pravatar.cc/150?img=47'
            : gender == 'male'
                ? 'https://i.pravatar.cc/150?img=12'
                : 'https://i.pravatar.cc/150?img=5');

    final weight = u['weight'];
    final height = u['height'];
    final weightKg = weight is num
        ? weight.toDouble()
        : double.tryParse('$weight') ?? 0.0;
    final heightCm = height is num
        ? height.round()
        : int.tryParse('$height') ??
            double.tryParse('$height')?.round() ??
            0;

    final id = u['id'];
    final membershipId = id != null ? '#${id.toString()}' : '—';

    return UserProfile(
      name: (u['name'] ?? 'Member').toString(),
      membershipId: membershipId,
      avatarUrl: avatarUrl,
      weightKg: weightKg > 0 ? weightKg : 0,
      heightCm: heightCm > 0 ? heightCm : 0,
    );
  }

  static UserProfile _fallbackUserProfile() {
    return UserProfile(
      name: 'Member',
      membershipId: '—',
      avatarUrl: 'https://i.pravatar.cc/150?img=5',
      weightKg: 0,
      heightCm: 0,
    );
  }

  Future<void> reloadFromRepo() => _loadProfile();

  Future<void> saveProfile() async {
    await ref.read(profileRepositoryProvider).syncPendingIfAny();
    await reloadFromRepo();
  }
}

// =====================================================================
// 2. THE UI SCREEN
// =====================================================================

class ProfileSettingsScreen extends ConsumerWidget {
  const ProfileSettingsScreen({super.key, this.showBottomNav = true});

  final bool showBottomNav;

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
      bottomNavigationBar: showBottomNav
          ? AppBottomNav(
              activeTab: AppTab.profile,
              onTabSelected: (tab) => _handleTab(context, tab),
            )
          : null,
    );
  }

  void _handleTab(BuildContext context, AppTab tab) {
    MainTabShell.open(context, tab: tab);
  }

  // --- UI Components ---

  PreferredSizeWidget _buildAppBar(BuildContext context, WidgetRef ref) {
    return AppBar(
      backgroundColor: Colors.white.withValues(alpha: 0.9),
      elevation: 0,
      scrolledUnderElevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFF0F0F0), height: 1),
      ),
      automaticallyImplyLeading: false,
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
      actions: const [],
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, UserProfile data) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildProfileHeader(context, ref, data),
          _buildStatsRow(data),
          Container(
            color: medicalBg,
            padding: const EdgeInsets.only(top: 24, bottom: 48),
            child: Column(
              children: [
                _buildHealthGoals(context, ref),
                const SizedBox(height: 24),
                _buildAccountSafety(context, ref, data),
                const SizedBox(height: 24),
                _buildSignOutButton(context, ref),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, WidgetRef ref, UserProfile data) {
    final avatarAsync = ref.watch(avatarUrlProvider);
    final genderAsync = ref.watch(genderProvider);

    final gender = (genderAsync.valueOrNull ?? '').toLowerCase();
    final fallback = gender == 'female'
        ? 'https://i.pravatar.cc/150?img=47'
        : gender == 'male'
            ? 'https://i.pravatar.cc/150?img=12'
            : data.avatarUrl;

    final avatarUrl = avatarAsync.valueOrNull ?? fallback;

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
                  border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                  image: DecorationImage(
                    image: NetworkImage(avatarUrl),
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
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 85,
                      maxWidth: 1024,
                    );
                    if (picked == null) return;

                    final url = await ref
                        .read(profileRepositoryProvider)
                        .uploadAvatar(File(picked.path));

                    if (url != null) {
                      ref.invalidate(avatarUrlProvider);
                      ref.invalidate(dashboardDataProvider);
                      ref.invalidate(leaderboardProvider);
                      await ref.read(profileProvider.notifier).reloadFromRepo();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Profile photo updated')),
                        );
                      }
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not update photo (check internet/login)'),
                          ),
                        );
                      }
                    }
                  },
                  child: const Icon(Icons.photo_camera, color: Colors.white, size: 18),
                ),
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
          Expanded(child: _buildStatItem('Height', '${data.heightCm}', 'cm', false)),
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

  Widget _buildHealthGoals(BuildContext context, WidgetRef ref) {
    final stepGoalAsync = ref.watch(stepGoalProvider);
    final stepGoalText = stepGoalAsync.when(
      data: (v) => (v == null || v <= 0) ? 'Tap to set your step goal' : '$v steps daily',
      loading: () => 'Loading...',
      error: (_, _) => 'Tap to set your step goal',
    );

    final dailyCalAsync = ref.watch(dailyCaloriesGoalProvider);
    final dailyCalSubtitle = dailyCalAsync.when(
      data: (v) => (v == null || v <= 0)
          ? 'Uses calories calculated from your health profile'
          : '$v kcal daily (custom goal)',
      loading: () => 'Loading...',
      error: (_, _) => 'Tap to set your calorie goal',
    );

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
                  icon: Icons.restaurant_menu,
                  title: 'Daily calorie goal',
                  subtitle: dailyCalSubtitle,
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1), size: 20),
                  showBorder: true,
                  onTap: () => _editDailyCalorieGoal(context, ref),
                ),
                _buildListTile(
                  icon: Icons.fitness_center,
                  title: 'Activity Goal',
                  subtitle: stepGoalText,
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1), size: 20),
                  showBorder: true,
                  onTap: () => _editStepGoal(context, ref),
                ),
                _buildListTile(
                  icon: Icons.people_outline,
                  title: 'Accountability partner',
                  subtitle: 'Link family or a friend',
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1), size: 20),
                  showBorder: false,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AccountabilityPartnerScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editDailyCalorieGoal(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(profileRepositoryProvider);
    final current = await repo.readLocalProfile();
    final existing = (current?['daily_calories_target'] as int?) ??
        int.tryParse((current?['daily_calories_target'] ?? '').toString());

    if (!context.mounted) return;

    final controller = TextEditingController(
      text: (existing == null || existing <= 0) ? '' : existing.toString(),
    );

    final res = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Daily calorie goal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set a fixed daily calorie target (800–8000 kcal), or use the value calculated from height, weight, activity, and goal.',
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'e.g. 2200',
                  suffixText: 'kcal',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(<String, dynamic>{'clear': true}),
              child: const Text('Use calculated'),
            ),
            TextButton(
              onPressed: () {
                final v = int.tryParse(controller.text.trim());
                if (v == null) return;
                Navigator.of(ctx).pop(<String, dynamic>{'value': v});
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (!context.mounted) return;
    if (res == null) return;

    if (res['clear'] == true) {
      await repo.saveAndSync(<String, dynamic>{'daily_calories_target': null});
      unawaited(ForegroundNotificationPrefs.updateCalorieGoal(0));
      ref.invalidate(dailyCaloriesGoalProvider);
      ref.invalidate(dashboardDataProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Using calculated daily calories from your profile')),
      );
      return;
    }

    final raw = res['value'];
    if (raw is! int) return;
    final clamped = raw.clamp(800, 8000);
    await repo.saveAndSync(<String, dynamic>{'daily_calories_target': clamped});
    unawaited(ForegroundNotificationPrefs.updateCalorieGoal(clamped));

    ref.invalidate(dailyCaloriesGoalProvider);
    ref.invalidate(dashboardDataProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Daily calorie goal updated to $clamped kcal')),
    );
  }

  Future<void> _editStepGoal(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(profileRepositoryProvider);
    final current = await repo.readLocalProfile();
    final existing = (current?['step_goal'] as int?) ??
        int.tryParse((current?['step_goal'] ?? '').toString());

    if (!context.mounted) return;

    final controller = TextEditingController(
      text: existing == null ? '' : existing.toString(),
    );

    final res = await showDialog<int?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Daily step goal'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'e.g. 10000',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final v = int.tryParse(controller.text.trim());
                Navigator.of(ctx).pop(v);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (res == null) return;
    final clamped = res.clamp(10, 1000000);
    await repo.saveAndSync({'step_goal': clamped});
    unawaited(ForegroundNotificationPrefs.updateStepGoal(clamped));

    // Update UI immediately across the app.
    ref.invalidate(stepGoalProvider);
    ref.invalidate(activityDataProvider);
    ref.invalidate(dashboardDataProvider);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Step goal updated to $clamped steps')),
    );
  }

  Widget _buildAccountSafety(BuildContext context, WidgetRef ref, UserProfile data) {
    final publicLb = ref.watch(publicLeaderboardProvider);

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
                publicLb.when(
                  loading: () => const ListTile(
                    title: Text('Public leaderboard'),
                    subtitle: Text('Loading…'),
                  ),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (enabled) => SwitchListTile(
                    title: Text(
                      'Public leaderboard',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: textDark,
                      ),
                    ),
                    subtitle: Text(
                      'Show your name and steps on Today / This month rankings',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: textLight,
                      ),
                    ),
                    value: enabled,
                    activeThumbColor: primary,
                    onChanged: (value) async {
                      final repo = ref.read(profileRepositoryProvider);
                      final synced = await repo.setPublicOnLeaderboard(value);
                      if (value) {
                        await StepsOfflineRecorder.flushTodayStepsForLeaderboard();
                      }
                      ref.invalidate(publicLeaderboardProvider);
                      ref.invalidate(leaderboardProvider);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            !synced
                                ? 'Saved on this device — will sync when you\'re back online'
                                : value
                                    ? 'You joined the public leaderboard'
                                    : 'You left the public leaderboard',
                          ),
                        ),
                      );
                    },
                  ),
                ),
                InkWell(
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const HealthProfileScreen(isEditing: true),
                      ),
                    );
                    if (!context.mounted) return;
                    await ref.read(profileProvider.notifier).reloadFromRepo();
                    ref.invalidate(avatarUrlProvider);
                    ref.invalidate(genderProvider);
                    ref.invalidate(dashboardDataProvider);
                    ref.invalidate(stepGoalProvider);
                    ref.invalidate(dailyCaloriesGoalProvider);
                  },
                  child: _buildListTile(
                    icon: Icons.edit_note,
                    title: 'Edit Health Profile',
                    trailing: const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1)),
                    showBorder: false,
                    isMinimal: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _invalidateSessionCaches(WidgetRef ref) {
    ref.invalidate(authInitializationProvider);
    ref.invalidate(dashboardDataProvider);
    ref.invalidate(profileProvider);
    ref.invalidate(stepGoalProvider);
    ref.invalidate(dailyCaloriesGoalProvider);
    ref.invalidate(avatarUrlProvider);
    ref.invalidate(genderProvider);
    ref.invalidate(activityDataProvider);
    ref.invalidate(yesterdayStepsLocalProvider);
    ref.invalidate(stepsTodayProvider);
    ref.invalidate(nutritionHistoryProvider);
    ref.invalidate(leaderboardProvider);
    ref.invalidate(safetyHubProvider);
    ref.invalidate(healthProfileProvider);
  }

  Widget _buildSignOutButton(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: () async {
                await ref.read(authProvider.notifier).signOut();
                _invalidateSessionCaches(ref);
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                  (_) => false,
                );
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
          // Removed app version/edition footer per request.
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
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: showBorder
              ? const Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))
              : null,
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
                      fontWeight:
                          isMinimal ? FontWeight.normal : FontWeight.w600,
                      color: textDark,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(fontSize: 13, color: textLight),
                    ),
                  ],
                ],
              ),
            ),
            trailing,
          ],
        ),
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
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}

