import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/shared/config/app_config.dart';
import 'package:mobile/shared/connectivity/connectivity_utils.dart';
import 'package:mobile/shared/fitness/leaderboard_refresh_bus.dart';
import 'package:mobile/shared/offline/sqlite_offline_db.dart';
import 'package:mobile/shared/profile/profile_repository.dart';

enum LeaderboardPeriod { day, month }

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

final leaderboardPeriodProvider = StateProvider<LeaderboardPeriod>(
  (ref) => LeaderboardPeriod.day,
);

class LeaderboardSnapshot {
  final List<LeaderboardUser> users;
  final bool fromCache;

  const LeaderboardSnapshot({
    required this.users,
    this.fromCache = false,
  });
}

bool mapLooksLikeLeaderboardRow(Map<String, dynamic> row) {
  return row.containsKey('total_steps') ||
      row.containsKey('step_count') ||
      (row.containsKey('id') && row.containsKey('name'));
}

List<Map<String, dynamic>> coerceLeaderboardRowMaps(dynamic node) {
  if (node == null) return [];

  if (node is String) {
    final trimmed = node.trim();
    if (trimmed.isEmpty) return [];
    try {
      return coerceLeaderboardRowMaps(jsonDecode(trimmed));
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
      final nested = coerceLeaderboardRowMaps(v);
      if (nested.isNotEmpty) return nested;
    }
    if (v is Map) {
      final nested = coerceLeaderboardRowMaps(v);
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

  if (mapLooksLikeLeaderboardRow(m)) return [m];
  return [];
}

int? parseLeaderboardInt(dynamic value, {int? fallback}) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return fallback;
}

String _cacheKeyFor(LeaderboardPeriod period) {
  final now = DateTime.now();
  if (period == LeaderboardPeriod.month) {
    final month =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
    return 'month:$month';
  }
  final day =
      '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  return 'day:$day';
}

String _periodQuery(LeaderboardPeriod period) =>
    period == LeaderboardPeriod.month ? 'month' : 'day';

Future<List<LeaderboardUser>> _usersFromApiMaps({
  required List<Map<String, dynamic>> list,
  required Map<String, dynamic>? me,
  required String? currentUserId,
}) {
  final users = <LeaderboardUser>[];
  for (var i = 0; i < list.length; i++) {
    final row = list[i];
    final id = (row['id'] ?? '').toString();
    final name = (row['name'] ?? '').toString();
    final steps = parseLeaderboardInt(
      row['total_steps'],
      fallback: parseLeaderboardInt(row['step_count']),
    ) ?? 0;
    final avatarRaw = (row['avatar_url'] ?? row['avatarUrl'])?.toString() ?? '';
    final avatarUrl =
        avatarRaw.isEmpty ? '' : AppConfig.normalizeUrlForDevice(avatarRaw);
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

  final optedIn = me?['optedIn'] == true;
  final meUser = me?['user'];
  final meId =
      (meUser is Map ? meUser['id'] : null)?.toString() ?? currentUserId;
  final meAvatarRaw =
      (meUser is Map ? (meUser['avatar_url'] ?? meUser['avatarUrl']) : null)
              ?.toString() ??
          '';
  final meAvatarUrl =
      meAvatarRaw.isEmpty ? '' : AppConfig.normalizeUrlForDevice(meAvatarRaw);
  final meLocation =
      (meUser is Map ? meUser['location'] : null)?.toString() ?? '';
  final meRank = parseLeaderboardInt(me?['rank']);
  final meSteps = parseLeaderboardInt(me?['stepsToday']) ??
      parseLeaderboardInt(me?['stepsThisMonth']);
  final alreadyInTop = users.any((u) => u.id == meId);
  if (optedIn &&
      meId != null &&
      meRank != null &&
      meSteps != null &&
      !alreadyInTop) {
    users.add(
      LeaderboardUser(
        id: meId,
        rank: meRank,
        name: 'You',
        location: meLocation,
        steps: meSteps,
        imageUrl: meAvatarUrl,
        isCurrentUser: true,
      ),
    );
  }

  return Future.value(users);
}

List<LeaderboardUser> _usersFromCachedJson(Map<String, dynamic> cached) {
  final rawUsers = cached['users'];
  if (rawUsers is! List) return [];
  return rawUsers
      .whereType<Map>()
      .map((row) {
        final m = row.map((k, v) => MapEntry(k.toString(), v));
        return LeaderboardUser(
          id: (m['id'] ?? '').toString(),
          rank: parseLeaderboardInt(m['rank']) ?? 0,
          name: (m['name'] ?? '').toString(),
          location: (m['location'] ?? '').toString(),
          steps: parseLeaderboardInt(m['steps']) ?? 0,
          imageUrl: (m['imageUrl'] ?? '').toString(),
          isCurrentUser: m['isCurrentUser'] == true,
        );
      })
      .toList();
}

Map<String, dynamic> _cachePayloadFromUsers(List<LeaderboardUser> users) {
  return {
    'users': users
        .map(
          (u) => {
            'id': u.id,
            'rank': u.rank,
            'name': u.name,
            'location': u.location,
            'steps': u.steps,
            'imageUrl': u.imageUrl,
            'isCurrentUser': u.isCurrentUser,
          },
        )
        .toList(),
    'cachedAt': DateTime.now().toIso8601String(),
  };
}

final leaderboardProvider =
    FutureProvider.autoDispose<LeaderboardSnapshot>((ref) async {
  final period = ref.watch(leaderboardPeriodProvider);
  ref.watch(leaderboardRefreshTickProvider);

  const storage = FlutterSecureStorage();
  final token = await storage.read(key: 'sanctum_token');
  if (token == null || token.isEmpty) {
    throw Exception('Missing auth token. Please login again.');
  }

  final cacheKey = _cacheKeyFor(period);
  final db = await SqliteOfflineDb.getInstance();

  Future<LeaderboardSnapshot?> loadCache() async {
    final cached = await db.getLeaderboardCache(cacheKey);
    if (cached == null) return null;
    final users = _usersFromCachedJson(cached);
    if (users.isEmpty) return null;
    return LeaderboardSnapshot(users: users, fromCache: true);
  }

  if (!await isDeviceOnline()) {
    final cached = await loadCache();
    if (cached != null) return cached;
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

  final localProfile =
      await ref.read(profileRepositoryProvider).readLocalProfile();
  final currentUserIdRaw = localProfile?['id'] ?? localProfile?['user_id'];
  final currentUserId = currentUserIdRaw?.toString();

  Map<String, dynamic>? me;
  try {
    final meResp = await dio.get(
      'leaderboard/daily/me',
      queryParameters: {'period': _periodQuery(period)},
    );
    if (meResp.data is Map) {
      me = (meResp.data as Map).map((k, v) => MapEntry(k.toString(), v));
    }
  } catch (_) {
    me = null;
  }

  Future<Map<String, dynamic>> fetchBoard() async {
    final now = DateTime.now();
    final query = <String, dynamic>{'period': _periodQuery(period)};
    if (period == LeaderboardPeriod.month) {
      query['month'] =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
    } else {
      query['date'] =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    }

    final resp = await dio.get('leaderboard/daily', queryParameters: query);
    final raw = resp.data;
    if (raw is List) return {'data': raw};
    if (raw is String) {
      final decoded = jsonDecode(raw);
      if (decoded is List) return {'data': decoded};
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
      throw Exception('Unexpected leaderboard response.');
    }
    if (raw is! Map) throw Exception('Unexpected leaderboard response.');
    return raw.map((k, v) => MapEntry(k.toString(), v));
  }

  try {
    final json = await fetchBoard();
    final list = coerceLeaderboardRowMaps(json);
    final users = await _usersFromApiMaps(
      list: list,
      me: me,
      currentUserId: currentUserId,
    );
    await db.putLeaderboardCache(cacheKey, _cachePayloadFromUsers(users));
    return LeaderboardSnapshot(users: users);
  } catch (_) {
    final cached = await loadCache();
    if (cached != null) return cached;
    rethrow;
  }
});

/// Bumped when steps sync or connectivity returns so leaderboard refetches.
final leaderboardRefreshTickProvider = StateProvider<int>((ref) => 0);

void requestLeaderboardRefresh() {
  LeaderboardRefreshBus.notify();
}
