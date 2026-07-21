import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/dashboard/presentation/dashboard_screen.dart';
import 'package:mobile/features/fitness/presentation/activity_tracking_screen.dart';
import 'package:mobile/features/nutrition/presentation/nutrition_history_screen.dart';
import 'package:mobile/features/profile/presentation/profile_settings_screen.dart';
import 'package:mobile/features/safety/presentation/health_safety_hub_screen.dart';
import 'package:mobile/shared/config/app_config.dart';
import 'package:mobile/shared/fitness/leaderboard_provider.dart';
import 'package:mobile/shared/navigation/app_bottom_nav.dart';

export 'package:mobile/shared/fitness/leaderboard_provider.dart'
    show LeaderboardEntry, LeaderboardPeriod, leaderboardProvider;

class DailyLeaderboardScreen extends ConsumerStatefulWidget {
  const DailyLeaderboardScreen({super.key});

  /// Matches Stride / dashboard brand greens (not the mock’s purple).
  static const Color _forest = Color(0xFF0F3D1F);
  static const Color _primary = Color(0xFF1A5D1A);
  static const Color _ink = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _meTint = Color(0xFFECF4EC);
  static const Color _gold = Color(0xFFF59E0B);
  static const Color _silver = Color(0xFF94A3B8);
  static const Color _bronze = Color(0xFFD97706);

  @override
  ConsumerState<DailyLeaderboardScreen> createState() =>
      _DailyLeaderboardScreenState();

  static String formatSteps(int steps) {
    final digits = steps.toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return buf.toString();
  }
}

class _DailyLeaderboardScreenState
    extends ConsumerState<DailyLeaderboardScreen> {
  bool _offlineDialogVisible = false;

  Future<void> _reload() async {
    ref.invalidate(leaderboardProvider);
    try {
      await ref.read(leaderboardProvider.future);
    } catch (_) {}
  }

  Future<void> _showOfflineDialog() async {
    if (!mounted || _offlineDialogVisible) return;
    _offlineDialogVisible = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        var refreshing = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              icon: Icon(
                Icons.wifi_off_rounded,
                size: 40,
                color: DailyLeaderboardScreen._muted,
              ),
              title: Text(
                'No internet connection',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: DailyLeaderboardScreen._ink,
                ),
              ),
              content: Text(
                'The leaderboard needs Wi‑Fi or mobile data. Connect, then tap Refresh.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.4,
                  color: DailyLeaderboardScreen._muted,
                ),
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                FilledButton.icon(
                  onPressed: refreshing
                      ? null
                      : () async {
                          setDialogState(() => refreshing = true);
                          await _reload();
                          if (!dialogContext.mounted) return;
                          final stillOffline = ref
                              .read(leaderboardProvider)
                              .hasError;
                          if (!stillOffline) {
                            Navigator.of(dialogContext).pop();
                            return;
                          }
                          setDialogState(() => refreshing = false);
                        },
                  icon: refreshing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded, size: 20),
                  label: Text(refreshing ? 'Checking…' : 'Refresh'),
                  style: FilledButton.styleFrom(
                    backgroundColor: DailyLeaderboardScreen._primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (mounted) {
      _offlineDialogVisible = false;
    }
  }

  static bool _isOfflineError(Object err) =>
      err.toString().contains('LEADERBOARD_OFFLINE');

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(leaderboardPeriodProvider);
    final state = ref.watch(leaderboardProvider);

    ref.listen<AsyncValue<LeaderboardSnapshot>>(leaderboardProvider,
        (previous, next) {
      next.whenOrNull(
        error: (err, _) {
          if (_isOfflineError(err)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showOfflineDialog();
            });
          }
        },
      );
    });

    return Scaffold(
      backgroundColor: DailyLeaderboardScreen._forest,
      bottomNavigationBar: AppBottomNav(
        activeTab: AppTab.stats,
        onTabSelected: (tab) => _handleTab(context, tab),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF14532D),
              Color(0xFF1A5D1A),
              Color(0xFF0F3D1F),
            ],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _Header(
                period: period,
                onPeriodChanged: (next) {
                  ref.read(leaderboardPeriodProvider.notifier).state = next;
                },
                onBack: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const ActivityTrackingScreen(),
                      ),
                    );
                  }
                },
              ),
              Expanded(
                child: state.when(
                  skipLoadingOnReload: true,
                  skipLoadingOnRefresh: true,
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  error: (err, _) => _ErrorBody(
                    offline: _isOfflineError(err),
                    onRetry: () async {
                      if (_isOfflineError(err)) {
                        await _showOfflineDialog();
                      } else {
                        await _reload();
                      }
                    },
                  ),
                  data: (snapshot) => RefreshIndicator(
                    color: DailyLeaderboardScreen._primary,
                    backgroundColor: Colors.white,
                    onRefresh: _reload,
                    child: _LeaderboardScroll(snapshot: snapshot),
                  ),
                ),
              ),
            ],
          ),
        ),
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
}

class _Header extends StatelessWidget {
  const _Header({
    required this.period,
    required this.onPeriodChanged,
    required this.onBack,
  });

  final LeaderboardPeriod period;
  final ValueChanged<LeaderboardPeriod> onPeriodChanged;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                color: Colors.white,
              ),
              Expanded(
                child: Text(
                  'Leaderboard',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 10),
          _PeriodPill(
            period: period,
            onChanged: onPeriodChanged,
          ),
        ],
      ),
    );
  }
}

class _PeriodPill extends StatelessWidget {
  const _PeriodPill({required this.period, required this.onChanged});

  final LeaderboardPeriod period;
  final ValueChanged<LeaderboardPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          _seg(
            label: 'Today',
            selected: period == LeaderboardPeriod.day,
            onTap: () => onChanged(LeaderboardPeriod.day),
          ),
          _seg(
            label: 'This Month',
            selected: period == LeaderboardPeriod.month,
            onTap: () => onChanged(LeaderboardPeriod.month),
          ),
        ],
      ),
    );
  }

  Widget _seg({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? DailyLeaderboardScreen._primary : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : DailyLeaderboardScreen._muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _LeaderboardScroll extends StatelessWidget {
  const _LeaderboardScroll({required this.snapshot});

  final LeaderboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final entries = snapshot.entries;
    final top = entries.take(3).toList();
    final rest = entries.length > 3 ? entries.sublist(3) : <LeaderboardEntry>[];

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (!snapshot.me.optedIn)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Text(
                  'Turn on “Public leaderboard” in Profile to join the rankings.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
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
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Your rank: #${snapshot.me.rank} · ${DailyLeaderboardScreen.formatSteps(snapshot.me.steps)} steps',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
          ),
        if (entries.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No rankings yet. Walk and opt in to appear here.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ),
          )
        else ...[
          if (top.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                child: _Podium(top: top),
              ),
            ),
          if (rest.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              sliver: SliverList.separated(
                itemCount: rest.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return _RankCard(entry: rest[index]);
                },
              ),
            ),
        ],
      ],
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.top});

  final List<LeaderboardEntry> top;

  LeaderboardEntry? _at(int rank) {
    for (final e in top) {
      if (e.rank == rank) return e;
    }
    if (rank >= 1 && rank <= top.length) return top[rank - 1];
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final first = _at(1);
    final second = _at(2);
    final third = _at(3);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: second == null
              ? const SizedBox.shrink()
              : _PodiumPerson(
                  entry: second,
                  avatarRadius: 36,
                  badgeColor: DailyLeaderboardScreen._silver,
                  lift: 8,
                ),
        ),
        Expanded(
          child: first == null
              ? const SizedBox.shrink()
              : _PodiumPerson(
                  entry: first,
                  avatarRadius: 48,
                  badgeColor: DailyLeaderboardScreen._gold,
                  lift: 28,
                  emphasize: true,
                ),
        ),
        Expanded(
          child: third == null
              ? const SizedBox.shrink()
              : _PodiumPerson(
                  entry: third,
                  avatarRadius: 36,
                  badgeColor: DailyLeaderboardScreen._bronze,
                  lift: 0,
                ),
        ),
      ],
    );
  }
}

class _PodiumPerson extends StatelessWidget {
  const _PodiumPerson({
    required this.entry,
    required this.avatarRadius,
    required this.badgeColor,
    required this.lift,
    this.emphasize = false,
  });

  final LeaderboardEntry entry;
  final double avatarRadius;
  final Color badgeColor;
  final double lift;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final name = entry.isMe ? 'You' : entry.name;
    return Padding(
      padding: EdgeInsets.only(bottom: lift),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: emphasize
                        ? DailyLeaderboardScreen._gold
                        : Colors.white.withValues(alpha: 0.85),
                    width: emphasize ? 3 : 2,
                  ),
                  boxShadow: emphasize
                      ? [
                          BoxShadow(
                            color: DailyLeaderboardScreen._gold
                                .withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
                child: _Avatar(
                  url: entry.avatarUrl,
                  name: name,
                  radius: avatarRadius,
                ),
              ),
              Positioned(
                bottom: -6,
                child: Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '${entry.rank}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            DailyLeaderboardScreen.formatSteps(entry.steps),
            style: GoogleFonts.plusJakartaSans(
              fontSize: emphasize ? 22 : 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankCard extends StatelessWidget {
  const _RankCard({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final isMe = entry.isMe;
    final name = isMe ? 'You' : entry.name;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? DailyLeaderboardScreen._meTint : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${entry.rank}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: DailyLeaderboardScreen._ink,
              ),
            ),
          ),
          _Avatar(url: entry.avatarUrl, name: name, radius: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
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
            '${DailyLeaderboardScreen.formatSteps(entry.steps)} pts',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: DailyLeaderboardScreen._primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.url,
    required this.name,
    required this.radius,
  });

  final String url;
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final resolved = url.trim().isEmpty
        ? ''
        : AppConfig.normalizeUrlForDevice(url.trim());

    Widget placeholder() => CircleAvatar(
          radius: radius,
          backgroundColor: const Color(0xFFE2E8F0),
          child: Text(
            initial,
            style: GoogleFonts.inter(
              fontSize: radius * 0.7,
              fontWeight: FontWeight.w700,
              color: DailyLeaderboardScreen._muted,
            ),
          ),
        );

    if (resolved.isEmpty) return placeholder();

    return ClipOval(
      child: Image.network(
        resolved,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            width: radius * 2,
            height: radius * 2,
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: DailyLeaderboardScreen._primary,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.offline, required this.onRetry});

  final bool offline;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: DailyLeaderboardScreen._primary,
      backgroundColor: Colors.white,
      onRefresh: onRetry,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
          Icon(
            offline ? Icons.wifi_off_rounded : Icons.error_outline,
            size: 40,
            color: Colors.white.withValues(alpha: 0.85),
          ),
          const SizedBox(height: 12),
          Text(
            offline
                ? 'Leaderboard needs internet'
                : 'Could not load leaderboard',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              offline
                  ? 'Connect to Wi‑Fi or mobile data, then try again.'
                  : 'Pull down to refresh or tap Retry.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.8),
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton(
              onPressed: () => onRetry(),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: DailyLeaderboardScreen._primary,
              ),
              child: const Text('Retry'),
            ),
          ),
        ],
      ),
    );
  }
}
