import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Matches [stepsTodayProvider]: today's steps = cumulative sensor total minus
/// the baseline stored under `steps_baseline_<yyyy-mm-dd>`.
final class TodayStepsFromSensor {
  TodayStepsFromSensor({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  String _dayKey(DateTime d) =>
      'steps_baseline_${d.toIso8601String().substring(0, 10)}';

  String? _sessionDayKey;
  bool? _hadStoredBaselineAtSessionStart;
  int? baseline;
  int? lastTotal;

  Future<void> _ensureSessionForClock(DateTime now) async {
    final key = _dayKey(now);
    if (_sessionDayKey == key) return;

    _sessionDayKey = key;
    final stored = await _storage.read(key: key);
    final parsed = stored != null ? int.tryParse(stored) : null;
    baseline = parsed;
    _hadStoredBaselineAtSessionStart = parsed != null;
    lastTotal = null;
  }

  /// Updates state from cumulative [sensorTotal] and returns steps walked today.
  Future<int> update(int sensorTotal, {DateTime? clock}) async {
    final now = clock ?? DateTime.now();
    await _ensureSessionForClock(now);
    final key = _dayKey(now);

    final beforeBaseline = baseline;
    baseline ??= sensorTotal;
    if (_hadStoredBaselineAtSessionStart != true && beforeBaseline == null) {
      await _storage.write(key: key, value: baseline.toString());
    }

    if (lastTotal != null && sensorTotal < lastTotal!) {
      baseline = sensorTotal;
      await _storage.write(key: key, value: baseline.toString());
    }
    lastTotal = sensorTotal;

    final b = baseline ?? 0;
    return (sensorTotal - b).clamp(0, 1 << 31);
  }
}
