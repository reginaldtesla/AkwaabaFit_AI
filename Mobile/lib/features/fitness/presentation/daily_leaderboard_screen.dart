import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/dashboard/presentation/dashboard_screen.dart';
import 'package:mobile/features/fitness/presentation/activity_tracking_screen.dart';
import 'package:mobile/features/nutrition/presentation/nutrition_history_screen.dart';
import 'package:mobile/features/profile/presentation/profile_settings_screen.dart';
import 'package:mobile/features/safety/presentation/health_safety_hub_screen.dart';
import 'package:mobile/shared/fitness/leaderboard_provider.dart';
import 'package:mobile/shared/navigation/app_bottom_nav.dart';

export 'package:mobile/shared/fitness/leaderboard_provider.dart'
    show LeaderboardEntry, LeaderboardPeriod, leaderboardProvider;

class DailyLeaderboardScreen extends ConsumerWidget {
  const DailyLeaderboardScreen({super.key});

  static const Color _primary = Color(0xFF1A5D1A);
  static const Color _ink = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _rule = Color(0xFFE2E8F0);
  static const Color _meTint = Color(0xFFECF4EC);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(leaderboardPeriodProvider);
    final state = ref.watch(leaderboardProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: AppBottomNav(
        activeTab: AppTab.stats,
        onTabSelected: (tab) => _handleTab(context, tab),
      ),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: Text(
          'Leaderboard',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SegmentedButton<LeaderboardPeriod>(
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStatePropertyAll(
                  GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              segments: const [
                ButtonSegment(
                  value: LeaderboardPeriod.day,
                  label: Text('Day'),
                ),
                ButtonSegment(
                  value: LeaderboardPeriod.month,
                  label: Text('Month'),
                ),
              ],
              selected: {period},
              onSelectionChanged: (next) {
                ref.read(leaderboardPeriodProvider.notifier).state = next.first;
              },
            ),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: _primary),
        ),
        error: (err, _) {
          final offline = err.toString().contains('LEADERBOARD_OFFLINE');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    offline ? Icons.wifi_off_rounded : Icons.error_outline,
                    size: 40,
                    color: _muted,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    offline
                        ? 'Leaderboard needs internet'
                        : 'Could not load leaderboard',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    offline
                        ? 'Connect to Wi‑Fi or mobile data, then try again.'
                        : 'Pull to refresh or try again in a moment.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: _muted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => ref.invalidate(leaderboardProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        },
        data: (snapshot) {
          return RefreshIndicator(
            color: _primary,
            onRefresh: () async {
              ref.invalidate(leaderboardProvider);
              await ref.read(leaderboardProvider.future);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (!snapshot.me.optedIn)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _rule),
                        ),
                        child: Text(
                          'Turn on “Public leaderboard” in Profile to join the rankings.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: _ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (snapshot.me.optedIn &&
                    snapshot.me.rank != null &&
                    !snapshot.me.inList)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text(
                        'Your rank: #${snapshot.me.rank} · ${_formatSteps(snapshot.me.steps)} steps',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _muted,
                        ),
                      ),
                    ),
                  ),
                if (snapshot.entries.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        'No rankings yet. Walk and opt in to appear here.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _muted,
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    sliver: SliverList.separated(
                      itemCount: snapshot.entries.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final entry = snapshot.entries[index];
                        return _LeaderboardRow(entry: entry);
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _formatSteps(int steps) {
    final digits = steps.toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return buf.toString();
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
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final isMe = entry.isMe;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? DailyLeaderboardScreen._meTint : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe
              ? DailyLeaderboardScreen._primary.withValues(alpha: 0.25)
              : DailyLeaderboardScreen._rule,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '#${entry.rank}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: DailyLeaderboardScreen._ink,
              ),
            ),
          ),
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFE2E8F0),
            backgroundImage: entry.avatarUrl.isNotEmpty
                ? NetworkImage(entry.avatarUrl)
                : null,
            child: entry.avatarUrl.isEmpty
                ? Text(
                    (isMe ? 'Y' : entry.name).isNotEmpty
                        ? (isMe ? 'Y' : entry.name)[0].toUpperCase()
                        : '?',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: DailyLeaderboardScreen._muted,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isMe ? 'You' : entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: DailyLeaderboardScreen._ink,
              ),
            ),
          ),
          Text(
            DailyLeaderboardScreen._formatSteps(entry.steps),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: DailyLeaderboardScreen._primary,
            ),
          ),
        ],
      ),
    );
  }
}
