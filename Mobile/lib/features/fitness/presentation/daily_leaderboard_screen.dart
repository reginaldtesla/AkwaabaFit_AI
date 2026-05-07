import 'dart:async';

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

class LeaderboardUser {
  final String id;
  final int rank;
  final String name;
  final String location;
  final int steps;
  final String imageUrl;
  final bool isCurrentUser;

  LeaderboardUser({
    required this.id,
    required this.rank,
    required this.name,
    required this.location,
    required this.steps,
    required this.imageUrl,
    this.isCurrentUser = false,
  });
}

final leaderboardProvider = FutureProvider<List<LeaderboardUser>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 600));
  return [
    LeaderboardUser(
      id: '1',
      rank: 1,
      name: 'Kofi A.',
      location: 'Accra',
      steps: 14200,
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDTlj8NjID93AWcaBayTFZZZl1ckYmpUJkDyiVAXdXX60HF7S0jEESs5w2MTdpoHs4G664K-kCR9euYRkkPrXlhkFGZPn-ambCKPZr54OrLao_k1YI4a4nOLNM4QQeGmJBDf8EcUbQLezuIPEv_0aKgJTAMHojdkeCAHpP-MqzXkfqkeu0Y67_3CdajSF-63xHHag9Eaa27DXZHg3ip46oFnSICxZuJd7PutPdjH9iOBesom0dsOToiYTqyTZuChVrQKcRvMjT4DbQ',
    ),
    LeaderboardUser(
      id: '2',
      rank: 2,
      name: 'Ama O.',
      location: 'Accra',
      steps: 12400,
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCnG4BQ3fH2h0YN5UfcBsBzlUES0hVo-8qihn6_69bEBmXhKU4s6e4CzK7T9runBjLFx9OC-n5cVnQ1dYKBseDnU1C_3hbaB1EQJdeOlLVw9h4PCopvw7IhepotAL5MMphyavSQURNPOW9fREhyZWG4uV0K-KAqcQFq9_aoFxHn1tMwdH497tD2tkRe9_u5pRC1E27Tc2vCXqOxuIbWZt9RA0yl2dd9Hrbd0JUsnH18bDt274WnR49eNIYsqurv78QuR3SfH0_F_6I',
    ),
    LeaderboardUser(
      id: '3',
      rank: 3,
      name: 'Esi K.',
      location: 'Accra',
      steps: 11800,
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBiFy7_F8Xy7JKWwUNtlXahvSJeVoexYgfNnFskDshOGJwu6IWscYllnYro-wF6mBA-JryoZnPQBod6ga37UeLbpyhIZHL9eRzKeN9lPK2mtKllQUpUpfeh3qqOZyeRMLHghgb1TY9cCPuIds1Lvvkgi8eonTbQyKrmQwWzp1Br5SIV2XsR5jPlzOoAsqHiJSMRxMuBkKmaOVARgtk5MF4Ko0EsW6jyzIhbNdavhA5WkbEHbxALAL4LhU0ib8SR5TMn8Ah9vb43XTE',
    ),
    LeaderboardUser(
      id: '4',
      rank: 4,
      name: 'Kwame M.',
      location: 'Accra Ridge',
      steps: 9840,
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDnhLWAPMXriZav51p9hxojvb4hFs_AnODKvWRWfIBika04EmUaQSz5Hh6KkaLGi55VBAiK4qGb12XB4YH8nroQB7X51jJU6cZq4Tra8wZPIUmjlfnoF1CwqKRi9H9Oqzwa1zSwR7fBfnB6yWdtzldaoyodNb8-Iw3y1T3X2tIrBG0AkKSe1gMW91gjIRyHgcSEbVA5dA3amWeDs3eWpKm06VRJpFIv8UfW3_7OfL92ga1ApmAGaf5jdC_a1Xy7e7oISPt7erLQUMA',
    ),
    LeaderboardUser(
      id: '5',
      rank: 5,
      name: 'Yaa A.',
      location: 'East Legon',
      steps: 8420,
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCHkL7EA-TGoytX8TdTbojqgqKk8sIaWP3xxjPH5i8N2Qh-llgOAvfs3HgVUgDj0iANz_IV7fzeHlWsPTuFVM7R_t55VE1IrUdbqTou6LGHlh8wHh4ldmFILID_czM6GGVpGE9K-iZP4GmfrYNjnKw4nYDSANVoI3Z57Ov_lkmrpMrZ7NgymMCSCwM2cbZ9u0dOwahnvgnPx7KvNyHxRMzvo8s-eNJs5UMlFNYMEsSz8nxm-GIVH54Rj3GYKdkiUgPHecZej_yE12I',
    ),
    LeaderboardUser(
      id: '6',
      rank: 6,
      name: 'You',
      location: 'Current Rank',
      steps: 7150,
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAEznOiLxBqQUeXGp9XrHOVsBDpYSGbokiVEoGH10OZ0wU1V-UCVH3ajRcGYa1gZzCmKjVhVONxEvmbboMi68Am6T7p0UMxXpZ8CoxXXvRhh3op-WaL0dZ_cRCIObMhhvjJ1NyAbkY0_eu8PHqbjgEKfiXs4rioSbe_lZXNyRtO2JIUbuTtA1189pwCZGCcLTSb8DT_SYoTrln7XNNlZfjTq1hT0U68G02CJ3nb3evn3R2v_qjZx1KbXICtunGWWtAnYsn9zATcdnM',
      isCurrentUser: true,
    ),
    LeaderboardUser(
      id: '7',
      rank: 7,
      name: 'Abena S.',
      location: 'Osu',
      steps: 6900,
      imageUrl: '',
    ),
  ];
});

// =====================================================================
// 2. THE UI SCREEN
// =====================================================================

class DailyLeaderboardScreen extends ConsumerStatefulWidget {
  const DailyLeaderboardScreen({super.key});

  @override
  ConsumerState<DailyLeaderboardScreen> createState() => _DailyLeaderboardScreenState();
}

class _DailyLeaderboardScreenState extends ConsumerState<DailyLeaderboardScreen>
    with SingleTickerProviderStateMixin {
  final Color primary = const Color(0xFF0A2E1F);
  final Color bgLight = const Color(0xFFFDFBF7);
  final Color surface = const Color(0xFFFFFFFF);
  final Color textMain = const Color(0xFF1A1A1A);
  final Color textMuted = const Color(0xFF8C8C8C);
  final Color accent = const Color(0xFFD4AF37);

  late Timer _timer;
  Duration _timeLeft = const Duration(hours: 4, minutes: 12, seconds: 59);
  late AnimationController _bounceController;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_timeLeft.inSeconds > 0) {
        setState(() => _timeLeft -= const Duration(seconds: 1));
      } else {
        _timer.cancel();
      }
    });

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer.cancel();
    _bounceController.dispose();
    super.dispose();
  }

  String get formattedTime {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final h = twoDigits(_timeLeft.inHours);
    final m = twoDigits(_timeLeft.inMinutes.remainder(60));
    final s = twoDigits(_timeLeft.inSeconds.remainder(60));
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final leaderboardState = ref.watch(leaderboardProvider);

    return Scaffold(
      backgroundColor: bgLight,
      bottomNavigationBar: AppBottomNav(
        activeTab: AppTab.stats,
        onTabSelected: (tab) => _handleTab(context, tab),
      ),
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: leaderboardState.when(
              loading: () => Center(child: CircularProgressIndicator(color: primary)),
              error: (err, stack) => const Center(child: Text('Error loading leaderboard')),
              data: (users) {
                if (users.length < 3) return const Center(child: Text('Not enough data.'));
                final topThree = users.sublist(0, 3);
                final others = users.sublist(3);

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          const SizedBox(height: 56),
                          _buildHeader(),
                          const SizedBox(height: 24),
                          _buildPodium(topThree),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildRankCard(others[index]),
                          childCount: others.length,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Positioned(top: 0, left: 0, right: 0, child: _buildCountdownBanner()),
        ],
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

  // --- UI Components ---

  Widget _buildCountdownBanner() {
    return Container(
      color: textMain,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'ENDS IN',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: surface,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formattedTime,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          'Daily Leaderboard',
          style: GoogleFonts.playfairDisplay(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: primary,
            height: 1.2,
          ),
        ),
        Text(
          'Accra Community Challenge',
          style: GoogleFonts.spaceGrotesk(fontSize: 14, color: textMuted),
        ),
      ],
    );
  }

  Widget _buildPodium(List<LeaderboardUser> topThree) {
    return SizedBox(
      height: 260,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(child: _buildPodiumColumn(topThree[1], 100, const Color(0xFFE5E5E5))),
          Expanded(child: _buildPodiumColumn(topThree[0], 140, primary, isFirst: true)),
          Expanded(child: _buildPodiumColumn(topThree[2], 80, const Color(0xFFE5E5E5))),
        ],
      ),
    );
  }

  Widget _buildPodiumColumn(
    LeaderboardUser user,
    double barHeight,
    Color barColor, {
    bool isFirst = false,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (isFirst)
          AnimatedBuilder(
            animation: _bounceController,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, -5 * _bounceController.value),
              child: Icon(Icons.workspace_premium, color: accent, size: 36),
            ),
          ),
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              width: isFirst ? 80 : 64,
              height: isFirst ? 80 : 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isFirst ? accent : bgLight, width: 4),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
                image: DecorationImage(image: NetworkImage(user.imageUrl), fit: BoxFit.cover),
              ),
            ),
            Positioned(
              bottom: -10,
              child: Container(
                width: isFirst ? 32 : 24,
                height: isFirst ? 32 : 24,
                decoration: BoxDecoration(
                  color: isFirst ? accent : surface,
                  shape: BoxShape.circle,
                  border: isFirst ? null : Border.all(color: textMuted),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                ),
                alignment: Alignment.center,
                child: Text(
                  '${user.rank}',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: isFirst ? 14 : 12,
                    fontWeight: FontWeight.bold,
                    color: isFirst ? surface : textMain,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          user.name,
          style: GoogleFonts.spaceGrotesk(
            fontSize: isFirst ? 16 : 14,
            fontWeight: FontWeight.bold,
            color: isFirst ? primary : textMain,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '${(user.steps / 1000).toStringAsFixed(1)}k',
          style: GoogleFonts.spaceGrotesk(
            fontSize: isFirst ? 14 : 12,
            fontWeight: FontWeight.bold,
            color: primary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: barHeight,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            boxShadow: isFirst
                ? [
                    const BoxShadow(
                      color: Color.fromRGBO(10, 46, 31, 0.1),
                      blurRadius: 12,
                      offset: Offset(0, -4),
                    ),
                  ]
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildRankCard(LeaderboardUser user) {
    final isMe = user.isCurrentUser;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe ? primary : surface,
        borderRadius: BorderRadius.circular(12),
        border: isMe ? null : Border.all(color: Colors.grey.shade100),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(10, 46, 31, 0.08),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (isMe)
            Positioned.fill(
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [accent.withOpacity(0.2), Colors.transparent],
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                  ),
                ),
              ),
            ),
          Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  '${user.rank}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isMe ? surface : textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  shape: BoxShape.circle,
                  border: isMe ? Border.all(color: accent, width: 2) : null,
                  image: user.imageUrl.isNotEmpty
                      ? DecorationImage(image: NetworkImage(user.imageUrl), fit: BoxFit.cover)
                      : null,
                ),
                child: user.imageUrl.isEmpty
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isMe ? surface : textMain,
                      ),
                    ),
                    Text(
                      user.location,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        color: isMe ? accent : textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${user.steps}',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isMe ? accent : primary,
                    ),
                  ),
                  Text(
                    'STEPS',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isMe ? surface.withOpacity(0.8) : textMuted,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

