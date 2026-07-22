import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Today's steps from the cumulative pedometer counter.
///
/// Android `TYPE_STEP_COUNTER` / iOS pedometer totals are since last reboot.
/// Today = (sensorTotal − day's baseline) + carry-from-before-reboot.
///
/// Never clamps to a "max daily steps". Inflation is prevented by locking the
/// baseline correctly and refusing to latch a poisoned floor into [carry].
final class TodayStepsFromSensor {
  TodayStepsFromSensor({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Ignore one-tick jumps larger than this (sensor glitches / baseline loss).
  static const int maxTickDelta = 8000;

  final FlutterSecureStorage _storage;

  String _baselineKey(DateTime d) =>
      'steps_baseline_${d.toIso8601String().substring(0, 10)}';

  String _carryKey(DateTime d) =>
      // v2: ignore carry poisoned by the old floor-latch bug (no daily max).
      'steps_carry_v2_${d.toIso8601String().substring(0, 10)}';

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
    if (carry < 0) carry = 0;
  }

  /// Updates state from cumulative [sensorTotal] and returns steps walked today.
  ///
  /// [floor] is the last persisted today total (SQLite / secure storage). Used
  /// only as a soft floor when it closely matches the sensor-derived total —
  /// never as a permanent latch (that was how cumulative leaks stuck at 1M+).
  Future<int> update(
    int sensorTotal, {
    DateTime? clock,
    int floor = 0,
  }) async {
    final now = clock ?? DateTime.now();
    await _ensureSessionForClock(now);
    final baselineKey = _baselineKey(now);
    final carryKey = _carryKey(now);
    final safeFloor = floor < 0 ? 0 : floor;

    // True reboot / sensor reset: cumulative total dropped below the stored baseline.
    if (baseline != null && sensorTotal < baseline!) {
      final countedBeforeReset = lastTotal != null
          ? (lastTotal! - baseline!).clamp(0, lastTotal!)
          : 0;
      carry = carry + countedBeforeReset;
      // Soft-adopt floor only when it is near what we just counted (UI lag).
      if (safeFloor > carry && safeFloor - carry <= maxTickDelta) {
        carry = safeFloor;
      }
      await _storage.write(key: carryKey, value: carry.toString());
      baseline = sensorTotal;
      await _storage.write(key: baselineKey, value: baseline.toString());
      _hadStoredBaselineAtSessionStart = true;
    }

    // First reading of the day: lock baseline to the cumulative counter.
    // Never treat a lone 0 as the permanent baseline if a later reading is large
    // (that yields today ≈ full since-reboot total).
    final beforeBaseline = baseline;
    if (baseline == null) {
      baseline = sensorTotal;
      if (_hadStoredBaselineAtSessionStart != true) {
        await _storage.write(key: baselineKey, value: baseline.toString());
      }
    } else if (beforeBaseline == 0 &&
        sensorTotal > maxTickDelta &&
        (lastTotal == null || lastTotal == 0)) {
      baseline = sensorTotal;
      await _storage.write(key: baselineKey, value: baseline.toString());
      _hadStoredBaselineAtSessionStart = true;
      lastTotal = sensorTotal;
      // Do not return a huge poisoned floor; sensor says we just started counting.
      if (safeFloor > 0 && safeFloor <= maxTickDelta) {
        return safeFloor;
      }
      return 0;
    }

    // Mid-session drop: only treat as a real counter reset when the drop is large.
    // Tiny OEM glitches (sensorTotal slightly < lastTotal) must not zero the baseline.
    if (lastTotal != null &&
        sensorTotal < lastTotal! &&
        (lastTotal! - sensorTotal) >= maxTickDelta) {
      final countedBeforeReset =
          (lastTotal! - (baseline ?? lastTotal!)).clamp(0, lastTotal!);
      carry = carry + countedBeforeReset;
      if (safeFloor > carry && safeFloor - carry <= maxTickDelta) {
        carry = safeFloor;
      }
      await _storage.write(key: carryKey, value: carry.toString());
      baseline = sensorTotal;
      await _storage.write(key: baselineKey, value: baseline.toString());
    }

    final previousLast = lastTotal;
    final previousBaseline = baseline;
    lastTotal = sensorTotal;

    final b = baseline ?? 0;
    var fromSensor = sensorTotal >= b ? sensorTotal - b : 0;

    // Reject absurd single-tick jumps (usually means baseline was lost).
    // Re-anchor so today's count stays continuous with the last good total.
    if (previousLast != null &&
        previousBaseline != null &&
        sensorTotal > previousLast &&
        (sensorTotal - previousLast) > maxTickDelta) {
      final previousToday =
          (previousLast - previousBaseline).clamp(0, previousLast) + carry;
      final keep = (safeFloor > 0 &&
              (safeFloor - previousToday).abs() <= maxTickDelta)
          ? safeFloor
          : previousToday;
      baseline = sensorTotal - keep.clamp(0, sensorTotal);
      if (baseline! < 0) baseline = sensorTotal;
      await _storage.write(key: baselineKey, value: baseline.toString());
      fromSensor = sensorTotal - baseline!;
      if (fromSensor < 0) fromSensor = 0;
      // Carry already folded into [keep]; avoid double-counting.
      carry = 0;
      await _storage.write(key: carryKey, value: '0');
      return fromSensor;
    }

    final total = fromSensor + carry;

    // Soft floor only: brief sensor lag, not a poisoned cache latch.
    if (safeFloor > total && safeFloor - total <= maxTickDelta) {
      return safeFloor;
    }
    return total < 0 ? 0 : total;
  }
}
