import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/shared/config/app_config.dart';
import 'package:mobile/shared/connectivity/connectivity_utils.dart';
import 'package:mobile/shared/fitness/steps_offline_recorder.dart';
import 'package:mobile/shared/offline/sqlite_offline_db.dart';

enum LeaderboardPeriod { day, month }

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.id,
    required this.rank,
    required this.name,
    required this.steps,
    required this.avatarUrl,
    required this.isMe,
  });

  final String id;
  final int rank;
  final String name;
  final int steps;
  final String avatarUrl;
  final bool isMe;
}

class LeaderboardMe {
  const LeaderboardMe({
    required this.optedIn,
    required this.steps,
    required this.inList,
    this.rank,
  });

  final bool optedIn;
  final int steps;
  final bool inList;
  final int? rank;
}

class LeaderboardSnapshot {
  const LeaderboardSnapshot({
    required this.entries,
    required this.me,
    required this.period,
    this.fromCache = false,
  });

  final List<LeaderboardEntry> entries;
  final LeaderboardMe me;
  final LeaderboardPeriod period;
  final bool fromCache;
}

final leaderboardPeriodProvider = StateProvider<LeaderboardPeriod>(
  (ref) => LeaderboardPeriod.day,
);

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

String _periodQuery(LeaderboardPeriod period) =>
    period == LeaderboardPeriod.month ? 'month' : 'day';

String _cacheKey(LeaderboardPeriod period, DateTime now) {
  if (period == LeaderboardPeriod.month) {
    final ym =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
    return 'month:$ym';
  }
  final ymd =
      '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  return 'day:$ymd';
}

LeaderboardSnapshot _snapshotFromJson(
  Map<String, dynamic> json,
  LeaderboardPeriod period, {
  required bool fromCache,
}) {
  final entriesRaw = json['entries'];
  final entries = <LeaderboardEntry>[];
  if (entriesRaw is List) {
    for (final item in entriesRaw) {
      if (item is! Map) continue;
      final row = item.map((k, v) => MapEntry(k.toString(), v));
      final avatarRaw = (row['avatar_url'] ?? '').toString();
      entries.add(
        LeaderboardEntry(
          id: (row['id'] ?? '').toString(),
          rank: _parseInt(row['rank']) ?? (entries.length + 1),
          name: (row['name'] ?? '').toString(),
          steps: _parseInt(row['steps']) ?? 0,
          avatarUrl: avatarRaw.isEmpty
              ? ''
              : AppConfig.normalizeUrlForDevice(avatarRaw),
          isMe: row['is_me'] == true || row['is_me'] == 1,
        ),
      );
    }
  }

  final meRaw = json['me'];
  final meMap = meRaw is Map
      ? meRaw.map((k, v) => MapEntry(k.toString(), v))
      : <String, dynamic>{};
  final me = LeaderboardMe(
    optedIn: meMap['opted_in'] == true || meMap['opted_in'] == 1,
    steps: _parseInt(meMap['steps']) ?? 0,
    inList: meMap['in_list'] == true || meMap['in_list'] == 1,
    rank: _parseInt(meMap['rank']),
  );

  return LeaderboardSnapshot(
    entries: entries,
    me: me,
    period: period,
    fromCache: fromCache,
  );
}

Map<String, dynamic> _jsonForCache(Map<String, dynamic> json) {
  return {
    'entries': json['entries'],
    'me': json['me'],
  };
}

final leaderboardProvider =
    FutureProvider.autoDispose<LeaderboardSnapshot>((ref) async {
  final period = ref.watch(leaderboardPeriodProvider);
  final now = DateTime.now();
  final key = _cacheKey(period, now);
  final db = await SqliteOfflineDb.getInstance();

  if (!await isDeviceOnline()) {
    final cached = await db.getLeaderboardCache(key);
    if (cached != null) {
      return _snapshotFromJson(cached, period, fromCache: true);
    }
    throw Exception('LEADERBOARD_OFFLINE');
  }

  // Push the phone's current today total before ranking so the board matches Stride.
  await StepsOfflineRecorder.flushTodayStepsForLeaderboard();

  const storage = FlutterSecureStorage();
  final token = await storage.read(key: 'sanctum_token');
  if (token == null || token.isEmpty) {
    throw Exception('Missing auth token. Please login again.');
  }

  final base = AppConfig.apiBaseUrl.endsWith('/')
      ? AppConfig.apiBaseUrl
      : '${AppConfig.apiBaseUrl}/';
  final dio = Dio(
    BaseOptions(
      baseUrl: base,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 8),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ),
  );

  final query = <String, dynamic>{'period': _periodQuery(period)};
  if (period == LeaderboardPeriod.month) {
    query['month'] =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
  } else {
    query['date'] =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  try {
    final resp = await dio.get('leaderboard/daily', queryParameters: query);
    final raw = resp.data;
    if (raw is! Map) {
      throw Exception('Unexpected leaderboard response.');
    }
    final json = raw.map((k, v) => MapEntry(k.toString(), v));
    await db.putLeaderboardCache(key, _jsonForCache(json));
    return _snapshotFromJson(json, period, fromCache: false);
  } catch (e) {
    final cached = await db.getLeaderboardCache(key);
    if (cached != null) {
      return _snapshotFromJson(cached, period, fromCache: true);
    }
    rethrow;
  }
});
