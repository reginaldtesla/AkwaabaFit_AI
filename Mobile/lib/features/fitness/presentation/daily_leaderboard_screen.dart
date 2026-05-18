import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:mobile/shared/connectivity/connectivity_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/dashboard/presentation/dashboard_screen.dart';
import 'package:mobile/features/fitness/presentation/activity_tracking_screen.dart';
import 'package:mobile/features/nutrition/presentation/nutrition_history_screen.dart';
import 'package:mobile/features/profile/presentation/profile_settings_screen.dart';
import 'package:mobile/features/safety/presentation/health_safety_hub_screen.dart';
import 'package:mobile/features/telehealth/presentation/tele_dietetics_screen.dart';
import 'package:mobile/shared/config/app_config.dart';
import 'package:mobile/shared/navigation/app_bottom_nav.dart';
import 'package:mobile/shared/profile/profile_repository.dart';

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

bool _mapLooksLikeLeaderboardRow(Map<String, dynamic> row) {
  return row.containsKey('total_steps') ||
      row.containsKey('step_count') ||
      (row.containsKey('id') && row.containsKey('name'));
}

/// Normalizes diverse API shapes (pagination wrappers, nested `data`, numeric-key
/// objects, JSON strings, etc.) into a flat list of row maps. Never throws.
List<Map<String, dynamic>> _coerceLeaderboardRowMaps(dynamic node) {
  if (node == null) return [];

  if (node is String) {
    final trimmed = node.trim();
    if (trimmed.isEmpty) return [];
    try {
      return _coerceLeaderboardRowMaps(jsonDecode(trimmed));
    } catch (_) {
      return [];
    }
  }

  if (node is List) {
    final out = <Map<String, dynamic>>[];
    for (final item in node) {
      if (item is Map) {
        out.add(item.map((k, v) => MapEntry(k.toString(), v)));
      }
    }
    return out;
  }

  if (node is! Map) return [];

  final m = node.map((k, v) => MapEntry(k.toString(), v));

  for (final key in [
    'data',
    'items',
    'results',
    'rows',
    'records',
    'entries',
    'leaderboard',
    'users',
  ]) {
    final v = m[key];
    if (v is List) {
      final nested = _coerceLeaderboardRowMaps(v);
      if (nested.isNotEmpty) return nested;
    }
    if (v is Map) {
      final nested = _coerceLeaderboardRowMaps(v);
      if (nested.isNotEmpty) return nested;
    }
  }

  final ints = <int>[];
  var allNumericKeys = true;
  for (final k in m.keys) {
    final n = int.tryParse(k);
    if (n == null) {
      allNumericKeys = false;
      break;
    }
    ints.add(n);
  }
  if (allNumericKeys && ints.isNotEmpty) {
    ints.sort();
    final out = <Map<String, dynamic>>[];
    for (final n in ints) {
      final v = m[n.toString()];
      if (v is Map) {
        out.add(v.map((k, val) => MapEntry(k.toString(), val)));
      }
    }
    return out;
  }

  if (_mapLooksLikeLeaderboardRow(m)) return [m];

  final gathered = <Map<String, dynamic>>[];
  for (final v in m.values) {
    if (v is Map) {
      final row = v.map((k, val) => MapEntry(k.toString(), val));
      if (_mapLooksLikeLeaderboardRow(row)) gathered.add(row);
    }
  }
  return gathered;
}

List<Map<String, dynamic>> _leaderboardRowsFromEnvelope(Map<String, dynamic> json) {
  final fromData = _coerceLeaderboardRowMaps(json['data']);
  if (fromData.isNotEmpty) return fromData;
  return _coerceLeaderboardRowMaps(json);
}

final leaderboardProvider = FutureProvider<List<LeaderboardUser>>((ref) async {
  const storage = FlutterSecureStorage();
  final token = await storage.read(key: 'sanctum_token');
  if (token == null || token.isEmpty) {
    throw Exception('Missing auth token. Please login again.');
  }

  if (!await isDeviceOnline()) {
    throw Exception('LEADERBOARD_OFFLINE');
  }

  final base = AppConfig.apiBaseUrl.endsWith('/')
      ? AppConfig.apiBaseUrl
      : '${AppConfig.apiBaseUrl}/';
  final dio = Dio(
    BaseOptions(
      baseUrl: base,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ),
  );

  // Local profile gives us the current user id/name if available.
  final localProfile = await ref.read(profileRepositoryProvider).readLocalProfile();
  final currentUserIdRaw = localProfile?['id'] ?? localProfile?['user_id'];
  final currentUserId = currentUserIdRaw?.toString();

  // Always fetch "me" rank (cheap) so we can highlight/append user.
  Map<String, dynamic>? me;
  try {
    // Important: do NOT prefix with "/" or Dio will drop the "/api" base path.
    final meResp = await dio.get('leaderboard/daily/me');
    if (meResp.data is Map) {
      me = (meResp.data as Map).map((k, v) => MapEntry(k.toString(), v));
    }
  } catch (_) {
    me = null;
  }

  String ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<Map<String, dynamic>> fetchBoard(DateTime date) async {
    final resp = await dio.get(
      'leaderboard/daily',
      queryParameters: {'date': ymd(date)},
    );
    final raw = resp.data;
    if (raw is List) {
      return {'data': raw};
    }
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return {'data': decoded};
        if (decoded is Map) {
          return decoded.map((k, v) => MapEntry(k.toString(), v));
        }
      } catch (_) {
        // Fall through.
      }
      throw Exception('Unexpected leaderboard response.');
    }
    if (raw is! Map) throw Exception('Unexpected leaderboard response.');
    return raw.map((k, v) => MapEntry(k.toString(), v));
  }

  // Fetch today. If empty, fallback to yesterday.
  var json = await fetchBoard(DateTime.now());
  var list = _leaderboardRowsFromEnvelope(json);
  if (list.isEmpty) {
    json = await fetchBoard(DateTime.now().subtract(const Duration(days: 1)));
    list = _leaderboardRowsFromEnvelope(json);
  }

  final users = <LeaderboardUser>[];
  for (var i = 0; i < list.length; i++) {
    final row = list[i];
    final id = (row['id'] ?? '').toString();
    final name = (row['name'] ?? '').toString();
    final steps = (row['total_steps'] as num?)?.toInt() ??
        (row['step_count'] as num?)?.toInt() ??
        0;
    final avatarRaw = (row['avatar_url'] ?? row['avatarUrl'])?.toString() ?? '';
    final avatarUrl = avatarRaw.isEmpty ? '' : AppConfig.normalizeUrlForDevice(avatarRaw);
    final location = (row['location'] ?? '').toString();
    final isMe = currentUserId != null && id == currentUserId;
    users.add(
      LeaderboardUser(
        id: id,
        rank: i + 1,
        name: isMe ? 'You' : name,
        location: location,
        steps: steps,
        imageUrl: avatarUrl,
        isCurrentUser: isMe,
      ),
    );
  }

  // If I'm opted-in and not in the top 50, append my rank line so I still see it.
  final optedIn = (me?['optedIn'] == true);
  final meUser = me?['user'];
  final meId = (meUser is Map ? meUser['id'] : null)?.toString() ?? currentUserId;
  final meAvatarRaw = (meUser is Map ? (meUser['avatar_url'] ?? meUser['avatarUrl']) : null)
          ?.toString() ??
      '';
  final meAvatarUrl =
      meAvatarRaw.isEmpty ? '' : AppConfig.normalizeUrlForDevice(meAvatarRaw);
  final meLocation = (meUser is Map ? meUser['location'] : null)?.toString() ?? '';
  final meRank = (me?['rank'] as num?)?.toInt();
  final meSteps = (me?['stepsToday'] as num?)?.toInt();
  final alreadyInTop = users.any((u) => u.id == meId);
  if (optedIn && meId != null && meRank != null && meSteps != null && !alreadyInTop) {
    users.add(
      LeaderboardUser(
        id: meId,
        rank: meRank,
        name: 'You',
        location: meLocation.isNotEmpty ? meLocation : 'Your rank',
        steps: meSteps,
        imageUrl: meAvatarUrl,
        isCurrentUser: true,
      ),
    );
  }

  return users;
});

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
  Duration _timeLeft = Duration.zero;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _meRowKey = GlobalKey();
  bool _didAutoScrollToMe = false;
  /// Tracks local calendar day so we refresh leaderboard & countdown at midnight.
  int? _lastLocalDayKey;

  int _localDayKey(DateTime d) =>
      d.year * 10000 + d.month * 100 + d.day;

  Future<bool> _isOnline() async => isDeviceOnline();

  @override
  void initState() {
    super.initState();
    _lastLocalDayKey = _localDayKey(DateTime.now());
    _timeLeft = _untilNextLocalMidnight();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      final dayKey = _localDayKey(now);
      if (_lastLocalDayKey != null && dayKey != _lastLocalDayKey) {
        // Local midnight passed — new “today” for leaderboard & countdown.
        ref.invalidate(leaderboardProvider);
        _didAutoScrollToMe = false;
      }
      _lastLocalDayKey = dayKey;
      setState(() => _timeLeft = _untilNextLocalMidnight());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Duration _untilNextLocalMidnight() {
    final now = DateTime.now();
    final nextMidnight =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final d = nextMidnight.difference(now);
    // Clock skew / edge at rollover: treat non-positive as “just hit midnight”.
    if (d <= Duration.zero) {
      return Duration.zero;
    }
    return d;
  }

  String get _formattedTimeLeft {
    String two(int n) => n.toString().padLeft(2, '0');
    final secs = _timeLeft.inSeconds.clamp(0, 86400);
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    final s = secs % 60;
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
          data: (users) {
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
          MaterialPageRoute(builder: (_) => const TeleDieteticsScreen()),
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
    return Row(
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
                'Today • Steps',
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

