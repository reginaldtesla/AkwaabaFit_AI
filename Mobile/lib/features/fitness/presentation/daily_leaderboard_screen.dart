import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/dashboard/presentation/dashboard_screen.dart';
import 'package:mobile/features/fitness/presentation/activity_tracking_screen.dart';
import 'package:mobile/features/nutrition/presentation/nutrition_history_screen.dart';
import 'package:mobile/features/profile/presentation/profile_settings_screen.dart';
import 'package:mobile/features/safety/presentation/health_safety_hub_screen.dart';
import 'package:mobile/shared/connectivity/connectivity_utils.dart';
import 'package:mobile/shared/fitness/leaderboard_provider.dart';
import 'package:mobile/shared/fitness/leaderboard_refresh_bus.dart';
import 'package:mobile/shared/navigation/app_bottom_nav.dart';

export 'package:mobile/shared/fitness/leaderboard_provider.dart'
    show LeaderboardUser, leaderboardProvider;

// =====================================================================
// 2. THE UI SCREEN
// =====================================================================

class DailyLeaderboardScreen extends ConsumerStatefulWidget {
  const DailyLeaderboardScreen({super.key});

  @override
  ConsumerState<DailyLeaderboardScreen> createState() =>
      _DailyLeaderboardScreenState();
}

class _DailyLeaderboardScreenState extends ConsumerState<DailyLeaderboardScreen> {
  static const Color secondaryBlue = Color(0xFF3B82F6);
  /// Matches dashboard brand green — first-place podium pillar.
  static const Color podiumFirstGreen = Color(0xFF1A5D1A);
  /// Muted dusty sage — second place (not bright).
  static const Color podiumSecondMuted = Color(0xFFB9C4B6);
  /// Muted blue-grey — third place (not bright).
  static const Color podiumThirdMuted = Color(0xFFB8C0C9);
  static const Color slateCustom = Color(0xFF64748B);
  static const Color cardBg = Color(0xFFFAFAFA);
  static const Color textDark = Color(0xFF0F172A);
  static const Color gold = Color(0xFFF59E0B);
  static const Color goldDeep = Color(0xFFD97706);

  late Timer _timer;
  StreamSubscription<void>? _refreshSub;
  Duration _timeLeft = Duration.zero;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _meRowKey = GlobalKey();
  bool _didAutoScrollToMe = false;
  int? _lastLocalMonthKey;
  String? _lastLocalDayKey;

  int _localMonthKey(DateTime d) => d.year * 100 + d.month;

  String _localDayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<bool> _isOnline() async => isDeviceOnline();

  void _bumpLeaderboardRefresh() {
    ref.read(leaderboardRefreshTickProvider.notifier).state++;
    ref.invalidate(leaderboardProvider);
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _lastLocalMonthKey = _localMonthKey(now);
    _lastLocalDayKey = _localDayKey(now);
    _timeLeft = _untilEndOfPeriod(ref.read(leaderboardPeriodProvider));
    _refreshSub = LeaderboardRefreshBus.stream.listen((_) {
      if (!mounted) return;
      _bumpLeaderboardRefresh();
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final tick = DateTime.now();
      final monthKey = _localMonthKey(tick);
      final dayKey = _localDayKey(tick);
      if (_lastLocalMonthKey != null && monthKey != _lastLocalMonthKey) {
        _bumpLeaderboardRefresh();
        _didAutoScrollToMe = false;
      }
      if (_lastLocalDayKey != null && dayKey != _lastLocalDayKey) {
        _bumpLeaderboardRefresh();
        _didAutoScrollToMe = false;
      }
      _lastLocalMonthKey = monthKey;
      _lastLocalDayKey = dayKey;
      setState(
        () => _timeLeft = _untilEndOfPeriod(ref.read(leaderboardPeriodProvider)),
      );
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _refreshSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Duration _untilEndOfPeriod(LeaderboardPeriod period) {
    final now = DateTime.now();
    if (period == LeaderboardPeriod.day) {
      final midnight = DateTime(now.year, now.month, now.day + 1);
      final d = midnight.difference(now);
      return d <= Duration.zero ? Duration.zero : d;
    }
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    final d = nextMonth.difference(now);
    return d <= Duration.zero ? Duration.zero : d;
  }

  String get _monthLabel {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final now = DateTime.now();
    return '${months[now.month - 1]} ${now.year}';
  }

  String get _periodSubtitle {
    final period = ref.watch(leaderboardPeriodProvider);
    if (period == LeaderboardPeriod.day) {
      return 'Resets at midnight';
    }
    return '$_monthLabel Monthly steps Public members only';
  }

  String get _formattedTimeLeft {
    String two(int n) => n.toString().padLeft(2, '0');
    final secs = _timeLeft.inSeconds.clamp(0, 86400 * 31);
    final days = secs ~/ 86400;
    final rem = secs % 86400;
    final h = rem ~/ 3600;
    final m = (rem % 3600) ~/ 60;
    final s = rem % 60;
    if (days > 0) {
      return '${days}d ${two(h)}:${two(m)}:${two(s)}';
    }
    return '${two(h)}:${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final leaderboardState = ref.watch(leaderboardProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: AppBottomNav(
        activeTab: AppTab.stats,
        onTabSelected: (tab) => _handleTab(context, tab),
      ),
      body: SafeArea(
        bottom: false,
        child: leaderboardState.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: secondaryBlue)),
          error: (err, stack) {
            final msg = err.toString();
            final offline = msg.contains('LEADERBOARD_OFFLINE');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      offline ? Icons.wifi_off_rounded : Icons.error_outline,
                      size: 40,
                      color: slateCustom,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      offline
                          ? 'Leaderboard needs internet'
                          : 'Leaderboard unavailable',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      offline
                          ? 'Connect to Wi‑Fi or mobile data to load rankings. Other tabs work offline.'
                          : msg,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: slateCustom,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          data: (snapshot) {
            final users = snapshot.users;
            if (users.isEmpty) {
              return Center(
                child: Text(
                  'No leaderboard data yet.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: slateCustom,
                  ),
                ),
              );
            }

            final sorted = [...users]..sort((a, b) => a.rank.compareTo(b.rank));
            final me = sorted.where((u) => u.isCurrentUser).toList();
            final meUser = me.isEmpty ? null : me.first;
            final showNotTop50Banner =
                meUser != null && meUser.rank > 50 && meUser.steps >= 0;
            final showNotOnBoardBanner = meUser == null;
            final topThree = sorted.length >= 3 ? sorted.sublist(0, 3) : sorted;
            final others = sorted.length > 3 ? sorted.sublist(3) : const <LeaderboardUser>[];

            if (!_didAutoScrollToMe &&
                meUser != null &&
                meUser.rank > 3 &&
                others.any((u) => u.isCurrentUser)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final ctx = _meRowKey.currentContext;
                if (ctx == null) return;
                Scrollable.ensureVisible(
                  ctx,
                  alignment: 0.2,
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                );
              });
              _didAutoScrollToMe = true;
            }

            return RefreshIndicator(
              color: secondaryBlue,
              onRefresh: () async {
                final online = await _isOnline();
                if (!online) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'No internet connection — showing last loaded leaderboard.',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                  return;
                }
                _didAutoScrollToMe = false;
                ref.invalidate(leaderboardProvider);
                await ref.read(leaderboardProvider.future);
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                controller: _scrollController,
                slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: _buildHeader(context),
                  ),
                ),
                if (snapshot.fromCache)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade100),
                        ),
                        child: Text(
                          'Showing last saved rankings — pull down to refresh when online.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (showNotOnBoardBanner)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.blueGrey.shade100),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              color: Colors.blueGrey.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "You're not on the leaderboard yet. Turn on “Public leaderboard” in Profile to join.",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  height: 1.35,
                                  fontWeight: FontWeight.w700,
                                  color: textDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (showNotTop50Banner)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: gold.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: gold.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: goldDeep,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "You're not in the Top 50 yet. Your rank is #${meUser.rank} — keep going!",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  height: 1.35,
                                  fontWeight: FontWeight.w700,
                                  color: textDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (topThree.length >= 3)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: _buildPodium(topThree),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildRankCard(others[index]),
                      childCount: others.length,
                    ),
                  ),
                ),
                ],
              ),
            );
          },
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

  // --- UI Components ---

  Widget _buildHeader(BuildContext context) {
    final period = ref.watch(leaderboardPeriodProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blueGrey.shade100),
                ),
                child: Icon(Icons.arrow_back, color: Colors.blueGrey.shade700, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Leaderboard',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _periodSubtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: slateCustom,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: secondaryBlue.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                    border:
                        Border.all(color: secondaryBlue.withValues(alpha: 0.18)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_outlined,
                          size: 16, color: Colors.blueGrey.shade700),
                      const SizedBox(width: 6),
                      Text(
                        _formattedTimeLeft,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: textDark,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: gold.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.emoji_events_rounded,
                          size: 16, color: goldDeep),
                      const SizedBox(width: 6),
                      Text(
                        'Top 50',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: goldDeep,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<LeaderboardPeriod>(
            segments: const [
              ButtonSegment(
                value: LeaderboardPeriod.day,
                label: Text('Today'),
              ),
              ButtonSegment(
                value: LeaderboardPeriod.month,
                label: Text('This month'),
              ),
            ],
            selected: {period},
            onSelectionChanged: (selected) {
              final next = selected.first;
              ref.read(leaderboardPeriodProvider.notifier).state = next;
              _didAutoScrollToMe = false;
              setState(() => _timeLeft = _untilEndOfPeriod(next));
              ref.invalidate(leaderboardProvider);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPodium(List<LeaderboardUser> topThree) {
    return SizedBox(
      height: 300,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child:
                _buildPodiumColumn(topThree[1], 88, podiumSecondMuted),
          ),
          Expanded(
            child: _buildPodiumColumn(topThree[0], 120, podiumFirstGreen,
                isFirst: true),
          ),
          Expanded(
            child:
                _buildPodiumColumn(topThree[2], 72, podiumThirdMuted),
          ),
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
          Icon(Icons.workspace_premium, color: gold, size: 34),
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              width: isFirst ? 80 : 64,
              height: isFirst ? 80 : 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isFirst ? gold : Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 10,
                  ),
                ],
                image: user.imageUrl.isNotEmpty
                    ? DecorationImage(image: NetworkImage(user.imageUrl), fit: BoxFit.cover)
                    : null,
              ),
              child: user.imageUrl.isEmpty
                  ? Center(
                      child: Text(
                        user.name.isNotEmpty ? user.name.characters.first : '?',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: isFirst ? 26 : 22,
                          fontWeight: FontWeight.bold,
                          color: textDark,
                        ),
                      ),
                    )
                  : null,
            ),
            Positioned(
              bottom: -10,
              child: Container(
                width: isFirst ? 32 : 24,
                height: isFirst ? 32 : 24,
                decoration: BoxDecoration(
                  color: isFirst ? gold : Colors.white,
                  shape: BoxShape.circle,
                  border: isFirst ? null : Border.all(color: Colors.blueGrey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 6,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  '${user.rank}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: isFirst ? 14 : 12,
                    fontWeight: FontWeight.bold,
                    color: isFirst ? Colors.white : textDark,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          user.name,
          style: GoogleFonts.plusJakartaSans(
            fontSize: isFirst ? 14 : 12,
            fontWeight: FontWeight.bold,
            color: textDark,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '${(user.steps / 1000).toStringAsFixed(1)}k',
          style: GoogleFonts.plusJakartaSans(
            fontSize: isFirst ? 12 : 11,
            fontWeight: FontWeight.bold,
            color: slateCustom,
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
                    BoxShadow(
                      color: podiumFirstGreen.withValues(alpha: 0.28),
                      blurRadius: 14,
                      offset: const Offset(0, -4),
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

    return KeyedSubtree(
      key: isMe ? _meRowKey : null,
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe ? secondaryBlue : cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueGrey.shade50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 6),
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
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [gold.withValues(alpha: 0.20), Colors.transparent],
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
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isMe ? Colors.white : slateCustom,
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
                  border: isMe ? Border.all(color: gold, width: 2) : null,
                  image: user.imageUrl.isNotEmpty
                      ? DecorationImage(image: NetworkImage(user.imageUrl), fit: BoxFit.cover)
                      : null,
                ),
                child: user.imageUrl.isEmpty
                    ? Center(
                        child: Text(
                          user.name.isNotEmpty ? user.name.characters.first : '?',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isMe ? Colors.white : textDark,
                      ),
                    ),
                    Text(
                      user.location,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: isMe ? gold.withValues(alpha: 0.95) : slateCustom,
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
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isMe ? gold : textDark,
                    ),
                  ),
                  Text(
                    'STEPS',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color:
                          isMe ? Colors.white.withValues(alpha: 0.85) : slateCustom,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }
}

