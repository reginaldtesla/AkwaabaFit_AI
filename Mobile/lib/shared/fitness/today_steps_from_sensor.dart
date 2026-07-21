import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Today's steps from the cumulative pedometer counter.
///
/// Android `TYPE_STEP_COUNTER` / iOS pedometer totals are since last reboot.
/// After a reboot the counter restarts near 0 while a stored baseline can still
/// be large — we reset the baseline and **carry forward** steps already counted
/// today so Stride and the notification stay aligned.
final class TodayStepsFromSensor {
  TodayStepsFromSensor({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  String _baselineKey(DateTime d) =>
      'steps_baseline_${d.toIso8601String().substring(0, 10)}';

  String _carryKey(DateTime d) =>
      'steps_carry_${d.toIso8601String().substring(0, 10)}';

  String? _sessionDayKey;
  bool? _hadStoredBaselineAtSessionStart;
  int? baseline;
  int? lastTotal;
  int carry = 0;

  Future<void> _ensureSessionForClock(DateTime now) async {
    final key = _baselineKey(now);
    if (_sessionDayKey == key) return;

    _sessionDayKey = key;
    final stored = await _storage.read(key: key);
    final parsed = stored != null ? int.tryParse(stored) : null;
    baseline = parsed;
    _hadStoredBaselineAtSessionStart = parsed != null;
    lastTotal = null;
    carry = int.tryParse(await _storage.read(key: _carryKey(now)) ?? '') ?? 0;
  }

  /// Updates state from cumulative [sensorTotal] and returns steps walked today.
  ///
  /// [floor] is the last persisted today total (SQLite / secure storage). Used
  /// when the counter resets so we do not drop steps already earned today.
  Future<int> update(
    int sensorTotal, {
    DateTime? clock,
    int floor = 0,
  }) async {
    final now = clock ?? DateTime.now();
    await _ensureSessionForClock(now);
    final baselineKey = _baselineKey(now);
    final carryKey = _carryKey(now);

    if (floor > carry) {
      carry = floor;
      await _storage.write(key: carryKey, value: carry.toString());
    }

    // Reboot / sensor reset: cumulative total dropped below the stored baseline.
    if (baseline != null && sensorTotal < baseline!) {
      final countedBeforeReset = lastTotal != null
          ? (lastTotal! - baseline!).clamp(0, 1 << 31)
          : 0;
      carry = (carry + countedBeforeReset).clamp(0, 1 << 31);
      if (floor > carry) {
        carry = floor;
      }
      await _storage.write(key: carryKey, value: carry.toString());
      baseline = sensorTotal;
      await _storage.write(key: baselineKey, value: baseline.toString());
      _hadStoredBaselineAtSessionStart = true;
    }

    final beforeBaseline = baseline;
    baseline ??= sensorTotal;
    if (_hadStoredBaselineAtSessionStart != true && beforeBaseline == null) {
      await _storage.write(key: baselineKey, value: baseline.toString());
    }

    // Mid-session drop (some OEMs reset the counter without a full reboot).
    if (lastTotal != null && sensorTotal < lastTotal!) {
      final countedBeforeReset = (lastTotal! - (baseline ?? lastTotal!))
          .clamp(0, 1 << 31);
      carry = (carry + countedBeforeReset).clamp(0, 1 << 31);
      if (floor > carry) {
        carry = floor;
      }
      await _storage.write(key: carryKey, value: carry.toString());
      baseline = sensorTotal;
      await _storage.write(key: baselineKey, value: baseline.toString());
    }
    lastTotal = sensorTotal;

    final b = baseline ?? 0;
    final fromSensor = (sensorTotal - b).clamp(0, 1 << 31);
    final total = (fromSensor + carry).clamp(0, 1 << 31);
    // Never go below the last saved today count (keeps UI + notification aligned).
    return total < floor ? floor : total;
  }
}
