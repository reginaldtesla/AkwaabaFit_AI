import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/shared/config/app_config.dart';
import 'package:mobile/shared/connectivity/connectivity_utils.dart';

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
  });

  final List<LeaderboardEntry> entries;
  final LeaderboardMe me;
  final LeaderboardPeriod period;
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

final leaderboardProvider =
    FutureProvider.autoDispose<LeaderboardSnapshot>((ref) async {
  final period = ref.watch(leaderboardPeriodProvider);

  if (!await isDeviceOnline()) {
    throw Exception('LEADERBOARD_OFFLINE');
  }

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
  if (raw is! Map) {
    throw Exception('Unexpected leaderboard response.');
  }
  final json = raw.map((k, v) => MapEntry(k.toString(), v));

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
  );
});
